/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Template Manager LWC. Provides methods to list,
 *               create, and clone work item templates.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryTemplateManagerController {

    /**
     * @description Returns all work item templates with fields needed for the
     *              template management table view.
     * @return List of template WorkItem__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkItem__c> getTemplates() {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c,
                   Tags__c, WorkflowTypeTxt__c, RequestTypePk__c, EstimatedHoursNumber__c,
                   DeveloperDaysSizeNumber__c, StageNamePk__c, Epic__c, ActivatedDateTime__c,
                   CreatedDate, LastModifiedDate
            FROM WorkItem__c
            WHERE TemplateMarkedDateTime__c != null
            WITH SYSTEM_MODE
            ORDER BY WorkflowTypeTxt__c ASC, BriefDescriptionTxt__c ASC
        ];
    }

    /**
     * @description Creates a new work item from an existing template, delegating to
     *              DeliveryRecurringItemService.cloneFromTemplate.
     * @param templateId The Id of the template WorkItem__c to clone.
     * @param overrides Map of field API names to values to override on the clone.
     * @return Id The Id of the newly created work item.
     */
    @AuraEnabled
    public static Id createFromTemplate(Id templateId, Map<String, Object> overrides) {
        if (templateId == null) {
            AuraHandledException ex = new AuraHandledException('Template Id is required.');
            ex.setMessage('Template Id is required.');
            throw ex;
        }
        return DeliveryRecurringItemService.cloneFromTemplate(templateId, overrides);
    }

    /**
     * @description Deactivates a template by setting ActivatedDateTime__c to null.
     *              This hides it from the template browser without deleting it.
     * @param templateId The Id of the template WorkItem__c to deactivate.
     */
    @AuraEnabled
    public static void deactivateTemplate(Id templateId) {
        if (templateId == null) {
            AuraHandledException ex = new AuraHandledException('Template Id is required.');
            ex.setMessage('Template Id is required.');
            throw ex;
        }
        List<WorkItem__c> templates = [
            SELECT Id, ActivatedDateTime__c, TemplateMarkedDateTime__c
            FROM WorkItem__c
            WHERE Id = :templateId
            AND TemplateMarkedDateTime__c != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('Template not found.');
            ex.setMessage('Template not found.');
            throw ex;
        }
        templates[0].ActivatedDateTime__c = null;
        Database.update(templates, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Reactivates a previously deactivated template.
     * @param templateId The Id of the template WorkItem__c to reactivate.
     */
    @AuraEnabled
    public static void activateTemplate(Id templateId) {
        if (templateId == null) {
            AuraHandledException ex = new AuraHandledException('Template Id is required.');
            ex.setMessage('Template Id is required.');
            throw ex;
        }
        List<WorkItem__c> templates = [
            SELECT Id, ActivatedDateTime__c, TemplateMarkedDateTime__c
            FROM WorkItem__c
            WHERE Id = :templateId
            AND TemplateMarkedDateTime__c != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('Template not found.');
            ex.setMessage('Template not found.');
            throw ex;
        }
        templates[0].ActivatedDateTime__c = Datetime.now();
        Database.update(templates, AccessLevel.SYSTEM_MODE);
    }
}
