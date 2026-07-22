/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Scheduled batch that auto-purges successfully synced SyncItem__c
 *              ledger rows older than the retention window, keeping the sync
 *              ledger from filling org data storage.
 *
 *              ONLY StatusPk__c = 'Synced' rows are ever deleted. Staged, Queued,
 *              Pending, and Failed rows are live work / triage evidence and are
 *              never touched by this job (the Failed lane has its own opt-in
 *              aging via FailedSyncAutoDismissDaysNumber__c, which dismisses —
 *              never deletes).
 *
 *              Retention window: SyncItemRetentionDaysNumber__c on
 *              DeliveryHubSettings__c org defaults, defaulting to 30 days when
 *              blank. Ages on LastModifiedDate (not CreatedDate) so a row that
 *              only recently reached Synced keeps its recent sync history for
 *              the full window.
 *
 *              Activation follows the package DateTime-toggle convention:
 *              DeliveryHubScheduler.enqueueSyncItemCleanupIfDue() runs this batch
 *              daily at 3 AM UTC only when EnableSyncItemCleanupDateTime__c is
 *              non-null (null = disabled, the default). Empirical motivator:
 *              dh-prod (5 MB Dev Edition) filled its data storage with old Synced
 *              ledger rows and broke sync entirely on 2026-07-02; with this job
 *              enabled the ledger is self-healing on every org.
 *
 *              QueryLocator batch pattern (50M-row ceiling) so any subscriber
 *              volume is safe — same hardening as DeliveryActivityLogCleanup.
 *
 * Schedule example for standalone use (daily at 3 AM):
 *   System.schedule('Delivery Sync Item Cleanup', '0 0 3 * * ?', new DeliverySyncItemCleanup());
 *
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class DeliverySyncItemCleanup implements Schedulable, Database.Batchable<SObject> {

    /** @description Retention window applied when SyncItemRetentionDaysNumber__c is blank. */
    @TestVisible
    private static final Integer DEFAULT_RETENTION_DAYS = 30;
    private static final Integer PURGE_BATCH_SIZE = 2000;

    // -----------------------------------------------------------------------
    // Schedulable entry point (standalone-cron path)
    // -----------------------------------------------------------------------

    /**
     * @description Kicks off the batch purge of aged Synced ledger rows.
     * @param sc The SchedulableContext provided by the platform.
     */
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new DeliverySyncItemCleanup(), PURGE_BATCH_SIZE);
    }

    // -----------------------------------------------------------------------
    // Batchable — deletes Synced rows older than the retention window
    // -----------------------------------------------------------------------

    /**
     * @description Returns a query locator for Synced SyncItem__c rows whose
     *              LastModifiedDate is older than the retention window. Statuses
     *              other than 'Synced' are excluded at the query level.
     * @param bc The BatchableContext provided by the platform.
     * @return QueryLocator targeting expired Synced ledger rows.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Integer retentionDays = settings != null && settings.SyncItemRetentionDaysNumber__c != null
            ? (Integer) settings.SyncItemRetentionDaysNumber__c : DEFAULT_RETENTION_DAYS;
        DateTime cutoff = DateTime.now().addDays(-retentionDays);

        return Database.getQueryLocator([
            SELECT Id
            FROM SyncItem__c
            WHERE StatusPk__c = 'Synced'
            AND LastModifiedDate < :cutoff
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Deletes one chunk of expired Synced rows. Re-verifies status
     *              by Id at delete time — a row whose status changed between
     *              start() and this chunk is skipped, so non-Synced rows can
     *              never be deleted even in a race. Partial-success delete so a
     *              single blocked row cannot stall the purge.
     * @param bc The BatchableContext provided by the platform.
     * @param scope The chunk of candidate rows from start().
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<SyncItem__c> stillSynced = [
            SELECT Id
            FROM SyncItem__c
            WHERE Id IN :scope
            AND StatusPk__c = 'Synced'
            WITH SYSTEM_MODE
        ];
        if (!stillSynced.isEmpty()) {
            Database.delete(stillSynced, false);
        }
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
