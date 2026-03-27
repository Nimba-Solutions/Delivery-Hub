/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for board saved-filter CRUD operations.
 *              Returns only the running user's own filters (Private sharing model).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliverySavedFilterController {

    /**
     * @description Returns all saved filters owned by the running user for a given workflow type.
     * @param workflowType The WorkflowType DeveloperName to filter by.
     * @return List of DeliverySavedFilter__c records ordered by label.
     */
    @AuraEnabled(cacheable=true)
    public static List<DeliverySavedFilter__c> getSavedFilters(String workflowType) {
        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }
        return [
            SELECT Id, Name, LabelTxt__c, FilterJsonTxt__c,
                   DefaultSetDateTime__c, WorkflowTypeTxt__c
            FROM DeliverySavedFilter__c
            WHERE OwnerId = :UserInfo.getUserId()
            AND WorkflowTypeTxt__c = :workflowType
            WITH SYSTEM_MODE
            ORDER BY LabelTxt__c ASC
            LIMIT 50
        ];
    }

    /**
     * @description Creates or updates a saved filter. When isDefault is true,
     *              any other default filter for the same user and workflow type is un-defaulted.
     * @param filterId Null for new filter, existing Id for update.
     * @param label User-given display name.
     * @param filterJson Serialized filter criteria JSON.
     * @param isDefault Whether this should be the default filter.
     * @param workflowType The workflow type this filter applies to.
     * @return The upserted DeliverySavedFilter__c record.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    public static DeliverySavedFilter__c saveBoardFilter(
        Id filterId,
        String label,
        String filterJson,
        Boolean isDefault,
        String workflowType
    ) {
        if (String.isBlank(label)) {
            throw createAuraException('Filter name is required.');
        }
        if (String.isBlank(filterJson)) {
            throw createAuraException('Filter criteria cannot be empty.');
        }
        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }

        if (isDefault == true) {
            clearExistingDefaults(workflowType, filterId);
        }

        DeliverySavedFilter__c sf;
        if (filterId != null) {
            sf = new DeliverySavedFilter__c(
                Id = filterId,
                LabelTxt__c = label,
                FilterJsonTxt__c = filterJson,
                DefaultSetDateTime__c = (isDefault == true) ? Datetime.now() : null,
                WorkflowTypeTxt__c = workflowType
            );
            update sf;
        } else {
            sf = new DeliverySavedFilter__c(
                LabelTxt__c = label,
                FilterJsonTxt__c = filterJson,
                DefaultSetDateTime__c = (isDefault == true) ? Datetime.now() : null,
                WorkflowTypeTxt__c = workflowType
            );
            insert sf;
        }
        return sf;
    }

    /**
     * @description Deletes a saved filter record owned by the running user.
     * @param filterId The Id of the DeliverySavedFilter__c to delete.
     */
    @AuraEnabled
    public static void deleteSavedFilter(Id filterId) {
        if (filterId == null) {
            throw createAuraException('Filter Id is required.');
        }

        List<DeliverySavedFilter__c> filters = [
            SELECT Id FROM DeliverySavedFilter__c
            WHERE Id = :filterId
            AND OwnerId = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (filters.isEmpty()) {
            throw createAuraException('Filter not found or you do not have permission to delete it.');
        }
        delete filters;
    }

    /**
     * @description Un-defaults all saved filters for the current user and workflow type,
     *              optionally excluding a specific filter Id.
     * @param workflowType The workflow type to scope the clear operation.
     * @param excludeId Optional Id to exclude from the clear.
     */
    private static void clearExistingDefaults(String workflowType, Id excludeId) {
        List<DeliverySavedFilter__c> existingDefaults = [
            SELECT Id, DefaultSetDateTime__c FROM DeliverySavedFilter__c
            WHERE OwnerId = :UserInfo.getUserId()
            AND WorkflowTypeTxt__c = :workflowType
            AND DefaultSetDateTime__c != null
            AND Id != :excludeId
            WITH SYSTEM_MODE
            LIMIT 50
        ];
        if (!existingDefaults.isEmpty()) {
            for (DeliverySavedFilter__c f : existingDefaults) {
                f.DefaultSetDateTime__c = null;
            }
            update existingDefaults;
        }
    }

    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
