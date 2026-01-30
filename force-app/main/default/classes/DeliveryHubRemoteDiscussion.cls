/**
 * @description REST Endpoint for receiving chat comments from Client Orgs.
 */
@RestResource(urlMapping='/deliveryhub/v1/discussion/*')
global without sharing class DeliveryHubRemoteDiscussion {

    /**
     * @description POST method to create a new comment on a ticket.
     * Expects the Ticket Name (e.g. T-0001) in the URL and a JSON body with 'body' and 'author'.
     */
    @HttpPost
    @SuppressWarnings('PMD.ApexCRUDViolation') 
    global static void postComment() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Parse Ticket Name from URL (e.g. T-0005)
            String targetTicketName = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            
            String jsonBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            
            String msgBody = (String) payload.get('body');
            String author = (String) payload.get('author');

            // Query by Name (or Id)
            Ticket__c t = [SELECT Id FROM Ticket__c WHERE Name = :targetTicketName LIMIT 1];

            Ticket_Comment__c c = new Ticket_Comment__c(
                TicketId__c = t.Id,
                BodyTxt__c = msgBody,
                AuthorTxt__c = author,
                SourcePk__c = 'Client Org', 
                JiraSyncStatusTxt__c = 'Synced'
            );
            insert c;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Success',
                'commentId' => c.Id
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}