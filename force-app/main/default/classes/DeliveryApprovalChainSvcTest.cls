/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryApprovalChainService.
 *               Uses @TestVisible mockSteps to inject ApprovalStep__mdt records
 *               since Custom Metadata cannot be inserted via DML in tests.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.CyclomaticComplexity')
private class DeliveryApprovalChainSvcTest {

    @TestSetup
    static void makeData() {
        WorkItem__c item = new WorkItem__c(
            BriefDescriptionTxt__c = 'Approval test item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
        );
        insert item;

        WorkLog__c log = new WorkLog__c(
            WorkItemId__c = item.Id,
            HoursLoggedNumber__c = 2,
            WorkDateDate__c = Date.today(),
            WorkDescriptionTxt__c = 'Test work log for approvals',
            StatusPk__c = 'Draft'
        );
        insert log;
    }

    private static WorkLog__c getTestLog() {
        return [
            SELECT Id, StatusPk__c, ApprovalStepNumber__c, ApprovedByTxt__c,
                   ApprovalRequestedDateTime__c, WorkItemId__c,
                   WorkItemId__r.WorkflowTypeTxt__c
            FROM WorkLog__c
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }

    private static List<ApprovalStep__mdt> buildSequentialSteps() {
        List<ApprovalStep__mdt> steps = new List<ApprovalStep__mdt>();
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'Step1',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 1,
            ApprovalModePk__c = 'Sequential',
            ApproverFieldTxt__c = 'Developer__c',
            TimeoutDaysNumber__c = 3,
            TimeoutActionPk__c = 'Auto_Approve',
            ActiveDateTime__c = Datetime.now()
        ));
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'Step2',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 2,
            ApprovalModePk__c = 'Sequential',
            ApproverFieldTxt__c = 'OwnerId',
            TimeoutDaysNumber__c = 5,
            TimeoutActionPk__c = 'Auto_Reject',
            ActiveDateTime__c = Datetime.now()
        ));
        return steps;
    }

    /**
     * @description initiateApproval sets step 1, Pending_Approval status, and timestamps.
     */
    @IsTest
    static void testInitiateApproval() {
        DeliveryApprovalChainService.mockSteps = buildSequentialSteps();
        WorkLog__c wl = getTestLog();

        Test.startTest();
        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Software_Delivery'
        );
        Test.stopTest();

        WorkLog__c updated = getTestLog();
        System.assertEquals(
            'Pending_Approval', updated.StatusPk__c,
            'Status should be Pending_Approval after initiation'
        );
        System.assertEquals(
            1, updated.ApprovalStepNumber__c,
            'Should start at step 1'
        );
        System.assertNotEquals(
            null, updated.ApprovalRequestedDateTime__c,
            'ApprovalRequestedDateTime should be stamped'
        );
        System.assertEquals(
            '[]', updated.ApprovedByTxt__c,
            'ApprovedBy should be empty JSON array'
        );
    }

    /**
     * @description initiateApproval with no matching steps does nothing.
     */
    @IsTest
    static void testInitiateApprovalNoSteps() {
        DeliveryApprovalChainService.mockSteps = new List<ApprovalStep__mdt>();
        WorkLog__c wl = getTestLog();

        Test.startTest();
        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Unknown_Type'
        );
        Test.stopTest();

        WorkLog__c updated = getTestLog();
        System.assertEquals(
            'Draft', updated.StatusPk__c,
            'Status should remain Draft when no steps exist'
        );
    }

    /**
     * @description processApproval approve on sequential 2-step chain advances to step 2.
     */
    @IsTest
    static void testProcessApprovalAdvancesStep() {
        DeliveryApprovalChainService.mockSteps = buildSequentialSteps();
        WorkLog__c wl = getTestLog();

        // Initiate first
        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Software_Delivery'
        );

        Test.startTest();
        Map<String, Object> result = DeliveryApprovalChainService.processApproval(
            wl.Id, UserInfo.getUserId(), true, 'Looks good'
        );
        Test.stopTest();

        System.assertEquals('Pending_Approval', result.get('status'),
            'Should still be pending (step 2 remains)');
        System.assertEquals(2, result.get('step'),
            'Should advance to step 2');

        WorkLog__c updated = getTestLog();
        System.assertEquals(2, updated.ApprovalStepNumber__c,
            'DB should reflect step 2');
    }

    /**
     * @description processApproval approve on final step sets Approved.
     */
    @IsTest
    static void testProcessApprovalFinalStep() {
        DeliveryApprovalChainService.mockSteps = buildSequentialSteps();
        WorkLog__c wl = getTestLog();

        // Initiate and advance through step 1
        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Software_Delivery'
        );
        DeliveryApprovalChainService.processApproval(
            wl.Id, UserInfo.getUserId(), true, 'Step 1 ok'
        );

        Test.startTest();
        Map<String, Object> result = DeliveryApprovalChainService.processApproval(
            wl.Id, UserInfo.getUserId(), true, 'Step 2 ok'
        );
        Test.stopTest();

        System.assertEquals('Approved', result.get('status'),
            'Should be Approved after final step');
    }

    /**
     * @description processApproval reject sets Rejected status.
     */
    @IsTest
    static void testProcessApprovalReject() {
        DeliveryApprovalChainService.mockSteps = buildSequentialSteps();
        WorkLog__c wl = getTestLog();

        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Software_Delivery'
        );

        Test.startTest();
        Map<String, Object> result = DeliveryApprovalChainService.processApproval(
            wl.Id, UserInfo.getUserId(), false, 'Not acceptable'
        );
        Test.stopTest();

        System.assertEquals('Rejected', result.get('status'),
            'Should be Rejected');
        WorkLog__c updated = getTestLog();
        System.assertEquals('Rejected', updated.StatusPk__c,
            'DB should reflect Rejected');
    }

    /**
     * @description processApproval in Parallel mode waits for required count.
     */
    @IsTest
    static void testProcessApprovalParallelMode() {
        List<ApprovalStep__mdt> steps = new List<ApprovalStep__mdt>();
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'ParallelStep',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 1,
            ApprovalModePk__c = 'Parallel',
            RequiredApprovalCountNumber__c = 2,
            TimeoutDaysNumber__c = 0,
            TimeoutActionPk__c = 'Escalate',
            ActiveDateTime__c = Datetime.now()
        ));
        DeliveryApprovalChainService.mockSteps = steps;

        WorkLog__c wl = getTestLog();
        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Software_Delivery'
        );

        Test.startTest();
        // First approval — not enough yet
        Map<String, Object> result1 = DeliveryApprovalChainService.processApproval(
            wl.Id, UserInfo.getUserId(), true, 'Approver 1'
        );
        System.assertEquals('Pending_Approval', result1.get('status'),
            'Should still be pending (need 2 approvals)');
        System.assertEquals(1, result1.get('approvalCount'),
            'Should have 1 approval recorded');

        // Second approval — completes
        Map<String, Object> result2 = DeliveryApprovalChainService.processApproval(
            wl.Id, UserInfo.getUserId(), true, 'Approver 2'
        );
        Test.stopTest();

        System.assertEquals('Approved', result2.get('status'),
            'Should be Approved after 2 parallel approvals');
    }

    /**
     * @description checkTimeouts auto-approves when days exceed TimeoutDaysNum.
     */
    @IsTest
    static void testCheckTimeoutsAutoApprove() {
        List<ApprovalStep__mdt> steps = new List<ApprovalStep__mdt>();
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'TimeoutStep',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 1,
            ApprovalModePk__c = 'Sequential',
            TimeoutDaysNumber__c = 1,
            TimeoutActionPk__c = 'Auto_Approve',
            ActiveDateTime__c = Datetime.now()
        ));
        DeliveryApprovalChainService.mockSteps = steps;

        WorkLog__c wl = getTestLog();
        // Set up as pending approval with a past request date
        wl.StatusPk__c = 'Pending_Approval';
        wl.ApprovalStepNumber__c = 1;
        wl.ApprovalRequestedDateTime__c = Datetime.now().addDays(-3);
        wl.ApprovedByTxt__c = '[]';
        update wl;

        Test.startTest();
        DeliveryApprovalChainService.checkTimeouts();
        Test.stopTest();

        WorkLog__c updated = getTestLog();
        System.assertEquals('Approved', updated.StatusPk__c,
            'Should be auto-approved after timeout');
    }

    /**
     * @description checkTimeouts auto-rejects when configured.
     */
    @IsTest
    static void testCheckTimeoutsAutoReject() {
        List<ApprovalStep__mdt> steps = new List<ApprovalStep__mdt>();
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'RejectStep',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 1,
            ApprovalModePk__c = 'Sequential',
            TimeoutDaysNumber__c = 1,
            TimeoutActionPk__c = 'Auto_Reject',
            ActiveDateTime__c = Datetime.now()
        ));
        DeliveryApprovalChainService.mockSteps = steps;

        WorkLog__c wl = getTestLog();
        wl.StatusPk__c = 'Pending_Approval';
        wl.ApprovalStepNumber__c = 1;
        wl.ApprovalRequestedDateTime__c = Datetime.now().addDays(-5);
        wl.ApprovedByTxt__c = '[]';
        update wl;

        Test.startTest();
        DeliveryApprovalChainService.checkTimeouts();
        Test.stopTest();

        WorkLog__c updated = getTestLog();
        System.assertEquals('Rejected', updated.StatusPk__c,
            'Should be auto-rejected after timeout');
    }

    /**
     * @description checkTimeouts with Escalate action leaves status unchanged.
     */
    @IsTest
    static void testCheckTimeoutsEscalate() {
        List<ApprovalStep__mdt> steps = new List<ApprovalStep__mdt>();
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'EscStep',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 1,
            ApprovalModePk__c = 'Sequential',
            TimeoutDaysNumber__c = 1,
            TimeoutActionPk__c = 'Escalate',
            ActiveDateTime__c = Datetime.now()
        ));
        DeliveryApprovalChainService.mockSteps = steps;

        WorkLog__c wl = getTestLog();
        wl.StatusPk__c = 'Pending_Approval';
        wl.ApprovalStepNumber__c = 1;
        wl.ApprovalRequestedDateTime__c = Datetime.now().addDays(-5);
        wl.ApprovedByTxt__c = '[]';
        update wl;

        Test.startTest();
        DeliveryApprovalChainService.checkTimeouts();
        Test.stopTest();

        WorkLog__c updated = getTestLog();
        System.assertEquals('Pending_Approval', updated.StatusPk__c,
            'Escalate should leave status as Pending_Approval');
    }

    /**
     * @description checkTimeouts skips records not yet timed out.
     */
    @IsTest
    static void testCheckTimeoutsNotExpired() {
        List<ApprovalStep__mdt> steps = new List<ApprovalStep__mdt>();
        steps.add(new ApprovalStep__mdt(
            DeveloperName = 'FreshStep',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StepOrderNumber__c = 1,
            ApprovalModePk__c = 'Sequential',
            TimeoutDaysNumber__c = 30,
            TimeoutActionPk__c = 'Auto_Reject',
            ActiveDateTime__c = Datetime.now()
        ));
        DeliveryApprovalChainService.mockSteps = steps;

        WorkLog__c wl = getTestLog();
        wl.StatusPk__c = 'Pending_Approval';
        wl.ApprovalStepNumber__c = 1;
        wl.ApprovalRequestedDateTime__c = Datetime.now();
        wl.ApprovedByTxt__c = '[]';
        update wl;

        Test.startTest();
        DeliveryApprovalChainService.checkTimeouts();
        Test.stopTest();

        WorkLog__c updated = getTestLog();
        System.assertEquals('Pending_Approval', updated.StatusPk__c,
            'Should remain Pending_Approval (not timed out yet)');
    }

    /**
     * @description getApprovalStatus returns correct data.
     */
    @IsTest
    static void testGetApprovalStatus() {
        DeliveryApprovalChainService.mockSteps = buildSequentialSteps();
        WorkLog__c wl = getTestLog();

        DeliveryApprovalChainService.initiateApproval(
            wl.Id, 'Software_Delivery'
        );

        Test.startTest();
        Map<String, Object> status = DeliveryApprovalChainService.getApprovalStatus(wl.Id);
        Test.stopTest();

        System.assertEquals('Pending_Approval', status.get('status'),
            'Status should be Pending_Approval');
        System.assertEquals(1, (Decimal) status.get('currentStep'),
            'Current step should be 1');
        System.assertEquals('[]', status.get('approvedBy'),
            'ApprovedBy should be empty array');
        System.assertNotEquals(null, status.get('requestedAt'),
            'requestedAt should be populated');
    }
}
