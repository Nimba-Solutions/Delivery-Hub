/**
 * @description REST Endpoint for receiving chat comments from Client Orgs.
 * Matches style of DeliveryHubFileIntake.
 */
@RestResource(urlMapping='/deliveryhub/v1/discussion/*')
global without sharing class DeliveryHubRemoteDiscussion {

    /**
     * @description POST: Post a comment to a specific Ticket.
     * URL Format: /services/apexrest/deliveryhub/v1/discussion/{remoteTicketId}
     * Expects JSON body with 'body' and 'author'.
     */
    @HttpPost
    @SuppressWarnings('PMD.ApexCRUDViolation') // System Mode intentional for integration
    global static void postComment() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // 1. Parse Remote Ticket ID from URL (e.g., .../discussion/T-1001)
            // This is the ID/Name of the ticket inside THIS (Mothership) org
            String targetTicketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            
            // 2. Parse JSON Body
            String jsonBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            
            String msgBody = (String) payload.get('body');
            String author = (String) payload.get('author');

            if (String.isBlank(msgBody) || String.isBlank(targetTicketId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Missing ticket ID or comment body');
                return;
            }

            // 3. Find the local Ticket
            // NOTE: Check if 'Name' or 'RemoteTicketIdTxt__c' is the correct matching field for your setup.
            // If the URL contains the SF ID, use 'Id'. If it contains 'T-0001', use 'Name'.
            Ticket__c t = [SELECT Id FROM Ticket__c WHERE RemoteTicketIdTxt__c = :targetTicketId LIMIT 1];

            // 4. Create the Comment
            Ticket_Comment__c c = new Ticket_Comment__c(
                TicketId__c = t.Id,
                BodyTxt__c = msgBody,
                AuthorTxt__c = author,
                SourcePk__c = 'Client Org', 
                JiraSyncStatusTxt__c = 'Synced' // No need to sync back immediately
            );
            insert c;

            // 5. Success Response
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Success',
                'commentId' => c.Id
            }));

        } catch (QueryException qe) {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf('Ticket not found: ' + qe.getMessage());
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}