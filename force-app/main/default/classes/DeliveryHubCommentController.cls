/**
 * @description Controller for the internal Ticket Chat LWC.
 * Handles fetching and posting comments, syncing via the related Request.
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
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching comments: ' + e.getMessage());
        }
    }

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
                JiraSyncStatusTxt__c = 'Pending'   
            );
            
            insert comment;
            
            if (!Test.isRunningTest()) {
                syncCommentAsync(comment.Id);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error posting comment: ' + e.getMessage());
        }
    }

    @future(callout=true)
    public static void syncCommentAsync(Id commentId) {
        try {
            // 1. Fetch the comment and its Ticket ID
            Ticket_Comment__c c = [
                SELECT Id, BodyTxt__c, AuthorTxt__c, TicketId__c 
                FROM Ticket_Comment__c 
                WHERE Id = :commentId 
                LIMIT 1
            ];

            // 2. Find the active Request linked to this Ticket that has a Remote ID
            // We order by CreatedDate DESC to get the latest engagement if multiple exist.
            List<Request__c> relatedRequests = [
                SELECT RemoteTicketIdTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :c.TicketId__c 
                AND RemoteTicketIdTxt__c != NULL
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            // If no linked request found, we cannot sync.
            if (relatedRequests.isEmpty()) {
                c.JiraSyncStatusTxt__c = 'Skipped: No Linked Request';
                update c;
                return; 
            }

            String remoteId = relatedRequests[0].RemoteTicketIdTxt__c;

            // 3. Prepare Payload
            Map<String, String> payload = new Map<String, String>();
            payload.put('remoteTicketId', remoteId);
            payload.put('body', c.BodyTxt__c);
            payload.put('author', c.AuthorTxt__c);

            // 4. Send via Service
            HttpResponse res = DeliveryHubCalloutService.post(
                'callout:Mothership/services/apexrest/DeliveryHubRemoteDiscussion', 
                payload
            );

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                c.JiraSyncStatusTxt__c = 'Synced';
                c.SyncedDateTime__c = System.now();
            } else {
                c.JiraSyncStatusTxt__c = 'Failed: ' + res.getStatus();
            }
            update c;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Sync Failed: ' + e.getMessage());
        }
    }
}