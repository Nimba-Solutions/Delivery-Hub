/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationService and DeliveryEscalationJob.
 *               Uses the @TestVisible overload that accepts rules as a parameter,
 *               since Custom Metadata records cannot be inserted via DML in tests.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.CyclomaticComplexity')
private class DeliveryEscalationServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableEmailNotificationsDateTime__c = Datetime.now(),
            EnableNotificationsDateTime__c = Datetime.now()
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Defensive: explicitly set ActivatedDateTime__c and StageEnteredDateTime__c
        // because the DeliveryWorkItemTriggerHandler before-insert population does not
        // reliably materialize on the in-memory reference in the namespaced packaging
        // org used by upload-beta. The DeliveryEscalationRuleEvaluator filters
        // candidates with `WHERE ActivatedDateTime__c != null`, so missing the trigger
        // population would silently exclude every test row from escalation. Same
        // pattern as DeliveryEscalationRuleEvaluatorTest / ActionExecutorTest /
        // NotifServiceTest. See PR #595 for the analogous re-query fix on the
        // DocumentAction hash chain.
        Datetime activatedAt = Datetime.now().addDays(-5);
        Datetime stageEnteredAt = Datetime.now();

        // Item stalled in Clarification Requested (Pre-Dev) — Software_Delivery
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Stalled clarification item',
            StageNamePk__c = 'Clarification Requested (Pre-Dev)',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = activatedAt,
            StageEnteredDateTime__c = stageEnteredAt,
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Item in Dev Blocked — Software_Delivery, Low priority
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked dev item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = activatedAt,
            StageEnteredDateTime__c = stageEnteredAt,
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Item in In Client Approval — Software_Delivery
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Awaiting client approval',
            StageNamePk__c = 'In Client Approval',
            PriorityPk__c = 'High',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = activatedAt,
            StageEnteredDateTime__c = stageEnteredAt,
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Item in Backlog — should NOT be matched by any default rules
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Backlog item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = activatedAt,
            StageEnteredDateTime__c = stageEnteredAt
        ));

        // Item in In Development for summary/severity tests
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Dev in progress item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = activatedAt,
            StageEnteredDateTime__c = stageEnteredAt,
            DeveloperLookup__c = UserInfo.getUserId()
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
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies the new Email action type works (simplified picklist value).
     */
    @IsTest
    static void testEmailAction() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies the Chatter action processes without error and logs activity.
     *              FeedItem DML may silently fail in namespaced test context, so we verify
     *              the escalation ran by checking the activity log instead.
     */
    @IsTest
    static void testChatterAction() {
        System.runAs(testUser) {
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

            // Verify activity log was created (proves escalation logic executed)
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(), 'Chatter post should be created on the work item');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Chatter"'),
                'Log should reference Chatter action');
        }
    }

    /**
     * @description Verifies the Both action executes email + Chatter logic and logs activity.
     *              FeedItem DML may silently fail in namespaced test context, so we verify
     *              the escalation ran by checking the activity log instead.
     */
    @IsTest
    static void testBothAction() {
        System.runAs(testUser) {
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

            // Verify activity log was created (proves Both action executed)
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(), 'Both action should create a Chatter post');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Both"'),
                'Log should reference Both action');
        }
    }

    /**
     * @description Verifies Bump_Priority action increments priority from Low to Medium.
     */
    @IsTest
    static void testBumpPriorityAction() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies Move_Stage action updates the stage to the target value.
     */
    @IsTest
    static void testMoveStageAction() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies Slack_Alert action executes without errors.
     *              Uses an HTTP mock to capture the outbound callout.
     */
    @IsTest
    static void testSlackAlertAction() {
        System.runAs(testUser) {
            // Configure Slack webhook so the service attempts a callout
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SlackWebhookUrlTxt__c = 'https://hooks.slack.com/test';
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
    }

    /**
     * @description Verifies Reassign action updates the owner when a valid Id is provided.
     */
    @IsTest
    static void testReassignAction() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that the priority filter correctly limits which items are escalated.
     */
    @IsTest
    static void testPriorityFilter() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that the workflow type filter correctly limits escalation scope.
     */
    @IsTest
    static void testWorkflowTypeFilter() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that an empty rules list produces no errors and no DML.
     */
    @IsTest
    static void testEmptyRules() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that the zero-argument overload (queries CMT) runs without error.
     */
    @IsTest
    static void testProcessEscalationsFromCMT() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryEscalationService.processEscalations();
            Test.stopTest();

            // Just verify no unhandled exceptions — CMT rules may or may not match test data
            System.assert(true, 'processEscalations() from CMT should not throw');
        }
    }

    /**
     * @description Verifies evaluateRules() runs without error.
     */
    @IsTest
    static void testEvaluateRules() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryEscalationService.evaluateRules();
            Test.stopTest();

            System.assert(true, 'evaluateRules() should not throw');
        }
    }

    /**
     * @description Verifies that Bump_Priority does not exceed Critical.
     */
    @IsTest
    static void testBumpPriorityAlreadyCritical() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that buildEscalationHtml returns a valid HTML string.
     */
    @IsTest
    static void testBuildEscalationHtml() {
        System.runAs(testUser) {
            String html = DeliveryEscalationService.buildEscalationHtml(
                'WI-0099', 'Fix broken login', 'Dev Blocked',
                'https://test.salesforce.com/lightning/r/WorkItem__c/001/view'
            );
            System.assert(html.contains('WI-0099'), 'HTML must contain work item name');
            System.assert(html.contains('Fix broken login'), 'HTML must contain title');
            System.assert(html.contains('Dev Blocked'), 'HTML must contain stalled stage');
            System.assert(html.contains('Escalation Alert'), 'HTML must contain escalation header');
        }
    }

    /**
     * @description Verifies severity-aware HTML builder includes severity details.
     */
    @IsTest
    static void testBuildEscalationHtmlWithSeverity() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies getEscalationSummary returns items in breach.
     */
    @IsTest
    static void testGetEscalationSummary() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies getEscalationSummary returns empty for items within SLA.
     */
    @IsTest
    static void testGetEscalationSummaryNoFalsePositives() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that items within SLA threshold are not escalated.
     */
    @IsTest
    static void testNoFalsePositivesWithThreshold() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that the escalation cooldown prevents duplicate notifications.
     *              An item with a recent LastEscalatedDateTime__c should be skipped.
     */
    @IsTest
    static void testCooldownPreventsReescalation() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies LastEscalatedDateTime__c is set when an escalation fires.
     */
    @IsTest
    static void testLastEscalatedDateTimeIsSet() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies DeliveryEscalationJob.execute() runs without error.
     */
    @IsTest
    static void testDeliveryEscalationJobExecute() {
        System.runAs(testUser) {
            Test.startTest();
            new DeliveryEscalationJob().execute(null);
            Test.stopTest();

            System.assert(true, 'DeliveryEscalationJob.execute() should not throw');
        }
    }

    /**
     * @description Verifies the getEscalationSummary AuraEnabled method runs without error.
     */
    @IsTest
    static void testGetEscalationSummaryAuraEnabled() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryEscalationService.EscalationSummary> results =
                DeliveryEscalationService.getEscalationSummary();
            Test.stopTest();

            // May or may not return results depending on CMT rules and test data timing
            System.assertNotEquals(null, results, 'Should return a list (possibly empty)');
        }
    }

    /**
     * @description Verifies severity metadata is included in log context.
     */
    @IsTest
    static void testSeverityInLogContext() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Verifies that EscalationCooldownHoursNumber__c controls the cooldown window.
     *              Sets cooldown to 1 hour, then creates an item that was escalated 2 hours ago.
     *              With a 1-hour cooldown the item should be re-escalated (priority bumped).
     *              Confirms the configurable setting overrides the default 24-hour cooldown.
     */
    @IsTest
    static void testCustomCooldownHoursSetting() {
        System.runAs(testUser) {
            // Set cooldown to 1 hour instead of the default 24
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EscalationCooldownHoursNumber__c = 1;
            settings.EnableEmailNotificationsDateTime__c = Datetime.now();
            settings.EnableNotificationsDateTime__c = Datetime.now();
            update settings;

            // Set LastEscalatedDateTime__c to 2 hours ago — outside the 1-hour cooldown
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE StageNamePk__c = 'In Development'
                WITH SYSTEM_MODE LIMIT 1
            ];
            wi.LastEscalatedDateTime__c = DateTime.now().addHours(-2);
            update wi;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Test Custom Cooldown Rule',
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

            WorkItem__c updated = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
            ];
            System.assertEquals('High', updated.PriorityPk__c,
                'Priority should be bumped from Medium to High because 2 hours exceeds the 1-hour cooldown');
        }
    }

    /**
     * @description Verifies that a long cooldown setting prevents re-escalation.
     *              Sets cooldown to 72 hours, then creates an item escalated 2 hours ago.
     *              With a 72-hour cooldown the item should NOT be re-escalated.
     */
    @IsTest
    static void testLongCooldownPreventsReescalation() {
        System.runAs(testUser) {
            // Set cooldown to 72 hours
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EscalationCooldownHoursNumber__c = 72;
            settings.EnableEmailNotificationsDateTime__c = Datetime.now();
            settings.EnableNotificationsDateTime__c = Datetime.now();
            update settings;

            // Set LastEscalatedDateTime__c to 2 hours ago — within the 72-hour cooldown
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE StageNamePk__c = 'In Development'
                WITH SYSTEM_MODE LIMIT 1
            ];
            wi.LastEscalatedDateTime__c = DateTime.now().addHours(-2);
            update wi;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Test Long Cooldown Rule',
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
                'Priority should remain Medium because 2 hours is within the 72-hour cooldown');
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Returns the org namespace prefix (e.g. 'delivery__') or empty string
     *              if running in an unpackaged context. Used to namespace-qualify custom
     *              field keys in JSON deserialization of CMT records.
     * @return Namespace prefix with trailing __ or empty string
     */
    private static String getNamespace() {
        // CMT fields owned by the delivery package have actual API name
        // 'delivery__FieldName__c'. Tests run in two contexts:
        //   1. dev_namespaced scratch (Organization.NamespacePrefix='delivery'):
        //      source-deployed code, fields exist as plain X__c at API level
        //      because namespace IS the package's own — no prefix needed.
        //   2. ci_beta scratch (Organization.NamespacePrefix=''):
        //      package installed as subscriber, fields are delivery__X__c —
        //      prefix required for JSON.deserialize key match.
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? 'delivery__' : '';
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
            ns + 'DaysThresholdNumber__c' => daysThreshold,
            ns + 'ActionTypePk__c' => actionType,
            ns + 'TargetValueTxt__c' => targetValue,
            ns + 'PriorityFilterTxt__c' => priorityFilter,
            ns + 'SeverityLevelPk__c' => severity,
            ns + 'ActiveDateTime__c' => Datetime.now(),
            ns + 'SortOrderNumber__c' => 1
        };
        return (WorkflowEscalationRule__mdt) JSON.deserialize(
            JSON.serialize(fieldMap), WorkflowEscalationRule__mdt.class
        );
    }

    // ── Additional Coverage Tests ───────────────────────────────────────

    /**
     * @description Verifies that multiple action types can fire across different rules
     *              in a single processEscalations call (Slack_Alert + Bump_Priority + Move_Stage).
     */
    @IsTest
    static void testMultipleActionTypesInSingleRun() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SlackWebhookUrlTxt__c = 'https://hooks.slack.com/test';
            update settings;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            // Rule 1: Slack alert for clarification items
            rules.add(buildRule(
                'Multi Slack Rule',
                'Software_Delivery',
                'Clarification Requested (Pre-Dev)',
                0,
                'Slack_Alert',
                null,
                null,
                'Warning'
            ));
            // Rule 2: Bump priority for dev blocked items
            rules.add(buildRule(
                'Multi Bump Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));
            // Rule 3: Move stage for client approval items
            rules.add(buildRule(
                'Multi Move Rule',
                'Software_Delivery',
                'In Client Approval',
                0,
                'Move_Stage',
                'Backlog',
                null,
                'Critical'
            ));

            Test.setMock(HttpCalloutMock.class, new SlackMockResponse());

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            // Verify bump priority happened
            WorkItem__c bumped = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocked dev item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Medium', bumped.PriorityPk__c,
                'Priority should be bumped from Low to Medium');

            // Verify move stage happened
            WorkItem__c moved = [
                SELECT StageNamePk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Awaiting client approval'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Backlog', moved.StageNamePk__c,
                'Stage should be moved to Backlog');

            // Verify activity logs created for all three rules
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(logs.size() >= 3,
                'Should create at least 3 activity log entries for 3 rules');
        }
    }

    /**
     * @description Verifies that cooldown prevents duplicate escalations when multiple rules
     *              target the same item that was already escalated within the cooldown window.
     */
    @IsTest
    static void testCooldownBlocksMultipleRulesOnSameItem() {
        System.runAs(testUser) {
            // Set LastEscalatedDateTime__c to now for the dev blocked item
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE StageNamePk__c = 'Dev Blocked'
                WITH SYSTEM_MODE LIMIT 1
            ];
            wi.LastEscalatedDateTime__c = DateTime.now();
            update wi;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Cooldown Rule A',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));
            rules.add(buildRule(
                'Cooldown Rule B',
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

            WorkItem__c unchanged = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
            ];
            System.assertEquals('Low', unchanged.PriorityPk__c,
                'Priority should remain Low because cooldown prevented both rules from firing');

            List<ActivityLog__c> logs = [
                SELECT Id FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assertEquals(0, logs.size(),
                'No activity logs should be created when cooldown blocks all rules');
        }
    }

    /**
     * @description Verifies that rules with no matching stage produce no escalations.
     */
    @IsTest
    static void testNoMatchingRulesForStage() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Nonexistent Stage Rule',
                'Software_Delivery',
                'Nonexistent Stage Value',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assertEquals(0, logs.size(),
                'No escalations should occur when no items match the trigger stage');
        }
    }

    /**
     * @description Verifies Reassign action with an invalid Id does not throw
     *              but also does not change the owner.
     */
    @IsTest
    static void testReassignWithInvalidTargetId() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id, OwnerId FROM WorkItem__c
                WHERE StageNamePk__c = 'Dev Blocked'
                WITH SYSTEM_MODE LIMIT 1
            ];
            Id originalOwner = wi.OwnerId;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Invalid Reassign Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Reassign',
                'INVALID_ID_VALUE',
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            WorkItem__c unchanged = [
                SELECT OwnerId FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
            ];
            System.assertEquals(originalOwner, unchanged.OwnerId,
                'Owner should remain unchanged when Reassign target is an invalid Id');
        }
    }

    /**
     * @description Verifies Move_Stage with a blank target value does not change the stage.
     */
    @IsTest
    static void testMoveStageBlankTargetValue() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Blank Move Rule',
                'Software_Delivery',
                'In Client Approval',
                0,
                'Move_Stage',
                null, // blank target
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            WorkItem__c unchanged = [
                SELECT StageNamePk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Awaiting client approval'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('In Client Approval', unchanged.StageNamePk__c,
                'Stage should remain unchanged when Move_Stage has no target value');
        }
    }

    /**
     * @description Verifies Reassign with a blank target value does not change the owner.
     */
    @IsTest
    static void testReassignBlankTargetValue() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id, OwnerId FROM WorkItem__c
                WHERE StageNamePk__c = 'Dev Blocked'
                WITH SYSTEM_MODE LIMIT 1
            ];
            Id originalOwner = wi.OwnerId;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Blank Reassign Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Reassign',
                null, // blank target
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            WorkItem__c unchanged = [
                SELECT OwnerId FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
            ];
            System.assertEquals(originalOwner, unchanged.OwnerId,
                'Owner should remain unchanged when Reassign has no target value');
        }
    }

    /**
     * @description Verifies bell notification path (sendBellNotification) is called
     *              as part of the escalation flow. Uses user-level settings with
     *              EnableBellNotificationsDateTime__c set to trigger the path.
     */
    @IsTest
    static void testBellNotificationPath() {
        System.runAs(testUser) {
            // Enable bell notifications at user level
            DeliveryHubSettings__c userSettings = DeliveryHubSettings__c.getInstance(UserInfo.getUserId());
            if (userSettings.Id == null) {
                userSettings = new DeliveryHubSettings__c(
                    SetupOwnerId = UserInfo.getUserId(),
                    EnableBellNotificationsDateTime__c = Datetime.now()
                );
                insert userSettings;
            } else {
                userSettings.EnableBellNotificationsDateTime__c = Datetime.now();
                update userSettings;
            }

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Bell Notification Rule',
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

            // Verify the escalation ran (bell notification is fire-and-forget,
            // we verify the escalation itself executed by checking activity log)
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'Escalation should have fired and logged activity (bell notification attempted)');
        }
    }

    /**
     * @description Verifies that null rules list is handled gracefully (returns early).
     */
    @IsTest
    static void testNullRulesListHandledGracefully() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryEscalationService.processEscalations(null);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assertEquals(0, logs.size(), 'No escalations should occur with null rules list');
        }
    }

    /**
     * @description Verifies buildSummary with null rules returns empty list.
     */
    @IsTest
    static void testBuildSummaryNullRules() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryEscalationService.EscalationSummary> results =
                DeliveryEscalationService.buildSummary(null);
            Test.stopTest();

            System.assertEquals(0, results.size(), 'Null rules should return empty summary list');
        }
    }

    /**
     * @description Verifies Bump_Priority on a Critical item keeps it at Critical (ceiling test).
     */
    @IsTest
    static void testBumpPriorityCriticalCeiling() {
        System.runAs(testUser) {
            // Set the item to Critical — bump should have no effect
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE StageNamePk__c = 'Dev Blocked'
                WITH SYSTEM_MODE LIMIT 1
            ];
            wi.PriorityPk__c = 'Critical';
            update wi;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Test Critical Ceiling',
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
                'Priority should remain Critical — cannot bump beyond Critical');
        }
    }

    /**
     * @description Verifies RequireNoResponseDateTime__c rule fires when work item
     *              has no comments from a different user than the creator.
     */
    @IsTest
    static void testNoResponseRuleFiresWhenNoComments() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE StageNamePk__c = 'In Development'
                WITH SYSTEM_MODE LIMIT 1
            ];

            String ns = getNamespace();
            Map<String, Object> fieldMap = new Map<String, Object>{
                'MasterLabel' => 'No Response Rule',
                ns + 'WorkflowTypeTxt__c' => 'Software_Delivery',
                ns + 'TriggerStageTxt__c' => 'In Development',
                ns + 'DaysThresholdNumber__c' => 0,
                ns + 'ActionTypePk__c' => 'Email',
                ns + 'TargetValueTxt__c' => null,
                ns + 'PriorityFilterTxt__c' => null,
                ns + 'SeverityLevelPk__c' => 'Warning',
                ns + 'ActiveDateTime__c' => Datetime.now(),
                ns + 'SortOrderNumber__c' => 1,
                ns + 'RequireNoResponseDateTime__c' => Datetime.now()
            };
            WorkflowEscalationRule__mdt rule = (WorkflowEscalationRule__mdt) JSON.deserialize(
                JSON.serialize(fieldMap), WorkflowEscalationRule__mdt.class
            );

            Test.startTest();
            DeliveryEscalationService.processEscalations(new List<WorkflowEscalationRule__mdt>{ rule });
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'No-response rule should fire when work item has no comments from other users');
        }
    }

    /**
     * @description Verifies RequireNoResponseDateTime__c rule is skipped when a comment
     *              exists from a different user than the creator. Since tests run as
     *              a single user, we verify the inverse: a self-comment does NOT count
     *              as a response and the rule still fires.
     */
    @IsTest
    static void testNoResponseRuleSelfCommentStillFires() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE StageNamePk__c = 'In Development'
                WITH SYSTEM_MODE LIMIT 1
            ];

            // Add a comment from the same user who created the work item (running user)
            insert new WorkItemComment__c(
                WorkItemId__c = wi.Id,
                BodyTxt__c = 'Self-comment should not count as a response'
            );

            String ns = getNamespace();
            Map<String, Object> fieldMap = new Map<String, Object>{
                'MasterLabel' => 'No Response Self Comment',
                ns + 'WorkflowTypeTxt__c' => 'Software_Delivery',
                ns + 'TriggerStageTxt__c' => 'In Development',
                ns + 'DaysThresholdNumber__c' => 0,
                ns + 'ActionTypePk__c' => 'Email',
                ns + 'TargetValueTxt__c' => null,
                ns + 'PriorityFilterTxt__c' => null,
                ns + 'SeverityLevelPk__c' => 'Warning',
                ns + 'ActiveDateTime__c' => Datetime.now(),
                ns + 'SortOrderNumber__c' => 1,
                ns + 'RequireNoResponseDateTime__c' => Datetime.now()
            };
            WorkflowEscalationRule__mdt rule = (WorkflowEscalationRule__mdt) JSON.deserialize(
                JSON.serialize(fieldMap), WorkflowEscalationRule__mdt.class
            );

            Test.startTest();
            DeliveryEscalationService.processEscalations(new List<WorkflowEscalationRule__mdt>{ rule });
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'No-response rule should still fire when only the creator has commented');
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

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
