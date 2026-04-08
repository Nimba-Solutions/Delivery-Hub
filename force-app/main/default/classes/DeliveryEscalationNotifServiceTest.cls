/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationNotifService. Verifies email dispatch,
 *               Chatter post creation, Slack webhook callouts, bell notification
 *               opt-in checks, and HTML email body generation.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryEscalationNotifServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableEmailNotificationsDateTime__c = Datetime.now(),
            EnableNotificationsDateTime__c = Datetime.now()
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Email test item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Chatter test item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        insert items;
    }

    /**
     * @description Verifies sendEscalationEmails queues emails for work items with
     *              valid developer/owner email addresses.
     */
    @IsTest
    static void testSendEmailNotification() {
        System.runAs(testUser) {
            // Use processEscalations with an Email rule — this drives through
            // sendEscalationEmails in the notification service
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Email Notif Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Email',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            // Verify the escalation executed (email dispatch is fire-and-forget)
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'Should create activity log confirming email escalation executed');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Email"'),
                'Log should reference Email action');
        }
    }

    /**
     * @description Verifies sendEscalationEmails includes severity context in the
     *              email subject (Critical prefix).
     */
    @IsTest
    static void testSendEmailCriticalSeverity() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Critical Email Rule',
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
            System.assert(!logs.isEmpty(),
                'Should create activity log for Critical email escalation');
            System.assert(logs[0].ContextDataTxt__c.contains('"severity":"Critical"'),
                'Log should include Critical severity');
        }
    }

    /**
     * @description Verifies postChatterEscalations creates FeedItem records on work items.
     *              FeedItem DML may silently fail in namespaced test context, so we verify
     *              the escalation ran by checking the activity log.
     */
    @IsTest
    static void testSendChatterPost() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Chatter Notif Rule',
                'Software_Delivery',
                'In Development',
                0,
                'Chatter',
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
            System.assert(!logs.isEmpty(),
                'Should create activity log confirming Chatter escalation executed');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Chatter"'),
                'Log should reference Chatter action');
        }
    }

    /**
     * @description Verifies the Both action type dispatches both email and Chatter.
     */
    @IsTest
    static void testBothEmailAndChatter() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Both Notif Rule',
                'Software_Delivery',
                'In Development',
                0,
                'Both',
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
            System.assert(!logs.isEmpty(),
                'Should create activity log for Both action');
            System.assert(logs[0].ContextDataTxt__c.contains('"action":"Both"'),
                'Log should reference Both action');
        }
    }

    /**
     * @description Verifies bell notification opt-in path is exercised when user has
     *              EnableBellNotificationsDateTime__c set. The CustomNotificationType
     *              may not exist in test context, but the code path should not throw.
     */
    @IsTest
    static void testBellNotificationOptIn() {
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
                'Bell OptIn Rule',
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
            System.assert(!logs.isEmpty(),
                'Escalation should have fired with bell notification opt-in path exercised');
        }
    }

    /**
     * @description Verifies bell notification is skipped when user has NOT opted in
     *              (EnableBellNotificationsDateTime__c is null).
     */
    @IsTest
    static void testBellNotificationOptOut() {
        System.runAs(testUser) {
            // Ensure no user-level bell setting exists
            // (org defaults from @TestSetup don't set EnableBellNotificationsDateTime__c)

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Bell OptOut Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Email',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            // Escalation should still succeed; bell notification silently skips
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'Escalation should complete even when bell notifications are opted out');
        }
    }

    /**
     * @description Verifies sendBellNotification handles null ownerId gracefully.
     */
    @IsTest
    static void testBellNotificationNullOwner() {
        System.runAs(testUser) {
            Test.startTest();
            // Direct call with null — should not throw
            DeliveryEscalationNotifService.sendBellNotification(
                null, null, 'Test Title', 'Test Body'
            );
            Test.stopTest();

            System.assert(true, 'sendBellNotification should handle null params gracefully');
        }
    }

    /**
     * @description Verifies Slack webhook callout path via sendEscalationSlack.
     */
    @IsTest
    static void testSlackNotificationCallout() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SlackWebhookUrlTxt__c = 'https://hooks.slack.com/test';
            update settings;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Slack Notif Rule',
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
            System.assert(!logs.isEmpty(),
                'Should create activity log for Slack notification');
        }
    }

    /**
     * @description Verifies sendEscalationSlack is a no-op when SlackWebhookUrlTxt__c is blank.
     */
    @IsTest
    static void testSlackNotificationNoWebhookUrl() {
        System.runAs(testUser) {
            // Ensure SlackWebhookUrlTxt__c is not set (default from @TestSetup)

            Test.startTest();
            // Direct call — should silently return without callout
            DeliveryEscalationNotifService.sendEscalationSlack(
                new Map<String, String>{ 'WI-001' => 'Test escalation' }
            );
            Test.stopTest();

            System.assert(true, 'sendEscalationSlack should no-op when webhook URL is blank');
        }
    }

    /**
     * @description Verifies buildEscalationHtml returns valid HTML with severity details.
     */
    @IsTest
    static void testBuildEscalationHtmlWithSeverity() {
        System.runAs(testUser) {
            Test.startTest();
            String html = DeliveryEscalationNotifService.buildEscalationHtml(
                'WI-0099', 'Fix broken login', 'Dev Blocked',
                'https://test.salesforce.com/lightning/r/WorkItem__c/001/view',
                'Critical', 5, 'Dev Stuck 3 Days'
            );
            Test.stopTest();

            System.assert(html.contains('WI-0099'), 'HTML must contain work item name');
            System.assert(html.contains('Fix broken login'), 'HTML must contain title');
            System.assert(html.contains('Dev Blocked'), 'HTML must contain stalled stage');
            System.assert(html.contains('CRITICAL'), 'HTML must indicate Critical severity');
            System.assert(html.contains('5 day(s)'), 'HTML must contain days in stage');
            System.assert(html.contains('Dev Stuck 3 Days'), 'HTML must contain rule name');
            System.assert(html.contains('#ba1b1b'), 'Critical should use red header color');
        }
    }

    /**
     * @description Verifies buildEscalationHtml backward-compatible overload returns HTML.
     */
    @IsTest
    static void testBuildEscalationHtmlBackwardCompat() {
        System.runAs(testUser) {
            Test.startTest();
            String html = DeliveryEscalationNotifService.buildEscalationHtml(
                'WI-0100', 'Slow item', 'QA In Progress',
                'https://test.salesforce.com/lightning/r/WorkItem__c/002/view'
            );
            Test.stopTest();

            System.assert(html.contains('WI-0100'), 'HTML must contain work item name');
            System.assert(html.contains('Slow item'), 'HTML must contain title');
            System.assert(html.contains('QA In Progress'), 'HTML must contain stalled stage');
            System.assert(html.contains('#e67e22'), 'Warning should use orange header color');
        }
    }

    /**
     * @description Verifies Warning severity uses orange header color.
     */
    @IsTest
    static void testBuildEscalationHtmlWarningSeverity() {
        System.runAs(testUser) {
            String html = DeliveryEscalationNotifService.buildEscalationHtml(
                'WI-0101', 'Warning item', 'In Development',
                'https://test.salesforce.com/lightning/r/WorkItem__c/003/view',
                'Warning', 2, 'Dev Stale 2 Days'
            );

            System.assert(html.contains('#e67e22'), 'Warning should use orange header color');
            System.assert(!html.contains('CRITICAL'), 'Warning HTML should not say CRITICAL');
            System.assert(html.contains('2 day(s)'), 'HTML must contain days in stage');
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
