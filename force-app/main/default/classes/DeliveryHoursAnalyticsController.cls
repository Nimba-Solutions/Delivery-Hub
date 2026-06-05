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
 *              forecast across the portfolio, bucketed at Week/Month/Quarter
 *              granularity. The ACTUALS (per-period logged bars + totalLoggedHours
 *              headline) count ALL WorkLog hours by WorkDateDate__c — no
 *              active-portfolio filter — so completed/archived work is never
 *              dropped from the historical totals. The FORECAST is schedule-based:
 *              each in-flight WorkItem's remaining estimate (estimate − logged) is
 *              spread evenly across the forward periods its
 *              EstimatedStartDevDate__c → EstimatedEndDevDate__c span covers — the
 *              SAME two fields the Gantt drag-writes, so the two views can't drift.
 *              Remaining that can't be placed on the calendar (no usable dates, or
 *              an end date in the past) accumulates into unscheduledRemainingHours
 *              rather than being silently dropped. Backs the deliveryPacingForecast
 *              HomePage LWC. ZERO new objects/fields.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.OperationWithLimitsInLoop')
global with sharing class DeliveryHoursAnalyticsController {

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

    /**
     * @description Cap on the number of in-flight WorkItems pulled for the
     *              schedule-based forecast. When the active set exceeds this,
     *              the forecast is computed from the first MAX_INFLIGHT_ITEMS and
     *              forecastCapped is flagged so the LWC can note the truncation.
     */
    private static final Integer MAX_INFLIGHT_ITEMS = 2000;

    /** @description Number of trailing history periods averaged for the run-rate. */
    private static final Integer RUN_RATE_WINDOW = 4;

    /** @description Days in a week — period stepping for Week granularity. */
    private static final Integer DAYS_PER_WEEK = 7;

    /** @description Months in a quarter — period stepping for Quarter granularity. */
    private static final Integer MONTHS_PER_QUARTER = 3;

    /** @description Terminal stages excluded from the active-portfolio scope. */
    private static final Set<String> TERMINAL_STAGES = new Set<String>{
        'Done', 'Cancelled', 'Closed', 'Rejected'
    };

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
    }

    /** @description Portfolio-level pacing + forecast headline returned to the LWC. */
    global class PortfolioPacingDTO {
        @AuraEnabled global String granularity;
        @AuraEnabled global Integer rootCount;
        @AuraEnabled global Decimal totalEstimatedHours;
        @AuraEnabled global Decimal totalLoggedHours;
        @AuraEnabled global Decimal projectedFinalHours;
        @AuraEnabled global Decimal runRateHoursPerPeriod;
        @AuraEnabled global Decimal blendedRate;
        @AuraEnabled global Boolean hasEstimate;
        @AuraEnabled global Boolean isOverBudgetTrajectory;
        /**
         * @description Remaining in-flight estimate (estimate − logged) that
         *              cannot be placed on the forecast calendar because the item
         *              has no usable EstimatedStart/End span (or its end date is in
         *              the past). Surfaced — not dropped — so the card can prompt
         *              "N hours of un-dated work the forecast can't place — set
         *              dates on the Gantt."
         */
        @AuraEnabled global Decimal unscheduledRemainingHours;
        /**
         * @description Total remaining in-flight estimate across all items
         *              (scheduled-spread + unscheduled). projectedFinalHours =
         *              totalLoggedHours + totalRemainingHours.
         */
        @AuraEnabled global Decimal totalRemainingHours;
        /** @description Count of in-flight WorkItems considered for the forecast. */
        @AuraEnabled global Integer inFlightCount;
        /** @description True when the in-flight set was truncated at MAX_INFLIGHT_ITEMS. */
        @AuraEnabled global Boolean forecastCapped;
        @AuraEnabled global Date earliestStart;
        @AuraEnabled global Date latestEnd;
        @AuraEnabled global List<PacingPeriodDTO> periods;
    }

    /**
     * @description Account/org-level pacing + schedule-based forecast.
     *              Builds a period skeleton of `periodsBack` history periods plus
     *              `periodsForward` forecast periods at the requested granularity.
     *
     *              ACTUALS (history bars + totalLoggedHours headline) count ALL
     *              WorkLog hours by WorkDateDate__c — there is NO active-portfolio
     *              filter on the actuals, so completed/archived work is never
     *              dropped from the totals.
     *
     *              FORECAST is schedule-based: each in-flight WorkItem's remaining
     *              estimate (estimate − logged-so-far) is spread evenly across the
     *              forward periods its EstimatedStart → EstimatedEnd span covers.
     *              Remaining that can't be placed on the calendar accumulates into
     *              unscheduledRemainingHours. projectedFinalHours =
     *              totalLoggedHours + Σ remaining(all in-flight).
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

            PortfolioPacingDTO dto = new PortfolioPacingDTO();
            dto.granularity = gran;
            dto.rootCount = rootIds.size();
            // Actuals are decoupled from the active portfolio scope — count ALL
            // logged hours so completed work is reflected in the totals.
            rollupPortfolioTotals(dto, rootIds);

            List<PacingPeriodDTO> periods = buildPeriodSkeleton(gran, back, forward);
            // ALL logged hours by WorkDateDate__c, not scoped to the portfolio tree.
            applyPortfolioLoggedHours(periods, gran);
            applyPortfolioTargets(periods, dto);
            applyScheduleBasedForecast(periods, dto, gran, back);

            dto.periods = periods;
            dto.blendedRate = resolveBlendedRate();
            return dto;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
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
              AND StageNamePk__c NOT IN :TERMINAL_STAGES
            WITH SYSTEM_MODE
            LIMIT :MAX_PORTFOLIO_ROOTS
        ]) {
            ids.add(wi.Id);
        }
        return ids;
    }

    /**
     * @description Expands the active roots into their full descendant trees via
     *              a level-by-level BFS (capped at MAX_TREE_DEPTH), bulk across all
     *              roots so each depth level is ONE query — no per-root loop.
     */
    private static Set<Id> collectPortfolioTree(Set<Id> rootIds) {
        Set<Id> collected = new Set<Id>(rootIds);
        Set<Id> frontier = new Set<Id>(rootIds);
        for (Integer depth = 0; depth < MAX_TREE_DEPTH && !frontier.isEmpty(); depth++) {
            Set<Id> next = new Set<Id>();
            for (WorkItem__c child : [
                SELECT Id
                FROM WorkItem__c
                WHERE ParentWorkItemLookup__c IN :frontier
                WITH SYSTEM_MODE
                LIMIT 50000
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

    /**
     * @description Sums the portfolio estimate and planned start/end span from the
     *              active portfolio tree (used only for the amortized TARGET line),
     *              and the all-time logged hours across EVERY WorkLog regardless of
     *              scope. The logged total is decoupled from the active-portfolio
     *              filter on purpose: completed/archived work still counts toward
     *              the actuals headline (the old scope filter undercounted it).
     * @param rootIds Active root WorkItem Ids (expanded to their trees here for the
     *                estimate/span; the logged total ignores this set entirely).
     */
    private static void rollupPortfolioTotals(PortfolioPacingDTO dto, Set<Id> rootIds) {
        dto.totalEstimatedHours = 0;
        dto.earliestStart = null;
        dto.latestEnd = null;

        Set<Id> portfolioIds = collectPortfolioTree(rootIds);
        if (!portfolioIds.isEmpty()) {
            for (WorkItem__c wi : [
                SELECT EstimatedHoursNumber__c,
                       EstimatedStartDevDate__c, EstimatedEndDevDate__c
                FROM WorkItem__c
                WHERE Id IN :portfolioIds
                WITH SYSTEM_MODE
                LIMIT 50000
            ]) {
                if (wi.EstimatedHoursNumber__c != null) {
                    dto.totalEstimatedHours += wi.EstimatedHoursNumber__c;
                }
                Date s = wi.EstimatedStartDevDate__c;
                if (s != null && (dto.earliestStart == null || s < dto.earliestStart)) {
                    dto.earliestStart = s;
                }
                Date e = wi.EstimatedEndDevDate__c;
                if (e != null && (dto.latestEnd == null || e > dto.latestEnd)) {
                    dto.latestEnd = e;
                }
            }
        }
        // ALL logged hours — no WorkItem scope filter — so completed work counts.
        dto.totalLoggedHours = sumAllLoggedHours();
        dto.hasEstimate = dto.totalEstimatedHours > 0;
    }

    /**
     * @description All-time logged hours across EVERY WorkLog in the org, read
     *              directly from WorkLog (NOT the TotalLoggedHoursSum__c roll-up,
     *              so the headline is correct regardless of roll-up recalc timing).
     *              No WorkItem scope filter: on a single-client org all logged work
     *              is that client's work, and dropping completed items undercounts.
     *              Grouped by WorkItemLookup__c (a bare aggregate with no GROUP BY
     *              fails to compile) and summed in Apex.
     */
    private static Decimal sumAllLoggedHours() {
        Decimal total = 0;
        for (AggregateResult ar : [
            SELECT SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE HoursLoggedNumber__c != NULL
            WITH SYSTEM_MODE
            GROUP BY WorkItemLookup__c
            LIMIT 50000
        ]) {
            Object totalObj = ar.get('total');
            if (totalObj != null) {
                total += (Decimal) totalObj;
            }
        }
        return total;
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
     *              granularity's calendar function. Counts ALL WorkLog hours in the
     *              window — there is no WorkItem scope filter — so the per-period
     *              bars equal the raw GROUP BY CALENDAR_x(WorkDateDate__c) totals.
     */
    private static void applyPortfolioLoggedHours(List<PacingPeriodDTO> periods, String gran) {
        if (periods.isEmpty()) {
            return;
        }
        Date windowStart = periods[0].startDate;
        Date windowEnd = periods[periods.size() - 1].endDate;
        Map<String, PacingPeriodDTO> byKey = new Map<String, PacingPeriodDTO>();
        for (PacingPeriodDTO p : periods) {
            byKey.put(dateKey(periodStartFor(gran, p.startDate)), p);
        }
        for (AggregateResult ar : queryLoggedByPeriod(windowStart, windowEnd, gran)) {
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
     * @description Runs the granularity-specific grouped aggregate over ALL
     *              WorkLogs in the window (no WorkItem scope filter). WEEK_IN_YEAR /
     *              CALENDAR_MONTH / CALENDAR_QUARTER each carry MIN(date) so the
     *              bucket can be mapped back to a concrete period-start date.
     */
    private static List<AggregateResult> queryLoggedByPeriod(Date windowStart, Date windowEnd, String gran) {
        if (gran == 'Week') {
            return [
                SELECT MIN(WorkDateDate__c) minDate, SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkDateDate__c >= :windowStart
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
                WHERE WorkDateDate__c >= :windowStart
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
            WHERE WorkDateDate__c >= :windowStart
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

    /** @description One in-flight WorkItem's forecast inputs: remaining + schedule. */
    private class InFlightItem {
        Decimal remaining;
        Date startDate;
        Date endDate;
    }

    /**
     * @description SCHEDULE-BASED forecast. Pulls every in-flight WorkItem (active,
     *              non-terminal, non-archived, non-template), computes each item's
     *              remaining = max(0, estimate − logged-so-far), and spreads that
     *              remaining EVENLY across the forward periods the item's
     *              EstimatedStart → EstimatedEnd span covers — the SAME two fields
     *              the Gantt drag-writes, so the two views can't drift. Remaining
     *              that can't be placed on the forward calendar (no usable dates, or
     *              an end date before the current period) goes to
     *              unscheduledRemainingHours instead of being dropped.
     *
     *              projectedFinalHours = totalLoggedHours + Σ remaining(all in-flight).
     *              The trailing run-rate is still computed as an informational
     *              headline (runRateHoursPerPeriod) but no longer drives the bars.
     * @param periods The period skeleton (history + forecast).
     * @param dto     Headline DTO (mutated: forecast fields + projectedFinalHours).
     * @param gran    Granularity for whole-period allocation alignment.
     * @param back    Count of leading history periods; forward periods are [back..n).
     */
    private static void applyScheduleBasedForecast(List<PacingPeriodDTO> periods, PortfolioPacingDTO dto, String gran, Integer back) {
        dto.runRateHoursPerPeriod = computeRunRate(periods, back).setScale(2, System.RoundingMode.HALF_UP);
        dto.unscheduledRemainingHours = 0;
        dto.totalRemainingHours = 0;
        dto.forecastCapped = false;

        List<InFlightItem> items = loadInFlightItems(dto);
        dto.inFlightCount = items.size();

        // Forward periods only — the band where remaining can be placed.
        List<PacingPeriodDTO> forward = new List<PacingPeriodDTO>();
        for (Integer i = back; i < periods.size(); i++) {
            forward.add(periods[i]);
        }
        Date currentPeriodStart = periodStartFor(gran, Date.today());

        Decimal totalRemaining = 0;
        Decimal unscheduled = 0;
        for (InFlightItem item : items) {
            if (item.remaining == null || item.remaining <= 0) {
                continue;
            }
            totalRemaining += item.remaining;
            Boolean placed = spreadRemaining(item, forward, currentPeriodStart);
            if (!placed) {
                unscheduled += item.remaining;
            }
        }

        for (PacingPeriodDTO p : forward) {
            p.forecastHours = p.forecastHours.setScale(2, System.RoundingMode.HALF_UP);
        }

        dto.totalRemainingHours = totalRemaining.setScale(2, System.RoundingMode.HALF_UP);
        dto.unscheduledRemainingHours = unscheduled.setScale(2, System.RoundingMode.HALF_UP);
        dto.projectedFinalHours = (dto.totalLoggedHours + totalRemaining)
            .setScale(2, System.RoundingMode.HALF_UP);
        dto.isOverBudgetTrajectory = dto.hasEstimate
            && dto.projectedFinalHours > dto.totalEstimatedHours;
    }

    /**
     * @description Spreads an item's remaining evenly across the forward periods its
     *              schedule covers — from max(currentPeriodStart, EstimatedStart)
     *              through EstimatedEnd, aligned to the granularity's whole periods.
     *              Adds each period's share onto its forecastHours.
     * @param item    The in-flight item (remaining + start/end).
     * @param forward The forecast periods (in chronological order).
     * @param currentPeriodStart Start of the period containing today.
     * @return True when the remaining was placed onto at least one forward period;
     *         false when it couldn't be scheduled (caller treats as unscheduled).
     */
    private static Boolean spreadRemaining(InFlightItem item, List<PacingPeriodDTO> forward, Date currentPeriodStart) {
        if (forward.isEmpty() || item.startDate == null || item.endDate == null) {
            return false;
        }
        // End in the past (before the current period) → nothing to place forward.
        if (item.endDate < currentPeriodStart) {
            return false;
        }
        // Clamp the placement window's left edge to the current period.
        Date effectiveStart = item.startDate > currentPeriodStart ? item.startDate : currentPeriodStart;
        if (effectiveStart > item.endDate) {
            effectiveStart = item.endDate;
        }
        // Collect the forward periods this item's span touches.
        List<PacingPeriodDTO> covered = new List<PacingPeriodDTO>();
        for (PacingPeriodDTO p : forward) {
            if (p.endDate >= effectiveStart && p.startDate <= item.endDate) {
                covered.add(p);
            }
        }
        if (covered.isEmpty()) {
            // Schedule falls entirely beyond the visible forward horizon — still a
            // real, dated commitment; do NOT route to unscheduled. Drop the share
            // into the last visible forward period so the total stays whole.
            forward[forward.size() - 1].forecastHours += item.remaining;
            return true;
        }
        Decimal share = item.remaining / covered.size();
        for (PacingPeriodDTO p : covered) {
            p.forecastHours += share;
        }
        return true;
    }

    /**
     * @description Loads in-flight WorkItems for the schedule-based forecast: active,
     *              non-terminal, non-archived, non-template — the same active filter
     *              as the portfolio scope, but applied PER ITEM (not tree-rolled).
     *              Computes each item's logged-so-far by summing its WorkLogs (one
     *              aggregate, bulk) for accuracy, falling back to TotalLoggedHoursSum__c
     *              only when no WorkLogs exist. Sets dto.forecastCapped when the
     *              active set is truncated at MAX_INFLIGHT_ITEMS.
     */
    private static List<InFlightItem> loadInFlightItems(PortfolioPacingDTO dto) {
        List<WorkItem__c> wis = [
            SELECT Id, EstimatedHoursNumber__c, TotalLoggedHoursSum__c,
                   EstimatedStartDevDate__c, EstimatedEndDevDate__c
            FROM WorkItem__c
            WHERE ActivatedDateTime__c != NULL
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
              AND StageNamePk__c NOT IN :TERMINAL_STAGES
              AND EstimatedHoursNumber__c != NULL
              AND EstimatedHoursNumber__c > 0
            WITH SYSTEM_MODE
            ORDER BY EstimatedEndDevDate__c ASC NULLS LAST
            LIMIT :MAX_INFLIGHT_ITEMS
        ];
        if (wis.size() == MAX_INFLIGHT_ITEMS) {
            dto.forecastCapped = true;
            System.debug(LoggingLevel.WARN,
                'DeliveryHoursAnalyticsController: in-flight forecast set capped at '
                + MAX_INFLIGHT_ITEMS + ' items — projection may be partial.');
        }

        Map<Id, Decimal> loggedByItem = sumLoggedByItem(wis);

        List<InFlightItem> out = new List<InFlightItem>();
        for (WorkItem__c wi : wis) {
            Decimal logged = loggedByItem.containsKey(wi.Id)
                ? loggedByItem.get(wi.Id)
                : (wi.TotalLoggedHoursSum__c != null ? wi.TotalLoggedHoursSum__c : 0);
            Decimal remaining = wi.EstimatedHoursNumber__c - logged;
            if (remaining < 0) {
                remaining = 0;
            }
            InFlightItem fi = new InFlightItem();
            fi.remaining = remaining;
            fi.startDate = wi.EstimatedStartDevDate__c;
            fi.endDate = wi.EstimatedEndDevDate__c;
            out.add(fi);
        }
        return out;
    }

    /**
     * @description Sums logged hours per WorkItem in ONE aggregate across the given
     *              items — bulk, no SOQL-in-loop. Preferred over the roll-up field
     *              for accuracy (roll-up recalc can lag).
     */
    private static Map<Id, Decimal> sumLoggedByItem(List<WorkItem__c> wis) {
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        if (wis.isEmpty()) {
            return out;
        }
        Set<Id> ids = new Map<Id, WorkItem__c>(wis).keySet();
        for (AggregateResult ar : [
            SELECT WorkItemLookup__c wiId, SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkItemLookup__c IN :ids
              AND HoursLoggedNumber__c != NULL
            WITH SYSTEM_MODE
            GROUP BY WorkItemLookup__c
            LIMIT 50000
        ]) {
            Id wiId = (Id) ar.get('wiId');
            Object totalObj = ar.get('total');
            if (wiId != null && totalObj != null) {
                out.put(wiId, (Decimal) totalObj);
            }
        }
        return out;
    }

    /**
     * @description Average logged hours across the trailing RUN_RATE_WINDOW
     *              history periods. Informational headline only — no longer drives
     *              the forecast bars. Counts only history periods (index < back).
     */
    private static Decimal computeRunRate(List<PacingPeriodDTO> periods, Integer back) {
        if (back <= 0) {
            return 0;
        }
        Integer window = Math.min(RUN_RATE_WINDOW, back);
        if (window == 0) {
            return 0;
        }
        Integer startIdx = back - window;
        Decimal sum = 0;
        for (Integer i = startIdx; i < back; i++) {
            sum += periods[i].loggedHours;
        }
        return sum / window;
    }

    /**
     * @description Reads a single blended hourly rate when EXACTLY ONE active
     *              NetworkEntity carries a DefaultHourlyRateCurrency__c, so the
     *              LWC can render a secondary $ axis. Returns null when zero or
     *              many distinct rates exist (ambiguous — hours-only display).
     */
    private static Decimal resolveBlendedRate() {
        // No describe guard: DefaultHourlyRateCurrency__c is referenced statically
        // in the SOQL below, so it is compile-time guaranteed to exist. A
        // fields.getMap().containsKey('DefaultHourlyRateCurrency__c') guard is also
        // namespace-UNSAFE — in the packaging org the map key is prefixed
        // ('delivery__defaulthourly...'), so the unprefixed containsKey returns
        // false and the method returned null in managed contexts (upload-beta only).
        List<NetworkEntity__c> rated = [
            SELECT DefaultHourlyRateCurrency__c
            FROM NetworkEntity__c
            WHERE DefaultHourlyRateCurrency__c != NULL
              AND DefaultHourlyRateCurrency__c > 0
              AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 2
        ];
        if (rated.size() == 1) {
            return rated[0].DefaultHourlyRateCurrency__c;
        }
        return null;
    }
}
