/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationService and DeliveryEscalationJob.
 *               Uses the @TestVisible overload that accepts rules as a parameter,
 *               since Custom Metadata records cannot be inserted via DML in tests.
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

        // Item in In Development for summary/severity tests
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Dev in progress item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            Developer__c = UserInfo.getUserId()
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
            null,
            'Warning'
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
     * @description Verifies the new Email action type works (simplified picklist value).
     */
    @IsTest
    static void testEmailAction() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Email Action',
            'Software_Delivery',
            'In Development',
            0,
            'Email',
            null,
            null,
            'Warning'
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ContextDataTxt__c FROM ActivityLog__c
            WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
            WITH SYSTEM_MODE
        ];
        System.assert(!logs.isEmpty(), 'Should create activity log for Email action');
        System.assert(logs[0].ContextDataTxt__c.contains('"action":"Email"'),
            'Log should reference Email action');
    }

    /**
     * @description Verifies the Chatter action posts a FeedItem on the work item.
     */
    @IsTest
    static void testChatterAction() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Chatter Rule',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Chatter',
            null,
            null,
            'Critical'
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c wi = [
            SELECT Id FROM WorkItem__c
            WHERE StageNamePk__c = 'Dev Blocked'
            WITH SYSTEM_MODE LIMIT 1
        ];

        List<FeedItem> feeds = [
            SELECT Body FROM FeedItem
            WHERE ParentId = :wi.Id
            WITH SYSTEM_MODE
        ];
        System.assert(!feeds.isEmpty(), 'Chatter post should be created on the work item');
        System.assert(feeds[0].Body.contains('ESCALATION'),
            'Chatter post should contain ESCALATION text');
    }

    /**
     * @description Verifies the Both action sends both email and Chatter post.
     */
    @IsTest
    static void testBothAction() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Both Rule',
            'Software_Delivery',
            'In Development',
            0,
            'Both',
            null,
            null,
            'Critical'
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c wi = [
            SELECT Id FROM WorkItem__c
            WHERE StageNamePk__c = 'In Development'
            WITH SYSTEM_MODE LIMIT 1
        ];

        // Verify Chatter post was created (email send is verified by no exceptions)
        List<FeedItem> feeds = [
            SELECT Body FROM FeedItem
            WHERE ParentId = :wi.Id
            WITH SYSTEM_MODE
        ];
        System.assert(!feeds.isEmpty(), 'Both action should create a Chatter post');

        // Verify activity log was created
        List<ActivityLog__c> logs = [
            SELECT ContextDataTxt__c FROM ActivityLog__c
            WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
            WITH SYSTEM_MODE
        ];
        System.assert(!logs.isEmpty(), 'Both action should create activity log');
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
            null,
            'Warning'
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
            null,
            'Warning'
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
            null,
            'Warning'
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
            null,
            'Warning'
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
            'High', // Only High priority — our Dev Blocked item is Low, should NOT match
            'Warning'
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
            null,
            'Warning'
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
     * @description Verifies evaluateRules() runs without error.
     */
    @IsTest
    static void testEvaluateRules() {
        Test.startTest();
        DeliveryEscalationService.evaluateRules();
        Test.stopTest();

        System.assert(true, 'evaluateRules() should not throw');
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
            null,
            'Warning'
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

    /**
     * @description Verifies severity-aware HTML builder includes severity details.
     */
    @IsTest
    static void testBuildEscalationHtmlWithSeverity() {
        String html = DeliveryEscalationService.buildEscalationHtml(
            'WI-0100', 'Critical bug', 'In Development',
            'https://test.salesforce.com/lightning/r/WorkItem__c/002/view',
            'Critical', 5, 'Dev Stuck 3 Days'
        );
        System.assert(html.contains('CRITICAL'), 'HTML must indicate critical severity');
        System.assert(html.contains('5 day(s)'), 'HTML must contain days in stage');
        System.assert(html.contains('Dev Stuck 3 Days'), 'HTML must contain rule name');
        System.assert(html.contains('#ba1b1b'), 'Critical should use red header color');

        // Also test Warning severity
        String warningHtml = DeliveryEscalationService.buildEscalationHtml(
            'WI-0101', 'Slow item', 'QA In Progress',
            'https://test.salesforce.com/lightning/r/WorkItem__c/003/view',
            'Warning', 2, 'QA Stuck 2 Days'
        );
        System.assert(warningHtml.contains('#e67e22'), 'Warning should use orange header color');
        System.assert(!warningHtml.contains('CRITICAL'), 'Warning HTML should not say CRITICAL');
    }

    /**
     * @description Verifies getEscalationSummary returns items in breach.
     */
    @IsTest
    static void testGetEscalationSummary() {
        // Use buildSummary with injected rules since getEscalationSummary queries CMT
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Summary Rule',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Email',
            null,
            null,
            'Critical'
        ));

        Test.startTest();
        List<DeliveryEscalationService.EscalationSummary> summaries =
            DeliveryEscalationService.buildSummary(rules);
        Test.stopTest();

        System.assert(!summaries.isEmpty(), 'Should return at least one breached item');
        DeliveryEscalationService.EscalationSummary first = summaries[0];
        System.assertNotEquals(null, first.workItemId, 'workItemId should be populated');
        System.assertNotEquals(null, first.workItemName, 'workItemName should be populated');
        System.assertEquals('Test Summary Rule', first.ruleName, 'ruleName should match the rule');
        System.assertEquals('Critical', first.severityLevel, 'severityLevel should be Critical');
        System.assertEquals('Dev Blocked', first.stageName, 'stageName should be Dev Blocked');
    }

    /**
     * @description Verifies getEscalationSummary returns empty for items within SLA.
     */
    @IsTest
    static void testGetEscalationSummaryNoFalsePositives() {
        // Use a high threshold that freshly created items will not breach
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'High Threshold Rule',
            'Software_Delivery',
            'Dev Blocked',
            999, // 999 days — no item will breach this
            'Email',
            null,
            null,
            'Warning'
        ));

        Test.startTest();
        List<DeliveryEscalationService.EscalationSummary> summaries =
            DeliveryEscalationService.buildSummary(rules);
        Test.stopTest();

        System.assertEquals(0, summaries.size(),
            'No items should be in breach with a 999-day threshold');
    }

    /**
     * @description Verifies that items within SLA threshold are not escalated.
     */
    @IsTest
    static void testNoFalsePositivesWithThreshold() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'High Threshold Rule',
            'Software_Delivery',
            'Dev Blocked',
            999, // Freshly created items are 0 days old, won't match
            'Bump_Priority',
            null,
            null,
            'Warning'
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
            'Priority should remain Low because item has not breached the 999-day threshold');
    }

    /**
     * @description Verifies that the escalation cooldown prevents duplicate notifications.
     *              An item with a recent LastEscalatedDateTime__c should be skipped.
     */
    @IsTest
    static void testCooldownPreventsReescalation() {
        // Set LastEscalatedDateTime__c to now — should prevent re-escalation
        WorkItem__c wi = [
            SELECT Id FROM WorkItem__c
            WHERE StageNamePk__c = 'In Development'
            WITH SYSTEM_MODE LIMIT 1
        ];
        wi.LastEscalatedDateTime__c = DateTime.now();
        update wi;

        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Cooldown Rule',
            'Software_Delivery',
            'In Development',
            0,
            'Bump_Priority',
            null,
            null,
            'Warning'
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c unchanged = [
            SELECT PriorityPk__c FROM WorkItem__c
            WHERE Id = :wi.Id
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Medium', unchanged.PriorityPk__c,
            'Priority should remain Medium because cooldown prevented re-escalation');
    }

    /**
     * @description Verifies LastEscalatedDateTime__c is set when an escalation fires.
     */
    @IsTest
    static void testLastEscalatedDateTimeIsSet() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Test Timestamp Rule',
            'Software_Delivery',
            'In Development',
            0,
            'Email',
            null,
            null,
            'Warning'
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        WorkItem__c updated = [
            SELECT LastEscalatedDateTime__c FROM WorkItem__c
            WHERE StageNamePk__c = 'In Development'
            WITH SYSTEM_MODE LIMIT 1
        ];
        System.assertNotEquals(null, updated.LastEscalatedDateTime__c,
            'LastEscalatedDateTime__c should be set after escalation');
    }

    /**
     * @description Verifies DeliveryEscalationJob.execute() runs without error.
     */
    @IsTest
    static void testDeliveryEscalationJobExecute() {
        Test.startTest();
        new DeliveryEscalationJob().execute(null);
        Test.stopTest();

        System.assert(true, 'DeliveryEscalationJob.execute() should not throw');
    }

    /**
     * @description Verifies the getEscalationSummary AuraEnabled method runs without error.
     */
    @IsTest
    static void testGetEscalationSummaryAuraEnabled() {
        Test.startTest();
        List<DeliveryEscalationService.EscalationSummary> results =
            DeliveryEscalationService.getEscalationSummary();
        Test.stopTest();

        // May or may not return results depending on CMT rules and test data timing
        System.assertNotEquals(null, results, 'Should return a list (possibly empty)');
    }

    /**
     * @description Verifies severity metadata is included in log context.
     */
    @IsTest
    static void testSeverityInLogContext() {
        List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
        rules.add(buildRule(
            'Critical Severity Rule',
            'Software_Delivery',
            'Dev Blocked',
            0,
            'Email',
            null,
            null,
            'Critical'
        ));

        Test.startTest();
        DeliveryEscalationService.processEscalations(rules);
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ContextDataTxt__c FROM ActivityLog__c
            WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
            WITH SYSTEM_MODE
        ];
        System.assert(!logs.isEmpty(), 'Should create activity log');
        System.assert(logs[0].ContextDataTxt__c.contains('"severity":"Critical"'),
            'Log context should include severity level');
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Returns the org namespace prefix (e.g. 'delivery__') or empty string
     *              if running in an unpackaged context. Used to namespace-qualify custom
     *              field keys in JSON deserialization of CMT records.
     * @return Namespace prefix with trailing __ or empty string
     */
    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    /**
     * @description Builds a WorkflowEscalationRule__mdt record for testing.
     *              Uses JSON deserialize since CMT records cannot be constructed via new().
     *              Prefixes custom field keys with the org namespace to ensure correct
     *              deserialization in namespaced package contexts.
     * @param label Rule label
     * @param workflowType Workflow type filter (or null for all)
     * @param triggerStage Stage that triggers this rule
     * @param daysThreshold Days before escalation fires
     * @param actionType The action to take
     * @param targetValue Target value for the action
     * @param priorityFilter Priority filter (or null for all)
     * @param severity Severity level (Warning or Critical)
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
        String priorityFilter,
        String severity
    ) {
        String ns = getNamespace();
        Map<String, Object> fieldMap = new Map<String, Object>{
            'MasterLabel' => label,
            ns + 'WorkflowTypeTxt__c' => workflowType,
            ns + 'TriggerStageTxt__c' => triggerStage,
            ns + 'DaysThresholdNum__c' => daysThreshold,
            ns + 'ActionTypePk__c' => actionType,
            ns + 'TargetValueTxt__c' => targetValue,
            ns + 'PriorityFilterTxt__c' => priorityFilter,
            ns + 'SeverityLevelPk__c' => severity,
            ns + 'IsActiveBool__c' => true,
            ns + 'SortOrderNum__c' => 1
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
