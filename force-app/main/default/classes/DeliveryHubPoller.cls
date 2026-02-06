/**
 * @description Client-side logic to poll the Mothership for updates.
 * Handles the HTTP callout and processing of the response.
 */
public without sharing class DeliveryHubPoller {

    /**
     * @description Main method to pull updates from the Mothership.
     * @return String Status message indicating success or failure count.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    @AuraEnabled
    public static String pollUpdates() {
        try {
            // 1. Get Active Vendor (Mothership)
            // Query runs in System Mode implicitly in Apex
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
                // 3. Process Results
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> events = (List<Object>) response.get('events');
                
                Integer successCount = 0;

                for (Object itemObj : events) {
                    Map<String, Object> item = (Map<String, Object>) itemObj;
                    String objectType = (String) item.get('objectType');
                    Map<String, Object> payload = (Map<String, Object>) item.get('payload');
                    
                    try {
                        DeliveryHubSyncService.processSync(objectType, payload);
                        successCount++;
                    } catch(Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Sync Error for ' + objectType + ': ' + e.getMessage());
                    }
                }

                // 4. Update High-Water Mark
                String serverTimeStr = (String) response.get('latestServerTime');
                if (serverTimeStr != null) {
                    vendor.LastInboundSyncDateTime__c = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
                    // Use AccessLevel.SYSTEM_MODE for DML to ensure it saves regardless of user perms
                    Database.update(vendor, AccessLevel.SYSTEM_MODE);
                }

                return 'Success: Synced ' + successCount + ' items.';
            } else {
                return 'Error: HTTP ' + res.getStatusCode() + ' ' + res.getBody();
            }

        } catch (Exception e) {
            return 'Exception: ' + e.getMessage() + ' ' + e.getStackTraceString();
        }
    }
}