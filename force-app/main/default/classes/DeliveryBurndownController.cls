/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides burndown chart data for the deliveryBurndownChart LWC.
 *              Queries WorkItem__c records grouped by week, calculating running
 *              totals of created, completed, and open items over a 12-week window.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryBurndownController {

    /** @description Number of weeks of history to return. */
    private static final Integer WEEKS_TO_SHOW = 12;

    /** @description Milliseconds in one day — not used in Apex but kept for clarity. */
    private static final Integer DAYS_PER_WEEK = 7;

    /**
     * @description Returns weekly burndown data for the given workflow type.
     * Each entry contains: date (ISO Monday of that week), totalCreated, totalCompleted, openCount.
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record. Defaults to
     *                         'Software_Delivery' when blank.
     * @return List of maps with keys: date, totalCreated, totalCompleted, openCount.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getBurndownData(String workflowTypeName) {
        try {
            if (String.isBlank(workflowTypeName)) {
                workflowTypeName = 'Software_Delivery';
            }

            Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowTypeName);
            Date windowStart = calculateWindowStart();

            List<WorkItem__c> workItems = queryWorkItems(workflowTypeName, windowStart);

            Map<Date, Integer> createdByWeek = new Map<Date, Integer>();
            Map<Date, Integer> completedByWeek = new Map<Date, Integer>();
            buildWeeklyBuckets(workItems, terminalStages, createdByWeek, completedByWeek);

            return assembleResult(windowStart, createdByWeek, completedByWeek);
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Calculates the Monday that starts our 12-week window.
     * @return Date representing the Monday 12 weeks before the current week's Monday.
     */
    private static Date calculateWindowStart() {
        Date today = Date.today();
        // toStartOfWeek() returns locale-based start. Force to Monday (ISO week).
        Date startOfWeek = today.toStartOfWeek();
        // Salesforce toStartOfWeek uses locale; adjust to Monday if it returned Sunday
        if (startOfWeek.daysBetween(today) == 0 && isSunday(today)) {
            startOfWeek = startOfWeek.addDays(1);
        }
        return startOfWeek.addDays(-(WEEKS_TO_SHOW - 1) * DAYS_PER_WEEK);
    }

    /**
     * @description Checks whether a given date falls on a Sunday.
     * @param d The date to check.
     * @return True if the date is a Sunday.
     */
    private static Boolean isSunday(Date d) {
        // Date.newInstance(2024,1,7) is a known Sunday
        Date knownSunday = Date.newInstance(2024, 1, 7);
        return Math.mod(knownSunday.daysBetween(d), 7) == 0;
    }

    /**
     * @description Returns the Monday of the ISO week containing the given date.
     * @param d Any date.
     * @return The Monday of that ISO week.
     */
    private static Date toMonday(Date d) {
        Date startOfWeek = d.toStartOfWeek();
        // If locale start is Sunday, Monday is +1
        Date knownSunday = Date.newInstance(2024, 1, 7);
        Integer daysSinceKnownSunday = Math.mod(knownSunday.daysBetween(d), 7);
        // daysSinceKnownSunday: 0=Sun, 1=Mon, 2=Tue, ...
        if (daysSinceKnownSunday == 0) {
            return d.addDays(1); // Sun → next Mon
        }
        return d.addDays(-(daysSinceKnownSunday - 1)); // Roll back to Mon
    }

    /**
     * @description Queries WorkItem__c records for the given workflow type created on or after
     *              the window start date.
     * @param workflowTypeName The workflow type developer name.
     * @param windowStart The earliest date to include.
     * @return List of WorkItem__c records.
     */
    private static List<WorkItem__c> queryWorkItems(String workflowTypeName, Date windowStart) {
        return [
            SELECT Id, CreatedDate, LastModifiedDate, StageNamePk__c
            FROM WorkItem__c
            WHERE WorkflowTypeTxt__c = :workflowTypeName
            AND CreatedDate >= :windowStart
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
        ];
    }

    /**
     * @description Populates the created-by-week and completed-by-week maps from work items.
     * @param workItems The queried work items.
     * @param terminalStages Set of stage values considered terminal (completed).
     * @param createdByWeek Output map: Monday date to count of items created that week.
     * @param completedByWeek Output map: Monday date to count of items completed that week.
     */
    private static void buildWeeklyBuckets(
        List<WorkItem__c> workItems,
        Set<String> terminalStages,
        Map<Date, Integer> createdByWeek,
        Map<Date, Integer> completedByWeek
    ) {
        for (WorkItem__c wi : workItems) {
            Date createdMonday = toMonday(wi.CreatedDate.date());
            Integer createdCount = createdByWeek.containsKey(createdMonday)
                ? createdByWeek.get(createdMonday) : 0;
            createdByWeek.put(createdMonday, createdCount + 1);

            if (terminalStages.contains(wi.StageNamePk__c)) {
                Date completedMonday = toMonday(wi.LastModifiedDate.date());
                Integer completedCount = completedByWeek.containsKey(completedMonday)
                    ? completedByWeek.get(completedMonday) : 0;
                completedByWeek.put(completedMonday, completedCount + 1);
            }
        }
    }

    /**
     * @description Builds the final list of weekly data points with running totals.
     * @param windowStart The Monday that begins the 12-week window.
     * @param createdByWeek Map of Monday dates to created counts.
     * @param completedByWeek Map of Monday dates to completed counts.
     * @return Ordered list of maps representing each week.
     */
    private static List<Map<String, Object>> assembleResult(
        Date windowStart,
        Map<Date, Integer> createdByWeek,
        Map<Date, Integer> completedByWeek
    ) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        Integer cumulativeCreated = 0;
        Integer cumulativeCompleted = 0;

        for (Integer i = 0; i < WEEKS_TO_SHOW; i++) {
            Date weekMonday = windowStart.addDays(i * DAYS_PER_WEEK);
            Integer weekCreated = createdByWeek.containsKey(weekMonday)
                ? createdByWeek.get(weekMonday) : 0;
            Integer weekCompleted = completedByWeek.containsKey(weekMonday)
                ? completedByWeek.get(weekMonday) : 0;

            cumulativeCreated += weekCreated;
            cumulativeCompleted += weekCompleted;

            Map<String, Object> row = new Map<String, Object>();
            row.put('date', String.valueOf(weekMonday));
            row.put('totalCreated', cumulativeCreated);
            row.put('totalCompleted', cumulativeCompleted);
            row.put('openCount', cumulativeCreated - cumulativeCompleted);
            result.add(row);
        }

        return result;
    }
}
