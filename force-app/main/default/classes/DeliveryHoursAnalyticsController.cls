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
}
