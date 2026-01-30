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
                AuthorTxt__c = UserInfo.getName(), // Auto-stamp the sender's name
                JiraSyncStatusTxt__c = 'Pending'   // Mark as pending sync
            );
            
            insert comment;
            
            // --- NEW: Trigger Async Sync to Mothership ---
            // Only attempt sync if this is not a test context (unless mocking callouts)
            if (!Test.isRunningTest()) {
                syncCommentAsync(comment.Id);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error posting comment: ' + e.getMessage());
        }
    }

    /**
     * @description Async method to send the comment to the Mothership org.
     * Requires a Named Credential 'Mothership' to be configured.
     * @param commentId The ID of the comment to sync.
     */
    @future(callout=true)
    public static void syncCommentAsync(Id commentId) {
        try {
            // 1. Fetch the comment and the Remote Ticket ID (the link to the other org)
            Ticket_Comment__c c = [
                SELECT Id, BodyTxt__c, AuthorTxt__c, TicketId__r.RemoteTicketIdTxt__c 
                FROM Ticket_Comment__c 
                WHERE Id = :commentId 
                LIMIT 1
            ];

            // If there is no link to the other org, we can't sync.
            if (String.isBlank(c.TicketId__r.RemoteTicketIdTxt__c)) {
                return; 
            }

            // 2. Prepare the Payload
            Map<String, String> payload = new Map<String, String>();
            payload.put('remoteTicketId', c.TicketId__r.RemoteTicketIdTxt__c); // The ID on the OTHER org
            payload.put('body', c.BodyTxt__c);
            payload.put('author', c.AuthorTxt__c);

            // 3. Build the Request
            // NOTE: 'callout:Mothership' assumes you have a Named Credential with this name.
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Mothership/services/apexrest/DeliveryHubRemoteDiscussion'); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));

            // 4. Send
            HttpResponse res = http.send(req);

            // 5. Update Status based on result
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                c.JiraSyncStatusTxt__c = 'Synced';
                c.SyncedDateTime__c = System.now();
                // Optionally store the remote ID if returned: c.JiraCommentIdTxt__c = res.getBody();
            } else {
                c.JiraSyncStatusTxt__c = 'Failed: ' + res.getStatus();
            }
            update c;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Sync Failed: ' + e.getMessage());
        }
    }
}