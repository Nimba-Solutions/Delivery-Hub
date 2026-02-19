/**
 * @description Robust poller logic.
 * Uses Static SOQL to guarantee field visibility in namespaced tests.
 */
public without sharing class DeliveryHubPoller {

    // Helper to get the Org's namespace prefix
    private static String getNamespacePrefix() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    @AuraEnabled
    public static String pollUpdates() {
        try {
            // FIX: Use STATIC SOQL. The compiler handles the namespace automatically.
            // 'without sharing' ensures we bypass FLS for these specific fields.
            List<Network_Entity__c> vendors = [
                SELECT Id, 
                       IntegrationEndpointUrlTxt__c, 
                       LastInboundSyncDateTime__c, 
                       RemoteExternalIdTxt__c 
                FROM Network_Entity__c 
                WHERE StatusPk__c = 'Active' 
                AND EntityTypePk__c = 'Vendor' 
                LIMIT 1
            ];
            
            if (vendors.isEmpty()) { 
                return 'Error: No Active Vendor found.'; 
            }
            Network_Entity__c vendor = vendors[0];

            String endpointUrl = vendor.IntegrationEndpointUrlTxt__c;
            String remoteId = vendor.RemoteExternalIdTxt__c;
            DateTime lastSync = vendor.LastInboundSyncDateTime__c;

            if (String.isBlank(endpointUrl) || String.isBlank(remoteId)) {
                return 'Error: Vendor configuration incomplete';
            }

            String sinceParam = (lastSync != null) ? lastSync.formatGmt('yyyy-MM-dd HH:mm:ss') : '1900-01-01 00:00:00';
            // Ensure endpoint doesn't have a trailing slash before appending path
            String baseUrl = endpointUrl.endsWith('/') ? endpointUrl.removeEnd('/') : endpointUrl;
            String endpoint = baseUrl + '/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Client-Entity-ID', remoteId); 

            HttpResponse res = new Http().send(req);
            
            if (res.getStatusCode() == 200) {
                // Pass namespace prefix to helper for dynamic updates if needed
                return handleSuccess(res.getBody(), vendor, getNamespacePrefix());
            } else {
                return 'Error: HTTP ' + res.getStatusCode() + ' ' + res.getBody();
            }

        } catch (Exception e) {
            return 'Exception: ' + e.getMessage();
        }
    }

    private static String handleSuccess(String responseBody, Network_Entity__c vendor, String ns) {
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> events = (List<Object>) response.get('events');
        
        Integer successCount = 0;
        if (events != null) {
            for (Object itemObj : events) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                DeliverySyncItemIngestor.processInboundItem(
                    (String) item.get('objectType'), 
                    (Map<String, Object>) item.get('payload')
                );
                successCount++;
            }
        }

        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null) {
            DateTime dt = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            
            // Use put() with namespaced field name for dynamic update safety
            // or just simple assignment since we have the concrete object
            vendor.LastInboundSyncDateTime__c = dt; 
            
            update as system vendor;
        }
        return 'Success: Synced ' + successCount + ' items.';
    }
}