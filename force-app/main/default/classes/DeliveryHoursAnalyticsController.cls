/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides per-month hours analytics for a WorkItem__c tree.
 *              Walks the parent-child hierarchy via ParentWorkItemLookup__c, sums
 *              WorkLog__c.HoursLoggedNumber__c grouped by CALENDAR_MONTH(WorkDateDate__c),
 *              and returns monthly buckets paired with a per-month linear-amortized
 *              estimate target derived from WorkItem__c.EstimatedHoursNumber__c +
 *              EstimatedStartDevDate__c/EstimatedEndDevDate__c when those are populated.
 *              Backs the deliveryProjectMonthlyHours record-page LWC.
 *
 *              Also exposes getPortfolioPacing — an account/org-level pacing +
 *              forecast across ALL active root WorkItems (not a single record),
 *              bucketed at Week/Month/Quarter granularity, with per-period
 *              targets and a schedule-based forecast (each in-flight item's
 *              remaining estimate spread across its own planned dates). Backs the
 *              deliveryPacingForecast HomePage LWC. ZERO new objects/fields.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.OperationWithLimitsInLoop,PMD.ExcessiveClassLength')
global with sharing class DeliveryHoursAnalyticsController {

    /**
     * @description Portfolio remaining work = SUM(max(0, estimate − logged)) across ALL
     *              in-scope items, independent of the display window. Computed in
     *              rollupPortfolioTotals and consumed by applyPortfolioForecast for the
     *              headline projectedFinalHours so out-of-window remaining work still
     *              counts. Not a DTO field (the serialized PacingData shape is fixed).
     */
    private static Decimal totalRemainingHours = 0;

    /**
     * @description Per in-scope item {estimate, logged, start, end} captured in
     *              rollupPortfolioTotals and consumed by applyPortfolioForecast to
     *              spread each item's REMAINING work across its OWN scheduled future
     *              span (schedule-based forecast). Same private-static pattern as
     *              totalRemainingHours — not a serialized DTO field.
     */
    private static List<ItemSchedule> portfolioItemSchedules = new List<ItemSchedule>();

    /**
     * @description Per-period drill-down composition for the schedule-based forecast,
     *              indexed PARALLEL to the period list (forecastItemsByPeriod[i] holds
     *              the items contributing to periods[i]). Populated in
     *              spreadScheduleBasedForecast as each item is placed, and serialized
     *              into each bucket's items[] by toPacingData so NG's forecast bucket
     *              drill-down lists the work composing the bar instead of "No itemized
     *              work in this period". Internal static (same pattern as
     *              portfolioItemSchedules) — not a serialized DTO field.
     */
    private static List<Map<Id, ForecastItemAccum>> forecastItemsByPeriod;

    /** @description Lightweight per-item schedule + work + meta struct (internal, not packaged). */
    private class ItemSchedule {
        Id workItemId;
        String name;
        String stage;
        String assignee;
        Decimal estimate;
        Decimal logged;
        Date startDate;
        Date endDate;
        /** 0.268 — the stacked-forecast commitment tier (PacingSegment.id) this item
         *  belongs to, derived once via tierForItem() (approval truth first —
         *  ClientPreApprovedHoursNumber__c > 0 → greenlit — else lane-derived). Drives
         *  both the per-bucket `segments` sums and each drill-down item's `tier`. */
        String tier;
    }

    /**
     * @description Accumulator for one work item's drill-down contribution to a single
     *              forecast period (hours summed across the period's overlap with the
     *              item's future span). Internal — toPacingData converts it to the NG
     *              PacingBucketItem Map shape.
     */
    private class ForecastItemAccum {
        ItemSchedule sched;
        Decimal hoursThisPeriod = 0;
    }

    /** @description Hard cap on recursion depth when walking the WI parent-child tree. */
    private static final Integer MAX_TREE_DEPTH = 10;

    /** @description Hard cap on the number of months returned. */
    private static final Integer MAX_MONTHS = 60;

    /** @description One DTO per (year, month) bucket returned to the LWC. */
    global class MonthlyHoursDTO {
        @AuraEnabled global Integer year;
        @AuraEnabled global Integer month;
        @AuraEnabled global String monthLabel;
        @AuraEnabled global Decimal hoursLogged;
        @AuraEnabled global Decimal monthlyTarget;
        @AuraEnabled global Boolean overTarget;
    }

    /** @description Project-level summary returned alongside the monthly buckets. */
    global class ProjectHoursSummary {
        @AuraEnabled global Id rootWorkItemId;
        @AuraEnabled global Integer descendantCount;
        @AuraEnabled global Decimal totalEstimatedHours;
        @AuraEnabled global Decimal totalLoggedHours;
        @AuraEnabled global Decimal monthlyTarget;
        @AuraEnabled global Boolean hasEstimate;
        @AuraEnabled global Date earliestStart;
        @AuraEnabled global Date latestEnd;
        @AuraEnabled global List<MonthlyHoursDTO> months;
    }

    /**
     * @description Returns monthly hours analytics for the WI tree rooted at workItemId.
     * @param workItemId Root WorkItem__c Id. Descendants are walked via
     *                   ParentWorkItemLookup__c up to MAX_TREE_DEPTH levels.
     * @param monthsBack How many months of history to include, counting back from the
     *                   start of the current month. Clamped to [1, MAX_MONTHS]. When null
     *                   or zero, defaults to 12.
     * @return ProjectHoursSummary with the monthly buckets + tree-level totals.
     */
    @AuraEnabled(cacheable=true)
    global static ProjectHoursSummary getMonthlyHoursForProject(Id workItemId, Integer monthsBack) {
        try {
            if (workItemId == null) {
                throw new AuraHandledException('workItemId is required.');
            }
            Integer effectiveMonths = (monthsBack == null || monthsBack <= 0) ? 12 : monthsBack;
            if (effectiveMonths > MAX_MONTHS) {
                effectiveMonths = MAX_MONTHS;
            }

            Set<Id> treeIds = walkDescendants(workItemId);
            List<WorkItem__c> tree = queryTreeRollup(treeIds);

            ProjectHoursSummary summary = buildSummaryFromTree(workItemId, tree);
            summary.monthlyTarget = computeMonthlyTarget(summary);

            List<MonthlyHoursDTO> months = buildMonthlyBuckets(effectiveMonths, summary.monthlyTarget);
            applyLoggedHours(months, treeIds);
            summary.months = months;

            return summary;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Rolls the tree's per-WI fields into a fresh summary. Extracted
     *              from the entry point to keep per-method cyclomatic complexity low.
     */
    private static ProjectHoursSummary buildSummaryFromTree(Id rootId, List<WorkItem__c> tree) {
        ProjectHoursSummary summary = new ProjectHoursSummary();
        summary.rootWorkItemId = rootId;
        summary.descendantCount = tree.size();
        summary.totalEstimatedHours = 0;
        summary.totalLoggedHours = 0;
        summary.earliestStart = null;
        summary.latestEnd = null;
        for (WorkItem__c wi : tree) {
            accumulateRollup(summary, wi);
        }
        summary.hasEstimate = summary.totalEstimatedHours > 0;
        return summary;
    }

    private static void accumulateRollup(ProjectHoursSummary summary, WorkItem__c wi) {
        if (wi.EstimatedHoursNumber__c != null) {
            summary.totalEstimatedHours += wi.EstimatedHoursNumber__c;
        }
        if (wi.TotalLoggedHoursSum__c != null) {
            summary.totalLoggedHours += wi.TotalLoggedHoursSum__c;
        }
        Date wiStart = wi.EstimatedStartDevDate__c;
        if (wiStart != null && (summary.earliestStart == null || wiStart < summary.earliestStart)) {
            summary.earliestStart = wiStart;
        }
        Date wiEnd = wi.EstimatedEndDevDate__c;
        if (wiEnd != null && (summary.latestEnd == null || wiEnd > summary.latestEnd)) {
            summary.latestEnd = wiEnd;
        }
    }

    /**
     * @description BFS walk from the root over ParentWorkItemLookup__c. Caps at
     *              MAX_TREE_DEPTH so a runaway cycle (shouldn't exist in data, but
     *              defensive) can't burn unbounded SOQL queries.
     */
    private static Set<Id> walkDescendants(Id rootId) {
        Set<Id> collected = new Set<Id>{ rootId };
        Set<Id> frontier = new Set<Id>{ rootId };
        for (Integer depth = 0; depth < MAX_TREE_DEPTH && !frontier.isEmpty(); depth++) {
            Set<Id> next = new Set<Id>();
            for (WorkItem__c child : [
                SELECT Id
                FROM WorkItem__c
                WHERE ParentWorkItemLookup__c IN :frontier
                WITH SYSTEM_MODE
                LIMIT 5000
            ]) {
                if (!collected.contains(child.Id)) {
                    collected.add(child.Id);
                    next.add(child.Id);
                }
            }
            frontier = next;
        }
        return collected;
    }

    private static List<WorkItem__c> queryTreeRollup(Set<Id> treeIds) {
        return [
            SELECT Id, EstimatedHoursNumber__c, TotalLoggedHoursSum__c,
                   EstimatedStartDevDate__c, EstimatedEndDevDate__c
            FROM WorkItem__c
            WHERE Id IN :treeIds
            WITH SYSTEM_MODE
            LIMIT 5000
        ];
    }

    /**
     * @description Linear-amortizes the total estimate across the project's
     *              planned month span. Returns 0 when either piece is missing —
     *              the LWC then renders only the actual bars, no target line.
     */
    private static Decimal computeMonthlyTarget(ProjectHoursSummary summary) {
        if (!summary.hasEstimate || summary.earliestStart == null || summary.latestEnd == null) {
            return 0;
        }
        Integer monthSpan = monthsBetween(summary.earliestStart, summary.latestEnd);
        if (monthSpan <= 0) {
            return summary.totalEstimatedHours;
        }
        return (summary.totalEstimatedHours / monthSpan).setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Integer monthsBetween(Date startDate, Date endDate) {
        Integer startMonths = startDate.year() * 12 + startDate.month();
        Integer endMonths = endDate.year() * 12 + endDate.month();
        return endMonths - startMonths + 1;
    }

    /**
     * @description Builds an empty monthly skeleton spanning effectiveMonths,
     *              ending at the current month. Hours are filled in by applyLoggedHours.
     */
    private static List<MonthlyHoursDTO> buildMonthlyBuckets(Integer effectiveMonths, Decimal monthlyTarget) {
        List<MonthlyHoursDTO> out = new List<MonthlyHoursDTO>();
        Date cursor = Date.today().toStartOfMonth().addMonths(-(effectiveMonths - 1));
        for (Integer i = 0; i < effectiveMonths; i++) {
            MonthlyHoursDTO row = new MonthlyHoursDTO();
            row.year = cursor.year();
            row.month = cursor.month();
            row.monthLabel = formatMonthLabel(cursor);
            row.hoursLogged = 0;
            row.monthlyTarget = monthlyTarget;
            row.overTarget = false;
            out.add(row);
            cursor = cursor.addMonths(1);
        }
        return out;
    }

    private static void applyLoggedHours(List<MonthlyHoursDTO> months, Set<Id> treeIds) {
        if (months.isEmpty()) {
            return;
        }
        Map<String, MonthlyHoursDTO> byKey = new Map<String, MonthlyHoursDTO>();
        for (MonthlyHoursDTO row : months) {
            byKey.put(bucketKey(row.year, row.month), row);
        }
        Date windowStart = Date.newInstance(months[0].year, months[0].month, 1);
        Date windowEnd = Date.newInstance(months[months.size() - 1].year, months[months.size() - 1].month, 1)
            .addMonths(1).addDays(-1);

        for (AggregateResult ar : [
            SELECT CALENDAR_YEAR(WorkDateDate__c) y,
                   CALENDAR_MONTH(WorkDateDate__c) m,
                   SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkItemLookup__c IN :treeIds
            AND WorkDateDate__c >= :windowStart
            AND WorkDateDate__c <= :windowEnd
            WITH SYSTEM_MODE
            GROUP BY CALENDAR_YEAR(WorkDateDate__c), CALENDAR_MONTH(WorkDateDate__c)
            LIMIT 5000
        ]) {
            Integer y = (Integer) ar.get('y');
            Integer m = (Integer) ar.get('m');
            Object totalObj = ar.get('total');
            if (totalObj == null) {
                continue;
            }
            Decimal total = (Decimal) totalObj;
            MonthlyHoursDTO bucket = byKey.get(bucketKey(y, m));
            if (bucket != null) {
                bucket.hoursLogged = total;
                bucket.overTarget = bucket.monthlyTarget > 0 && total > bucket.monthlyTarget;
            }
        }
    }

    private static String bucketKey(Integer y, Integer m) {
        return y + '-' + m;
    }

    private static String formatMonthLabel(Date d) {
        List<String> names = new List<String>{
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        };
        return names[d.month() - 1] + ' ' + String.valueOf(d.year()).substring(2);
    }

    // ════════════════════════════════════════════════════════════════════
    // Portfolio Pacing & Forecast — account/org-level pacing across ALL
    // active root WorkItems (not a single record). Backs the
    // deliveryPacingForecast HomePage LWC. ZERO new objects/fields.
    // ════════════════════════════════════════════════════════════════════

    /** @description Hard cap on the number of pacing periods (history + forecast). */
    private static final Integer MAX_PERIODS = 60;

    /** @description Cap on active root WorkItems scanned for the portfolio scope. */
    private static final Integer MAX_PORTFOLIO_ROOTS = 500;

    /** @description Number of trailing history periods averaged for the run-rate. */
    private static final Integer RUN_RATE_WINDOW = 4;

    /** @description Days in a week — period stepping for Week granularity. */
    private static final Integer DAYS_PER_WEEK = 7;

    /** @description Months in a quarter — period stepping for Quarter granularity. */
    private static final Integer MONTHS_PER_QUARTER = 3;

    /** @description Terminal stages excluded from the active-portfolio scope (CMT-driven cross-type union). */
    private static Set<String> terminalStages {
        get {
            if (terminalStages == null) {
                terminalStages = DeliveryWorkflowConfigService.getAllTerminalStageValues();
            }
            return terminalStages;
        }
        set;
    }

    /**
     * @description Maps a WorkItem `PriorityGroupPk__c` lane onto the NG stacked-forecast
     *              commitment tier (PacingSegment.id) for items that are NOT client-approved.
     *              Item 8 (approved-green cohort): membership in the 'greenlit' (Committed)
     *              tier is APPROVAL TRUTH, not lane truth — an item is greenlit iff
     *              `ClientPreApprovedHoursNumber__c > 0` (the canonical client-approved cap
     *              stamped by DeliveryWorkApprovalService), regardless of lane (see
     *              tierForItem). Unapproved items land in their lane-derived tier here, so
     *              the formerly-greenlit lanes (top-priority/active — work that is moving
     *              but not literally approved) now read 'predicted'. Segment IDS/COLORS are
     *              an NG contract (SEGMENT_DEFS) and are unchanged — only membership moved.
     *              This makes DH's AUTHORITATIVE split intentionally STRICTER than NG's
     *              task-derived PREVIEW (PACING_LANE_TO_SEGMENT in
     *              packages/app/src/renderers/pacing.ts, which has no approval signal);
     *              authoritative wins whenever DH feeds segments.
     *              Fallbacks preserve the "no work silently vanishes" invariant: every
     *              forecasted item lands in a tier, so the per-bucket segments always sum to
     *              the bucket forecast (NG renders bar = actual + Σ segments and ignores
     *              `forecast` once segments are present). Blank/unknown unapproved →
     *              'predicted' (never 'greenlit' — greenlit is approval-only);
     *              'deferred' (on-hold) → 'ready' (the speculative/dotted upside tier)
     *              rather than NG's exclude, because DH's schedule spread already counts
     *              on-hold remaining and dropping its tier would shrink the bar.
     */
    private static final Map<String, String> PRIORITY_GROUP_TO_TIER = new Map<String, String>{
        'top-priority' => 'predicted',
        'active'       => 'predicted',
        'follow-on'    => 'predicted',
        'proposed'     => 'ready',
        'deferred'     => 'ready'
    };

    /** @description The approval-only Committed tier id (NG PacingSegment.id contract). */
    private static final String GREENLIT_TIER = 'greenlit';

    /** @description Fallback tier for blank/unknown lanes on UNAPPROVED items (no-vanish — see above). */
    private static final String DEFAULT_TIER = 'predicted';

    /**
     * @description The DH-declared stacked-forecast tier definitions, in stack order, in
     *              NG's PacingSegment shape. Colors/style match NG's PACING_SEGMENT_DEFAULTS
     *              (and the MF prototype: committed green / predicted blue / ready amber-
     *              dotted) so the legend, palette, and tier-grouped drill-down render
     *              identically whether DH feeds segments or NG falls back to its preview.
     *              toPacingData only advertises the tiers that actually carry hours.
     */
    private static final Map<String, Map<String, Object>> SEGMENT_DEFS = new Map<String, Map<String, Object>>{
        'greenlit'  => new Map<String, Object>{ 'id' => 'greenlit',  'label' => 'Committed',         'color' => '#059669', 'style' => 'solid',   'order' => 0 },
        'predicted' => new Map<String, Object>{ 'id' => 'predicted', 'label' => 'Predicted',         'color' => '#2563eb', 'style' => 'solid',   'order' => 1 },
        'ready'     => new Map<String, Object>{ 'id' => 'ready',     'label' => 'Ready to approve',  'color' => '#d97706', 'style' => 'dotted',  'order' => 2 },
        'recurring' => new Map<String, Object>{ 'id' => 'recurring', 'label' => 'Recurring intake',  'color' => '#7c3aed', 'style' => 'hatched', 'order' => 3 }
    };

    /** @description Tier order for emitting the segment-def array (matches SEGMENT_DEFS order). */
    private static final List<String> TIER_ORDER = new List<String>{ 'greenlit', 'predicted', 'ready', 'recurring' };

    /**
     * @description Resolves a WorkItem's forecast tier. Approval truth first: any item the
     *              client has pre-approved hours for (`ClientPreApprovedHoursNumber__c > 0`)
     *              is 'greenlit' regardless of lane; everything else falls back to its
     *              lane-derived tier (see PRIORITY_GROUP_TO_TIER — never 'greenlit').
     * @param approvedHours The WorkItem `ClientPreApprovedHoursNumber__c` value (nullable).
     * @param lane The WorkItem `PriorityGroupPk__c` value (may be blank).
     * @return A PacingSegment.id — never null.
     */
    private static String tierForItem(Decimal approvedHours, String lane) {
        if (approvedHours != null && approvedHours > 0) {
            return GREENLIT_TIER;
        }
        return tierForGroup(lane);
    }

    /**
     * @description Resolves a WorkItem lane to its UNAPPROVED forecast tier (see
     *              PRIORITY_GROUP_TO_TIER). Callers wanting the full approval-aware
     *              resolution use tierForItem.
     * @param lane The WorkItem `PriorityGroupPk__c` value (may be blank).
     * @return A PacingSegment.id — never null (blank/unknown fall back to DEFAULT_TIER).
     */
    private static String tierForGroup(String lane) {
        if (String.isNotBlank(lane) && PRIORITY_GROUP_TO_TIER.containsKey(lane)) {
            return PRIORITY_GROUP_TO_TIER.get(lane);
        }
        return DEFAULT_TIER;
    }

    /** @description One period (history or forecast) on the pacing timeline. */
    global class PacingPeriodDTO {
        @AuraEnabled global String label;
        @AuraEnabled global Date startDate;
        @AuraEnabled global Date endDate;
        @AuraEnabled global Decimal loggedHours;
        @AuraEnabled global Decimal targetHours;
        @AuraEnabled global Decimal forecastHours;
        @AuraEnabled global Boolean isForecast;
        @AuraEnabled global Boolean overTarget;
        /** W5.3 (T6.1) — per-tier forecast split (segment id → hours) so the ADMIN
         *  pacing card renders the same stacked commitment-tier bars the buyer
         *  surface already renders. Null for history periods and for forecast
         *  periods with nothing scheduled; the tier sums (+ the synthetic
         *  recurring tier when the org sets it) equal the bucket forecast, so a
         *  stacked bar is exactly as tall as the flat bar it replaces. */
        @AuraEnabled global Map<String, Decimal> segments;
    }

    /** @description One stacked-forecast tier definition (legend + palette) in stack
     *               order — the LWC-facing mirror of NG's PacingSegment contract. */
    global class PacingSegmentDefDTO {
        @AuraEnabled global String id;
        @AuraEnabled global String label;
        @AuraEnabled global String color;
        @AuraEnabled global String style;
    }

    /** @description Portfolio-level pacing + forecast headline returned to the LWC. */
    global class PortfolioPacingDTO {
        @AuraEnabled global String granularity;
        @AuraEnabled global Integer rootCount;
        @AuraEnabled global Decimal totalEstimatedHours;
        @AuraEnabled global Decimal totalLoggedHours;
        @AuraEnabled global Decimal projectedFinalHours;
        @AuraEnabled global Decimal runRateHoursPerPeriod;
        @AuraEnabled global Decimal unscheduledRemainingHours;
        @AuraEnabled global Decimal blendedRate;
        @AuraEnabled global Boolean hasEstimate;
        @AuraEnabled global Boolean isOverBudgetTrajectory;
        @AuraEnabled global Date earliestStart;
        @AuraEnabled global Date latestEnd;
        @AuraEnabled global List<PacingPeriodDTO> periods;
        /** W5.3 — tier definitions (stack order) for only the tiers that carry hours
         *  across the returned periods; null when no period has segments. */
        @AuraEnabled global List<PacingSegmentDefDTO> segmentDefs;
    }

    /**
     * @description Account/org-level pacing + forecast across the whole active
     *              portfolio (all active root WorkItems + their descendant trees).
     *              Builds a period skeleton of `periodsBack` history periods plus
     *              `periodsForward` forecast periods at the requested granularity,
     *              fills actuals from one WorkLog AggregateResult, amortizes the
     *              portfolio estimate into per-period targets, and projects forward
     *              periods at the portfolio run-rate (capped at remaining estimate).
     * @param granularity 'Week' | 'Month' | 'Quarter'. Defaults to 'Month'.
     * @param periodsBack History periods to include. Clamped to [1, MAX_PERIODS].
     *                    Null/zero defaults to 6.
     * @param periodsForward Forecast periods to project. Clamped to [0, MAX_PERIODS].
     *                    Null defaults to 3. Total periods are capped at MAX_PERIODS.
     * @return PortfolioPacingDTO with the period series + headline numbers.
     */
    @AuraEnabled(cacheable=true)
    global static PortfolioPacingDTO getPortfolioPacing(String granularity, Integer periodsBack, Integer periodsForward) {
        try {
            String gran = normalizeGranularity(granularity);
            Integer back = clampPeriods(periodsBack, 6, 1);
            Integer forward = clampPeriods(periodsForward, 3, 0);
            if (back + forward > MAX_PERIODS) {
                forward = MAX_PERIODS - back;
                if (forward < 0) {
                    forward = 0;
                }
            }

            Set<Id> rootIds = queryActiveRootIds();
            Set<Id> portfolioIds = collectPortfolioTree(rootIds);

            PortfolioPacingDTO dto = new PortfolioPacingDTO();
            dto.granularity = gran;
            dto.rootCount = rootIds.size();
            rollupPortfolioTotals(dto, portfolioIds);

            List<PacingPeriodDTO> periods = buildPeriodSkeleton(gran, back, forward);
            applyPortfolioLoggedHours(periods, portfolioIds, gran);
            applyPortfolioTargets(periods, dto);
            applyPortfolioForecast(periods, dto, back);

            dto.periods = periods;
            applyPeriodSegments(dto);
            dto.blendedRate = DeliveryRateService.resolveBlendedRate();
            return dto;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description One in-scope WorkItem as the capacity-forecast slider
     *              (deliveryCapacityForecast LWC) consumes it: the flat,
     *              leaf-only, board-active item with its estimate, logged,
     *              remaining, dates, and commitment tier. The slider's
     *              client-side greedy packer reflows these against a
     *              dev-count ceiling to show when work lands per pace.
     *
     *              BUYER-FACING: this DTO is shown to the client. It carries
     *              NO person identity — ItemSchedule.assignee
     *              (DeveloperLookup__r.Name) is deliberately NOT mapped here.
     *              `name` is the work-item label (BriefDescriptionTxt__c, else
     *              the T-NNNN auto-number), never a developer. Keep it that way
     *              in pass two — do not re-add assignee.
     */
    public class ForecastItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public Decimal estimate;
        @AuraEnabled public Decimal logged;
        /** estimate - logged, floored at 0 — the hours the packer schedules. */
        @AuraEnabled public Decimal remaining;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        /** PacingSegment.id (greenlit / predicted / ...) — same tier the stacked
         *  forecast colors by; greenlit = client-approved (drains first). */
        @AuraEnabled public String tier;
        /** Terminal-stage (Done/Cancelled/...) — real history, no forward work;
         *  the packer skips these so they never inflate the future schedule. */
        @AuraEnabled public Boolean isTerminal;
    }

    /**
     * @description The flat in-scope item list backing the capacity-forecast
     *              slider — the SAME active portfolio scope, leaf-only counting,
     *              terminal-stage handling, and tier resolution the stacked
     *              forecast (getPacing) uses, exposed as raw items so the LWC
     *              can repack them client-side against a dev-count ceiling
     *              without an Apex round-trip per drag. Reuses
     *              queryActiveRootIds + collectPortfolioTree + rollupPortfolioTotals
     *              (which populates portfolioItemSchedules as it computes the
     *              rollup) so this list and the headline forecast can never drift.
     *
     *              NOT cacheable — same live-edit / reprioritize staleness
     *              landmine documented on getPacing below: the slider issues
     *              reorder writes (updateWorkItemSortOrder) and the list must
     *              reflect them on the next read, not serve a stale LDS cache.
     * @return Every board-active leaf WorkItem in scope as a ForecastItemDTO
     *         (estimate / logged / remaining / dates / tier); empty when none.
     */
    @AuraEnabled
    public static List<ForecastItemDTO> getForecastItems() {
        try {
            Set<Id> rootIds = queryActiveRootIds();
            Set<Id> portfolioIds = collectPortfolioTree(rootIds);
            PortfolioPacingDTO dto = new PortfolioPacingDTO();
            // Side effect: populates the static portfolioItemSchedules with the
            // leaf-only, tier-resolved per-item schedules we map below.
            rollupPortfolioTotals(dto, portfolioIds);

            List<ForecastItemDTO> out = new List<ForecastItemDTO>();
            for (ItemSchedule s : portfolioItemSchedules) {
                ForecastItemDTO d = new ForecastItemDTO();
                d.id = s.workItemId;
                d.name = s.name;
                d.stage = s.stage;
                d.estimate = s.estimate == null ? 0 : s.estimate;
                d.logged = s.logged == null ? 0 : s.logged;
                Decimal rem = d.estimate - d.logged;
                d.remaining = rem > 0 ? rem : 0;
                d.startDate = s.startDate;
                d.endDate = s.endDate;
                d.tier = s.tier;
                d.isTerminal = String.isNotBlank(s.stage)
                    && terminalStages.contains(s.stage);
                // s.assignee intentionally dropped — buyer-facing, no names.
                out.add(d);
            }
            return out;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Serializes getPortfolioPacing into nimbus-gantt's render-ready
     *              PacingData shape (the DH->NG forecast contract,
     *              nimbus-gantt/docs/dispatch-pacing-view-0195.md) and returns it
     *              as a JSON string the deliveryProFormaTimeline LWC feeds to the
     *              NG mount via config.pacing.data. Mirrors NG's
     *              portfolioPacingToPacingData adapter 1:1 (period totals ->
     *              actual/forecast/target, granularity -> bucket, blendedRate ->
     *              rate, summary from totals) so the in-gantt Pacing subtab shows
     *              DH's authoritative dated actuals / $ / scope instead of NG's
     *              task-derived fallback preview. Per-period items[] are left empty
     *              -- NG's items-hybrid fills the drill-down from the task buckets.
     *              Returned as JSON to avoid adding new global packaged DTO types.
     * @param granularity 'Week' | 'Month' | 'Quarter'. Defaults to 'Month'.
     * @param periodsBack History periods to include. Forwarded to getPortfolioPacing
     *                    (clamped there). Null defaults to 6.
     * @param periodsForward Forecast periods to project. Forwarded to
     *                    getPortfolioPacing (clamped there). Null defaults to 3.
     * @return JSON String of the NG PacingData object (buckets + bucket size +
     *         summary + optional rate, authoritative=true).
     */
    // 0.271 — NOT cacheable. The forecast must reflect live WorkItem edits (dates/estimates/
    // logs) and a fresh recompute right after a package install; the LDS client cache served
    // stale numbers until a hard reload (a live-demo landmine). getPacing is called only
    // imperatively (deliveryProFormaTimeline), so dropping cacheable is safe — no @wire depends
    // on it. getPortfolioPacing stays cacheable for the cart's @wire.
    @AuraEnabled
    global static String getPacing(String granularity, Integer periodsBack, Integer periodsForward) {
        try {
            PortfolioPacingDTO dto = getPortfolioPacing(granularity, periodsBack, periodsForward);
            return JSON.serialize(toPacingData(dto), true);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Maps a PortfolioPacingDTO to the NG PacingData shape as a plain
     *              Map (serialized by getPacing). Kept in lock-step with NG's
     *              portfolioPacingToPacingData(dto) so the Home card, the email,
     *              and the in-gantt subtab cannot disagree.
     * @param dto The portfolio pacing result from getPortfolioPacing.
     * @return Map<String, Object> matching NG's PacingData interface.
     */
    private static Map<String, Object> toPacingData(PortfolioPacingDTO dto) {
        Date today = Date.today();
        String g = (dto != null && dto.granularity != null) ? dto.granularity.toLowerCase() : 'month';
        String bucketSize = g.startsWith('week') ? 'week' : (g.startsWith('quart') ? 'quarter' : 'month');

        Decimal est = numOrZero(dto == null ? null : dto.totalEstimatedHours);
        Decimal logged = numOrZero(dto == null ? null : dto.totalLoggedHours);

        List<Object> buckets = new List<Object>();
        // 0.268 — accumulate which commitment tiers actually carry hours so the top-level
        // segments[] defs only advertise non-empty tiers (mirrors NG's own legend filter).
        Set<String> tiersWithHours = new Set<String>();
        Decimal recurring = resolveRecurringHoursPerPeriod(bucketSize);
        if (dto != null && dto.periods != null) {
            for (Integer idx = 0; idx < dto.periods.size(); idx++) {
                PacingPeriodDTO p = dto.periods[idx];
                Boolean isForecast = (p.isForecast == true);
                Boolean isCurrent = (p.startDate != null && p.endDate != null
                    && today >= p.startDate && today <= p.endDate);
                Boolean isPast = (!isForecast && p.endDate != null && p.endDate < today);
                String key = (p.startDate != null) ? isoDate(p.startDate)
                    : (p.label != null ? p.label : '');
                Map<String, Object> b = new Map<String, Object>{
                    'key' => key,
                    'label' => (p.label != null ? p.label : (p.startDate != null ? isoDate(p.startDate) : '')),
                    'actual' => numOrZero(p.loggedHours),
                    'forecast' => numOrZero(p.forecastHours),
                    'target' => numOrZero(p.targetHours),
                    'isPast' => isPast,
                    'isCurrent' => isCurrent,
                    'items' => buildBucketItems(idx)
                };
                if (p.startDate != null) {
                    b.put('startMs', dateToMs(p.startDate));
                }
                // 0.268 — per-period commitment-tier split (the stacked hockey-stick).
                // Only forecast buckets have scheduled work; recurring rides on forecast
                // buckets as a synthetic tier (inert until resolveRecurringHoursPerPeriod
                // returns > 0).
                Map<String, Decimal> segs = buildBucketSegments(idx);
                if (isForecast && recurring > 0) {
                    segs.put('recurring', recurring);
                }
                if (!segs.isEmpty()) {
                    b.put('segments', segs);
                    tiersWithHours.addAll(segs.keySet());
                }
                buckets.add(b);
            }
        }

        Decimal remaining = (est - logged) > 0 ? (est - logged) : 0;
        Decimal projected = numOrZero(dto == null ? null : dto.projectedFinalHours);
        Map<String, Object> summary = new Map<String, Object>{
            'estimatedHours' => est,
            'loggedHours' => logged,
            'remainingHours' => remaining,
            'projectedFinalHours' => projected != 0 ? projected : est,
            'pacingPct' => est > 0 ? Math.round((logged / est) * 100) : 0,
            'activeItems' => (dto != null && dto.rootCount != null) ? dto.rootCount : 0,
            'unscheduledHours' => numOrZero(dto == null ? null : dto.unscheduledRemainingHours),
            // 0.271 — scope designation for NG's pacing banner, so the active-portfolio scope
            // (active roots + descendants, incl. proposed) reads as deliberate rather than a
            // mismatch against the board's flat VIEW-filtered count.
            'scopeLabel' => 'Active portfolio (roots + descendants; may differ from the board view filter)'
        };

        Map<String, Object> out = new Map<String, Object>{
            'buckets' => buckets,
            'bucket' => bucketSize,
            'summary' => summary,
            'authoritative' => true
        };
        // 0.268 — declare the stacked-forecast tier definitions (NG PacingData.segments),
        // in stack order, for only the tiers that carry hours. NG renders the legend + the
        // tier-grouped drill-down from these; absent → NG falls back to its preview split.
        if (!tiersWithHours.isEmpty()) {
            List<Object> segmentDefs = new List<Object>();
            for (String t : TIER_ORDER) {
                if (tiersWithHours.contains(t) && SEGMENT_DEFS.containsKey(t)) {
                    segmentDefs.add(SEGMENT_DEFS.get(t));
                }
            }
            if (!segmentDefs.isEmpty()) {
                out.put('segments', segmentDefs);
            }
        }
        if (dto != null && dto.blendedRate != null) {
            out.put('rate', dto.blendedRate);
        }
        return out;
    }

    /**
     * @description Composes a forecast period's drill-down rows in NG's PacingBucketItem
     *              shape from the per-period accumulator built during the schedule-based
     *              spread. Each entry carries id + name + hours (this period) + the
     *              estimate/logged/remaining/budgetUsedPct + pctOfItem + start/end/stage/
     *              assignee meta NG renders. History (non-forecast) periods have no
     *              accumulator entries, so they get an empty list (unchanged behavior).
     *              Sorted by hours desc to match NG's own ordering. Unscheduled/overdue
     *              items are never placed on any period, so they never appear here.
     * @param periodIndex Index into forecastItemsByPeriod (parallel to dto.periods).
     * @return List of Map<String,Object> matching NG's PacingBucketItem interface.
     */
    private static List<Object> buildBucketItems(Integer periodIndex) {
        List<Object> items = new List<Object>();
        if (forecastItemsByPeriod == null
            || periodIndex < 0 || periodIndex >= forecastItemsByPeriod.size()) {
            return items;
        }
        List<ForecastItemAccum> accs = forecastItemsByPeriod[periodIndex].values();
        // Sort by hoursThisPeriod desc (mirrors NG's items.sort by hours desc).
        for (Integer i = 0; i < accs.size(); i++) {
            for (Integer j = i + 1; j < accs.size(); j++) {
                if (accs[j].hoursThisPeriod > accs[i].hoursThisPeriod) {
                    ForecastItemAccum tmp = accs[i];
                    accs[i] = accs[j];
                    accs[j] = tmp;
                }
            }
        }
        for (ForecastItemAccum acc : accs) {
            // Drop drill-down rows that contribute 0h (or less) to this period — they're
            // noise in the bucket's items[] list.
            if (acc.hoursThisPeriod == null || acc.hoursThisPeriod <= 0) {
                continue;
            }
            ItemSchedule s = acc.sched;
            Decimal est = numOrZero(s.estimate);
            Decimal logged = numOrZero(s.logged);
            Decimal remaining = (est - logged) > 0 ? (est - logged) : 0;
            Decimal hoursThisPeriod = acc.hoursThisPeriod.setScale(2, System.RoundingMode.HALF_UP);
            // pctOfItem = this bucket's hours ÷ the item's spread total (its remaining).
            Long pctOfItem = (remaining > 0)
                ? Math.round((hoursThisPeriod / remaining) * 100) : 0L;
            Long budgetUsedPct = (est > 0) ? Math.round((logged / est) * 100) : 0L;
            Map<String, Object> item = new Map<String, Object>{
                'id' => s.workItemId,
                'name' => (s.name != null) ? s.name : String.valueOf(s.workItemId),
                'hours' => hoursThisPeriod,
                'pctOfItem' => pctOfItem,
                'estimatedHours' => est,
                'loggedHours' => logged,
                'remainingHours' => remaining,
                'budgetUsedPct' => budgetUsedPct
            };
            if (s.startDate != null) {
                item.put('startDate', isoDate(s.startDate));
            }
            if (s.endDate != null) {
                item.put('endDate', isoDate(s.endDate));
            }
            if (String.isNotBlank(s.stage)) {
                item.put('status', s.stage);
            }
            if (String.isNotBlank(s.assignee)) {
                item.put('assignee', s.assignee);
            }
            if (String.isNotBlank(s.tier)) {
                item.put('tier', s.tier);
            }
            items.add(item);
        }
        return items;
    }

    /**
     * @description W5.3 (T6.1) — mirrors the per-bucket commitment-tier split onto the
     *              LWC-facing PortfolioPacingDTO so the ADMIN pacing card
     *              (deliveryPacingForecast) can render the same STACKED forecast bars
     *              the buyer surface already gets via getPacing/toPacingData. Ports the
     *              buyer-side rule verbatim: a bucket's bar = Σ segments once segments
     *              are present (the flat `forecastHours` is ignored for stacked bars),
     *              the synthetic recurring tier rides on forecast buckets when the org
     *              sets RecurringHoursPerMonthNumber__c, and only tiers that actually
     *              carry hours are advertised in segmentDefs (stack order). History
     *              periods carry no segments — actuals aren't tiered. Must run AFTER
     *              applyPortfolioForecast (it reads the same forecastItemsByPeriod
     *              accumulator buildBucketSegments uses).
     * @param dto The pacing DTO whose periods get their segments populated.
     */
    private static void applyPeriodSegments(PortfolioPacingDTO dto) {
        if (dto.periods == null || dto.periods.isEmpty()) {
            return;
        }
        String g = (dto.granularity != null) ? dto.granularity.toLowerCase() : 'month';
        String bucketSize = g.startsWith('week') ? 'week' : (g.startsWith('quart') ? 'quarter' : 'month');
        Decimal recurring = resolveRecurringHoursPerPeriod(bucketSize);

        Set<String> tiersWithHours = new Set<String>();
        for (Integer i = 0; i < dto.periods.size(); i++) {
            PacingPeriodDTO p = dto.periods[i];
            Map<String, Decimal> segs = buildBucketSegments(i);
            if (p.isForecast == true && recurring > 0) {
                segs.put('recurring', recurring);
            }
            if (!segs.isEmpty()) {
                p.segments = segs;
                tiersWithHours.addAll(segs.keySet());
            }
        }
        if (tiersWithHours.isEmpty()) {
            return;
        }
        List<PacingSegmentDefDTO> defs = new List<PacingSegmentDefDTO>();
        for (String t : TIER_ORDER) {
            if (tiersWithHours.contains(t) && SEGMENT_DEFS.containsKey(t)) {
                Map<String, Object> def = SEGMENT_DEFS.get(t);
                PacingSegmentDefDTO d = new PacingSegmentDefDTO();
                d.id = (String) def.get('id');
                d.label = (String) def.get('label');
                d.color = (String) def.get('color');
                d.style = (String) def.get('style');
                defs.add(d);
            }
        }
        if (!defs.isEmpty()) {
            dto.segmentDefs = defs;
        }
    }

    /**
     * @description Sums a forecast period's scheduled hours BY COMMITMENT TIER, from the
     *              same per-period accumulator that backs buildBucketItems. Produces NG's
     *              `PacingBucket.segments` map (segId → hours) so the forecast bar renders
     *              as a STACKED hockey-stick (Committed / Predicted / Ready). Because every
     *              forecasted item carries a tier (tierForGroup never returns null), these
     *              per-tier sums add up to the bucket's `forecast` total — NG draws the bar
     *              as actual + Σ segments and ignores `forecast` when segments are present,
     *              so the stack height equals the un-split bar (no regression). History
     *              periods have no accumulator entries → empty map (no segments emitted).
     * @param periodIndex Index into forecastItemsByPeriod (parallel to dto.periods).
     * @return Map of PacingSegment.id → hours for this period (rounded; empty for history).
     */
    private static Map<String, Decimal> buildBucketSegments(Integer periodIndex) {
        Map<String, Decimal> segs = new Map<String, Decimal>();
        if (forecastItemsByPeriod == null
            || periodIndex < 0 || periodIndex >= forecastItemsByPeriod.size()) {
            return segs;
        }
        for (ForecastItemAccum acc : forecastItemsByPeriod[periodIndex].values()) {
            if (acc.hoursThisPeriod == null || acc.hoursThisPeriod <= 0) {
                continue;
            }
            String tier = String.isNotBlank(acc.sched.tier) ? acc.sched.tier : DEFAULT_TIER;
            Decimal running = segs.containsKey(tier) ? segs.get(tier) : 0;
            segs.put(tier, running + acc.hoursThisPeriod);
        }
        for (String k : new List<String>(segs.keySet())) {
            segs.put(k, segs.get(k).setScale(2, System.RoundingMode.HALF_UP));
        }
        return segs;
    }

    /**
     * @description Hours per forecast period for the SYNTHETIC 'recurring' steady-state
     *              intake tier — the ~N small inbounds that always land regardless of the
     *              dated backlog. Added uniformly to every forecast bucket as its own tier
     *              so the curve extends to the right beyond scheduled work.
     *              Sourced per-org from DeliveryHubSettings__c.RecurringHoursPerMonthNumber__c
     *              (a MONTHLY rate), scaled here to the requested bucket. Default/blank/<=0 =
     *              tier off (prod unchanged until an org sets it) — so MF can set ~69 without
     *              injecting phantom recurring work into other subscriber orgs' forecasts.
     * @param bucketSize 'week' | 'month' | 'quarter' — the period the hours are scaled to.
     * @return Recurring hours per forecast period (0 = tier off).
     */
    private static Decimal resolveRecurringHoursPerPeriod(String bucketSize) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Decimal perMonth = (settings == null || settings.RecurringHoursPerMonthNumber__c == null)
            ? 0 : settings.RecurringHoursPerMonthNumber__c;
        if (perMonth <= 0) {
            return 0;
        }
        if (bucketSize == 'week') {
            // 12 months / 52 weeks — average monthly rate spread per week.
            return (perMonth * 12 / 52).setScale(2, System.RoundingMode.HALF_UP);
        }
        if (bucketSize == 'quarter') {
            return (perMonth * MONTHS_PER_QUARTER).setScale(2, System.RoundingMode.HALF_UP);
        }
        return perMonth.setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * @description Null-safe numeric coalesce to 0 (mirrors NG's _num helper).
     * @param v Possibly-null Decimal.
     * @return v when non-null, else 0.
     */
    private static Decimal numOrZero(Decimal v) {
        return (v == null) ? 0 : v;
    }

    /**
     * @description Formats a Date as an ISO yyyy-MM-dd string (PacingBucket.key).
     * @param d The date to format.
     * @return ISO yyyy-MM-dd date string.
     */
    private static String isoDate(Date d) {
        return DateTime.newInstance(d.year(), d.month(), d.day()).format('yyyy-MM-dd');
    }

    /**
     * @description UTC epoch millis at midnight for a Date (PacingBucket.startMs).
     * @param d The date to convert.
     * @return Epoch milliseconds (GMT midnight).
     */
    private static Long dateToMs(Date d) {
        return DateTime.newInstanceGmt(d.year(), d.month(), d.day(), 0, 0, 0).getTime();
    }

    private static String normalizeGranularity(String granularity) {
        if (String.isBlank(granularity)) {
            return 'Month';
        }
        String g = granularity.trim().toLowerCase();
        if (g == 'week') {
            return 'Week';
        }
        if (g == 'quarter') {
            return 'Quarter';
        }
        return 'Month';
    }

    private static Integer clampPeriods(Integer requested, Integer fallback, Integer floor) {
        Integer value = (requested == null) ? fallback : requested;
        if (value < floor) {
            value = floor;
        }
        if (value > MAX_PERIODS) {
            value = MAX_PERIODS;
        }
        return value;
    }

    /**
     * @description Active root WorkItems = the portfolio scope. Mirrors the
     *              DeliveryForecastAlertService candidate filter.
     */
    private static Set<Id> queryActiveRootIds() {
        Set<Id> ids = new Set<Id>();
        for (WorkItem__c wi : [
            SELECT Id
            FROM WorkItem__c
            WHERE ParentWorkItemLookup__c = NULL
              AND ActivatedDateTime__c != NULL
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
              AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            LIMIT :MAX_PORTFOLIO_ROOTS
        ]) {
            ids.add(wi.Id);
        }
        return ids;
    }

    /**
     * @description Expands the active roots into their descendant trees via a
     *              level-by-level BFS (capped at MAX_TREE_DEPTH), bulk across all
     *              roots so each depth level is ONE query — no per-root loop.
     *
     *              Descendants are filtered to the board's canonical "Active"
     *              definition — `ActivatedDateTime__c != NULL AND
     *              TemplateMarkedDateTime__c = NULL` — so the pacing item
     *              universe matches exactly what the gantt board draws
     *              (DeliveryGanttController.getProFormaTimelineData with
     *              showCompleted=false). Before this gate, the BFS pulled in
     *              EVERY child regardless of activation/template state, so the
     *              forecast's active-item universe drifted ABOVE the board count
     *              (e.g. 99 in Pacing vs 95 on the board on MF prod) — the extra
     *              records were non-activated / template descendants the board
     *              never shows. The number the forecast totals + the consumer's
     *              activeItems count are derived from must equal the client-
     *              visible board, or it raises questions in the client review.
     *
     *              Note: traversal of the frontier uses the raw parent link
     *              (every child is followed so the walk is never cut short by a
     *              non-active mid-tree parent), but a child is only ADDED to the
     *              returned scope when it is itself board-active. This keeps an
     *              activated grandchild reachable under a non-activated parent —
     *              matching the board's flat (parent-state-independent) view —
     *              while excluding the non-active records themselves.
     */
    private static Set<Id> collectPortfolioTree(Set<Id> rootIds) {
        Set<Id> collected = new Set<Id>(rootIds);
        Set<Id> visited = new Set<Id>(rootIds);
        Set<Id> frontier = new Set<Id>(rootIds);
        for (Integer depth = 0; depth < MAX_TREE_DEPTH && !frontier.isEmpty(); depth++) {
            Set<Id> next = new Set<Id>();
            for (WorkItem__c child : [
                SELECT Id, ActivatedDateTime__c, TemplateMarkedDateTime__c
                FROM WorkItem__c
                WHERE ParentWorkItemLookup__c IN :frontier
                WITH SYSTEM_MODE
                LIMIT 50000
            ]) {
                if (visited.contains(child.Id)) {
                    continue;
                }
                visited.add(child.Id);
                next.add(child.Id);
                // Board-active gate: only activated, non-template descendants
                // join the scope — mirrors getProFormaTimelineData(false).
                if (child.ActivatedDateTime__c != null && child.TemplateMarkedDateTime__c == null) {
                    collected.add(child.Id);
                }
            }
            frontier = next;
        }
        return collected;
    }

    /**
     * @description Sums the portfolio estimate and planned start/end span from the
     *              WorkItem tree (one query), and the all-time logged hours straight
     *              from WorkLog (one aggregate). Logged hours are read from WorkLog
     *              directly — NOT the TotalLoggedHoursSum__c roll-up — so the headline
     *              stays correct regardless of roll-up recalc timing. Also computes
     *              totalRemainingHours = SUM(max(0, estimate − logged)) per item,
     *              independent of any display window, so the headline Projected Final
     *              can count remaining work that falls beyond the windowed forecast.
     */
    private static void rollupPortfolioTotals(PortfolioPacingDTO dto, Set<Id> portfolioIds) {
        dto.totalEstimatedHours = 0;
        dto.totalLoggedHours = 0;
        dto.earliestStart = null;
        dto.latestEnd = null;
        totalRemainingHours = 0;
        portfolioItemSchedules = new List<ItemSchedule>();
        if (portfolioIds.isEmpty()) {
            dto.hasEstimate = false;
            return;
        }
        Map<Id, Decimal> loggedByItem = loggedHoursByItem(portfolioIds);
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, DeveloperLookup__r.Name,
                   EstimatedHoursNumber__c, PriorityGroupPk__c, ParentWorkItemLookup__c,
                   ClientPreApprovedHoursNumber__c,
                   EstimatedStartDevDate__c, EstimatedEndDevDate__c
            FROM WorkItem__c
            WHERE Id IN :portfolioIds
            WITH SYSTEM_MODE
            LIMIT 50000
        ];
        // 0.269 — LEAF-ONLY counting. A WorkItem that is the PARENT of another in-scope item
        // is a CONTAINER whose EstimatedHoursNumber__c is a planning rollup of its children
        // (verified on MF-Prod: RR-ENGINE-PARENT 200h == its children RR-ENG-1/2/3 = 80+70+50).
        // Counting BOTH the parent and its children double-counts the same work, inflating
        // estimate / remaining / forecast above the real total (the Pacing-2,640h-vs-board-
        // 1,460h credibility gap). So estimate, remaining, and the schedule-based spread count
        // LEAVES only (items with no in-scope child). Logged stays INCLUSIVE — a WorkLog is
        // recorded against one specific item (never a parent↔child rollup), so it can't
        // double-count, and dropping a parent's direct logs would lose real history.
        Set<Id> parentIds = new Set<Id>();
        for (WorkItem__c wi : items) {
            if (wi.ParentWorkItemLookup__c != null) {
                parentIds.add(wi.ParentWorkItemLookup__c);
            }
        }
        for (WorkItem__c wi : items) {
            // Skip container parents — their work is counted via their (leaf) children.
            if (parentIds.contains(wi.Id)) {
                continue;
            }
            // Terminal-stage items (Done/Cancelled/Closed/Rejected) are dead work: their
            // already-LOGGED hours are real history (kept in totalLoggedHours + the actual
            // series, both sourced from WorkLog independent of stage), but their REMAINING
            // (estimate − logged) must NOT contribute to totalRemainingHours / forecast /
            // projectedFinal / the schedule-based spread / the unscheduled bucket. We skip
            // their remaining here and in spreadScheduleBasedForecast via the same stage
            // flag (carried on ItemSchedule.stage).
            Boolean isTerminal = String.isNotBlank(wi.StageNamePk__c)
                && terminalStages.contains(wi.StageNamePk__c);
            Decimal estimate = (wi.EstimatedHoursNumber__c == null) ? 0 : wi.EstimatedHoursNumber__c;
            dto.totalEstimatedHours += estimate;
            Decimal logged = loggedByItem.containsKey(wi.Id) ? loggedByItem.get(wi.Id) : 0;
            Decimal itemRemaining = estimate - logged;
            if (!isTerminal && itemRemaining > 0) {
                totalRemainingHours += itemRemaining;
            }
            // Capture per-item schedule + work + meta for the schedule-based forecast
            // spread AND the per-period drill-down composition (toPacingData items[]).
            ItemSchedule sched = new ItemSchedule();
            sched.workItemId = wi.Id;
            // 0.271 — drill-down name: brief description, else the WorkItem Name (the
            // auto-number T-NNNN the board shows), else (guarded downstream) the Id. The big
            // CF rocks have a blank BriefDescriptionTxt__c, so without the Name fallback the
            // forecast drill-down rendered raw 18-char Ids for the most important line items.
            // Mirrors DeliveryCartService.toLine.
            sched.name = String.isNotBlank(wi.BriefDescriptionTxt__c) ? wi.BriefDescriptionTxt__c : wi.Name;
            sched.stage = wi.StageNamePk__c;
            sched.assignee = (wi.DeveloperLookup__r != null) ? wi.DeveloperLookup__r.Name : null;
            sched.estimate = estimate;
            sched.logged = logged;
            sched.startDate = wi.EstimatedStartDevDate__c;
            sched.endDate = wi.EstimatedEndDevDate__c;
            // Item 8 — greenlit = literally approved (ClientPreApprovedHoursNumber__c > 0),
            // regardless of lane; unapproved items keep their lane-derived tier.
            sched.tier = tierForItem(wi.ClientPreApprovedHoursNumber__c, wi.PriorityGroupPk__c);
            portfolioItemSchedules.add(sched);
            Date s = wi.EstimatedStartDevDate__c;
            if (s != null && (dto.earliestStart == null || s < dto.earliestStart)) {
                dto.earliestStart = s;
            }
            Date e = wi.EstimatedEndDevDate__c;
            if (e != null && (dto.latestEnd == null || e > dto.latestEnd)) {
                dto.latestEnd = e;
            }
        }
        Decimal loggedTotal = 0;
        for (Decimal v : loggedByItem.values()) {
            loggedTotal += v;
        }
        dto.totalLoggedHours = loggedTotal;
        dto.hasEstimate = dto.totalEstimatedHours > 0;
    }

    /**
     * @description All-time logged hours across the portfolio, read from WorkLog,
     *              keyed per WorkItem. Grouped by WorkItemLookup__c (a bare aggregate
     *              with no GROUP BY fails to compile with "Non-grouped query that uses
     *              an aggregate function"). Callers sum the values for the portfolio
     *              total and read per-item entries for per-item remaining work.
     * @param portfolioIds The in-scope WorkItem ids.
     * @return Map of WorkItem id → its all-time logged hours (items with no logs absent).
     */
    private static Map<Id, Decimal> loggedHoursByItem(Set<Id> portfolioIds) {
        Map<Id, Decimal> byItem = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT WorkItemLookup__c wid, SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkItemLookup__c IN :portfolioIds
            WITH SYSTEM_MODE
            GROUP BY WorkItemLookup__c
            LIMIT 5000
        ]) {
            Object widObj = ar.get('wid');
            Object totalObj = ar.get('total');
            if (widObj != null && totalObj != null) {
                byItem.put((Id) widObj, (Decimal) totalObj);
            }
        }
        return byItem;
    }

    /**
     * @description Builds the empty period skeleton: `back` history periods ending
     *              at the current period, then `forward` forecast periods. Period
     *              boundaries align to the granularity (week start, month start,
     *              quarter start).
     */
    private static List<PacingPeriodDTO> buildPeriodSkeleton(String gran, Integer back, Integer forward) {
        List<PacingPeriodDTO> out = new List<PacingPeriodDTO>();
        Date currentStart = periodStartFor(gran, Date.today());
        Date cursor = stepPeriod(gran, currentStart, -(back - 1));
        Integer total = back + forward;
        for (Integer i = 0; i < total; i++) {
            PacingPeriodDTO p = new PacingPeriodDTO();
            p.startDate = cursor;
            p.endDate = stepPeriod(gran, cursor, 1).addDays(-1);
            p.label = formatPeriodLabel(gran, cursor);
            p.loggedHours = 0;
            p.targetHours = 0;
            p.forecastHours = 0;
            p.isForecast = i >= back;
            p.overTarget = false;
            out.add(p);
            cursor = stepPeriod(gran, cursor, 1);
        }
        return out;
    }

    /** @description Normalizes a date to the start of its period for the granularity. */
    private static Date periodStartFor(String gran, Date d) {
        if (gran == 'Week') {
            return d.toStartOfWeek();
        }
        if (gran == 'Quarter') {
            Integer q = (d.month() - 1) / MONTHS_PER_QUARTER;
            return Date.newInstance(d.year(), q * MONTHS_PER_QUARTER + 1, 1);
        }
        return d.toStartOfMonth();
    }

    /** @description Advances a period-start date by `count` periods (may be negative). */
    private static Date stepPeriod(String gran, Date periodStart, Integer count) {
        if (gran == 'Week') {
            return periodStart.addDays(DAYS_PER_WEEK * count);
        }
        if (gran == 'Quarter') {
            return periodStart.addMonths(MONTHS_PER_QUARTER * count);
        }
        return periodStart.addMonths(count);
    }

    private static String formatPeriodLabel(String gran, Date periodStart) {
        if (gran == 'Week') {
            return 'Wk ' + formatMonthLabel(periodStart).split(' ')[0]
                + ' ' + String.valueOf(periodStart.day());
        }
        if (gran == 'Quarter') {
            Integer q = (periodStart.month() - 1) / MONTHS_PER_QUARTER + 1;
            return 'Q' + q + ' ' + String.valueOf(periodStart.year()).substring(2);
        }
        return formatMonthLabel(periodStart);
    }

    /**
     * @description Fills the history periods with actual logged hours from ONE
     *              window-bounded WorkLog AggregateResult, grouped by the
     *              granularity's calendar function.
     */
    private static void applyPortfolioLoggedHours(List<PacingPeriodDTO> periods, Set<Id> portfolioIds, String gran) {
        if (periods.isEmpty() || portfolioIds.isEmpty()) {
            return;
        }
        Date windowStart = periods[0].startDate;
        Date windowEnd = periods[periods.size() - 1].endDate;
        Map<String, PacingPeriodDTO> byKey = new Map<String, PacingPeriodDTO>();
        for (PacingPeriodDTO p : periods) {
            byKey.put(dateKey(periodStartFor(gran, p.startDate)), p);
        }
        for (AggregateResult ar : queryLoggedByPeriod(portfolioIds, windowStart, windowEnd, gran)) {
            Object totalObj = ar.get('total');
            if (totalObj == null) {
                continue;
            }
            Date keyDate = periodStartFromAggregate(gran, ar);
            if (keyDate == null) {
                continue;
            }
            PacingPeriodDTO bucket = byKey.get(dateKey(keyDate));
            if (bucket != null) {
                bucket.loggedHours = (Decimal) totalObj;
            }
        }
    }

    /**
     * @description Runs the granularity-specific grouped aggregate. WEEK_IN_YEAR /
     *              CALENDAR_MONTH / CALENDAR_QUARTER each carry MIN(date) so the
     *              bucket can be mapped back to a concrete period-start date.
     */
    private static List<AggregateResult> queryLoggedByPeriod(Set<Id> portfolioIds, Date windowStart, Date windowEnd, String gran) {
        if (gran == 'Week') {
            return [
                SELECT MIN(WorkDateDate__c) minDate, SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :portfolioIds
                  AND WorkDateDate__c >= :windowStart
                  AND WorkDateDate__c <= :windowEnd
                WITH SYSTEM_MODE
                GROUP BY CALENDAR_YEAR(WorkDateDate__c), WEEK_IN_YEAR(WorkDateDate__c)
                LIMIT 5000
            ];
        }
        if (gran == 'Quarter') {
            return [
                SELECT CALENDAR_YEAR(WorkDateDate__c) y, CALENDAR_QUARTER(WorkDateDate__c) q,
                       SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :portfolioIds
                  AND WorkDateDate__c >= :windowStart
                  AND WorkDateDate__c <= :windowEnd
                WITH SYSTEM_MODE
                GROUP BY CALENDAR_YEAR(WorkDateDate__c), CALENDAR_QUARTER(WorkDateDate__c)
                LIMIT 5000
            ];
        }
        return [
            SELECT CALENDAR_YEAR(WorkDateDate__c) y, CALENDAR_MONTH(WorkDateDate__c) m,
                   SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkItemLookup__c IN :portfolioIds
              AND WorkDateDate__c >= :windowStart
              AND WorkDateDate__c <= :windowEnd
            WITH SYSTEM_MODE
            GROUP BY CALENDAR_YEAR(WorkDateDate__c), CALENDAR_MONTH(WorkDateDate__c)
            LIMIT 5000
        ];
    }

    /** @description Stable, locale-independent map key for a period-start date. */
    private static String dateKey(Date d) {
        return d.year() + '-' + d.month() + '-' + d.day();
    }

    /** @description Resolves an aggregate row back to its period-start date. */
    private static Date periodStartFromAggregate(String gran, AggregateResult ar) {
        if (gran == 'Week') {
            Date minDate = (Date) ar.get('minDate');
            return minDate == null ? null : minDate.toStartOfWeek();
        }
        if (gran == 'Quarter') {
            Integer y = (Integer) ar.get('y');
            Integer q = (Integer) ar.get('q');
            return Date.newInstance(y, (q - 1) * MONTHS_PER_QUARTER + 1, 1);
        }
        Integer yr = (Integer) ar.get('y');
        Integer m = (Integer) ar.get('m');
        return Date.newInstance(yr, m, 1);
    }

    /**
     * @description Amortizes the portfolio estimate across each period in
     *              proportion to how many of the period's days fall inside the
     *              planned active span [earliestStart, latestEnd]. Generalizes
     *              computeMonthlyTarget to variable-length periods. No-op (target
     *              stays 0) when the portfolio has no estimate or no planned span.
     */
    private static void applyPortfolioTargets(List<PacingPeriodDTO> periods, PortfolioPacingDTO dto) {
        if (!dto.hasEstimate || dto.earliestStart == null || dto.latestEnd == null) {
            return;
        }
        Integer spanDays = dto.earliestStart.daysBetween(dto.latestEnd) + 1;
        if (spanDays <= 0) {
            return;
        }
        Decimal perDay = dto.totalEstimatedHours / spanDays;
        for (PacingPeriodDTO p : periods) {
            Integer overlap = overlapDays(p.startDate, p.endDate, dto.earliestStart, dto.latestEnd);
            if (overlap <= 0) {
                continue;
            }
            p.targetHours = (perDay * overlap).setScale(2, System.RoundingMode.HALF_UP);
            p.overTarget = !p.isForecast && p.targetHours > 0 && p.loggedHours > p.targetHours;
        }
    }

    /** @description Count of days in [aStart,aEnd] that intersect [bStart,bEnd]. */
    private static Integer overlapDays(Date aStart, Date aEnd, Date bStart, Date bEnd) {
        Date lo = aStart > bStart ? aStart : bStart;
        Date hi = aEnd < bEnd ? aEnd : bEnd;
        if (lo > hi) {
            return 0;
        }
        return lo.daysBetween(hi) + 1;
    }

    /**
     * @description Builds the per-period forecast bars from the PLAN (schedule-based),
     *              not historical velocity: each in-flight item's REMAINING estimate is
     *              spread linearly across its OWN future scheduled span (see
     *              spreadScheduleBasedForecast). Items that can't be placed on the
     *              future timeline (no dates / overdue with work remaining) go to
     *              unscheduledRemainingHours. The headline projectedFinalHours stays
     *              logged + the FULL remaining work across ALL in-scope items
     *              (totalRemainingHours, computed in rollupPortfolioTotals), independent
     *              of the display window, so it equals the estimate when on-budget and
     *              only exceeds it for genuinely over-budget items. runRateHoursPerPeriod
     *              is still reported (historical velocity signal) but no longer drives
     *              the bars. Also sets the over-budget-trajectory flag.
     */
    private static void applyPortfolioForecast(List<PacingPeriodDTO> periods, PortfolioPacingDTO dto, Integer back) {
        dto.runRateHoursPerPeriod = 0;
        dto.projectedFinalHours = dto.totalLoggedHours;
        dto.unscheduledRemainingHours = 0;
        dto.isOverBudgetTrajectory = false;

        // Run-rate retained for reporting (historical velocity signal) — it no longer
        // drives the bars, which now come from each item's PLAN, not its velocity.
        Decimal runRate = computeRunRate(periods, back);
        dto.runRateHoursPerPeriod = runRate.setScale(2, System.RoundingMode.HALF_UP);

        spreadScheduleBasedForecast(periods, dto, back);

        // Headline: logged + ALL remaining work (per-item max(0, estimate − logged)),
        // independent of the display window — out-of-window remaining still counts and
        // stays consistent with the placed bars + unscheduled (≈ total remaining).
        Decimal remainingAll = (totalRemainingHours == null) ? 0 : totalRemainingHours;
        dto.projectedFinalHours = (dto.totalLoggedHours + remainingAll)
            .setScale(2, System.RoundingMode.HALF_UP);
        if (dto.hasEstimate) {
            // W5.4 (F15) — "over budget" fires only STRICTLY ABOVE 100% at the same
            // whole-percent precision the card displays. The raw projected-vs-estimate
            // comparison could flip the flag on a fractional overshoot that still
            // DISPLAYS as "PACING 100%" (the audited 247h == 247h case), pairing an
            // at-budget number with an over-budget label. Rounding the percentage to
            // the displayed precision first means the label and the number can never
            // disagree: 100.4% reads (and is flagged) as at-budget, 101% as over.
            Decimal pacingPct = (dto.projectedFinalHours / dto.totalEstimatedHours) * 100;
            dto.isOverBudgetTrajectory =
                pacingPct.setScale(0, System.RoundingMode.HALF_UP) > 100;
        }
    }

    /**
     * @description Schedule-based per-period forecast bars: for each in-scope item
     *              with remaining work, spread its REMAINING estimate linearly across
     *              its OWN future span [max(today, itemStart) .. itemEnd] using the
     *              same overlapDays + per-day-rate amortization as applyPortfolioTargets,
     *              but per item and over the not-yet-elapsed portion only. Items with
     *              no start/end, or whose planned end is already past while work remains
     *              (overdue), can't be placed on the future timeline — their remaining
     *              accumulates into unscheduledRemainingHours instead of fabricating a
     *              period bar. Resets every forecast period's forecastHours to 0 first.
     */
    private static void spreadScheduleBasedForecast(List<PacingPeriodDTO> periods, PortfolioPacingDTO dto, Integer back) {
        // Reset every forecast period (bars) and prime a per-period drill-down map
        // parallel to the period list so toPacingData can compose each bucket's items[].
        forecastItemsByPeriod = new List<Map<Id, ForecastItemAccum>>();
        for (Integer i = 0; i < periods.size(); i++) {
            forecastItemsByPeriod.add(new Map<Id, ForecastItemAccum>());
            if (i >= back) {
                periods[i].forecastHours = 0;
            }
        }

        Date today = Date.today();
        Decimal unscheduled = 0;
        for (ItemSchedule sched : portfolioItemSchedules) {
            // Terminal-stage items contribute 0 remaining — never spread onto a forecast
            // bar and never pushed into the unscheduled bucket (dead work isn't forecast).
            if (String.isNotBlank(sched.stage) && terminalStages.contains(sched.stage)) {
                continue;
            }
            Decimal itemRemaining = sched.estimate - sched.logged;
            if (itemRemaining == null || itemRemaining <= 0) {
                continue;
            }
            // No dates, or planned window already elapsed → can't place on the timeline.
            if (sched.startDate == null || sched.endDate == null || sched.endDate < today) {
                unscheduled += itemRemaining;
                continue;
            }
            Date futureStart = (sched.startDate > today) ? sched.startDate : today;
            Date futureEnd = sched.endDate;
            Integer spanDays = futureStart.daysBetween(futureEnd) + 1;
            if (spanDays <= 0) {
                unscheduled += itemRemaining;
                continue;
            }
            Decimal perDay = itemRemaining / spanDays;
            for (Integer i = back; i < periods.size(); i++) {
                PacingPeriodDTO p = periods[i];
                Integer overlap = overlapDays(p.startDate, p.endDate, futureStart, futureEnd);
                if (overlap <= 0) {
                    continue;
                }
                Decimal hoursThisPeriod = perDay * overlap;
                p.forecastHours = p.forecastHours + hoursThisPeriod;
                recordForecastItem(i, sched, hoursThisPeriod);
            }
        }

        // Round the accumulated bars at the end.
        for (Integer i = back; i < periods.size(); i++) {
            periods[i].forecastHours = periods[i].forecastHours.setScale(2, System.RoundingMode.HALF_UP);
        }
        dto.unscheduledRemainingHours = unscheduled.setScale(2, System.RoundingMode.HALF_UP);
    }

    /**
     * @description Accumulates one item's drill-down contribution to a forecast period
     *              (summed across multiple overlap fragments of the same item+period).
     *              Skips items with no Id (defensive — every in-scope item is queried
     *              with Id). Keyed by WorkItem Id so a re-entered item adds to its
     *              existing per-period total.
     * @param periodIndex Index into forecastItemsByPeriod (parallel to the period list).
     * @param sched The item's captured schedule + meta.
     * @param hoursThisPeriod Hours this fragment places on the period.
     */
    private static void recordForecastItem(Integer periodIndex, ItemSchedule sched, Decimal hoursThisPeriod) {
        if (sched.workItemId == null) {
            return;
        }
        Map<Id, ForecastItemAccum> byItem = forecastItemsByPeriod[periodIndex];
        ForecastItemAccum acc = byItem.get(sched.workItemId);
        if (acc == null) {
            acc = new ForecastItemAccum();
            acc.sched = sched;
            byItem.put(sched.workItemId, acc);
        }
        acc.hoursThisPeriod += hoursThisPeriod;
    }

    /**
     * @description Average logged hours across the trailing RUN_RATE_WINDOW
     *              history periods. Counts only history periods (index < back).
     */
    private static Decimal computeRunRate(List<PacingPeriodDTO> periods, Integer back) {
        if (back <= 0) {
            return 0;
        }
        Integer window = Math.min(RUN_RATE_WINDOW, back);
        Integer startIdx = back - window;
        Decimal sum = 0;
        for (Integer i = startIdx; i < back; i++) {
            sum += periods[i].loggedHours;
        }
        if (window == 0) {
            return 0;
        }
        return sum / window;
    }

}
