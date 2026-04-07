/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  CMT-driven approval chain service. Reads ApprovalStep__mdt records
 *               to define multi-step sequential/parallel approval workflows for WorkLogs.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryApprovalChainService {

    @TestVisible
    private static List<ApprovalStep__mdt> mockSteps;

    /**
     * @description Initiates the approval chain for a WorkLog record.
     *              Reads ApprovalStep__mdt for the workflow type, sets step 1,
     *              and timestamps the request.
     */
    public static void initiateApproval(Id workLogId, String workflowType) {
        List<ApprovalStep__mdt> steps = getActiveSteps(workflowType);
        if (steps.isEmpty()) {
            return;
        }

        WorkLog__c wl = [
            SELECT Id, StatusPk__c
            FROM WorkLog__c
            WHERE Id = :workLogId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        wl.StatusPk__c = 'Pending_Approval';
        wl.ApprovalStepNumber__c = 1;
        wl.ApprovalRequestedDateTime__c = Datetime.now();
        wl.ApprovedByTxt__c = '[]';
        Database.update(wl, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Processes an approval/rejection action on a WorkLog.
     *              For Sequential mode, advances to next step on approve.
     *              For Parallel/Any mode, counts approvals against required count.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    public static Map<String, Object> processApproval(
        Id workLogId,
        Id approverId,
        Boolean approved,
        String comments
    ) {
        WorkLog__c wl = [
            SELECT Id, StatusPk__c, ApprovalStepNumber__c, ApprovedByTxt__c,
                   WorkItemLookup__r.WorkflowTypeTxt__c
            FROM WorkLog__c
            WHERE Id = :workLogId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String wfType = wl.WorkItemLookup__r.WorkflowTypeTxt__c;
        List<ApprovalStep__mdt> steps = getActiveSteps(wfType);
        Integer currentStep = wl.ApprovalStepNumber__c != null
            ? wl.ApprovalStepNumber__c.intValue() : 1;

        if (!approved) {
            wl.StatusPk__c = 'Rejected';
            Database.update(wl, AccessLevel.SYSTEM_MODE);
            return new Map<String, Object>{
                'status' => 'Rejected',
                'step' => currentStep
            };
        }

        // Record the approver
        List<Object> approvers = (List<Object>) JSON.deserializeUntyped(
            String.isNotBlank(wl.ApprovedByTxt__c) ? wl.ApprovedByTxt__c : '[]'
        );
        approvers.add(String.valueOf(approverId));
        wl.ApprovedByTxt__c = JSON.serialize(approvers);

        // Check if current step is complete
        ApprovalStep__mdt step = currentStep <= steps.size()
            ? steps[currentStep - 1] : null;
        Boolean stepComplete = true;
        if (step != null && step.ApprovalModePk__c == 'Parallel') {
            Integer required = step.RequiredApprovalCountNumber__c != null
                ? step.RequiredApprovalCountNumber__c.intValue() : 1;
            stepComplete = approvers.size() >= required;
        }

        if (stepComplete && currentStep < steps.size()) {
            // Advance to next step
            wl.ApprovalStepNumber__c = currentStep + 1;
            wl.StatusPk__c = 'Pending_Approval';
            Database.update(wl, AccessLevel.SYSTEM_MODE);
            return new Map<String, Object>{
                'status' => 'Pending_Approval',
                'step' => currentStep + 1
            };
        } else if (stepComplete) {
            // All steps complete
            wl.StatusPk__c = 'Approved';
            Database.update(wl, AccessLevel.SYSTEM_MODE);
            return new Map<String, Object>{
                'status' => 'Approved',
                'step' => currentStep
            };
        } else {
            // Step not yet complete (parallel mode, waiting for more approvals)
            Database.update(wl, AccessLevel.SYSTEM_MODE);
            return new Map<String, Object>{
                'status' => 'Pending_Approval',
                'step' => currentStep,
                'approvalCount' => approvers.size()
            };
        }
    }

    /**
     * @description Checks for timed-out approval requests and executes timeout actions.
     *              Called by DeliveryHubScheduler.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    public static void checkTimeouts() {
        List<WorkLog__c> pending = [
            SELECT Id, StatusPk__c, ApprovalStepNumber__c,
                   ApprovalRequestedDateTime__c,
                   WorkItemLookup__r.WorkflowTypeTxt__c
            FROM WorkLog__c
            WHERE StatusPk__c = 'Pending_Approval'
            AND ApprovalRequestedDateTime__c != null
            WITH SYSTEM_MODE
        ];

        if (pending.isEmpty()) {
            return;
        }

        List<WorkLog__c> toUpdate = new List<WorkLog__c>();
        for (WorkLog__c wl : pending) {
            String wfType = wl.WorkItemLookup__r.WorkflowTypeTxt__c;
            List<ApprovalStep__mdt> steps = getActiveSteps(wfType);
            Integer currentStep = wl.ApprovalStepNumber__c != null
                ? wl.ApprovalStepNumber__c.intValue() : 1;

            if (currentStep > steps.size()) {
                continue;
            }
            ApprovalStep__mdt step = steps[currentStep - 1];

            Integer timeoutDays = step.TimeoutDaysNumber__c != null
                ? step.TimeoutDaysNumber__c.intValue() : 0;
            if (timeoutDays <= 0) {
                continue;
            }

            Long msSinceRequest = Datetime.now().getTime()
                - wl.ApprovalRequestedDateTime__c.getTime();
            Long daysSinceRequest = msSinceRequest / (1000L * 60 * 60 * 24);
            if (daysSinceRequest < timeoutDays) {
                continue;
            }

            String action = step.TimeoutActionPk__c;
            if (action == 'Auto_Approve') {
                wl.StatusPk__c = 'Approved';
            } else if (action == 'Auto_Reject') {
                wl.StatusPk__c = 'Rejected';
            }
            // 'Escalate' leaves as Pending_Approval (future: could bump priority)
            toUpdate.add(wl);
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Returns approval status for a WorkLog.
     */
    public static Map<String, Object> getApprovalStatus(Id workLogId) {
        WorkLog__c wl = [
            SELECT Id, StatusPk__c, ApprovalStepNumber__c, ApprovedByTxt__c,
                   ApprovalRequestedDateTime__c,
                   WorkItemLookup__r.WorkflowTypeTxt__c
            FROM WorkLog__c
            WHERE Id = :workLogId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return new Map<String, Object>{
            'status' => wl.StatusPk__c,
            'currentStep' => wl.ApprovalStepNumber__c,
            'approvedBy' => wl.ApprovedByTxt__c,
            'requestedAt' => wl.ApprovalRequestedDateTime__c
        };
    }

    private static Map<String, List<ApprovalStep__mdt>> stepCache =
        new Map<String, List<ApprovalStep__mdt>>();

    /** @description Returns active approval steps for the given workflow type, with caching. */
    @TestVisible
    private static List<ApprovalStep__mdt> getActiveSteps(String workflowType) {
        if (mockSteps != null) {
            // Filter mock steps by workflow type
            List<ApprovalStep__mdt> filtered = new List<ApprovalStep__mdt>();
            for (ApprovalStep__mdt s : mockSteps) {
                if (s.WorkflowTypeTxt__c == workflowType && s.ActiveDateTime__c != null) {
                    filtered.add(s);
                }
            }
            return filtered;
        }

        if (stepCache.containsKey(workflowType)) {
            return stepCache.get(workflowType);
        }
        List<ApprovalStep__mdt> steps = [
            SELECT DeveloperName, WorkflowTypeTxt__c, StepOrderNumber__c,
                   ApproverFieldTxt__c, ApprovalModePk__c,
                   RequiredApprovalCountNumber__c,
                   TimeoutDaysNumber__c, TimeoutActionPk__c
            FROM ApprovalStep__mdt
            WHERE WorkflowTypeTxt__c = :workflowType
            AND ActiveDateTime__c != null
            WITH SYSTEM_MODE
            ORDER BY StepOrderNumber__c ASC
        ];
        stepCache.put(workflowType, steps);
        return steps;
    }
}
