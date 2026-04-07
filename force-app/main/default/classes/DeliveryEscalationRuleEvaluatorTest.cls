/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationRuleEvaluator. Verifies rule matching,
 *               cooldown enforcement, workflow type filtering, no-response detection,
 *               and summary building. Uses JSON-deserialized CMT records since Custom
 *               Metadata cannot be inserted via DML in tests.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryEscalationRuleEvaluatorTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableEmailNotificationsDateTime__c = Datetime.now(),
            EnableNotificationsDateTime__c = Datetime.now(),
            EscalationCooldownHoursNumber__c = 24
        );

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Software_Delivery item in Dev Blocked
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked dev item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Software_Delivery item in In Development
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Dev in progress item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        // Item in Backlog — should NOT be matched
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Backlog safe item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery',
            ActivatedDateTime__c = Datetime.now().addDays(-5)
        ));

        // Loan_Approval item in Dev Blocked (for workflow type filter test)
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Loan approval blocked item',
            StageNamePk__c = 'Dev Blocked',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Loan_Approval',
            ActivatedDateTime__c = Datetime.now().addDays(-5),
            DeveloperLookup__c = UserInfo.getUserId()
        ));

        insert items;
    }

    /**
     * @description Verifies that a matching rule triggers escalation on a work item
     *              in the correct stage and workflow type.
     */
    @IsTest
    static void testEvaluateMatchingRule() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Matching Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationRuleEvaluator.processRules(rules);
            Test.stopTest();

            WorkItem__c updated = [
                SELECT PriorityPk__c, LastEscalatedDateTime__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocked dev item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Medium', updated.PriorityPk__c,
                'Priority should be bumped from Low to Medium');
            System.assertNotEquals(null, updated.LastEscalatedDateTime__c,
                'LastEscalatedDateTime__c should be set after escalation');
        }
    }

    /**
     * @description Verifies that items recently escalated within the cooldown window
     *              are skipped by the evaluator.
     */
    @IsTest
    static void testCooldownRespected() {
        System.runAs(testUser) {
            // Set LastEscalatedDateTime__c to now — within 24h default cooldown
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Dev in progress item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            wi.LastEscalatedDateTime__c = DateTime.now();
            update wi;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Cooldown Test Rule',
                'Software_Delivery',
                'In Development',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationRuleEvaluator.processRules(rules);
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
     * @description Verifies that cooldown expires and allows re-escalation when
     *              enough time has passed.
     */
    @IsTest
    static void testCooldownExpiresAllowsReescalation() {
        System.runAs(testUser) {
            // Set cooldown to 1 hour and last escalated 2 hours ago
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EscalationCooldownHoursNumber__c = 1;
            update settings;

            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Dev in progress item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            wi.LastEscalatedDateTime__c = DateTime.now().addHours(-2);
            update wi;

            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Expired Cooldown Rule',
                'Software_Delivery',
                'In Development',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationRuleEvaluator.processRules(rules);
            Test.stopTest();

            WorkItem__c updated = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
            ];
            System.assertEquals('High', updated.PriorityPk__c,
                'Priority should be bumped because 2 hours exceeds the 1-hour cooldown');
        }
    }

    /**
     * @description Verifies that a rule with a mismatched WorkflowTypeTxt__c does
     *              not escalate items belonging to a different workflow type.
     */
    @IsTest
    static void testNoMatchWhenWrongWorkflowType() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Wrong Type Rule',
                'Loan_Approval',
                'Dev Blocked',
                0,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationRuleEvaluator.processRules(rules);
            Test.stopTest();

            // The Software_Delivery item should remain untouched
            WorkItem__c sdItem = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocked dev item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Low', sdItem.PriorityPk__c,
                'Software_Delivery item should not be escalated by a Loan_Approval rule');

            // The Loan_Approval item SHOULD be escalated
            WorkItem__c laItem = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Loan approval blocked item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('High', laItem.PriorityPk__c,
                'Loan_Approval item should be bumped from Medium to High');
        }
    }

    /**
     * @description Verifies RequireNoResponseDateTime__c rule fires when work item
     *              has no comments from a different user than the creator.
     */
    @IsTest
    static void testNoResponseRuleFiresWhenNoComments() {
        System.runAs(testUser) {
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
            DeliveryEscalationRuleEvaluator.processRules(
                new List<WorkflowEscalationRule__mdt>{ rule }
            );
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
     * @description Verifies RequireNoResponseDateTime__c rule still fires when only
     *              the creator has commented (self-comments do not count as a response).
     *              Since tests run as a single user, the creator == commenter.
     */
    @IsTest
    static void testNoResponseRuleSelfCommentStillFires() {
        System.runAs(testUser) {
            WorkItem__c wi = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Dev in progress item'
                WITH SYSTEM_MODE LIMIT 1
            ];

            // Add a comment from the same user who created the work item
            insert new WorkItemComment__c(
                WorkItemLookup__c = wi.Id,
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
            DeliveryEscalationRuleEvaluator.processRules(
                new List<WorkflowEscalationRule__mdt>{ rule }
            );
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

    /**
     * @description Verifies that items within the days threshold are not escalated.
     */
    @IsTest
    static void testThresholdPreventsEscalation() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'High Threshold Rule',
                'Software_Delivery',
                'Dev Blocked',
                999,
                'Bump_Priority',
                null,
                null,
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationRuleEvaluator.processRules(rules);
            Test.stopTest();

            WorkItem__c unchanged = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocked dev item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Low', unchanged.PriorityPk__c,
                'Priority should remain Low because item has not breached the 999-day threshold');
        }
    }

    /**
     * @description Verifies queryActiveRules returns results without error.
     */
    @IsTest
    static void testQueryActiveRules() {
        System.runAs(testUser) {
            Test.startTest();
            List<WorkflowEscalationRule__mdt> rules =
                DeliveryEscalationRuleEvaluator.queryActiveRules();
            Test.stopTest();

            // May or may not have CMT records; just verify no exception
            System.assertNotEquals(null, rules, 'Should return a list (possibly empty)');
        }
    }

    /**
     * @description Verifies buildSummary returns items matching the rule criteria.
     */
    @IsTest
    static void testBuildSummary() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Summary Rule',
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
                DeliveryEscalationRuleEvaluator.buildSummary(rules);
            Test.stopTest();

            System.assert(!summaries.isEmpty(), 'Should return at least one breached item');
            DeliveryEscalationService.EscalationSummary first = summaries[0];
            System.assertNotEquals(null, first.workItemId, 'workItemId should be populated');
            System.assertEquals('Summary Rule', first.ruleName, 'ruleName should match');
            System.assertEquals('Critical', first.severityLevel, 'severityLevel should be Critical');
            System.assertEquals('Dev Blocked', first.stageName, 'stageName should be Dev Blocked');
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
                DeliveryEscalationRuleEvaluator.buildSummary(null);
            Test.stopTest();

            System.assertEquals(0, results.size(), 'Null rules should return empty summary list');
        }
    }

    /**
     * @description Verifies that rules targeting a nonexistent stage produce no escalations.
     */
    @IsTest
    static void testNoMatchingStageProducesNoEscalations() {
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
            DeliveryEscalationRuleEvaluator.processRules(rules);
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
     * @description Verifies calculateDaysInStage uses StageEnteredDateTime__c when available.
     */
    @IsTest
    static void testCalculateDaysInStage() {
        System.runAs(testUser) {
            WorkItem__c wi = new WorkItem__c(
                StageEnteredDateTime__c = Datetime.now().addDays(-7)
            );

            Test.startTest();
            Integer days = DeliveryEscalationRuleEvaluator.calculateDaysInStage(wi, Date.today());
            Test.stopTest();

            System.assertEquals(7, days,
                'Should return 7 days based on StageEnteredDateTime__c');
        }
    }

    /**
     * @description Verifies the priority filter correctly limits which items are escalated.
     */
    @IsTest
    static void testPriorityFilterExcludesNonMatching() {
        System.runAs(testUser) {
            List<WorkflowEscalationRule__mdt> rules = new List<WorkflowEscalationRule__mdt>();
            rules.add(buildRule(
                'Priority Filter Rule',
                'Software_Delivery',
                'Dev Blocked',
                0,
                'Bump_Priority',
                null,
                'High', // Only High priority — our Dev Blocked item is Low, should NOT match
                'Warning'
            ));

            Test.startTest();
            DeliveryEscalationRuleEvaluator.processRules(rules);
            Test.stopTest();

            WorkItem__c unchanged = [
                SELECT PriorityPk__c FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocked dev item'
                WITH SYSTEM_MODE LIMIT 1
            ];
            System.assertEquals('Low', unchanged.PriorityPk__c,
                'Priority should remain Low because the High filter excluded this item');
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
