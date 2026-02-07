public with sharing class DeliveryHubCommentController {

    public class CommentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String body;
        @AuraEnabled public String authorName;
        @AuraEnabled public Long timestamp;
        @AuraEnabled public Boolean isOutbound; 
    }

    @AuraEnabled(cacheable=true)
    public static List<CommentWrapper> getComments(Id ticketId) {
        return queryComments(ticketId);
    }

    @AuraEnabled
    public static List<CommentWrapper> getCommentsLive(Id ticketId) {
        try {
            // 1. DYNAMIC ROUTING: Find the Active Request linked to this Ticket
            // We need the Endpoint URL and the Remote Ticket ID
            List<Request__c> requests = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :ticketId 
                AND RemoteTicketIdTxt__c != null
                AND DeliveryEntityId__r.IntegrationEndpointUrlTxt__c != null
                LIMIT 1
            ];

            // If no active request, return local data only
            if (requests.isEmpty()) {
                return queryComments(ticketId);
            }

            Request__c reqRec = requests[0];
            String baseUrl = reqRec.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            String remoteTicketId = reqRec.RemoteTicketIdTxt__c;

            // 2. High Water Mark (Find the last time we synced)
            DateTime lastSync = DateTime.newInstance(1900, 1, 1);
            List<Ticket_Comment__c> lastRemote = [
                SELECT CreatedDate 
                FROM Ticket_Comment__c 
                WHERE TicketId__c = :ticketId 
                AND JiraCommentIdTxt__c != null 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!lastRemote.isEmpty()) {
                lastSync = lastRemote[0].CreatedDate;
            }

            // 3. Construct URL
            // e.g. https://.../deliveryhub/v1/comments/{RemoteID}?since={Time}
            String endpoint = baseUrl + '/comments/' + remoteTicketId + '?since=' + lastSync.getTime();
            
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

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
                        
                        Ticket_Comment__c c = new Ticket_Comment__c();
                        c.TicketId__c = ticketId;
                        c.BodyTxt__c = body;
                        c.AuthorTxt__c = author; 
                        c.JiraCommentIdTxt__c = remoteSyncId; // The "Golden Thread" ID
                        c.SourcePk__c = 'Mothership'; // INBOUND: Comes from them
                        c.JiraSyncStatusTxt__c = 'Synced';
                        
                        newComments.add(c);
                    }
                }

                // 5. Deduplicate (Don't insert what we already have)
                if (!incomingRemoteIds.isEmpty()) {
                    List<Ticket_Comment__c> existing = [
                        SELECT JiraCommentIdTxt__c 
                        FROM Ticket_Comment__c 
                        WHERE JiraCommentIdTxt__c IN :incomingRemoteIds
                    ];
                    Set<String> existingIds = new Set<String>();
                    for (Ticket_Comment__c exist : existing) {
                        existingIds.add(exist.JiraCommentIdTxt__c);
                    }
                    
                    List<Ticket_Comment__c> finalInsert = new List<Ticket_Comment__c>();
                    for (Ticket_Comment__c nc : newComments) {
                        if (!existingIds.contains(nc.JiraCommentIdTxt__c)) {
                            finalInsert.add(nc);
                        }
                    }
                    
                    if (!finalInsert.isEmpty()) {
                        insert finalInsert;
                    }
                }
            } 
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Live pull failed: ' + e.getMessage());
        }
        
        return queryComments(ticketId);
    }

    @AuraEnabled
    public static void postComment(Id ticketId, String body) {
        if (String.isBlank(body)) {
            throw new AuraHandledException('Comment body cannot be empty.');
        }

        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticketId,
            BodyTxt__c = body,
            AuthorTxt__c = UserInfo.getName(), 
            SourcePk__c = 'Client', // OUTBOUND: Matches your picklist value
            JiraSyncStatusTxt__c = 'Pending' 
        );
        insert comment;
    }

    private static List<CommentWrapper> queryComments(Id ticketId) {
        List<CommentWrapper> chat = new List<CommentWrapper>();
        
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
            w.timestamp = c.CreatedDate.getTime();
            w.authorName = c.AuthorTxt__c;
            
            // ALIGNMENT LOGIC:
            // If Source is 'Client', it is mine -> Right Side (Outbound)
            // If Source is 'Mothership', 'Jira', 'Salesforce' -> Left Side (Inbound)
            w.isOutbound = (c.SourcePk__c == 'Client');
            
            chat.add(w);
        }
        return chat;
    }
}