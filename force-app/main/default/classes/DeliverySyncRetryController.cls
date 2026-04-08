/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliverySyncRetryPanel LWC admin component.
 *              Surfaces failed sync items, supports bulk retry, and exposes
 *              dismiss/restore for admin triage. Dismissed items are hidden
 *              from the default view but visible when includeDismissed=true.
 * @author Cloud Nimbus LLC
 */
global with sharing class DeliverySyncRetryController {

    /** @description Summary of a failed sync item for display. */
    global class FailedSyncRow {
        @AuraEnabled public String id;
        @AuraEnabled public String objectType;
        @AuraEnabled public String errorLog;
        @AuraEnabled public String lastModified;
        @AuraEnabled public Boolean dismissed;
    }

    /**
     * @description Returns the count of failed syncs and the 10 most recent error rows.
     *              Excludes dismissed items by default. Pass includeDismissed=true
     *              to surface dismissed rows for admin review/restore.
     * @param includeDismissed When true, dismissed Failed items are included.
     * @return Map with 'failedCount' (Integer) and 'recentErrors' (List<FailedSyncRow>).
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getSyncHealth(Boolean includeDismissed) {
        Boolean showDismissed = includeDismissed == true;
        Map<String, Object> result = new Map<String, Object>();

        Integer failedCount;
        if (showDismissed) {
            failedCount = [
                SELECT COUNT() FROM SyncItem__c
                WHERE StatusPk__c = 'Failed'
                WITH SYSTEM_MODE
            ];
        } else {
            failedCount = [
                SELECT COUNT() FROM SyncItem__c
                WHERE StatusPk__c = 'Failed'
                AND DismissedDateTime__c = NULL
                WITH SYSTEM_MODE
            ];
        }
        result.put('failedCount', failedCount);

        List<FailedSyncRow> rows = new List<FailedSyncRow>();
        List<SyncItem__c> recent;
        if (showDismissed) {
            recent = [
                SELECT Id, ObjectTypePk__c, ErrorLogTxt__c, LastModifiedDate, DismissedDateTime__c
                FROM SyncItem__c
                WHERE StatusPk__c = 'Failed'
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 10
            ];
        } else {
            recent = [
                SELECT Id, ObjectTypePk__c, ErrorLogTxt__c, LastModifiedDate, DismissedDateTime__c
                FROM SyncItem__c
                WHERE StatusPk__c = 'Failed'
                AND DismissedDateTime__c = NULL
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 10
            ];
        }
        for (SyncItem__c si : recent) {
            FailedSyncRow row = new FailedSyncRow();
            row.id           = si.Id;
            row.objectType   = si.ObjectTypePk__c;
            row.errorLog     = si.ErrorLogTxt__c;
            row.lastModified = si.LastModifiedDate.format('MM/dd h:mm a', UserInfo.getTimeZone().getId());
            row.dismissed    = si.DismissedDateTime__c != null;
            rows.add(row);
        }
        result.put('recentErrors', rows);
        return result;
    }

    /**
     * @description Resets all non-dismissed failed SyncItem__c records to Queued
     *              so the scheduler retries them. Dismissed items are intentionally
     *              skipped — admins must restore them first if a retry is desired.
     */
    @AuraEnabled
    global static void retryFailed() {
        List<SyncItem__c> failed = [
            SELECT Id
            FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            AND DismissedDateTime__c = NULL
            WITH SYSTEM_MODE
            LIMIT 200
        ];
        List<SyncItem__c> toRetry = new List<SyncItem__c>();
        for (SyncItem__c si : failed) {
            toRetry.add(new SyncItem__c(Id = si.Id, StatusPk__c = 'Queued', ErrorLogTxt__c = null));
        }
        if (!toRetry.isEmpty()) {
            // SYSTEM_MODE to prevent packaging test failures on namespaced fields
            Database.update(toRetry, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Marks the given Failed SyncItem__c records as dismissed
     *              via DeliverySyncDismissalService. The service enforces admin
     *              permissions and writes an ActivityLog__c row.
     * @param ids List of SyncItem__c Ids to dismiss.
     * @param reason Optional free-text reason persisted in the audit log.
     * @return Count of records actually dismissed.
     */
    @AuraEnabled
    global static Integer dismissFailed(List<Id> ids, String reason) {
        if (ids == null || ids.isEmpty()) {
            return 0;
        }
        return DeliverySyncDismissalService.dismiss(new Set<Id>(ids), reason);
    }

    /**
     * @description Restores previously dismissed SyncItem__c records by clearing
     *              DismissedDateTime__c. Status is unchanged; restored items
     *              re-appear in the default view and dashboard health.
     * @param ids List of SyncItem__c Ids to restore.
     * @return Count of records actually restored.
     */
    @AuraEnabled
    global static Integer restoreDismissed(List<Id> ids) {
        if (ids == null || ids.isEmpty()) {
            return 0;
        }
        return DeliverySyncDismissalService.restore(new Set<Id>(ids));
    }
}
