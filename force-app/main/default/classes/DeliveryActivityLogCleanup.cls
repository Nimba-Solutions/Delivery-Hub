/**
 * @description Scheduled job that maintains the Activity_Log__c table.
 *
 * Two responsibilities run in sequence:
 * 1. **Aggregate** — Summarizes the last 30 days of activity per Network Entity into a
 *    JSON blob on Network_Entity__c.UsageAnalyticsJsonTxt__c and queues an outbound
 *    Sync_Item__c so the vendor org receives the analytics.
 * 2. **Purge** — Batch-deletes activity log records older than the retention window
 *    (default 90 days) to prevent storage bloat.
 *
 * Schedule example (daily at 2 AM):
 *   System.schedule('Delivery Activity Log Cleanup', '0 0 2 * * ?', new DeliveryActivityLogCleanup());
 *
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliveryActivityLogCleanup implements Schedulable, Database.Batchable<SObject> {

    @TestVisible
    private static final Integer RETENTION_DAYS = 90;
    private static final Integer AGGREGATION_DAYS = 30;

    // -----------------------------------------------------------------------
    // Schedulable entry point
    // -----------------------------------------------------------------------

    /**
     * @description Runs usage aggregation then kicks off the batch purge of old activity logs.
     * @param sc The SchedulableContext provided by the platform.
     */
    public void execute(SchedulableContext sc) {
        aggregateUsageAnalytics();
        Database.executeBatch(new DeliveryActivityLogCleanup(), 2000);
    }

    // -----------------------------------------------------------------------
    // Batchable — deletes records older than retention window
    // -----------------------------------------------------------------------

    /**
     * @description Returns a query locator for Activity_Log__c records older than the retention window.
     * @param bc The BatchableContext provided by the platform.
     * @return QueryLocator targeting expired activity log records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoff = DateTime.now().addDays(-RETENTION_DAYS);
        return Database.getQueryLocator([
            SELECT Id
            FROM Activity_Log__c
            WHERE CreatedDate < :cutoff
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Deletes a batch of expired activity log records.
     * @param bc The BatchableContext provided by the platform.
     * @param scope The list of records to delete in this batch.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        delete scope;
    }

    /**
     * @description Post-batch callback. No processing needed for this job.
     * @param bc The BatchableContext provided by the platform.
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public void finish(Database.BatchableContext bc) {
        // No post-processing needed
    }

    // -----------------------------------------------------------------------
    // Aggregation — builds JSON summary per Network Entity and queues sync
    // -----------------------------------------------------------------------

    @TestVisible
    private static void aggregateUsageAnalytics() {
        DateTime since = DateTime.now().addDays(-AGGREGATION_DAYS);
        Map<Id, Map<String, Integer>> entityActionCounts = new Map<Id, Map<String, Integer>>();
        Map<Id, Map<String, Integer>> entityComponentCounts = new Map<Id, Map<String, Integer>>();
        Map<Id, Set<String>> entityUniqueUsers = new Map<Id, Set<String>>();
        Map<Id, Integer> entityTotals = new Map<Id, Integer>();

        collectLogMetrics(since, entityActionCounts, entityComponentCounts, entityUniqueUsers, entityTotals);

        if (entityTotals.isEmpty()) {
            return;
        }

        buildSummariesAndSync(entityActionCounts, entityComponentCounts, entityUniqueUsers, entityTotals);
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    private static void collectLogMetrics(
        DateTime since,
        Map<Id, Map<String, Integer>> entityActionCounts,
        Map<Id, Map<String, Integer>> entityComponentCounts,
        Map<Id, Set<String>> entityUniqueUsers,
        Map<Id, Integer> entityTotals
    ) {
        for (Activity_Log__c log : [
            SELECT NetworkEntityId__c, ActionTypePk__c, ComponentNameTxt__c, UserIdTxt__c
            FROM Activity_Log__c
            WHERE CreatedDate >= :since
            AND NetworkEntityId__c != null
            WITH SYSTEM_MODE
            ORDER BY NetworkEntityId__c
            LIMIT 50000
        ]) {
            Id entId = log.NetworkEntityId__c;

            entityTotals.put(entId, (entityTotals.containsKey(entId) ? entityTotals.get(entId) : 0) + 1);

            incrementBucket(entityActionCounts, entId,
                String.isNotBlank(log.ActionTypePk__c) ? log.ActionTypePk__c : 'Unknown');

            incrementBucket(entityComponentCounts, entId,
                String.isNotBlank(log.ComponentNameTxt__c) ? log.ComponentNameTxt__c : 'Unknown');

            if (!entityUniqueUsers.containsKey(entId)) {
                entityUniqueUsers.put(entId, new Set<String>());
            }
            if (String.isNotBlank(log.UserIdTxt__c)) {
                entityUniqueUsers.get(entId).add(log.UserIdTxt__c);
            }
        }
    }

    private static void incrementBucket(Map<Id, Map<String, Integer>> buckets, Id entId, String key) {
        if (!buckets.containsKey(entId)) {
            buckets.put(entId, new Map<String, Integer>());
        }
        Map<String, Integer> bucket = buckets.get(entId);
        bucket.put(key, (bucket.containsKey(key) ? bucket.get(key) : 0) + 1);
    }

    private static void buildSummariesAndSync(
        Map<Id, Map<String, Integer>> entityActionCounts,
        Map<Id, Map<String, Integer>> entityComponentCounts,
        Map<Id, Set<String>> entityUniqueUsers,
        Map<Id, Integer> entityTotals
    ) {
        List<Network_Entity__c> toUpdate = new List<Network_Entity__c>();
        List<Sync_Item__c> syncItems = new List<Sync_Item__c>();

        for (Id entId : entityTotals.keySet()) {
            Map<String, Object> summary = new Map<String, Object>();
            summary.put('lastUpdated', DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            summary.put('periodDays', AGGREGATION_DAYS);
            summary.put('totalActions', entityTotals.get(entId));
            summary.put('uniqueUsers', entityUniqueUsers.containsKey(entId)
                ? entityUniqueUsers.get(entId).size() : 0);
            summary.put('topActions', sortedEntries(entityActionCounts.get(entId)));
            summary.put('topComponents', sortedEntries(entityComponentCounts.get(entId)));

            String jsonBlob = JSON.serialize(summary);

            toUpdate.add(new Network_Entity__c(
                Id = entId,
                UsageAnalyticsJsonTxt__c = jsonBlob
            ));

            syncItems.add(new Sync_Item__c(
                ObjectTypePk__c = 'UsageAnalytics',
                DirectionPk__c = 'Outbound',
                StatusPk__c = 'Queued',
                LocalRecordIdTxt__c = entId,
                PayloadTxt__c = jsonBlob
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        if (!syncItems.isEmpty()) {
            insert syncItems;
        }
    }

    private static List<Map<String, Object>> sortedEntries(Map<String, Integer> counts) {
        if (counts == null || counts.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        List<Map<String, Object>> entries = new List<Map<String, Object>>();
        for (String key : counts.keySet()) {
            entries.add(new Map<String, Object>{
                'name' => key,
                'count' => counts.get(key)
            });
        }

        // Insertion sort descending by count (small N)
        for (Integer i = 1; i < entries.size(); i++) {
            Map<String, Object> current = entries[i];
            Integer currentCount = (Integer) current.get('count');
            Integer j = i - 1;
            while (j >= 0 && (Integer) entries[j].get('count') < currentCount) {
                entries[j + 1] = entries[j];
                j--;
            }
            entries[j + 1] = current;
        }

        // Return top 10
        Integer limit10 = Math.min(entries.size(), 10);
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Integer i = 0; i < limit10; i++) {
            result.add(entries[i]);
        }
        return result;
    }
}
