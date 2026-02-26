/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliverySyncRetryPanel LWC admin component.
 *              Surfaces failed sync items and allows bulk retry.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliverySyncRetryController {

    /** @description Summary of a failed sync item for display. */
    public class FailedSyncRow {
        @AuraEnabled public String id;
        @AuraEnabled public String objectType;
        @AuraEnabled public String errorLog;
        @AuraEnabled public String lastModified;
    }

    /**
     * @description Returns the count of failed syncs and the 10 most recent error rows.
     * @return Map with 'failedCount' (Integer) and 'recentErrors' (List<FailedSyncRow>).
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSyncHealth() {
        Map<String, Object> result = new Map<String, Object>();

        result.put('failedCount', [
            SELECT COUNT() FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            WITH SYSTEM_MODE
        ]);

        List<FailedSyncRow> rows = new List<FailedSyncRow>();
        for (SyncItem__c si : [
            SELECT Id, ObjectTypePk__c, ErrorLogTxt__c, LastModifiedDate
            FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ]) {
            FailedSyncRow row  = new FailedSyncRow();
            row.id             = si.Id;
            row.objectType     = si.ObjectTypePk__c;
            row.errorLog       = si.ErrorLogTxt__c;
            row.lastModified   = si.LastModifiedDate.format('MM/dd h:mm a', UserInfo.getTimeZone().getId());
            rows.add(row);
        }
        result.put('recentErrors', rows);
        return result;
    }

    /**
     * @description Resets all failed SyncItem__c records to Queued so the scheduler retries them.
     */
    @AuraEnabled
    public static void retryFailed() {
        List<SyncItem__c> failed = [
            SELECT Id
            FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            WITH SYSTEM_MODE
        ];
        List<SyncItem__c> toRetry = new List<SyncItem__c>();
        for (SyncItem__c si : failed) {
            toRetry.add(new SyncItem__c(Id = si.Id, StatusPk__c = 'Queued', ErrorLogTxt__c = null));
        }
        if (!toRetry.isEmpty()) {
            // FIX: SYSTEM_MODE to prevent packaging test failures on namespaced fields
            Database.update(toRetry, AccessLevel.SYSTEM_MODE);
        }
    }
}
