/**
 * @description Controller for the internal Ticket Chat LWC.
 * Handles fetching, posting, and on-demand refreshing of comments.
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
        @AuraEnabled public Boolean isOutbound; 
    }

    /**
     * @description Fetches all comments for a specific Ticket, ordered chronologically.
     * @param ticketId The ID of the Ticket record.
     * @return List<CommentWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<CommentWrapper> getComments(Id ticketId) {
        try {
            return queryComments(ticketId);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching comments: ' + e.getMessage());
        }
    }

    /**
     * @description Forces a live pull from the Mothership before returning comments.
     * Called by the "Refresh" button or initial load in the LWC.
     * @param ticketId The ID of the Ticket record.
     * @return List<CommentWrapper> Updated list of comments.
     */
    @AuraEnabled
    public static List<CommentWrapper> getCommentsLive(Id ticketId) {
        try {
            // 1. Attempt to pull new messages from Mothership
            DeliveryHubSubscriptionService.pullUpdates(ticketId);
        } catch (Exception e) {
            // Log failure but continue to return local cache so the UI doesn't break
            System.debug(LoggingLevel.ERROR, 'Live pull failed: ' + e.getMessage());
        }

        // 2. Return the latest local records
        return queryComments(ticketId);
    }

    /**
     * @description Posts a new comment to the Ticket.
     * The TicketCommentRouter trigger will handle the actual syncing/routing.
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
                AuthorTxt__c = UserInfo.getName(), 
                JiraSyncStatusTxt__c = 'Pending' // Trigger will pick this up
            );
            
            insert comment;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error posting comment: ' + e.getMessage());
        }
    }

    /**
     * @description Private helper to query and wrap comments.
     * Centralizes the query logic used by both getComments and getCommentsLive.
     */
    private static List<CommentWrapper> queryComments(Id ticketId) {
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
            w.authorName = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : c.CreatedBy.Name;
            w.isOutbound = (c.CreatedById == currentUserId);
            chat.add(w);
        }
        return chat;
    }
}