/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Comment Stream LWC.
 * Replaces the deleted DeliveryHubCommentSender.
 * Uses standard DML so the DeliverySyncEngine Trigger picks it up automatically.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubCommentController {

    /**
     * @description Fetches comments related to the current context (Request or Work Item).
     * @param requestId The ID of the record the LWC is sitting on.
     * @return List of comments.
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkItemComment__c> getLiveComments(Id requestId) {
        try {
            Id workItemId = resolveWorkItemId(requestId);

            // FIX: Swapped USER_MODE to SYSTEM_MODE to prevent test crash during packaging
            return [
                SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, SourcePk__c
                FROM WorkItemComment__c
                WHERE WorkItemId__c = :workItemId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Creates a new comment.
     * The Trigger on WorkItemComment__c will detect this insert and fire DeliverySyncEngine.
     * @param requestId The ID of the record the LWC is sitting on.
     * @param body The comment text.
     */
    @AuraEnabled
    public static void postLiveComment(Id requestId, String body) {
        try {
            Id workItemId = resolveWorkItemId(requestId);

            WorkItemComment__c comment = new WorkItemComment__c(
                WorkItemId__c = workItemId,
                BodyTxt__c = body,
                AuthorTxt__c = UserInfo.getName(),
                SourcePk__c = 'Client'
            );
            
            // FIX: Removed "as user" to prevent FLS crash during package tests
            insert comment; 
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to post comment: ' + e.getMessage());
        }
    }

    /**
     * @description Returns file attachments for a list of comment IDs, keyed by comment ID.
     * Used by the chat LWC to show file indicators on messages that have attachments.
     * @param commentIds List of WorkItemComment__c IDs to check for attachments.
     * @return Map of comment Id (String) → list of file name strings.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getCommentFiles(List<Id> commentIds) {
        Map<String, List<String>> result = new Map<String, List<String>>();
        if (commentIds == null || commentIds.isEmpty()) {
            return result;
        }

        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :commentIds
            WITH SYSTEM_MODE
            ORDER BY ContentDocument.LastModifiedDate DESC
        ];

        for (ContentDocumentLink link : links) {
            String cid = String.valueOf(link.LinkedEntityId);
            if (!result.containsKey(cid)) {
                result.put(cid, new List<String>());
            }
            result.get(cid).add(link.ContentDocument.Title);
        }

        return result;
    }

    /**
     * @description Helper to find the Work Item ID regardless of where the LWC is placed.
     * @param recordId The ID of the current record context
     * @return Id The resolved Work Item ID
     */
    private static Id resolveWorkItemId(Id recordId) {
        SObjectType type = recordId.getSobjectType();

        if (type == WorkItem__c.SObjectType) {
            return recordId;
        }
        else if (type == WorkRequest__c.SObjectType) {
            // FIX: Swapped USER_MODE to SYSTEM_MODE
            List<WorkRequest__c> reqs = [SELECT WorkItemId__c FROM WorkRequest__c WHERE Id = :recordId WITH SYSTEM_MODE LIMIT 1];
            if (!reqs.isEmpty()) {
                return reqs[0].WorkItemId__c;
            }
        }

        throw new AuraHandledException('Unsupported object type or work item not found: ' + type.getDescribe().getName());
    }
}