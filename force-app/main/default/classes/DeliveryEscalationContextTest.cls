/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEscalationContext. Protects the 9-field
 *               constructor against silent field drift — if someone reorders
 *               the ctor params or drops an accumulator, these tests fail
 *               before the escalation pipeline silently loses writes.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
private class DeliveryEscalationContextTest {

    @IsTest
    static void testAllFieldsAssigned() {
        WorkflowEscalationRule__mdt rule = new WorkflowEscalationRule__mdt(
            DeveloperName = 'TestRule'
        );
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'ctx-item',
            StageNamePk__c = 'Backlog'
        );
        insert wi;

        Map<Id, WorkItem__c> itemsToUpdate = new Map<Id, WorkItem__c>{ wi.Id => wi };
        Map<Id, DeliveryEscalationService.EscalationDetail> emailTargets =
            new Map<Id, DeliveryEscalationService.EscalationDetail>();
        Map<Id, String> chatterTargets = new Map<Id, String>{ wi.Id => 'chat' };
        Map<String, String> slackNotifications = new Map<String, String>{ 'WI-1' => 'slack' };
        List<ActivityLog__c> logEntries = new List<ActivityLog__c>{
            new ActivityLog__c(DescriptionTxt__c = 'test-log')
        };

        DeliveryEscalationContext ctx = new DeliveryEscalationContext(
            rule, wi, 7, 'Critical',
            itemsToUpdate, emailTargets, chatterTargets, slackNotifications, logEntries
        );

        System.assertEquals(rule, ctx.rule, 'Rule should be set');
        System.assertEquals(wi.Id, ctx.workItem.Id, 'WorkItem should be set');
        System.assertEquals(7, ctx.daysInStage, 'Days in stage should be set');
        System.assertEquals('Critical', ctx.severity, 'Severity should be set');
        System.assertEquals(itemsToUpdate, ctx.itemsToUpdate, 'itemsToUpdate accumulator should be set by reference');
        System.assertEquals(emailTargets, ctx.emailTargets, 'emailTargets accumulator should be set by reference');
        System.assertEquals(chatterTargets, ctx.chatterTargets, 'chatterTargets accumulator should be set by reference');
        System.assertEquals(slackNotifications, ctx.slackNotifications, 'slackNotifications accumulator should be set by reference');
        System.assertEquals(logEntries, ctx.logEntries, 'logEntries accumulator should be set by reference');
    }

    @IsTest
    static void testAccumulatorsAreReferences() {
        // The whole point of the context is that escalation handlers share
        // accumulator state. Mutating via the ctx should be visible to the
        // caller that passed the collections in.
        WorkflowEscalationRule__mdt rule = new WorkflowEscalationRule__mdt(DeveloperName = 'R');
        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'x', StageNamePk__c = 'Backlog');
        insert wi;

        Map<Id, String> chatterTargets = new Map<Id, String>();
        DeliveryEscalationContext ctx = new DeliveryEscalationContext(
            rule, wi, 3, 'Warning',
            new Map<Id, WorkItem__c>(),
            new Map<Id, DeliveryEscalationService.EscalationDetail>(),
            chatterTargets,
            new Map<String, String>(),
            new List<ActivityLog__c>()
        );

        ctx.chatterTargets.put(wi.Id, 'via-ctx');

        System.assertEquals('via-ctx', chatterTargets.get(wi.Id),
            'Mutation via ctx.chatterTargets must reach the original map (accumulator aliasing)');
    }

    @IsTest
    static void testAcceptsNullAccumulators() {
        // DH has plenty of call sites that only fill a subset of the
        // accumulators. The ctor itself shouldn't reject null.
        WorkflowEscalationRule__mdt rule = new WorkflowEscalationRule__mdt(DeveloperName = 'R');
        DeliveryEscalationContext ctx = new DeliveryEscalationContext(
            rule, null, null, null, null, null, null, null, null
        );

        System.assertNotEquals(null, ctx, 'Constructor should tolerate null payload members');
        System.assertEquals(rule, ctx.rule, 'Rule should still be populated');
        System.assertEquals(null, ctx.workItem, 'Null workItem should pass through');
        System.assertEquals(null, ctx.severity, 'Null severity should pass through');
    }

    @IsTest
    static void testSeverityIsIndependentOfDays() {
        // Severity is a derived field the caller resolves; the context must
        // store whatever it's told — it must NOT infer severity from
        // daysInStage. Protects against someone "helpfully" adding that
        // logic in the ctor and making rule-driven overrides stop working.
        WorkflowEscalationRule__mdt rule = new WorkflowEscalationRule__mdt(DeveloperName = 'R');
        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'y', StageNamePk__c = 'Backlog');
        insert wi;

        DeliveryEscalationContext lowDaysCritical = new DeliveryEscalationContext(
            rule, wi, 1, 'Critical',
            new Map<Id, WorkItem__c>(),
            new Map<Id, DeliveryEscalationService.EscalationDetail>(),
            new Map<Id, String>(),
            new Map<String, String>(),
            new List<ActivityLog__c>()
        );
        DeliveryEscalationContext highDaysWarning = new DeliveryEscalationContext(
            rule, wi, 99, 'Warning',
            new Map<Id, WorkItem__c>(),
            new Map<Id, DeliveryEscalationService.EscalationDetail>(),
            new Map<Id, String>(),
            new Map<String, String>(),
            new List<ActivityLog__c>()
        );

        System.assertEquals('Critical', lowDaysCritical.severity, '1-day Critical should stay Critical');
        System.assertEquals(1, lowDaysCritical.daysInStage, 'daysInStage should not be altered by severity');
        System.assertEquals('Warning', highDaysWarning.severity, '99-day Warning should stay Warning');
        System.assertEquals(99, highDaysWarning.daysInStage, 'daysInStage should not be altered by severity');
    }
}
