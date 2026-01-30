/**
 * @description Controller for the Comment Stream LWC.
 */
public with sharing class DeliveryHubCommentSender {

    @AuraEnabled
    public static List<Map<String, Object>> getLiveComments(Id requestId) {
        try {
            Request__c req = getRequestInfo(requestId);
            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                return new List<Map<String, Object>>();
            }

            // --- CLEANER SYNTAX HERE ---
            // No need to pass the fallback string; the Service handles it.
            String baseUrl = DeliveryHubCalloutService.getBaseUrl(
                req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            );
            
            String endpoint = baseUrl + 'comments/' + req.RemoteTicketIdTxt__c;
            
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(endpoint);
            httpReq.setMethod('GET');
            httpReq.setTimeout(120000);
            
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

    @AuraEnabled
    public static void postLiveComment(Id requestId, String body) {
        try {
            Request__c req = getRequestInfo(requestId);
            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                throw new AuraHandledException('Offer must be sent before commenting.');
            }

            Map<String, Object> payload = new Map<String, Object>{
                'body' => body,
                'author' => UserInfo.getName() + ' (' + UserInfo.getOrganizationName() + ')'
            };

            // --- CLEANER SYNTAX HERE ---
            String baseUrl = DeliveryHubCalloutService.getBaseUrl(
                req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            );
            
            String endpoint = baseUrl + 'comments/' + req.RemoteTicketIdTxt__c;

            HttpResponse res = DeliveryHubCalloutService.post(endpoint, payload);

            if (res.getStatusCode() >= 300) {
                throw new AuraHandledException('Failed: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Request__c getRequestInfo(Id requestId) {
        return [
            SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
            FROM Request__c 
            WHERE Id = :requestId 
            LIMIT 1
        ];
    }
}