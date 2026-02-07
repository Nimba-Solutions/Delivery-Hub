/**
 * @description Controller for the internal Ticket Chat LWC.
 * Handles fetching, posting, and live polling of comments from the Mothership.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubCommentController {

    /**
     * @description Wrapper class to transport comment data to LWC.
     */
    public class CommentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String body;
        @AuraEnabled public String authorName;
        @AuraEnabled public Long timestamp; // Changed to Long for easier JS handling
        @AuraEnabled public Boolean isOutbound; 
    }

    /**
     * @description Fetches cached comments for a Ticket.
     * @param ticketId The ID of the Ticket to query.
     * @return List<CommentWrapper> List of formatted comments.
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
     * @description Forces a live API pull from Mothership, then returns the latest comments.
     * @param ticketId The ID of the Ticket to refresh.
     * @return List<CommentWrapper> List of formatted comments including new ones.
     */
    @AuraEnabled
    public static List<CommentWrapper> getCommentsLive(Id ticketId) {
        try {
            // 1. Get Ticket & Remote ID
            Ticket__c t = [SELECT SourceEventReplayIdTxt__c FROM Ticket__c WHERE Id = :ticketId LIMIT 1];
            
            // If not linked to Mothership yet, just return local
            if (t.SourceEventReplayIdTxt__c == null) {
                return queryComments(ticketId);
            }

            // 2. Determine "Since" Timestamp (High Water Mark)
            // We find the most recent comment we received from the Mothership to ask for only newer stuff.
            DateTime lastSync = DateTime.newInstance(1900, 1, 1);
            List<Ticket_Comment__c> lastRemote = [
                SELECT CreatedDate 
                FROM Ticket_Comment__c 
                WHERE TicketId__c = :ticketId 
                AND RemoteExternalIDTxt__c != null 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!lastRemote.isEmpty()) {
                lastSync = lastRemote[0].CreatedDate;
            }

            // 3. Call Mothership (GET)
            // Ensure 'DeliveryHubMothership' is in Named Credentials
            String endpoint = 'callout:DeliveryHubMothership/services/apexrest/deliveryhub/v1/comments/' 
                            + t.SourceEventReplayIdTxt__c 
                            + '?since=' + lastSync.getTime();
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // 4. Process Incoming Envelopes
                List<Object> envelopes = (List<Object>) JSON.deserializeUntyped(res.getBody());
                List<Ticket_Comment__c> newComments = new List<Ticket_Comment__c>();
                Set<String> incomingRemoteIds = new Set<String>();

                for (Object obj : envelopes) {
                    Map<String, Object> env = (Map<String, Object>) obj;
                    
                    String remoteSyncId = (String) env.get('mothershipSyncId');
                    String body = (String) env.get('body');
                    String author = (String) env.get('author');
                    
                    if (String.isNotBlank(remoteSyncId)) {
                        incomingRemoteIds.add(remoteSyncId);
                        
                        // Prepare the local record
                        Ticket_Comment__c c = new Ticket_Comment__c();
                        c.TicketId__c = ticketId;
                        c.BodyTxt__c = body;
                        c.AuthorTxt__c = author; 
                        c.RemoteExternalIDTxt__c = remoteSyncId; // THE GOLDEN THREAD
                        c.IsOutbound__c = false; // It came FROM the Mothership
                        
                        newComments.add(c);
                    }
                }

                // 5. Deduplicate (Critical Step)
                // Check if we already have these Remote IDs in our database
                if (!incomingRemoteIds.isEmpty()) {
                    List<Ticket_Comment__c> existing = [
                        SELECT RemoteExternalIDTxt__c 
                        FROM Ticket_Comment__c 
                        WHERE RemoteExternalIDTxt__c IN :incomingRemoteIds
                    ];
                    Set<String> existingIds = new Set<String>();
                    for (Ticket_Comment__c exist : existing) {
                        existingIds.add(exist.RemoteExternalIDTxt__c);
                    }
                    
                    // Filter list to insert only genuinely new items
                    List<Ticket_Comment__c> finalInsert = new List<Ticket_Comment__c>();
                    for (Ticket_Comment__c nc : newComments) {
                        if (!existingIds.contains(nc.RemoteExternalIDTxt__c)) {
                            finalInsert.add(nc);
                        }
                    }
                    
                    if (!finalInsert.isEmpty()) {
                        insert finalInsert;
                    }
                }
            } else {
                System.debug('Mothership Poll Failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Live pull failed: ' + e.getMessage());
            // Swallowed so UI doesn't crash
        }
        
        // Return updated list
        return queryComments(ticketId);
    }

    /**
     * @description Posts a new comment to the database.
     * @param ticketId The parent Ticket ID.
     * @param body The text content of the comment.
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
                IsOutbound__c = true, // I wrote this, so it goes OUT
                JiraSyncStatusTxt__c = 'Pending' 
            );
            insert comment;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error posting comment: ' + e.getMessage());
        }
    }

    /**
     * @description Private helper to query and wrap comments.
     */
    private static List<CommentWrapper> queryComments(Id ticketId) {
        List<CommentWrapper> chat = new List<CommentWrapper>();
        
        List<Ticket_Comment__c> records = [
            SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, IsOutbound__c
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :ticketId 
            ORDER BY CreatedDate ASC
        ];

        for (Ticket_Comment__c c : records) {
            CommentWrapper w = new CommentWrapper();
            w.id = c.Id;
            w.body = c.BodyTxt__c;
            w.timestamp = c.CreatedDate.getTime();
            w.authorName = c.AuthorTxt__c;
            
            // Simple Logic: If I marked it as Outbound, it's mine (Right). 
            // If it came from Mothership (IsOutbound__c = false), it's theirs (Left).
            w.isOutbound = c.IsOutbound__c;
            
            chat.add(w);
        }
        return chat;
    }
}