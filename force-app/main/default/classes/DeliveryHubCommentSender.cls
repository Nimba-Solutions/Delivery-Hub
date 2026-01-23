/**
 * @description Controller for the Comment Stream LWC.
 * Handles fetching and posting comments via the Mothership API.
 */
public with sharing class DeliveryHubCommentSender {

    /**
     * @description Fetches the live conversation from the Mothership
     * @param requestId The ID of the Request record to fetch comments for.
     * @return List<Map<String, Object>> A list of comment objects.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getLiveComments(Id requestId) {
        try {
            Request__c req = getRequestInfo(requestId);
            // FIX: Added curly braces
            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                return new List<Map<String, Object>>();
            }

            String endpoint = getBaseUrl(req) + '/' + req.RemoteTicketIdTxt__c;

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('GET');
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

            if (res.getStatusCode() == 200) {
                List<Object> rawList = (List<Object>) JSON.deserializeUntyped(res.getBody());
                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (Object obj : rawList) {
                    result.add((Map<String, Object>) obj);
                }
                return result;
            }
            return new List<Map<String, Object>>();
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Posts a new comment to the Mothership
     * @param requestId The ID of the Request record.
     * @param body The text content of the comment.
     */
    @AuraEnabled
    public static void postLiveComment(Id requestId, String body) {
        try {
            Request__c req = getRequestInfo(requestId);
            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                throw new AuraHandledException('Offer must be sent before commenting.');
            }

            String endpoint = getBaseUrl(req) + '/' + req.RemoteTicketIdTxt__c;
            
            Map<String, Object> payload = new Map<String, Object>{
                'body' => body,
                'author' => UserInfo.getName() + ' (' + UserInfo.getOrganizationName() + ')'
            };

            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

            if (res.getStatusCode() >= 300) {
                throw new AuraHandledException('Failed: ' + res.getBody());
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // Helper to get URL and clean it up (replaces /intake with /comments)
    private static String getBaseUrl(Request__c req) {
        String base = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
        return base.replace('/intake', '/comments');
    }

    private static Request__c getRequestInfo(Id requestId) {
        // FIX: Added WITH USER_MODE for security compliance
        return [
            SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
            FROM Request__c 
            WHERE Id = :requestId 
            WITH USER_MODE
            LIMIT 1
        ];
    }
}