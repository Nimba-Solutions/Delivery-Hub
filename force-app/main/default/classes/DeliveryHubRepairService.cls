/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Generic repair dispatcher invoked from the Health Dashboard
 *               LWC. Each repair key maps to one corrective action — a
 *               reusable, org-agnostic version of the scripts that lived in
 *               scripts/scratch-verify/.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubRepairService {

    /**
     * @description Run a repair by its key. Returns a short message used by
     *              the dashboard LWC to refresh the relevant card.
     * @param repairKey One of: scheduleAll, requeueFailedSyncs,
     *                  backfillPermSets, reconcileNow.
     * @return Human-readable result message.
     */
    @AuraEnabled
    public static String runRepair(String repairKey) {
        if (String.isBlank(repairKey)) {
            throw new AuraHandledException('repairKey is required');
        }
        if (repairKey == 'scheduleAll') {
            return repairScheduleAll();
        }
        if (repairKey == 'requeueFailedSyncs') {
            return repairRequeueFailedSyncs();
        }
        if (repairKey == 'backfillPermSets') {
            return repairBackfillPermSets();
        }
        if (repairKey == 'reconcileNow') {
            return repairReconcileNow();
        }
        throw new AuraHandledException('Unknown repairKey: ' + repairKey);
    }

    private static String repairScheduleAll() {
        DeliveryHubScheduler.scheduleAll();
        return 'Scheduled four sync slots.';
    }

    /**
     * @description Reset Failed SyncItems back to Queued so the next
     *              scheduler tick picks them up. Caps at 1000 per invocation
     *              to stay under DML limits — re-run for larger backlogs.
     * @return Count of rows reset.
     */
    private static String repairRequeueFailedSyncs() {
        List<SyncItem__c> failed = [
            SELECT Id FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            WITH SYSTEM_MODE
            LIMIT 1000
        ];
        for (SyncItem__c row : failed) {
            row.StatusPk__c = 'Queued';
            row.RetryCountNumber__c = 0;
            row.ErrorLogTxt__c = null;
        }
        if (!failed.isEmpty()) {
            update failed;
        }
        return 'Requeued ' + failed.size() + ' Failed SyncItems.';
    }

    private static String repairBackfillPermSets() {
        DeliveryUserTriggerHandler.assignAllActiveUsers();
        return 'Permission set backfill enqueued — assignments propagate via @future.';
    }

    private static String repairReconcileNow() {
        DeliveryHubScheduler.reconcileNow();
        return 'Reconciliation enqueued.';
    }
}
