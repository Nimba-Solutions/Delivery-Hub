/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryTemplateManagerController.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@isTest
private class DeliveryTemplateManagerControllerTest {

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.runAfterLogic = false;

        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Active Template',
                DetailsTxt__c = 'An active template',
                PriorityPk__c = 'High',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = null,
                EstimatedHoursNumber__c = 4,
                DeveloperDaysSizeNumber__c = 1
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Inactive Template',
                DetailsTxt__c = 'An inactive template',
                PriorityPk__c = 'Low',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = null,
                TemplateMarkedDateTime__c = Datetime.now(),
                RecurringEnabledDateTime__c = null,
                EstimatedHoursNumber__c = 2
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Normal Item',
                StageNamePk__c = 'Backlog',
                WorkflowTypeTxt__c = 'Software_Delivery',
                ActivatedDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = null,
                RecurringEnabledDateTime__c = null
            )
        };
        insert items;
    }

    @isTest
    static void testGetTemplatesReturnsAllTemplates() {
        Test.startTest();
        List<WorkItem__c> templates = DeliveryTemplateManagerController.getTemplates();
        Test.stopTest();

        // Should return both active and inactive templates (2 total)
        System.assertEquals(2, templates.size(), 'Should return all templates regardless of active status');
    }

    @isTest
    static void testGetTemplatesFieldsPopulated() {
        Test.startTest();
        List<WorkItem__c> templates = DeliveryTemplateManagerController.getTemplates();
        Test.stopTest();

        WorkItem__c active = null;
        for (WorkItem__c t : templates) {
            if (t.BriefDescriptionTxt__c == 'Active Template') {
                active = t;
                break;
            }
        }
        System.assertNotEquals(null, active, 'Should find Active Template');
        System.assertEquals('High', active.PriorityPk__c, 'Priority should be populated');
        System.assertEquals(4, active.EstimatedHoursNumber__c, 'Estimated hours should be populated');
        System.assertEquals('Software_Delivery', active.WorkflowTypeTxt__c, 'Workflow type should be populated');
    }

    @isTest
    static void testCreateFromTemplateSuccess() {
        WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Active Template' LIMIT 1];

        Test.startTest();
        Id newId = DeliveryTemplateManagerController.createFromTemplate(template.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, newId, 'Should return new record Id');

        WorkItem__c clone = [
            SELECT BriefDescriptionTxt__c, TemplateMarkedDateTime__c, ActivatedDateTime__c
            FROM WorkItem__c WHERE Id = :newId
        ];
        System.assertEquals('Active Template', clone.BriefDescriptionTxt__c, 'Clone should copy title');
        System.assertEquals(null, clone.TemplateMarkedDateTime__c, 'Clone should not be a template');
        System.assertNotEquals(null, clone.ActivatedDateTime__c, 'Clone should be active');
    }

    @isTest
    static void testCreateFromTemplateWithOverrides() {
        WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Active Template' LIMIT 1];
        Map<String, Object> overrides = new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Overridden Title',
            'PriorityPk__c' => 'Low'
        };

        Test.startTest();
        Id newId = DeliveryTemplateManagerController.createFromTemplate(template.Id, overrides);
        Test.stopTest();

        WorkItem__c clone = [
            SELECT BriefDescriptionTxt__c, PriorityPk__c
            FROM WorkItem__c WHERE Id = :newId
        ];
        System.assertEquals('Overridden Title', clone.BriefDescriptionTxt__c, 'Title should be overridden');
        System.assertEquals('Low', clone.PriorityPk__c, 'Priority should be overridden');
    }

    @isTest
    static void testCreateFromTemplateNullId() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryTemplateManagerController.createFromTemplate(null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for null template Id');
    }

    @isTest
    static void testDeactivateTemplate() {
        WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Active Template' LIMIT 1];

        Test.startTest();
        DeliveryTemplateManagerController.deactivateTemplate(template.Id);
        Test.stopTest();

        WorkItem__c updated = [SELECT ActivatedDateTime__c FROM WorkItem__c WHERE Id = :template.Id];
        System.assertEquals(null, updated.ActivatedDateTime__c, 'Template should be deactivated');
    }

    @isTest
    static void testDeactivateTemplateNullId() {
        Boolean threw = false;
        try {
            DeliveryTemplateManagerController.deactivateTemplate(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for null template Id');
    }

    @isTest
    static void testActivateTemplate() {
        WorkItem__c template = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Inactive Template' LIMIT 1];

        Test.startTest();
        DeliveryTemplateManagerController.activateTemplate(template.Id);
        Test.stopTest();

        WorkItem__c updated = [SELECT ActivatedDateTime__c FROM WorkItem__c WHERE Id = :template.Id];
        System.assertNotEquals(null, updated.ActivatedDateTime__c, 'Template should be reactivated');
    }

    @isTest
    static void testActivateTemplateNullId() {
        Boolean threw = false;
        try {
            DeliveryTemplateManagerController.activateTemplate(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for null template Id');
    }
}
