/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Scheduled job that maintains the ActivityLog__c table.
 *
 * Two responsibilities run in sequence, both fully batched:
 * 1. **Aggregate** — DeliveryUsageAnalyticsBatch summarizes the last 30 days of
 *    activity per Network Entity into a JSON blob on
 *    NetworkEntity__c.UsageAnalyticsJsonTxt__c and queues an outbound
 *    SyncItem__c so the vendor org receives the analytics.
 * 2. **Purge** — this class (as the batch chained from the aggregation batch's
 *    finish()) deletes activity log records older than the retention window
 *    (default 90 days) to prevent storage bloat.
 *
 * HISTORY / WHY BATCHED: aggregation used to run synchronously inside the
 * Schedulable execute() with a LIMIT 50000 row-loop. Subscribers generating
 * >50K log rows per 30 days (MF-Prod: ~67K) blew the query-row governor
 * ("Too many query rows: 50001") BEFORE Database.executeBatch was reached, so
 * the purge never enqueued and retention was unbounded. Both stages are now
 * QueryLocator-driven batches, safe at any row volume.
 *
 * Schedule example (daily at 2 AM):
 *   System.schedule('Delivery Activity Log Cleanup', '0 0 2 * * ?', new DeliveryActivityLogCleanup());
 *
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class DeliveryActivityLogCleanup implements Schedulable, Database.Batchable<SObject> {

    @TestVisible
    private static Integer retentionDays = 90;
    private static final Integer ANALYTICS_BATCH_SIZE = 2000;

    // -----------------------------------------------------------------------
    // Schedulable entry point
    // -----------------------------------------------------------------------

    /**
     * @description Launches the batched usage aggregation, which chains the batch
     *              purge of old activity logs from its finish() — preserving the
     *              historical "aggregate first, then purge" ordering without any
     *              unbounded synchronous query.
     * @param sc The SchedulableContext provided by the platform.
     */
    global void execute(SchedulableContext sc) {
        runMaintenance();
    }

    /**
     * @description Single entry point for the daily maintenance pass. Enqueues
     *              DeliveryUsageAnalyticsBatch (stateful, chunked aggregation);
     *              its finish() chains this class as the purge batch. Called by
     *              DeliveryHubScheduler.enqueueActivityLogCleanupIfDue() and the
     *              standalone-cron Schedulable path above.
     */
    public static void runMaintenance() {
        Database.executeBatch(new DeliveryUsageAnalyticsBatch(true), ANALYTICS_BATCH_SIZE);
    }

    /**
     * @description Launches the usage-analytics aggregation WITHOUT chaining the
     *              purge batch. Retained for callers that only want the telemetry
     *              roll-up. The old synchronous implementation lives in
     *              DeliveryUsageAnalyticsBatch now — see that class for why this
     *              must be a batch (MF-Prod 50001 crash).
     */
    public static void aggregateUsageAnalytics() {
        Database.executeBatch(new DeliveryUsageAnalyticsBatch(false), ANALYTICS_BATCH_SIZE);
    }

    // -----------------------------------------------------------------------
    // Batchable — deletes records older than retention window
    // -----------------------------------------------------------------------

    /**
     * @description Returns a query locator for ActivityLog__c records older than the retention window.
     *              Field_Change records are excluded from purge unless FieldChangeRetentionDaysNumber__c
     *              is set to a positive value, in which case they are purged after that many days.
     * @param bc The BatchableContext provided by the platform.
     * @return QueryLocator targeting expired activity log records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DeliveryHubSettings__c retentionSettings = DeliveryHubSettings__c.getOrgDefaults();
        Integer logRetentionDays = retentionSettings != null && retentionSettings.ActivityLogRetentionDaysNumber__c != null
            ? (Integer) retentionSettings.ActivityLogRetentionDaysNumber__c : 90;
        DateTime cutoff = DateTime.now().addDays(-logRetentionDays);

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        Decimal retentionDays = (settings != null) ? settings.FieldChangeRetentionDaysNumber__c : null;

        if (retentionDays != null && retentionDays > 0) {
            DateTime fieldChangeCutoff = DateTime.now().addDays(-retentionDays.intValue());
            return Database.getQueryLocator([
                SELECT Id
                FROM ActivityLog__c
                WHERE ((CreatedDate < :cutoff AND ActionTypePk__c != 'Field_Change')
                   OR (CreatedDate < :fieldChangeCutoff AND ActionTypePk__c = 'Field_Change'))
                AND LegalHoldDateTime__c = null
                WITH SYSTEM_MODE
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id
            FROM ActivityLog__c
            WHERE CreatedDate < :cutoff
            AND ActionTypePk__c != 'Field_Change'
            AND LegalHoldDateTime__c = null
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Deletes a batch of expired activity log records. Partial-success
     *              delete so a single blocked row (e.g. one that gained a legal
     *              hold between start() and this chunk — the delete trigger's
     *              blockLegalHoldDeletion addError) cannot fail the whole chunk
     *              and stall the purge.
     * @param bc The BatchableContext provided by the platform.
     * @param scope The list of records to delete in this batch.
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Database.delete(scope, false);
    }

    /**
     * @description Post-batch callback. No processing needed for this job.
     * @param bc The BatchableContext provided by the platform.
     */
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public void finish(Database.BatchableContext bc) {
        // No post-processing needed
    }
}
