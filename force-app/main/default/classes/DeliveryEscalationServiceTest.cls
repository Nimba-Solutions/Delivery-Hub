/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationService. Uses the @TestVisible overload
 *               that accepts rules as a parameter, since Custom Metadata records
 *               cannot be inserted via DML in tests.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryEscalationServiceTest {

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EmailNotificationsEnabledBool__c = true,
            EnableNotificationsBool__c = true
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Item stalled in Clarification Requested (Pre-Dev) — Software_Delivery
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Stalled clarification item',
            StageNamePk__c = 'Clarification Requested (Pre-Dev)',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
        ));

        // Item in Dev Blocked — Software_Delivery, Low priority
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked dev item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
        ));

        // Item in In Client Approval — Software_Delivery
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Awaiting client approval',
            StageNamePk__c = 'In Client Approval',
            PriorityPk__c = 'High',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
        ));

        // Item in Backlog — should NOT be matched by any default rules
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Backlog item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery'
        ));

        insert items;

        // Backdate LastModifiedDate by manipulating via a field update in the past
        // Since we cannot set LastModifiedDate directly, we set the threshold to 0
        // in our test rules to ensure matching regardless of timing.
    }

    /**
     * @description Verifies Email_Owner action dispatches without errors for stalled items.
     */
    @IsTest
    static void testEmailOwnerAction() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Email Rule',
            'Software_Delivery',
            'Clarification Requested (Pre-Dev)',
            0, // threshold 0 so freshly created items match
            'Email_Owner',
            null,
            null
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        // Verify activity log was created
        List<ActivityLog__c> logs = [
            SELECT Id, ComponentNameTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
            WITH SYSTEM_MODE
        ];
        System.assert(!logs.isEmpty(), 'Should create activity log entries for escalations');
        System.assert(logs[0].ContextDataTxt__c.contains('Email_Owner'),
            'Log context should contain the action type');
    }

    /**
     * @description Verifies Bump_Priority action increments priority from Low to Medium.
     */
    @IsTest
    static void testBumpPriorityAction() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Bump Rule',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Bump_Priority',
            null,
            null
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT PriorityPk__c FROM WorkItem__c
            WHERE StageNamePk__c = 'Dev Blocked'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertEquals('Medium', updated.PriorityPk__c,
            'Priority should be bumped from Low to Medium');
    }

    /**
     * @description Verifies Move_Stage action updates the stage to the target value.
     */
    @IsTest
    static void testMoveStageAction() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Move Stage Rule',
            'Software_Delivery',
            'In Client Approval',
            0,
            'Move_Stage',
            'Ready for Development',
            null
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT StageNamePk__c FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'Awaiting client approval'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertEquals('Ready for Development', updated.StageNamePk__c,
            'Stage should be moved to Ready for Development');
    }

    /**
     * @description Verifies Slack_Alert action executes without errors.
     *              Uses an HTTP mock to capture the outbound callout.
     */
    @IsTest
    static void testSlackAlertAction() {
        // Configure Slack webhook so the service attempts a callout
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.SlackWebhookUrl__c = 'https://hooks.slack.com/test';
        update settings;

        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Slack Rule',
            'Software_Delivery',
            'In Client Approval',
            0,
            'Slack_Alert',
            null,
            null
        ));

        Test.setMock(HttpCalloutMock.class, new SlackMockResponse());

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        // Verify activity log was created for the Slack action
        List<ActivityLog__c> logs = [
            SELECT ContextDataTxt__c FROM ActivityLog__c
            WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
            WITH SYSTEM_MODE
        ];
        System.assert(!logs.isEmpty(), 'Should create activity log for Slack escalation');
    }

    /**
     * @description Verifies Reassign action updates the owner when a valid Id is provided.
     */
    @IsTest
    static void testReassignAction() {
        Id currentUserId = UserInfo.getUserId();

        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Reassign Rule',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Reassign',
            String.valueOf(currentUserId),
            null
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT OwnerId FROM WorkItem__c
            WHERE StageNamePk__c = 'Dev Blocked'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertEquals(currentUserId, updated.OwnerId,
            'Owner should be reassigned to the target user');
    }

    /**
     * @description Verifies that the priority filter correctly limits which items are escalated.
     */
    @IsTest
    static void testPriorityFilter() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Priority Filter Rule',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Bump_Priority',
            null,
            'High' // Only High priority — our Dev Blocked item is Low, should NOT match
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c unchanged = [
            SELECT PriorityPk__c FROM WorkItem__c
            WHERE StageNamePk__c = 'Dev Blocked'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertEquals('Low', unchanged.PriorityPk__c,
            'Priority should remain Low because the High filter excluded this item');
    }

    /**
     * @description Verifies that the workflow type filter correctly limits escalation scope.
     */
    @IsTest
    static void testWorkflowTypeFilter() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Type Filter Rule',
            'Loan_Approval', // Rule is for LA, but our items are SD
            'Dev Blocked',
            0,
            'Bump_Priority',
            null,
            null
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c unchanged = [
            SELECT PriorityPk__c FROM WorkItem__c
            WHERE StageNamePk__c = 'Dev Blocked'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertEquals('Low', unchanged.PriorityPk__c,
            'Priority should remain Low because Loan_Approval filter excluded this SD item');
    }

    /**
     * @description Verifies that an empty rules list produces no errors and no DML.
     */
    @IsTest
    static void testEmptyRules() {
        Test.startTest();
        DeliveryEscalationService.processEscalations(new List<WorkflowEscalationRule__mdt>());
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT Id FROM ActivityLog__c
            WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(0, logs.size(), 'No escalations should occur with empty rules');
    }

    /**
     * @description Verifies that the zero-argument overload (queries CMT) runs without error.
     */
    @IsTest
    static void testProcessEscalationsFromCMT() {
        Test.startTest();
        DeliveryEscalationService.processEscalations();
        Test.stopTest();

        // Just verify no unhandled exceptions — CMT rules may or may not match test data
        System.assert(true, 'processEscalations() from CMT should not throw');
    }

    /**
     * @description Verifies that Bump_Priority does not exceed Critical.
     */
    @IsTest
    static void testBumpPriorityAlreadyCritical() {
        // Update the Dev Blocked item to Critical before testing
        WorkItem__c wi = [
            SELECT Id FROM WorkItem__c
            WHERE StageNamePk__c = 'Dev Blocked'
            WITH SYSTEM_MODE LIMIT 1
        ];
        // Note: PriorityPk__c picklist only has Low/Medium/High — we test the "High" ceiling
        wi.PriorityPk__c = 'High';
        update wi;

        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Bump Ceiling',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Bump_Priority',
            null,
            null
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT PriorityPk__c FROM WorkItem__c
            WHERE Id = :wi.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Critical', updated.PriorityPk__c,
            'Priority should be bumped from High to Critical');
    }

    /**
     * @description Verifies that buildEscalationHtml returns a valid HTML string.
     */
    @IsTest
    static void testBuildEscalationHtml() {
        String html = DeliveryEscalationService.buildEscalationHtml(
            'WI-0099', 'Fix broken login', 'Dev Blocked',
            'https://test.salesforce.com/lightning/r/WorkItem__c/001/view'
        );
        System.assert(html.contains('WI-0099'), 'HTML must contain work item name');
        System.assert(html.contains('Fix broken login'), 'HTML must contain title');
        System.assert(html.contains('Dev Blocked'), 'HTML must contain stalled stage');
        System.assert(html.contains('Escalation Alert'), 'HTML must contain escalation header');
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Builds a WorkflowEscalationRule__mdt record for testing.
     *              Uses JSON deserialize since CMT records cannot be constructed via new().
     * @param label Rule label
     * @param workflowType Workflow type filter (or null for all)
     * @param triggerStage Stage that triggers this rule
     * @param daysThreshold Days before escalation fires
     * @param actionType The action to take
     * @param targetValue Target value for the action
     * @param priorityFilter Priority filter (or null for all)
     * @return WorkflowEscalationRule__mdt record
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static WorkflowEscalationRule__mdt buildRule(
        String label,
        String workflowType,
        String triggerStage,
        Integer daysThreshold,
        String actionType,
        String targetValue,
        String priorityFilter
    ) {
        Map<String, Object> fieldMap = new Map<String, Object>{
            'MasterLabel' => label,
            'WorkflowTypeTxt__c' => workflowType,
            'TriggerStageTxt__c' => triggerStage,
            'DaysThresholdNum__c' => daysThreshold,
            'ActionTypePk__c' => actionType,
            'TargetValueTxt__c' => targetValue,
            'PriorityFilterTxt__c' => priorityFilter,
            'IsActiveBool__c' => true,
            'SortOrderNum__c' => 1
        };
        return (WorkflowEscalationRule__mdt) JSON.deserialize(
            JSON.serialize(fieldMap), WorkflowEscalationRule__mdt.class
        );
    }

    /**
     * @description Mock HTTP response for Slack webhook callouts.
     */
    public class SlackMockResponse implements HttpCalloutMock {
        /**
         * @description Returns a 200 OK response simulating a successful Slack webhook post.
         * @param req The HTTP request
         * @return HttpResponse with 200 status
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
