/**
 * @description Controller for the Comment Stream LWC.
 */
public with sharing class DeliveryHubCommentSender {

    // Default Base URL matches the Setup Controller
    private static final String DEFAULT_BASE_URL = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/delivery/deliveryhub/v1';

    /**
     * @description Fetches the live conversation from the Mothership
     * @param requestId The ID of the Request record.
     * @return List<Map<String, Object>> Comment list.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getLiveComments(Id requestId) {
        try {
            Request__c req = getRequestInfo(requestId);
            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                return new List<Map<String, Object>>();
            }

            // Construct URL: .../deliveryhub/v1/comments/{RemoteTicketId}
            String endpoint = getBaseUrl(req) + 'comments/' + req.RemoteTicketIdTxt__c;
            
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
     * @param requestId The ID of the Request.
     * @param body The comment body.
     */
    @AuraEnabled
    public static void postLiveComment(Id requestId, String body) {
        try {
            Request__c req = getRequestInfo(requestId);
            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                throw new AuraHandledException('Offer must be sent before commenting.');
            }

            // Construct URL: .../deliveryhub/v1/comments/{RemoteTicketId}
            String endpoint = getBaseUrl(req) + 'comments/' + req.RemoteTicketIdTxt__c;
            
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

    /**
     * @description Calculates the base URL from the Entity record or default.
     */
    private static String getBaseUrl(Request__c req) {
        String base = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
        
        if (String.isBlank(base)) {
            base = DEFAULT_BASE_URL;
        }

        // Ensure proper slash formatting
        if (!base.endsWith('/')) {
            base += '/';
        }
        
        return base;
    }

    private static Request__c getRequestInfo(Id requestId) {
        // Suppress CRUD check if necessary, or use WITH USER_MODE if your users have permissions
        return [
            SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
            FROM Request__c 
            WHERE Id = :requestId 
            LIMIT 1
        ];
    }
}