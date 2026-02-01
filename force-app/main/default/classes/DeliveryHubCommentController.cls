/**
 * @description Controller for the internal Ticket Chat LWC.
 * Handles fetching, posting, and on-demand refreshing of comments.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubCommentController {

    public class CommentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String body;
        @AuraEnabled public String authorName;
        @AuraEnabled public DateTime timestamp;
        @AuraEnabled public Boolean isOutbound; 
    }

    @AuraEnabled(cacheable=true)
    public static List<CommentWrapper> getComments(Id ticketId) {
        try {
            return queryComments(ticketId);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching comments: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<CommentWrapper> getCommentsLive(Id ticketId) {
        try {
            // Force the pull. If it works, new comments are inserted.
            DeliveryHubSubscriptionService.pullUpdates(ticketId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Live pull failed: ' + e.getMessage());
            // We swallow the error here so the chat doesn't crash, 
            // returning whatever IS in the database.
        }
        return queryComments(ticketId);
    }

    @AuraEnabled
    public static void postComment(Id ticketId, String body) {
        try {
            if (String.isBlank(body)) throw new AuraHandledException('Comment body cannot be empty.');

            Ticket_Comment__c comment = new Ticket_Comment__c(
                TicketId__c = ticketId,
                BodyTxt__c = body,
                AuthorTxt__c = UserInfo.getName(), // Capture YOUR name
                JiraSyncStatusTxt__c = 'Pending' 
            );
            insert comment;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error posting comment: ' + e.getMessage());
        }
    }

    /**
     * @description Private helper to query and wrap comments.
     * FIXED: Logic for determining "isOutbound" (Left vs Right alignment).
     */
    private static List<CommentWrapper> queryComments(Id ticketId) {
        List<CommentWrapper> chat = new List<CommentWrapper>();
        String currentUserName = UserInfo.getName(); // Check Name, not ID

        List<Ticket_Comment__c> records = [
            SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, SourcePk__c 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :ticketId 
            ORDER BY CreatedDate ASC
        ];

        for (Ticket_Comment__c c : records) {
            CommentWrapper w = new CommentWrapper();
            w.id = c.Id;
            w.body = c.BodyTxt__c;
            w.timestamp = c.CreatedDate;
            w.authorName = c.AuthorTxt__c;

            // --- ALIGNMENT LOGIC FIX ---
            // 1. If I am the Author, it's Outbound (Right).
            // 2. If the Source is EXPLICITLY 'Client Org', it's Outbound (Right).
            // 3. Otherwise (Source is 'Mothership' or Author is 'Support'), it's Inbound (Left).
            
            if (c.AuthorTxt__c == currentUserName) {
                w.isOutbound = true;
            } else if (c.SourcePk__c == 'Client Org') {
                w.isOutbound = true;
            } else {
                w.isOutbound = false; // Left side (Vendor/Mothership)
            }
            
            chat.add(w);
        }
        return chat;
    }
}