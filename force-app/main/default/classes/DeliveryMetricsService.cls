/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service class that provides board-level metrics for the
 *               deliveryBoardMetrics LWC. Returns velocity, throughput, WIP,
 *               stage distribution, priority breakdown, aging items, and
 *               completion rate data.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryMetricsService {

    // -------------------------------------------------------------------------
    // Wrapper classes — typed response for LWC
    // -------------------------------------------------------------------------

    /** Top-level wrapper returned by getBoardMetrics. */
    public class BoardMetrics {
        @AuraEnabled public List<WeeklyVelocity> velocity;
        @AuraEnabled public Decimal avgThroughputDays;
        @AuraEnabled public Decimal prevAvgThroughputDays;
        @AuraEnabled public Integer wipCount;
        @AuraEnabled public List<StageCount> stageDistribution;
        @AuraEnabled public List<PriorityCount> priorityBreakdown;
        @AuraEnabled public Integer agingItemCount;
        @AuraEnabled public List<AgingItem> agingItems;
        @AuraEnabled public Integer completedLast30;
        @AuraEnabled public Integer totalLast30;
        @AuraEnabled public Decimal completionRate;
    }

    /** Weekly velocity data point (one per week, last 4 weeks). */
    public class WeeklyVelocity {
        @AuraEnabled public String weekLabel;
        @AuraEnabled public Integer count;
    }

    /** Count of items in a given stage. */
    public class StageCount {
        @AuraEnabled public String stage;
        @AuraEnabled public String phase;
        @AuraEnabled public Integer count;
    }

    /** Count of items at a given priority level. */
    public class PriorityCount {
        @AuraEnabled public String priority;
        @AuraEnabled public Integer count;
    }

    /** A work item that has not moved in 3+ days. */
    public class AgingItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public Integer daysInStage;
    }

    // -------------------------------------------------------------------------
    // AuraEnabled entry point
    // -------------------------------------------------------------------------

    /**
     * @description Returns comprehensive board metrics for the dashboard LWC.
     * @return BoardMetrics wrapper with all metric sections populated.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static BoardMetrics getBoardMetrics() {
        BoardMetrics result = new BoardMetrics();

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        Map<String, String> stageToPhase = DeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');

        result.velocity            = calcVelocity(terminalStages);
        result.wipCount            = calcWipCount(terminalStages);
        result.stageDistribution   = calcStageDistribution(terminalStages, stageToPhase);
        result.priorityBreakdown   = calcPriorityBreakdown(terminalStages);
        calcThroughput(result, terminalStages);
        calcAgingItems(result, terminalStages);
        calcCompletionRate(result, terminalStages);

        return result;
    }

    // -------------------------------------------------------------------------
    // Private calculation helpers
    // -------------------------------------------------------------------------

    /**
     * Velocity: items completed per week for the last 4 weeks.
     */
    private static List<WeeklyVelocity> calcVelocity(Set<String> terminalStages) {
        List<WeeklyVelocity> weeks = new List<WeeklyVelocity>();

        Date today = Date.today();
        // Build 4 week boundaries (Mon-Sun buckets)
        Date currentWeekStart = today.toStartOfWeek();

        // We need 4 complete weeks ending before current week + partial current week
        // Week 0 = current partial week, weeks 1-3 = 3 prior full weeks
        List<Date> weekStarts = new List<Date>();
        for (Integer i = 3; i >= 0; i--) {
            weekStarts.add(currentWeekStart.addDays(-7 * i));
        }

        // Query all items completed in the last 4 weeks
        Date fourWeeksAgo = currentWeekStart.addDays(-21);
        Datetime fourWeeksAgoDt = Datetime.newInstance(fourWeeksAgo, Time.newInstance(0, 0, 0, 0));

        List<WorkItem__c> completedItems = [
            SELECT Id, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND StageNamePk__c != 'Cancelled'
            AND LastModifiedDate >= :fourWeeksAgoDt
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
        ];

        // Bucket into weeks
        Map<Date, Integer> weekBuckets = new Map<Date, Integer>();
        for (Date ws : weekStarts) {
            weekBuckets.put(ws, 0);
        }

        for (WorkItem__c wi : completedItems) {
            Date itemDate = wi.LastModifiedDate.date();
            Date itemWeekStart = itemDate.toStartOfWeek();
            if (weekBuckets.containsKey(itemWeekStart)) {
                weekBuckets.put(itemWeekStart, weekBuckets.get(itemWeekStart) + 1);
            }
        }

        for (Date ws : weekStarts) {
            WeeklyVelocity wv = new WeeklyVelocity();
            wv.weekLabel = Datetime.newInstance(ws, Time.newInstance(0, 0, 0, 0)).format('MMM d');
            wv.count = weekBuckets.get(ws);
            weeks.add(wv);
        }

        return weeks;
    }

    /**
     * WIP count: items currently in non-terminal stages.
     */
    private static Integer calcWipCount(Set<String> terminalStages) {
        return [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
        ];
    }

    /**
     * Stage distribution: count of items per non-terminal stage, enriched with phase.
     */
    private static List<StageCount> calcStageDistribution(Set<String> terminalStages, Map<String, String> stageToPhase) {
        List<StageCount> distribution = new List<StageCount>();

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, COUNT(Id) cnt
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
            GROUP BY StageNamePk__c
            ORDER BY COUNT(Id) DESC
        ]) {
            StageCount sc = new StageCount();
            sc.stage = (String) ar.get('stage');
            sc.count = ((Decimal) ar.get('cnt')).intValue();
            sc.phase = stageToPhase.containsKey(sc.stage) ? stageToPhase.get(sc.stage) : 'Other';
            distribution.add(sc);
        }

        return distribution;
    }

    /**
     * Priority breakdown: count of items per priority level (non-terminal only).
     */
    private static List<PriorityCount> calcPriorityBreakdown(Set<String> terminalStages) {
        List<PriorityCount> breakdown = new List<PriorityCount>();

        for (AggregateResult ar : [
            SELECT PriorityPk__c priority, COUNT(Id) cnt
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
            GROUP BY PriorityPk__c
        ]) {
            PriorityCount pc = new PriorityCount();
            pc.priority = (String) ar.get('priority');
            if (String.isBlank(pc.priority)) {
                pc.priority = 'Unset';
            }
            pc.count = ((Decimal) ar.get('cnt')).intValue();
            breakdown.add(pc);
        }

        return breakdown;
    }

    /**
     * Throughput: average days from creation to terminal stage (last 30 days)
     * and previous 30-day period for trend comparison.
     */
    private static void calcThroughput(BoardMetrics result, Set<String> terminalStages) {
        Date today = Date.today();
        Datetime thirtyDaysAgo = Datetime.newInstance(today.addDays(-30), Time.newInstance(0, 0, 0, 0));
        Datetime sixtyDaysAgo  = Datetime.newInstance(today.addDays(-60), Time.newInstance(0, 0, 0, 0));

        // Current period (last 30 days)
        List<WorkItem__c> currentCompleted = [
            SELECT CreatedDate, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND StageNamePk__c != 'Cancelled'
            AND LastModifiedDate >= :thirtyDaysAgo
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
        ];
        result.avgThroughputDays = calcAvgDays(currentCompleted);

        // Previous period (30-60 days ago)
        List<WorkItem__c> prevCompleted = [
            SELECT CreatedDate, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND StageNamePk__c != 'Cancelled'
            AND LastModifiedDate >= :sixtyDaysAgo
            AND LastModifiedDate < :thirtyDaysAgo
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
        ];
        result.prevAvgThroughputDays = calcAvgDays(prevCompleted);
    }

    /**
     * Helper: average days between CreatedDate and LastModifiedDate.
     */
    private static Decimal calcAvgDays(List<WorkItem__c> items) {
        if (items.isEmpty()) {
            return 0;
        }
        Decimal totalDays = 0;
        for (WorkItem__c wi : items) {
            Long millis = wi.LastModifiedDate.getTime() - wi.CreatedDate.getTime();
            totalDays += Decimal.valueOf(millis) / (1000 * 60 * 60 * 24);
        }
        return (totalDays / items.size()).setScale(1, RoundingMode.HALF_UP);
    }

    /**
     * Aging items: non-terminal items where StageEnteredDateTime__c is 3+ days ago.
     * Falls back to LastModifiedDate when StageEnteredDateTime__c is null.
     */
    private static void calcAgingItems(BoardMetrics result, Set<String> terminalStages) {
        Datetime threeDaysAgo = Datetime.now().addDays(-3);

        List<WorkItem__c> stale = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, StageEnteredDateTime__c, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND IsTemplateBool__c = false
            AND (
                (StageEnteredDateTime__c != null AND StageEnteredDateTime__c <= :threeDaysAgo)
                OR (StageEnteredDateTime__c = null AND LastModifiedDate <= :threeDaysAgo)
            )
            WITH SYSTEM_MODE
            ORDER BY StageEnteredDateTime__c ASC NULLS LAST
            LIMIT 50
        ];

        List<AgingItem> agingList = new List<AgingItem>();
        for (WorkItem__c wi : stale) {
            AgingItem ai = new AgingItem();
            ai.id    = wi.Id;
            ai.name  = wi.Name;
            ai.title = wi.BriefDescriptionTxt__c;
            ai.stage = wi.StageNamePk__c;

            Datetime refDate = wi.StageEnteredDateTime__c != null ? wi.StageEnteredDateTime__c : wi.LastModifiedDate;
            ai.daysInStage = refDate.date().daysBetween(Date.today());
            agingList.add(ai);
        }

        result.agingItemCount = agingList.size();
        result.agingItems = agingList;
    }

    /**
     * Completion rate: items completed vs total items created in the last 30 days.
     */
    private static void calcCompletionRate(BoardMetrics result, Set<String> terminalStages) {
        Datetime thirtyDaysAgo = Datetime.newInstance(Date.today().addDays(-30), Time.newInstance(0, 0, 0, 0));

        Integer completed = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND StageNamePk__c != 'Cancelled'
            AND LastModifiedDate >= :thirtyDaysAgo
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
        ];

        Integer total = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE CreatedDate >= :thirtyDaysAgo
            AND IsTemplateBool__c = false
            WITH SYSTEM_MODE
        ];

        result.completedLast30 = completed;
        result.totalLast30 = total;
        result.completionRate = total > 0
            ? (Decimal.valueOf(completed) / Decimal.valueOf(total) * 100).setScale(1, RoundingMode.HALF_UP)
            : 0;
    }
}
