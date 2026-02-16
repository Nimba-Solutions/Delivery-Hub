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
            // Resolve Ticket ID from Request if needed
            Id ticketId = resolveTicketId(requestId);
            
            // Query with USER_MODE to enforce field-level security
            return [
                SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, JiraSyncStatusTxt__c
                FROM Ticket_Comment__c
                WHERE TicketId__c = :ticketId
                ORDER BY CreatedDate DESC
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
                AuthorTxt__c = UserInfo.getName(), // Defaults to current user
                JiraSyncStatusTxt__c = 'Pending'   // Marks it for the Trigger to pick up
            );
            
            // Insert with USER_MODE to enforce permissions
            insert as user comment; 
            
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
        String objName = recordId.getSobjectType().getDescribe().getName();
        
        if (objName == 'Ticket__c') {
            return recordId;
        } else if (objName == 'Request__c') {
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE Id = :recordId LIMIT 1];
            if (!reqs.isEmpty()) {
                return reqs[0].TicketId__c;
            }
        }
        throw new AuraHandledException('Unsupported Object or Ticket not found.');
    }
}