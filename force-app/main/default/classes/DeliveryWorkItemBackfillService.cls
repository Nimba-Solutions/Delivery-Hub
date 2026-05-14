/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Idempotent backfills for WorkItem__c records that need
 *              correction after metadata-default changes. Today: flips
 *              Status=New to Active for records older than 24h, closing the
 *              invisible-WI gap on tenants who were upgraded across the
 *              field-default change in PR #752 (Status default New → Active).
 *
 *              Called from DeliveryHubInstallHandler on package install /
 *              upgrade. Safe to invoke manually too.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryWorkItemBackfillService {

    @TestVisible
    private static final Integer BACKFILL_LIMIT = 5000;

    @TestVisible
    private static final Integer STALE_FLOOR_HOURS = 24;

    /**
     * @description Flips Status=New to Active for WorkItems created more than
     *              STALE_FLOOR_HOURS ago. Records that recent are presumed
     *              in-flight (just submitted, awaiting first triage) and are
     *              left alone.
     *
     *              Why this exists: PR #752 changed the field-level default
     *              for StatusPk__c from 'New' to 'Active' so the gantt's
     *              Active filter shows newly-created WorkItems. That fix
     *              only applies to records created AFTER the upgrade — any
     *              record already at Status=New (e.g., portal submissions,
     *              data-loader imports, Apex inserts without explicit Status)
     *              stays invisible. This service backfills them on install.
     *
     *              Idempotent — re-running is a no-op once the backlog is
     *              cleared. Uses allOrNone=false so a single record-level
     *              validation failure does not abort the install.
     * @return Number of records successfully updated.
     */
    public static Integer backfillStatusDefaults() {
        Datetime floor = Datetime.now().addHours(-STALE_FLOOR_HOURS);
        List<WorkItem__c> stale = [
            SELECT Id
            FROM WorkItem__c
            WHERE StatusPk__c = 'New'
              AND CreatedDate < :floor
            WITH SYSTEM_MODE
            LIMIT :BACKFILL_LIMIT
        ];
        if (stale.isEmpty()) {
            return 0;
        }
        for (WorkItem__c w : stale) {
            w.StatusPk__c = 'Active';
        }
        Database.SaveResult[] results = Database.update(stale, false);
        Integer succeeded = 0;
        Integer failed = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult r = results[i];
            if (r.isSuccess()) {
                succeeded++;
            } else {
                failed++;
                // Surface the failure so install-handler logs show partial-DML breakage.
                // Mirrors DeliveryWorkItemETAService.cls:316-320 pattern.
                String reasons = '';
                for (Database.Error err : r.getErrors()) {
                    reasons += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                }
                System.debug(LoggingLevel.WARN,
                    '[DeliveryWorkItemBackfillService] Status backfill failed for '
                    + stale[i].Id + ' — ' + reasons);
            }
        }
        if (failed > 0) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkItemBackfillService] backfillStatusDefaults: '
                + succeeded + ' succeeded, ' + failed + ' failed');
        }
        return succeeded;
    }
}
