/**
 * @description Scheduled job that maintains the Delivery_Activity_Log__c table.
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

    public void execute(SchedulableContext sc) {
        aggregateUsageAnalytics();
        Database.executeBatch(new DeliveryActivityLogCleanup(), 2000);
    }

    // -----------------------------------------------------------------------
    // Batchable — deletes records older than retention window
    // -----------------------------------------------------------------------

    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime cutoff = DateTime.now().addDays(-RETENTION_DAYS);
        return Database.getQueryLocator([
            SELECT Id
            FROM Delivery_Activity_Log__c
            WHERE CreatedDate < :cutoff
            WITH SYSTEM_MODE
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        delete scope;
    }

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

        // --- 1. Counts by entity + action type ---
        Map<Id, Map<String, Integer>> entityActionCounts = new Map<Id, Map<String, Integer>>();
        Map<Id, Map<String, Integer>> entityComponentCounts = new Map<Id, Map<String, Integer>>();
        Map<Id, Set<String>> entityUniqueUsers = new Map<Id, Set<String>>();
        Map<Id, Integer> entityTotals = new Map<Id, Integer>();

        for (Delivery_Activity_Log__c log : [
            SELECT NetworkEntityId__c, ActionTypePk__c, ComponentNameTxt__c, UserIdTxt__c
            FROM Delivery_Activity_Log__c
            WHERE CreatedDate >= :since
            AND NetworkEntityId__c != null
            WITH SYSTEM_MODE
            ORDER BY NetworkEntityId__c
            LIMIT 50000
        ]) {
            Id entId = log.NetworkEntityId__c;

            // Total count
            entityTotals.put(entId, (entityTotals.containsKey(entId) ? entityTotals.get(entId) : 0) + 1);

            // Action type counts
            if (!entityActionCounts.containsKey(entId)) {
                entityActionCounts.put(entId, new Map<String, Integer>());
            }
            String action = String.isNotBlank(log.ActionTypePk__c) ? log.ActionTypePk__c : 'Unknown';
            Map<String, Integer> actions = entityActionCounts.get(entId);
            actions.put(action, (actions.containsKey(action) ? actions.get(action) : 0) + 1);

            // Component counts
            if (!entityComponentCounts.containsKey(entId)) {
                entityComponentCounts.put(entId, new Map<String, Integer>());
            }
            String comp = String.isNotBlank(log.ComponentNameTxt__c) ? log.ComponentNameTxt__c : 'Unknown';
            Map<String, Integer> comps = entityComponentCounts.get(entId);
            comps.put(comp, (comps.containsKey(comp) ? comps.get(comp) : 0) + 1);

            // Unique users
            if (!entityUniqueUsers.containsKey(entId)) {
                entityUniqueUsers.put(entId, new Set<String>());
            }
            if (String.isNotBlank(log.UserIdTxt__c)) {
                entityUniqueUsers.get(entId).add(log.UserIdTxt__c);
            }
        }

        if (entityTotals.isEmpty()) {
            return;
        }

        // --- 2. Build JSON and update Network Entities ---
        List<Network_Entity__c> toUpdate = new List<Network_Entity__c>();
        List<Sync_Item__c> syncItems = new List<Sync_Item__c>();

        for (Id entId : entityTotals.keySet()) {
            Map<String, Object> summary = new Map<String, Object>();
            summary.put('lastUpdated', DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            summary.put('periodDays', AGGREGATION_DAYS);
            summary.put('totalActions', entityTotals.get(entId));
            summary.put('uniqueUsers', entityUniqueUsers.containsKey(entId)
                ? entityUniqueUsers.get(entId).size() : 0);

            // Top action types (sorted descending by count)
            List<Map<String, Object>> topActions = sortedEntries(entityActionCounts.get(entId));
            summary.put('topActions', topActions);

            // Top components (sorted descending by count)
            List<Map<String, Object>> topComponents = sortedEntries(entityComponentCounts.get(entId));
            summary.put('topComponents', topComponents);

            String jsonBlob = JSON.serialize(summary);

            toUpdate.add(new Network_Entity__c(
                Id = entId,
                UsageAnalyticsJsonTxt__c = jsonBlob
            ));

            // Queue outbound sync so vendor receives analytics
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

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    private static List<Map<String, Object>> sortedEntries(Map<String, Integer> counts) {
        if (counts == null || counts.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        // Build sortable list (Apex has no built-in sorted-map-by-value)
        List<Map<String, Object>> entries = new List<Map<String, Object>>();
        for (String key : counts.keySet()) {
            entries.add(new Map<String, Object>{
                'name' => key,
                'count' => counts.get(key)
            });
        }

        // Simple insertion sort descending by count (small N)
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
