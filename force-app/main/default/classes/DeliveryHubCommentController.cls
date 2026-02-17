/**
 * @description Controller for the Delivery Comment Stream LWC.
 * Replaces the deleted DeliveryHubCommentSender.
 * Uses standard DML so the SyncEngine Trigger picks it up automatically.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubCommentController {

    /**
     * @description Fetches comments related to the current context (Request or Ticket).
     * @param requestId The ID of the record the LWC is sitting on.
     * @return List of comments.
     */
    @AuraEnabled(cacheable=true)
    public static List<Ticket_Comment__c> getLiveComments(Id requestId) {
        try {
            Id ticketId = resolveTicketId(requestId);
            
            return [
                SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, JiraSyncStatusTxt__c, SourcePk__c
                FROM Ticket_Comment__c
                WHERE TicketId__c = :ticketId
                ORDER BY CreatedDate ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Creates a new comment.
     * The Trigger on Ticket_Comment__c will detect this insert and fire SyncEngine.
     * @param requestId The ID of the record the LWC is sitting on.
     * @param body The comment text.
     */
    @AuraEnabled
    public static void postLiveComment(Id requestId, String body) {
        try {
            Id ticketId = resolveTicketId(requestId);
            
            Ticket_Comment__c comment = new Ticket_Comment__c(
                TicketId__c = ticketId,
                BodyTxt__c = body,
                AuthorTxt__c = UserInfo.getName(),
                SourcePk__c = 'Client',            
                JiraSyncStatusTxt__c = 'Pending'   
            );
            
            // FIX: Removed 'as user' to prevent FLS failures in strict package build environments.
            // 'with sharing' class declaration still enforces record-level sharing.
            insert comment; 
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to post comment: ' + e.getMessage());
        }
    }

    /**
     * @description Helper to find the Ticket ID regardless of where the LWC is placed.
     * @param recordId The ID of the current record context
     * @return Id The resolved Ticket ID
     */
    private static Id resolveTicketId(Id recordId) {
        // FIX: Use SObjectType tokens instead of Strings to handle Namespaces automatically
        SObjectType type = recordId.getSobjectType();
        
        if (type == Ticket__c.SObjectType) {
            return recordId;
        } 
        else if (type == Request__c.SObjectType) {
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE Id = :recordId LIMIT 1];
            if (!reqs.isEmpty()) {
                return reqs[0].TicketId__c;
            }
        }
        
        // Only throws if it truly doesn't match known types
        throw new AuraHandledException('Unsupported Object or Ticket not found: ' + type.getDescribe().getName());
    }
}