/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Ghost Recorder LWC.
 * Logs user activity to ActivityLog__c and creates quick work items.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class DeliveryGhostController {

    /**
     * @description Logs a user navigation or action event to the ActivityLog__c object.
     * Parses the contextData JSON to extract component name and populates the running
     * user's ID automatically.
     * @param actionType The type of action (e.g., 'Navigation', 'Button_Click', 'Feature_Use').
     * @param contextData JSON string containing browser/URL/component info.
     */
    @SuppressWarnings('PMD.StdCyclomaticComplexity, PMD.CyclomaticComplexity')
    @AuraEnabled
    global static void logUserActivity(String actionType, String contextData) {
        try {
            // Gate: activity logging must be explicitly enabled in org settings
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
            if (settings == null || settings.EnableActivityLoggingDateTime__c == null) {
                return;
            }

            ActivityLog__c log = new ActivityLog__c();
            log.ActionTypePk__c = actionType;
            log.ContextDataTxt__c = contextData;
            log.UserIdTxt__c = UserInfo.getUserId();

            // Extract structured fields from the context JSON when available
            if (String.isNotBlank(contextData)) {
                populateFromContext(log, contextData);
            }

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
    global static String createQuickRequest(String subject, String description, String priority, String contextData, String workItemType) {
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
            // Inbound requests are NOT activated on creation. Leaving
            // ActivatedDateTime__c null routes the request into the Intake
            // queue (front of pipe) for a triager to review and activate onto
            // the Board — activation = stamping ActivatedDateTime__c, which is
            // what makes the item appear on the Board/Gantt. Auto-activating
            // here would skip Intake entirely (the item would land straight on
            // the Board), which defeats the triage step.
            t.StatusPk__c = 'New';

            // Insert honoring the intake-first org setting, then ping live
            // subscribers so the new request pops into Intake — see
            // persistInboundRequest.
            persistInboundRequest(t);

            return t.Id;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Create Work Item Failed: ' + e.getMessage());
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // ── Private Helpers ──────────────────────────────────────────────────

    /**
     * @description Inserts an inbound quick-request WorkItem honoring the
     *              intake-first org setting, then pings live subscribers. When
     *              EnableAutoActivateDateTime__c is null (default), the
     *              before-insert trigger's auto-activate is suppressed for this
     *              insert so the request lands un-activated in the Intake queue;
     *              when set (e.g. post-quickstart) it auto-activates onto the
     *              board as before. The suppress flag is reset in finally so it
     *              never leaks to other DML in the request. The published
     *              DeliveryWorkItemChange__e lets the Intake queue refresh live.
     * @param t The WorkItem to insert (assigned its new Id in place).
     */
    private static void persistInboundRequest(WorkItem__c t) {
        if (!Schema.sObjectType.WorkItem__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create Work Item.');
        }
        Boolean autoActivate = DeliveryHubSettings__c.getInstance().EnableAutoActivateDateTime__c != null;
        if (!autoActivate) {
            DeliveryTriggerControl.suppressAutoActivate = true;
        }
        try {
            insert t; //NOPMD - with sharing class handles CRUD; isCreateable checked above
        } finally {
            DeliveryTriggerControl.suppressAutoActivate = false;
        }
        EventBus.publish(new DeliveryWorkItemChange__e(
            WorkItemIdTxt__c = t.Id,
            ChangeTypeTxt__c = 'intake_new'
        ));
    }

    private static void populateFromContext(ActivityLog__c log, String contextData) {
        try {
            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(contextData);
            String pageLabel = safeGetString(ctx, 'pageLabel');
            if (String.isNotBlank(pageLabel)) {
                log.ComponentNameTxt__c = pageLabel;
            } else {
                String objName = safeGetString(ctx, 'objectName');
                if (String.isNotBlank(objName)) {
                    log.ComponentNameTxt__c = objName;
                }
            }
            log.RecordIdTxt__c = safeGetString(ctx, 'recordId');
            String url = safeGetString(ctx, 'url');
            if (String.isNotBlank(url)) {
                log.PageUrlTxt__c = url.length() > 255 ? url.substring(0, 255) : url;
            }
            log.SessionIdTxt__c = safeGetString(ctx, 'sessionId');
        } catch (Exception parseEx) {
            // Non-critical — context is best-effort
            System.debug(LoggingLevel.FINE, 'Context parse skipped: ' + parseEx.getMessage());
        }
    }

    private static String safeGetString(Map<String, Object> ctx, String key) {
        try {
            return (String) ctx.get(key);
        } catch (Exception e) {
            return null;
        }
    }
}
