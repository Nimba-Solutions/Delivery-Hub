/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliveryTimeLogger LWC. Creates a WorkLog__c
 *              entry against a Work Item, which the roll-up summary on
 *              TotalLoggedHoursSum__c then reflects automatically.
 *              Also provides approval/rejection of WorkLogs and an
 *              isApprovalRequired check for the UI.
 *
 *              Approve-before-hours is a SOFT gate: logging never fails just
 *              because no request has been accepted. The log hangs off the
 *              newest Accepted / In Progress request, else the newest Draft,
 *              else a new Draft request (see
 *              DeliveryWorkItemTriggerHandler.ensureLogRequestId). Hours on a
 *              non-accepted request show on the Home "Hours without approval"
 *              card for the approver to clear.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier')
global with sharing class DeliveryTimeLoggerController {

    private static final String STATUS_DRAFT = 'Draft';
    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_REJECTED = 'Rejected';

    /**
     * @description Inserts a WorkLog__c record linked to the given work item.
     *              When approval is required, the log is saved as Draft;
     *              otherwise it is saved as Approved (preserving current behavior).
     * @param workItemId   The Id of the WorkItem__c record to log time against.
     * @param hours      The positive number of hours to log.
     * @param workNotes  Optional description of work performed.
     * @param workDate   The date the work was performed. Defaults to today if null.
     */
    @AuraEnabled
    global static void logHours(Id workItemId, Decimal hours, String workNotes, Date workDate) {
        if (hours == null || hours <= 0) {
            throw new AuraHandledException('Hours must be greater than zero.');
        }
        Id requestId = DeliveryWorkItemTriggerHandler.ensureLogRequestId(workItemId);

        Boolean approvalRequired = DeliveryWorkLogTriggerHandler.isApprovalRequired();
        String status = approvalRequired ? STATUS_DRAFT : STATUS_APPROVED;

        WorkLog__c entry = new WorkLog__c(
            RequestId__c          = requestId,
            WorkItemLookup__c     = workItemId,
            HoursLoggedNumber__c  = hours,
            WorkDateDate__c       = workDate != null ? workDate : Date.today(),
            WorkDescriptionTxt__c = workNotes,
            StatusPk__c           = status
        );
        Database.insert(entry, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Returns whether WorkLog approval is required in this org.
     * @return true when RequireWorkLogApprovalDateTime__c is set.
     */
    @AuraEnabled(cacheable=true)
    global static Boolean isApprovalRequired() {
        return DeliveryWorkLogTriggerHandler.isApprovalRequired();
    }

    /**
     * @description Batch-approves WorkLogs by setting StatusPk__c to 'Approved'.
     *              The trigger handler's onAfterUpdate will create SyncItems.
     *              Only the configured approver or an admin may call it.
     * @param workLogIds List of WorkLog__c Ids to approve.
     */
    @AuraEnabled
    global static void approveWorkLogs(List<Id> workLogIds) {
        DeliveryAccessService.requireApproverOrAdmin('approve work logs');
        decideWorkLogs(workLogIds, true);
    }

    /**
     * @description Batch-rejects WorkLogs by setting StatusPk__c to 'Rejected'.
     *              Only the configured approver or an admin may call it.
     * @param workLogIds List of WorkLog__c Ids to reject.
     */
    @AuraEnabled
    global static void rejectWorkLogs(List<Id> workLogIds) {
        DeliveryAccessService.requireApproverOrAdmin('reject work logs');
        decideWorkLogs(workLogIds, false);
    }

    /**
     * @description Unguarded decision core. Moves Draft logs to Approved or
     *              Rejected. For callers that authenticate the caller their own
     *              way (the public REST API authenticates by X-Api-Key and runs
     *              as the site user, so the user-role check does not apply).
     * @param workLogIds WorkLog__c ids; non-Draft ids are ignored.
     * @param approve true = Approved, false = Rejected.
     */
    public static void decideWorkLogs(List<Id> workLogIds, Boolean approve) {
        if (workLogIds == null || workLogIds.isEmpty()) {
            return;
        }
        List<WorkLog__c> logs = [
            SELECT Id, StatusPk__c FROM WorkLog__c
            WHERE Id IN :workLogIds AND StatusPk__c = :STATUS_DRAFT
            WITH SYSTEM_MODE
        ];
        String target = approve ? STATUS_APPROVED : STATUS_REJECTED;
        for (WorkLog__c wl : logs) {
            wl.StatusPk__c = target;
        }
        if (!logs.isEmpty()) {
            Database.update(logs, AccessLevel.SYSTEM_MODE);
        }
    }
}
