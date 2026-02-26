/**
 * @description Controller for the Delivery Ghost Recorder LWC.
 * Logs user activity to Activity_Log__c and creates quick work items.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryGhostController {

    /**
     * @description Logs a user navigation or action event to the Activity_Log__c object.
     * Parses the contextData JSON to extract component name and populates the running
     * user's ID automatically.
     * @param actionType The type of action (e.g., 'Navigation', 'Button_Click', 'Feature_Use').
     * @param contextData JSON string containing browser/URL/component info.
     */
    @AuraEnabled
    public static void logUserActivity(String actionType, String contextData) {
        try {
            Activity_Log__c log = new Activity_Log__c();
            log.ActionTypePk__c = actionType;
            log.ContextDataTxt__c = contextData;
            log.UserIdTxt__c = UserInfo.getUserId();

            // Extract component/object name from the context JSON when available
            if (String.isNotBlank(contextData)) {
                try {
                    Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(contextData);
                    String objName = (String) ctx.get('objectName');
                    if (String.isNotBlank(objName)) {
                        log.ComponentNameTxt__c = objName;
                    }
                    String sessionId = (String) ctx.get('sessionId');
                    if (String.isNotBlank(sessionId)) {
                        log.SessionIdTxt__c = sessionId;
                    }
                } catch (Exception parseEx) {
                    // Non-critical — context is best-effort
                    System.debug(LoggingLevel.FINE, 'Context parse skipped: ' + parseEx.getMessage());
                }
            }

            // Attempt to link to the first active Network Entity (client org identity)
            List<Network_Entity__c> entities = [
                SELECT Id FROM Network_Entity__c
                WHERE StatusPk__c = 'Active'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!entities.isEmpty()) {
                log.NetworkEntityId__c = entities[0].Id;
            }

            insert as system log;
        } catch (Exception e) {
            // Activity logging must never break the user experience
            System.debug(LoggingLevel.WARN, 'Activity log write failed: ' + e.getMessage());
        }
    }

    /**
     * @description Creates a Work Item from the Ghost Recorder.
     * @param subject The work item summary.
     * @param description The detailed description.
     * @param priority The priority level.
     * @param contextData The captured browser/url context.
     * @param workItemType 'Bug' or 'Feature' (from the radio button).
     * @return Id of the created work item.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    public static String createQuickRequest(String subject, String description, String priority, String contextData, String workItemType) {
        try {
            // 1. Format the Description with Context
            String fullDescription = description;
            if (String.isNotBlank(contextData)) {
                fullDescription += '\n\n----------------\nAuto-Captured Context:\n' + contextData;
            }

            // 2. Format Subject based on Type (Work Item Name)
            String prefix = (String.isNotBlank(workItemType)) ? '[' + workItemType + '] ' : '[Issue] ';
            String fullSubject = prefix + subject;

            // 3. Generate Brief Description (Max 100 chars)
            String briefSource = fullSubject + ' - ' + (String.isBlank(description) ? '' : description);
            String briefDesc = (briefSource.length() > 100) ? briefSource.substring(0, 100) : briefSource;

            // 4. Create Work Item
            WorkItem__c t = new WorkItem__c();
            t.BriefDescriptionTxt__c = briefDesc;
            t.DetailsTxt__c = fullDescription;
            t.PriorityPk__c = priority;
            t.StageNamePk__c = 'Backlog';
            t.IsActiveBool__c = true;
            t.StatusPk__c = 'New';

            if (Schema.sObjectType.WorkItem__c.isCreateable()) {
                insert t;
            } else {
                throw new AuraHandledException('Insufficient permissions to create Work Item.');
            }

            return t.Id;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Create Work Item Failed: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}
