/**
 * @description Client-side logic to poll the Mothership for updates.
 * Handles the HTTP callout and processing of the response.
 */
public without sharing class DeliveryHubPoller {

    /**
     * @description Main method to pull updates from the Mothership.
     * @return String Status message indicating success or failure count.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation')
    @AuraEnabled
    public static String pollUpdates() {
        try {
            // 1. Get Active Vendor (Mothership)
            Network_Entity__c vendor = [
                SELECT Id, IntegrationEndpointUrlTxt__c, LastInboundSyncDateTime__c, RemoteExternalIdTxt__c 
                FROM Network_Entity__c 
                WHERE StatusPk__c = 'Active' 
                AND EntityTypePk__c = 'Vendor' 
                LIMIT 1
            ];

            if (String.isBlank(vendor.IntegrationEndpointUrlTxt__c)) {
                return 'Error: Vendor URL missing';
            }
            if (String.isBlank(vendor.RemoteExternalIdTxt__c)) {
                return 'Error: Remote ID (My ID) missing on Vendor record';
            }

            // 2. Prepare Request
            String sinceParam = (vendor.LastInboundSyncDateTime__c != null) 
                ? vendor.LastInboundSyncDateTime__c.formatGmt('yyyy-MM-dd HH:mm:ss')
                : '1900-01-01 00:00:00';

            String endpoint = vendor.IntegrationEndpointUrlTxt__c + '/services/apexrest/delivery/v1/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Client-Entity-ID', vendor.RemoteExternalIdTxt__c); 
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId()); 

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return handleSuccess(res.getBody(), vendor);
            } else {
                return 'Error: HTTP ' + res.getStatusCode() + ' ' + res.getBody();
            }

        } catch (Exception e) {
            return 'Exception: ' + e.getMessage() + ' ' + e.getStackTraceString();
        }
    }

    /**
     * @description Helper to process the successful JSON response.
     * @param responseBody The JSON string from the server.
     * @param vendor The vendor record to update with the new high-water mark.
     * @return Status string.
     */
    private static String handleSuccess(String responseBody, Network_Entity__c vendor) {
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> events = (List<Object>) response.get('events');
        
        Integer successCount = processEvents(events);

        // Update High-Water Mark
        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null) {
            vendor.LastInboundSyncDateTime__c = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            // AccessLevel.SYSTEM_MODE ensures the timestamp updates regardless of user perms
            Database.update(vendor, AccessLevel.SYSTEM_MODE);
        }

        return 'Success: Synced ' + successCount + ' items.';
    }

    /**
     * @description Helper to loop through events and call the service.
     * @param events List of event objects.
     * @return Count of successfully processed items.
     */
    private static Integer processEvents(List<Object> events) {
        Integer count = 0;
        for (Object itemObj : events) {
            Map<String, Object> item = (Map<String, Object>) itemObj;
            try {
                DeliveryHubSyncService.processSync(
                    (String) item.get('objectType'), 
                    (Map<String, Object>) item.get('payload')
                );
                count++;
            } catch(Exception e) {
                System.debug(LoggingLevel.ERROR, 'Sync Error: ' + e.getMessage());
            }
        }
        return count;
    }
}