/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for cycle time analytics. Provides weekly average cycle
 * time data for completed work items and current stage age breakdowns for active items.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryCycleTimeController {

    /** @description Number of days to look back for completed work items */
    private static final Integer LOOKBACK_DAYS = 90;

    /** @description Number of milliseconds in one day */
    private static final Long MS_PER_DAY = 86400000L;

    // -------------------------------------------------------------------------
    // AuraEnabled — called by deliveryCycleTimeChart LWC
    // -------------------------------------------------------------------------

    /**
     * @description Returns weekly average cycle time data for completed work items
     * from the last 90 days. Cycle time = LastModifiedDate - CreatedDate in days.
     * @param workflowTypeName DeveloperName of WorkflowType__mdt (defaults to Software_Delivery)
     * @return List of maps with weekLabel (String), avgCycleDays (Decimal), itemCount (Integer)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCycleTimeData(String workflowTypeName) {
        try {
            String resolvedType = resolveWorkflowType(workflowTypeName);
            Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(resolvedType);
            Date cutoff = Date.today().addDays(-LOOKBACK_DAYS);

            List<WorkItem__c> completedItems = queryCompletedItems(terminalStages, cutoff, resolvedType);
            Map<String, WeekBucket> weekMap = groupByWeek(completedItems);
            return buildWeeklyResults(weekMap);
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Returns average days in current stage for active (non-terminal) work items,
     * grouped by stage. Falls back to LastModifiedDate when StageEnteredDatetime__c is null.
     * @param workflowTypeName DeveloperName of WorkflowType__mdt (defaults to Software_Delivery)
     * @return List of maps with stageName (String), avgDays (Decimal), itemCount (Integer)
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCurrentStageAges(String workflowTypeName) {
        try {
            String resolvedType = resolveWorkflowType(workflowTypeName);
            Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(resolvedType);

            List<WorkItem__c> activeItems = queryActiveItems(terminalStages, resolvedType);
            Map<String, StageBucket> stageMap = groupByStage(activeItems);
            return buildStageResults(stageMap);
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers — workflow type resolution
    // -------------------------------------------------------------------------

    /**
     * @description Resolves the workflow type name, defaulting to Software_Delivery if blank.
     * @param workflowTypeName Raw input from the caller
     * @return Resolved workflow type developer name
     */
    private static String resolveWorkflowType(String workflowTypeName) {
        return String.isBlank(workflowTypeName) ? 'Software_Delivery' : workflowTypeName;
    }

    // -------------------------------------------------------------------------
    // Private helpers — SOQL queries
    // -------------------------------------------------------------------------

    /**
     * @description Queries completed work items in terminal stages after the cutoff date.
     * @param terminalStages Set of terminal stage API values
     * @param cutoff Earliest creation date to include
     * @param workflowType Workflow type developer name
     * @return List of completed WorkItem__c records
     */
    private static List<WorkItem__c> queryCompletedItems(
        Set<String> terminalStages, Date cutoff, String workflowType
    ) {
        return [
            SELECT Id, CreatedDate, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND LastModifiedDate >= :cutoff
            AND WorkflowTypeTxt__c = :workflowType
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate ASC
        ];
    }

    /**
     * @description Queries active (non-terminal) work items for stage age analysis.
     * @param terminalStages Set of terminal stage API values to exclude
     * @param workflowType Workflow type developer name
     * @return List of active WorkItem__c records
     */
    private static List<WorkItem__c> queryActiveItems(
        Set<String> terminalStages, String workflowType
    ) {
        return [
            SELECT Id, StageNamePk__c, StageEnteredDatetime__c, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND WorkflowTypeTxt__c = :workflowType
            WITH SYSTEM_MODE
        ];
    }

    // -------------------------------------------------------------------------
    // Private helpers — grouping logic
    // -------------------------------------------------------------------------

    /**
     * @description Groups completed work items by ISO week and accumulates cycle times.
     * @param items List of completed WorkItem__c records
     * @return Map of week label to WeekBucket aggregation
     */
    private static Map<String, WeekBucket> groupByWeek(List<WorkItem__c> items) {
        Map<String, WeekBucket> weekMap = new Map<String, WeekBucket>();
        for (WorkItem__c item : items) {
            Decimal cycleDays = calcDaysBetween(item.CreatedDate, item.LastModifiedDate);
            String weekLabel = buildWeekLabel(item.LastModifiedDate);

            if (!weekMap.containsKey(weekLabel)) {
                weekMap.put(weekLabel, new WeekBucket(weekLabel));
            }
            weekMap.get(weekLabel).addItem(cycleDays);
        }
        return weekMap;
    }

    /**
     * @description Groups active work items by stage and accumulates stage age durations.
     * @param items List of active WorkItem__c records
     * @return Map of stage name to StageBucket aggregation
     */
    private static Map<String, StageBucket> groupByStage(List<WorkItem__c> items) {
        Map<String, StageBucket> stageMap = new Map<String, StageBucket>();
        Datetime now = Datetime.now();

        for (WorkItem__c item : items) {
            Datetime enteredDate = (item.StageEnteredDatetime__c != null)
                ? item.StageEnteredDatetime__c
                : item.LastModifiedDate;
            Decimal daysInStage = calcDaysBetween(enteredDate, now);
            String stage = item.StageNamePk__c;

            if (!stageMap.containsKey(stage)) {
                stageMap.put(stage, new StageBucket(stage));
            }
            stageMap.get(stage).addItem(daysInStage);
        }
        return stageMap;
    }

    // -------------------------------------------------------------------------
    // Private helpers — result building
    // -------------------------------------------------------------------------

    /**
     * @description Converts weekly bucket map to sorted list of result maps.
     * @param weekMap Map of week label to WeekBucket
     * @return List of maps sorted by week label ascending
     */
    private static List<Map<String, Object>> buildWeeklyResults(Map<String, WeekBucket> weekMap) {
        List<String> sortedKeys = new List<String>(weekMap.keySet());
        sortedKeys.sort();

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (String key : sortedKeys) {
            WeekBucket bucket = weekMap.get(key);
            results.add(bucket.toMap());
        }
        return results;
    }

    /**
     * @description Converts stage bucket map to a list sorted by avgDays descending.
     * @param stageMap Map of stage name to StageBucket
     * @return List of maps sorted by average days descending (slowest first)
     */
    private static List<Map<String, Object>> buildStageResults(Map<String, StageBucket> stageMap) {
        List<StageBucket> buckets = stageMap.values();
        buckets.sort();

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (StageBucket bucket : buckets) {
            results.add(bucket.toMap());
        }
        return results;
    }

    // -------------------------------------------------------------------------
    // Private helpers — date math
    // -------------------------------------------------------------------------

    /**
     * @description Calculates the number of days between two datetimes, rounded to 1 decimal.
     * @param startDt Start datetime
     * @param endDt End datetime
     * @return Decimal number of days (rounded to 1 decimal place)
     */
    private static Decimal calcDaysBetween(Datetime startDt, Datetime endDt) {
        Long diffMs = endDt.getTime() - startDt.getTime();
        Decimal rawDays = Decimal.valueOf(diffMs) / Decimal.valueOf(MS_PER_DAY);
        return rawDays.setScale(1, RoundingMode.HALF_UP);
    }

    /**
     * @description Builds a week label string (e.g. "2026-W09") from a datetime.
     * @param dt The datetime to derive the week label from
     * @return ISO-style week label string
     */
    private static String buildWeekLabel(Datetime dt) {
        Date d = dt.dateGmt();
        Date startOfYear = Date.newInstance(d.year(), 1, 1);
        Integer dayOfYear = startOfYear.daysBetween(d) + 1;
        Integer weekNum = ((dayOfYear - 1) / 7) + 1;
        return d.year() + '-W' + String.valueOf(weekNum).leftPad(2, '0');
    }

    // -------------------------------------------------------------------------
    // Inner classes — bucket aggregators
    // -------------------------------------------------------------------------

    /**
     * @description Aggregation bucket for weekly cycle time data.
     */
    private class WeekBucket {
        /** @description Label for the week (e.g. "2026-W09") */
        private String weekLabel;
        /** @description Total accumulated cycle days */
        private Decimal totalDays;
        /** @description Number of items in the bucket */
        private Integer itemCount;

        /**
         * @description Constructs a new WeekBucket with the given label.
         * @param weekLabel The ISO week label
         */
        public WeekBucket(String weekLabel) {
            this.weekLabel = weekLabel;
            this.totalDays = 0;
            this.itemCount = 0;
        }

        /**
         * @description Adds a work item's cycle time to the bucket.
         * @param cycleDays Days for this item's cycle
         */
        public void addItem(Decimal cycleDays) {
            this.totalDays += cycleDays;
            this.itemCount++;
        }

        /**
         * @description Converts bucket to a result map.
         * @return Map with weekLabel, avgCycleDays, and itemCount
         */
        public Map<String, Object> toMap() {
            Decimal avg = (this.itemCount > 0)
                ? (this.totalDays / this.itemCount).setScale(1, RoundingMode.HALF_UP)
                : 0;
            return new Map<String, Object>{
                'weekLabel'    => this.weekLabel,
                'avgCycleDays' => avg,
                'itemCount'    => this.itemCount
            };
        }
    }

    /**
     * @description Aggregation bucket for stage age data. Implements Comparable
     * so buckets can be sorted by average days descending (slowest first).
     */
    private class StageBucket implements Comparable {
        /** @description Stage API name */
        private String stageName;
        /** @description Total accumulated days */
        private Decimal totalDays;
        /** @description Number of items in the bucket */
        private Integer itemCount;

        /**
         * @description Constructs a new StageBucket with the given stage name.
         * @param stageName The stage API value
         */
        public StageBucket(String stageName) {
            this.stageName = stageName;
            this.totalDays = 0;
            this.itemCount = 0;
        }

        /**
         * @description Adds a work item's stage duration to the bucket.
         * @param days Days in stage for this item
         */
        public void addItem(Decimal days) {
            this.totalDays += days;
            this.itemCount++;
        }

        /**
         * @description Returns the average days in stage.
         * @return Decimal average rounded to 1 decimal
         */
        private Decimal getAvgDays() {
            if (this.itemCount == 0) {
                return 0;
            }
            return (this.totalDays / this.itemCount).setScale(1, RoundingMode.HALF_UP);
        }

        /**
         * @description Converts bucket to a result map.
         * @return Map with stageName, avgDays, and itemCount
         */
        public Map<String, Object> toMap() {
            return new Map<String, Object>{
                'stageName' => this.stageName,
                'avgDays'   => getAvgDays(),
                'itemCount' => this.itemCount
            };
        }

        /**
         * @description Compares two StageBuckets by avgDays descending (slowest first).
         * @param compareTo The other object to compare against
         * @return Integer: negative if this has MORE days, positive if fewer, 0 if equal
         */
        public Integer compareTo(Object compareTo) {
            StageBucket other = (StageBucket) compareTo;
            Decimal diff = other.getAvgDays() - this.getAvgDays();
            if (diff > 0) {
                return 1;
            } else if (diff < 0) {
                return -1;
            }
            return 0;
        }
    }
}
