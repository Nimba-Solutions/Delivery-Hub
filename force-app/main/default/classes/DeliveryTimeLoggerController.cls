/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliveryTimeLogger LWC. Creates a WorkLog__c
 *              entry against a Work Item, which the roll-up summary on
 *              TotalLoggedHoursNumber__c then reflects automatically.
 *              Also provides approval/rejection of WorkLogs and an
 *              isApprovalRequired check for the UI.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryTimeLoggerController {

    /**
     * @description Inserts a WorkLog__c record linked to the given work item.
     *              When approval is required, the log is saved as Draft;
     *              otherwise it is saved as Approved (preserving current behavior).
     * @param workItemId   The Id of the WorkItem__c record to log time against.
     * @param hours      The positive number of hours to log.
     * @param workNotes  Optional description of work performed.
     * @param workDate   The date the work was performed. Defaults to today if null.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    public static void logHours(Id workItemId, Decimal hours, String workNotes, Date workDate) {
        List<WorkRequest__c> activeReqs = [
            SELECT Id FROM WorkRequest__c
            WHERE WorkItemId__c = :workItemId
            AND StatusPk__c IN ('Draft', 'Accepted', 'In Progress')
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (activeReqs.isEmpty()) {
            throw new AuraHandledException('No accepted request found for this work item. Please accept a vendor quote before logging time.');
        }

        Boolean approvalRequired = DeliveryWorkLogTriggerHandler.isApprovalRequired();
        String status = approvalRequired ? 'Draft' : 'Approved';

        WorkLog__c entry = new WorkLog__c(
            RequestId__c          = activeReqs[0].Id,
            WorkItemId__c           = workItemId,
            HoursLoggedNumber__c  = hours,
            WorkDateDate__c       = workDate != null ? workDate : Date.today(),
            WorkDescriptionTxt__c = workNotes,
            StatusPk__c           = status
        );
        Database.insert(entry, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Returns whether WorkLog approval is required in this org.
     * @return true when RequireWorkLogApprovalDate__c is set.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isApprovalRequired() {
        return DeliveryWorkLogTriggerHandler.isApprovalRequired();
    }

    /**
     * @description Batch-approves WorkLogs by setting StatusPk__c to 'Approved'.
     *              The trigger handler's onAfterUpdate will create SyncItems.
     * @param workLogIds List of WorkLog__c Ids to approve.
     */
    @AuraEnabled
    public static void approveWorkLogs(List<Id> workLogIds) {
        if (workLogIds == null || workLogIds.isEmpty()) {
            return;
        }
        List<WorkLog__c> logs = [
            SELECT Id, StatusPk__c FROM WorkLog__c
            WHERE Id IN :workLogIds AND StatusPk__c = 'Draft'
            WITH SYSTEM_MODE
        ];
        for (WorkLog__c wl : logs) {
            wl.StatusPk__c = 'Approved';
        }
        if (!logs.isEmpty()) {
            Database.update(logs, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Batch-rejects WorkLogs by setting StatusPk__c to 'Rejected'.
     * @param workLogIds List of WorkLog__c Ids to reject.
     */
    @AuraEnabled
    public static void rejectWorkLogs(List<Id> workLogIds) {
        if (workLogIds == null || workLogIds.isEmpty()) {
            return;
        }
        List<WorkLog__c> logs = [
            SELECT Id, StatusPk__c FROM WorkLog__c
            WHERE Id IN :workLogIds AND StatusPk__c = 'Draft'
            WITH SYSTEM_MODE
        ];
        for (WorkLog__c wl : logs) {
            wl.StatusPk__c = 'Rejected';
        }
        if (!logs.isEmpty()) {
            Database.update(logs, AccessLevel.SYSTEM_MODE);
        }
    }
}
