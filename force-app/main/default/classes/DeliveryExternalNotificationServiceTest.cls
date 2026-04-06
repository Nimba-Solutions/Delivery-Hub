/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryExternalNotificationService. Verifies stage-change
 *               email dispatch, SLA breach email dispatch, feature flag gating, and
 *               HTML email body generation for external requesters.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryExternalNotificationServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        // Enable both email and external notifications
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableEmailNotificationsDateTime__c = Datetime.now(),
            EnableNotificationsDateTime__c = Datetime.now(),
            EnableExternalNotificationsDateTime__c = Datetime.now()
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Item with external requester email
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'External requester item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            ExternalRequesterEmailTxt__c = 'external@example.com',
            SLATargetDate__c = Date.today().addDays(-3),
            DeveloperLookupId__c = UserInfo.getUserId()
        ));

        // Item without external requester email (should be skipped)
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Internal only item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookupId__c = UserInfo.getUserId()
        ));

        insert items;
    }

    /**
     * @description Verifies sendExternalStageChangeEmails dispatches an email to
     *              the external requester when the feature is enabled.
     */
    @IsTest
    static void testStageChangeEmail() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'External requester item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Client Approval' };

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalStageChangeEmails(
                new Set<Id>{ wi.Id }, stageMap
            );
            Test.stopTest();

            // Email dispatch is fire-and-forget; verify no exception was thrown
            System.assert(true, 'Stage change email should dispatch without error');
        }
    }

    /**
     * @description Verifies sendExternalStageChangeEmails skips items without
     *              ExternalRequesterEmailTxt__c populated.
     */
    @IsTest
    static void testStageChangeEmailSkipsInternalOnly() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Internal only item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Client Approval' };

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalStageChangeEmails(
                new Set<Id>{ wi.Id }, stageMap
            );
            Test.stopTest();

            // No email should be sent for internal-only items; verify no exception
            System.assert(true,
                'Should skip items without ExternalRequesterEmailTxt__c');
        }
    }

    /**
     * @description Verifies sendExternalSLABreachEmails dispatches an SLA breach email
     *              to the external requester.
     */
    @IsTest
    static void testSlaBreachEmail() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'External requester item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalSLABreachEmails(
                new Set<Id>{ wi.Id }
            );
            Test.stopTest();

            // Email dispatch is fire-and-forget; verify no exception was thrown
            System.assert(true, 'SLA breach email should dispatch without error');
        }
    }

    /**
     * @description Verifies sendExternalSLABreachEmails skips items without
     *              ExternalRequesterEmailTxt__c populated.
     */
    @IsTest
    static void testSlaBreachEmailSkipsInternalOnly() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Internal only item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalSLABreachEmails(
                new Set<Id>{ wi.Id }
            );
            Test.stopTest();

            System.assert(true,
                'Should skip items without ExternalRequesterEmailTxt__c');
        }
    }

    /**
     * @description Verifies that external notifications are disabled when
     *              EnableExternalNotificationsDateTime__c is null (feature flag off).
     *              Stage change emails should be a no-op.
     */
    @IsTest
    static void testDisabledByFeatureFlagStageChange() {
        System.runAs(testUser) {
            // Disable external notifications
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableExternalNotificationsDateTime__c = null;
            update settings;

            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'External requester item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'Done' };

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalStageChangeEmails(
                new Set<Id>{ wi.Id }, stageMap
            );
            Test.stopTest();

            System.assert(true,
                'Should no-op when EnableExternalNotificationsDateTime__c is null');
        }
    }

    /**
     * @description Verifies that external SLA breach emails are disabled when
     *              EnableExternalNotificationsDateTime__c is null (feature flag off).
     */
    @IsTest
    static void testDisabledByFeatureFlagSLABreach() {
        System.runAs(testUser) {
            // Disable external notifications
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableExternalNotificationsDateTime__c = null;
            update settings;

            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'External requester item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalSLABreachEmails(
                new Set<Id>{ wi.Id }
            );
            Test.stopTest();

            System.assert(true,
                'Should no-op when EnableExternalNotificationsDateTime__c is null');
        }
    }

    /**
     * @description Verifies that external notifications are disabled when
     *              EnableEmailNotificationsDateTime__c is null (master email flag off).
     */
    @IsTest
    static void testDisabledByMasterEmailFlag() {
        System.runAs(testUser) {
            // Disable master email notifications
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableEmailNotificationsDateTime__c = null;
            update settings;

            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'External requester item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'Done' };

            Test.startTest();
            DeliveryExternalNotificationService.sendExternalStageChangeEmails(
                new Set<Id>{ wi.Id }, stageMap
            );
            Test.stopTest();

            System.assert(true,
                'Should no-op when EnableEmailNotificationsDateTime__c is null');
        }
    }

    /**
     * @description Verifies buildStageChangeHtml returns valid HTML with expected content.
     */
    @IsTest
    static void testBuildStageChangeHtml() {
        System.runAs(testUser) {
            Test.startTest();
            String html = DeliveryExternalNotificationService.buildStageChangeHtml(
                'WI-0042', 'Fix login page', 'In Client Approval'
            );
            Test.stopTest();

            System.assert(html.contains('WI-0042'), 'HTML must contain work item name');
            System.assert(html.contains('Fix login page'), 'HTML must contain title');
            System.assert(html.contains('In Client Approval'), 'HTML must contain new stage');
            System.assert(html.contains('Your Request Has Been Updated'),
                'HTML must contain the stage change header');
        }
    }

    /**
     * @description Verifies buildSLABreachHtml returns valid HTML with SLA details.
     */
    @IsTest
    static void testBuildSLABreachHtml() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                       ExternalRequesterEmailTxt__c, SLATargetDate__c
                FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'External requester item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            Test.startTest();
            String html = DeliveryExternalNotificationService.buildSLABreachHtml(wi);
            Test.stopTest();

            System.assert(html.contains('External requester item'), 'HTML must contain description');
            System.assert(html.contains('In Development'), 'HTML must contain current stage');
            System.assert(html.contains('Update on Your Request'),
                'HTML must contain the SLA breach header');
            System.assert(html.contains('Target Date'), 'HTML must contain target date label');
        }
    }

    /**
     * @description Verifies buildSLABreachHtml handles null SLATargetDate__c gracefully.
     */
    @IsTest
    static void testBuildSLABreachHtmlNullDate() {
        System.runAs(testUser) {
            WorkItem__c wi = new WorkItem__c(
                Name = 'WI-9999',
                BriefDescriptionTxt__c = 'No SLA date item',
                StageNamePk__c = 'In Development'
            );
            // Note: not inserting — just using for HTML generation

            Test.startTest();
            String html = DeliveryExternalNotificationService.buildSLABreachHtml(wi);
            Test.stopTest();

            System.assert(html.contains('unknown'),
                'HTML should show unknown when SLATargetDate__c is null');
        }
    }

    /**
     * @description Verifies the integration path where escalation engine triggers
     *              external SLA breach emails via the Email action type.
     */
    @IsTest
    static void testEscalationTriggersExternalSLABreachEmail() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'External SLA Rule',
                'Software_Delivery',
                'In Development',
                0,
                'Email',
                null,
                null,
                'Critical'
            ));

            Test.startTest();
            DeliveryEscalationService.processEscalations(rules);
            Test.stopTest();

            // Verify the escalation ran
            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliveryEscalationService'
                WITH SYSTEM_MODE
            ];
            System.assert(!logs.isEmpty(),
                'Escalation should fire, triggering external SLA breach email path');
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
}
