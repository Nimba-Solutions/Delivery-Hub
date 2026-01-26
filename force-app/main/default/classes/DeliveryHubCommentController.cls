/**
 * @description Controller for the internal Ticket Chat LWC.
 * Handles fetching and posting comments to the Ticket_Comment__c object.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubCommentController {

    /**
     * @description Wrapper class to send clean data to the LWC
     */
    public class CommentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String body;
        @AuraEnabled public String authorName;
        @AuraEnabled public DateTime timestamp;
        @AuraEnabled public Boolean isOutbound; // True = Current User (Right side), False = Others (Left side)
    }

    /**
     * @description Fetches all comments for a specific Ticket, ordered chronologically.
     * @param ticketId The ID of the Ticket record.
     * @return List<CommentWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<CommentWrapper> getComments(Id ticketId) {
        try {
            List<CommentWrapper> chat = new List<CommentWrapper>();
            String currentUserId = UserInfo.getUserId();

            List<Ticket_Comment__c> records = [
                SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, CreatedById, CreatedBy.Name 
                FROM Ticket_Comment__c 
                WHERE TicketId__c = :ticketId 
                ORDER BY CreatedDate ASC
            ];

            for (Ticket_Comment__c c : records) {
                CommentWrapper w = new CommentWrapper();
                w.id = c.Id;
                w.body = c.BodyTxt__c;
                w.timestamp = c.CreatedDate;
                
                // Logic: If AuthorTxt__c (manual name) is set, use it. Otherwise use the System User Name.
                w.authorName = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : c.CreatedBy.Name;
                
                // Logic: Determine alignment. If I created it, it's "Outbound" (Right).
                w.isOutbound = (c.CreatedById == currentUserId);
                
                chat.add(w);
            }
            return chat;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching comments: ' + e.getMessage());
        }
    }

    /**
     * @description Posts a new comment to the Ticket.
     * @param ticketId The Ticket ID.
     * @param body The message content.
     */
    @AuraEnabled
    public static void postComment(Id ticketId, String body) {
        try {
            if (String.isBlank(body)) {
                throw new AuraHandledException('Comment body cannot be empty.');
            }

            Ticket_Comment__c comment = new Ticket_Comment__c(
                TicketId__c = ticketId,
                BodyTxt__c = body,
                AuthorTxt__c = UserInfo.getName() // Auto-stamp the sender's name
            );
            
            insert comment;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error posting comment: ' + e.getMessage());
        }
    }
}