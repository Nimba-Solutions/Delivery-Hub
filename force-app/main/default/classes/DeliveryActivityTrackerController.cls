/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the deliveryActivityTracker LWC.
 *               Accepts lightweight navigation/action events and persists them
 *               to ActivityLog__c for user activity analytics.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
global with sharing class DeliveryActivityTrackerController {

    /**
     * @description Logs a single user activity event to ActivityLog__c.
     *              Respects the org-level EnableActivityLoggingDateTime__c toggle —
     *              when disabled, the method returns silently without inserting.
     *              This is a fire-and-forget call; errors are swallowed to ensure
     *              tracking never disrupts the user experience.
     * @param actionType    Picklist value (Navigation, Button_Click, Feature_Use, etc.)
     * @param componentName Page or component being viewed (e.g., "Account", "Home")
     * @param recordId      18-char Salesforce record ID, or blank
     * @param contextData   JSON string with extended context (url, objectApiName, etc.)
     * @param sessionId     Browser session UUID from sessionStorage
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    global static void logActivity(
        String actionType,
        String componentName,
        String recordId,
        String contextData,
        String sessionId
    ) {
        try {
            // Gate: activity logging must be explicitly enabled in org settings
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
            if (settings == null || settings.EnableActivityLoggingDateTime__c == null) {
                return;
            }

            ActivityLog__c log = new ActivityLog__c();
            log.ActionTypePk__c   = actionType;
            log.ComponentNameTxt__c = componentName;
            log.RecordIdTxt__c    = String.isNotBlank(recordId) ? recordId : null;
            log.UserIdTxt__c      = UserInfo.getUserId();
            log.SessionIdTxt__c   = sessionId;
            log.ContextDataTxt__c = contextData;

            // Attempt to link to the first active Network Entity (client org identity)
            List<NetworkEntity__c> entities = [
                SELECT Id FROM NetworkEntity__c
                WHERE StatusPk__c = 'Active'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            if (!entities.isEmpty()) {
                log.NetworkEntityLookup__c = entities[0].Id;
            }

            insert as system log;
        } catch (Exception e) {
            // Activity tracking must never break the user experience
            System.debug(LoggingLevel.WARN, 'ActivityTracker log failed: ' + e.getMessage());
        }
    }
}
