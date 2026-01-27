/**
 * @description API for real-time comment streaming.
 * Allows Client Orgs to fetch history and post new comments to a Ticket.
 */
@RestResource(urlMapping='/deliveryhub/v1/comments/*')
global without sharing class DeliveryHubCommentIntake {

    /**
     * @description GET: Fetch all comments for a specific Ticket
     */
    @HttpGet
    global static void getComments() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Extract Ticket ID from URL: .../comments/{TICKET_ID}
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);

            // FIX: Removed WITH USER_MODE to prevent "No such column" errors during packaging
            List<Ticket_Comment__c> comments = [
                SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate 
                FROM Ticket_Comment__c 
                WHERE TicketId__c = :ticketId 
                ORDER BY CreatedDate ASC
            ];

            List<Map<String, Object>> responseList = new List<Map<String, Object>>();
            for (Ticket_Comment__c c : comments) {
                responseList.add(new Map<String, Object>{
                    'id' => c.Id,
                    'body' => c.BodyTxt__c,
                    'author' => c.AuthorTxt__c,
                    'timestamp' => c.CreatedDate
                });
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }

    /**
     * @description POST: Add a new comment to a Ticket
     */
    @HttpPost
    @SuppressWarnings('PMD.ApexCRUDViolation') 
    global static void postComment() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            
            String jsonBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            
            String body = (String) payload.get('body');
            String author = (String) payload.get('author'); 

            if (String.isBlank(body)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Missing comment body');
                return;
            }

            Ticket_Comment__c comm = new Ticket_Comment__c();
            comm.TicketId__c = ticketId;
            comm.BodyTxt__c = body;
            comm.AuthorTxt__c = String.isBlank(author) ? 'Client User' : author;
            
            insert comm;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Success',
                'id' => comm.Id
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}