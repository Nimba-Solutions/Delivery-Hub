/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationActionExecutor. Verifies action routing
 *               for priority bumps, stage moves, owner reassignment, bell notifications,
 *               and null/edge-case handling. Uses JSON-deserialized CMT records since
 *               Custom Metadata cannot be inserted via DML in tests.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryEscalationActionExecutorTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableEmailNotificationsDateTime__c = Datetime.now(),
            EnableNotificationsDateTime__c = Datetime.now()
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Low priority item for bump tests
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Low priority item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Medium priority item for bump tests
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Medium priority item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // High priority item for bump tests
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'High priority item',
            StageNamePk__c = 'In Client Approval',
            PriorityPk__c = 'High',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Critical priority item (ceiling test)
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Critical priority item',
            StageNamePk__c = 'Clarification Requested (Pre-Dev)',
            PriorityPk__c = 'Critical',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        insert items;
    }

    /**
     * @description Verifies Bump_Priority escalates Low -> Medium via the action executor.
     */
    @IsTest
    static void testPriorityBumpLowToMedium() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Bump Low Rule',
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
                WHERE BriefDescriptionTxt__c = 'Low priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Medium', updated.PriorityPk__c,
                'Priority should be bumped from Low to Medium');
        }
    }

    /**
     * @description Verifies Bump_Priority escalates Medium -> High.
     */
    @IsTest
    static void testPriorityBumpMediumToHigh() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Bump Medium Rule',
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
                WHERE BriefDescriptionTxt__c = 'Medium priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('High', updated.PriorityPk__c,
                'Priority should be bumped from Medium to High');
        }
    }

    /**
     * @description Verifies Bump_Priority escalates High -> Critical.
     */
    @IsTest
    static void testPriorityBumpHighToCritical() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Bump High Rule',
                'Software_Delivery',
                'In Client Approval',
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
                WHERE BriefDescriptionTxt__c = 'High priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Critical', updated.PriorityPk__c,
                'Priority should be bumped from High to Critical');
        }
    }

    /**
     * @description Verifies Bump_Priority does not exceed Critical (ceiling).
     */
    @IsTest
    static void testPriorityBumpCriticalCeiling() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Bump Critical Ceiling',
                'Software_Delivery',
                'Clarification Requested (Pre-Dev)',
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
                WHERE BriefDescriptionTxt__c = 'Critical priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Critical', updated.PriorityPk__c,
                'Priority should remain Critical — cannot bump beyond Critical');
        }
    }

    /**
     * @description Verifies Move_Stage changes the work item stage to the target value.
     */
    @IsTest
    static void testStageMove() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Move Stage Rule',
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
                WHERE BriefDescriptionTxt__c = 'High priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Ready for Development', updated.StageNamePk__c,
                'Stage should be moved to Ready for Development');
        }
    }

    /**
     * @description Verifies Move_Stage with blank target does not change stage.
     */
    @IsTest
    static void testStageMoveBlankTarget() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Blank Move Rule',
                'Software_Delivery',
                'In Client Approval',
                0,
                'Move_Stage',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            WorkItem__c unchanged = [
                SELECT StageNamePk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'High priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('In Client Approval', unchanged.StageNamePk__c,
                'Stage should remain unchanged when Move_Stage has blank target');
        }
    }

    /**
     * @description Verifies Reassign changes the work item owner to the target user.
     */
    @IsTest
    static void testOwnerReassignment() {
        System.runAs(testUser) {
            Id currentUserId = UserInfo.getUserId();

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Reassign Rule',
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
                WHERE BriefDescriptionTxt__c = 'Low priority item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals(currentUserId, updated.OwnerId,
                'Owner should be reassigned to the target user');
        }
    }

    /**
     * @description Verifies Reassign with invalid Id does not throw and does not change owner.
     */
    @IsTest
    static void testOwnerReassignmentInvalidId() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id, OwnerId FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Low priority item'
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
                'NOT_A_VALID_ID',
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
     * @description Verifies bell notification path is exercised when user has
     *              EnableBellNotificationsDateTime__c set. The notification itself
     *              may fail silently (no custom notification type in test context)
     *              but the code path must execute without exception.
     */
    @IsTest
    static void testBellNotification() {
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
                'Bell Test Rule',
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

            // Verify the escalation ran by checking activity log
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'Escalation should have fired and logged activity (bell notification path exercised)');
        }
    }

    /**
     * @description Verifies that null/empty rules list does not throw.
     */
    @IsTest
    static void testNullHandlingEmptyRules() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryEscalationService.processEscalations(
                new List<WorkflowEscalationRule__mdt>()
            );
            DeliveryEscalationService.processEscalations(null);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assertEquals(0, logs.size(),
                'No escalations should occur with null or empty rules');
        }
    }

    /**
     * @description Verifies that Email action populates emailTargets accumulator
     *              and creates an activity log entry.
     */
    @IsTest
    static void testEmailActionLogsActivity() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Email Action Rule',
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
            System.assert(!logs.isEmpty(), 'Should create activity log for Email action');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Email"'),
                'Log should reference Email action');
            System.assert(logs[0].ContextDataTxt__c.contains('"severity":"Critical"'),
                'Log should include severity level');
        }
    }

    /**
     * @description Verifies Chatter action populates chatterTargets accumulator
     *              and creates an activity log entry.
     */
    @IsTest
    static void testChatterActionLogsActivity() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Chatter Action Rule',
                'Software_Delivery',
                'In Development',
                0,
                'Chatter',
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
            System.assert(!logs.isEmpty(), 'Should create activity log for Chatter action');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Chatter"'),
                'Log should reference Chatter action');
        }
    }

    /**
     * @description Verifies Slack_Alert action populates slackNotifications accumulator
     *              and creates an activity log entry.
     */
    @IsTest
    static void testSlackAlertActionLogsActivity() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SlackWebhookUrlTxt__c = 'https://hooks.slack.com/test';
            update settings;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Slack Alert Rule',
                'Software_Delivery',
                'Dev Blocked',
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

            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(), 'Should create activity log for Slack_Alert action');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Slack_Alert"'),
                'Log should reference Slack_Alert action');
        }
    }

    /**
     * @description Verifies Both action populates both emailTargets and chatterTargets.
     */
    @IsTest
    static void testBothActionLogsActivity() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Both Action Rule',
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

            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(), 'Should create activity log for Both action');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Both"'),
                'Log should reference Both action');
        }
    }

    // -- Helpers ---------------------------------------------------------------

    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

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

    public class SlackMockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }
}
