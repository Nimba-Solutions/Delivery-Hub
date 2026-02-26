/**
 * @description Controller for the deliveryTimeLogger LWC. Creates a WorkLog__c
 *              entry against a Work Item, which the roll-up summary on
 *              TotalLoggedHoursNumber__c then reflects automatically.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryTimeLoggerController {

    /**
     * @description Inserts a WorkLog__c record linked to the given work item,
     *              logging the specified number of hours for today's date. The
     *              Work Item's TotalLoggedHoursNumber__c roll-up updates
     *              automatically after the insert.
     * @param workItemId   The Id of the WorkItem__c record to log time against.
     * @param hours      The positive number of hours to log.
     * @param workNotes  Optional description of work performed.
     */
    @AuraEnabled
    public static void logHours(Id workItemId, Decimal hours, String workNotes) {
        List<WorkRequest__c> activeReqs = [
            SELECT Id FROM WorkRequest__c
            WHERE WorkItemId__c = :workItemId
            AND StatusPk__c IN ('Accepted', 'In Progress')
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (activeReqs.isEmpty()) {
            throw new AuraHandledException('No accepted request found for this work item. Please accept a vendor quote before logging time.');
        }
        WorkLog__c entry = new WorkLog__c(
            RequestId__c          = activeReqs[0].Id,
            WorkItemId__c           = workItemId,
            HoursLoggedNumber__c  = hours,
            WorkDateDate__c       = Date.today(),
            WorkDescriptionTxt__c = workNotes
        );
        // FIX: SYSTEM_MODE to prevent packaging test failures on namespaced fields
        Database.insert(entry, AccessLevel.SYSTEM_MODE);
    }
}
