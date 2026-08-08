/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Stateful batch that summarizes the last 30 days of ActivityLog__c
 *              activity per Network Entity into a JSON blob on
 *              NetworkEntity__c.UsageAnalyticsJsonTxt__c and queues an outbound
 *              SyncItem__c so the vendor org receives the analytics.
 *
 *              This replaces the old synchronous row-loop in
 *              DeliveryActivityLogCleanup.aggregateUsageAnalytics(), which read up
 *              to LIMIT 50000 ActivityLog__c rows in a single transaction. Any
 *              subscriber generating >50K log rows per 30 days blew the query-row
 *              governor ("Too many query rows: 50001") and — because aggregation
 *              ran BEFORE Database.executeBatch on the purge job — the purge never
 *              enqueued either, so retention became unbounded. Empirical motivator:
 *              MF-Prod generated ~67K rows/30d and the 2 AM cron crashed daily from
 *              2026-03-13 onward, letting ActivityLog__c grow to 195K rows.
 *
 *              As a Database.Batchable over a QueryLocator (50M-row ceiling) with
 *              Database.Stateful accumulation, aggregation now survives any
 *              subscriber's volume. finish() writes the summaries and then chains
 *              the DeliveryActivityLogCleanup purge batch, preserving the original
 *              "aggregate first, then purge" ordering. The summary write is
 *              try/caught so a telemetry failure can never block the purge again.
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliveryUsageAnalyticsBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private static final Integer AGGREGATION_DAYS = 30;
    private static final Integer PURGE_BATCH_SIZE = 2000;

    /** @description When true, finish() chains the ActivityLog__c purge batch. */
    private Boolean chainPurgeAfterFinish;

    // ── Database.Stateful accumulators (carried across execute() chunks) ──
    /** @description Action type counts per entity. */
    private Map<Id, Map<String, Integer>> actionCounts = new Map<Id, Map<String, Integer>>();
    /** @description Component counts per entity. */
    private Map<Id, Map<String, Integer>> componentCounts = new Map<Id, Map<String, Integer>>();
    /** @description Unique user IDs per entity. */
    private Map<Id, Set<String>> uniqueUsers = new Map<Id, Set<String>>();
    /** @description Total action count per entity. */
    private Map<Id, Integer> totals = new Map<Id, Integer>();

    /**
     * @description Default constructor — chains the purge batch after aggregation,
     *              which is the behavior the daily maintenance entry points want.
     */
    public DeliveryUsageAnalyticsBatch() {
        this(true);
    }

    /**
     * @description Constructor with explicit chaining control.
     * @param chainPurgeAfterFinish When true, finish() launches the
     *        DeliveryActivityLogCleanup purge batch after writing summaries.
     *        Pass false to run aggregation standalone.
     */
    public DeliveryUsageAnalyticsBatch(Boolean chainPurgeAfterFinish) {
        this.chainPurgeAfterFinish = chainPurgeAfterFinish == true;
    }

    /**
     * @description Returns a locator over the last 30 days of entity-linked
     *              activity logs. A QueryLocator scales to 50M rows, so any
     *              subscriber volume is safe (the old synchronous path died at 50K).
     * @param bc The BatchableContext provided by the platform.
     * @return QueryLocator over ActivityLog__c rows in the aggregation window.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime since = DateTime.now().addDays(-AGGREGATION_DAYS);
        return Database.getQueryLocator([
            SELECT NetworkEntityLookup__c, ActionTypePk__c, ComponentNameTxt__c, UserIdTxt__c
            FROM ActivityLog__c
            WHERE CreatedDate >= :since
            AND NetworkEntityLookup__c != null
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Accumulates per-entity metrics for one chunk of activity logs.
     *              State persists across chunks via Database.Stateful.
     * @param bc The BatchableContext provided by the platform.
     * @param scope The chunk of ActivityLog__c rows to accumulate.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        for (SObject sObj : scope) {
            ActivityLog__c log = (ActivityLog__c) sObj;
            Id entId = log.NetworkEntityLookup__c;

            totals.put(entId, (totals.containsKey(entId) ? totals.get(entId) : 0) + 1);

            incrementBucket(actionCounts, entId,
                String.isNotBlank(log.ActionTypePk__c) ? log.ActionTypePk__c : 'Unknown');

            incrementBucket(componentCounts, entId,
                String.isNotBlank(log.ComponentNameTxt__c) ? log.ComponentNameTxt__c : 'Unknown');

            if (!uniqueUsers.containsKey(entId)) {
                uniqueUsers.put(entId, new Set<String>());
            }
            if (String.isNotBlank(log.UserIdTxt__c)) {
                uniqueUsers.get(entId).add(log.UserIdTxt__c);
            }
        }
    }

    /**
     * @description Writes the accumulated summaries (JSON on NetworkEntity__c plus
     *              an outbound telemetry SyncItem__c per entity), then chains the
     *              ActivityLog__c purge batch. The summary write is try/caught so
     *              an aggregation failure can never block the purge — that
     *              coupling is exactly what caused the MF-Prod unbounded-retention
     *              incident.
     * @param bc The BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        try {
            buildSummariesAndSync();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[DeliveryUsageAnalyticsBatch] summary write failed: ' + e.getMessage());
        }
        // Chaining executeBatch from finish() is not allowed in Apex test context;
        // tests cover the purge batch directly.
        if (chainPurgeAfterFinish && !Test.isRunningTest()) {
            Database.executeBatch(new DeliveryActivityLogCleanup(), PURGE_BATCH_SIZE);
        }
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    private static void incrementBucket(Map<Id, Map<String, Integer>> buckets, Id entId, String key) {
        if (!buckets.containsKey(entId)) {
            buckets.put(entId, new Map<String, Integer>());
        }
        Map<String, Integer> bucket = buckets.get(entId);
        bucket.put(key, (bucket.containsKey(key) ? bucket.get(key) : 0) + 1);
    }

    private void buildSummariesAndSync() {
        if (totals.isEmpty()) {
            return;
        }

        List<NetworkEntity__c> toUpdate = new List<NetworkEntity__c>();
        List<SyncItem__c> syncItems = new List<SyncItem__c>();

        for (Id entId : totals.keySet()) {
            Map<String, Object> summary = new Map<String, Object>();
            summary.put('lastUpdated', DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
            summary.put('periodDays', AGGREGATION_DAYS);
            summary.put('totalActions', totals.get(entId));
            summary.put('uniqueUsers', uniqueUsers.containsKey(entId)
                ? uniqueUsers.get(entId).size() : 0);
            summary.put('topActions', sortedEntries(actionCounts.get(entId)));
            summary.put('topComponents', sortedEntries(componentCounts.get(entId)));

            String jsonBlob = JSON.serialize(summary);

            toUpdate.add(new NetworkEntity__c(
                Id = entId,
                UsageAnalyticsJsonTxt__c = jsonBlob
            ));

            syncItems.add(new SyncItem__c(
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
