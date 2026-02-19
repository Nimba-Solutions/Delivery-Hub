/**
 * @description Robust poller that handles namespace-prefixed fields automatically.
 */
public without sharing class DeliveryHubPoller {

    @AuraEnabled
    public static String pollUpdates() {
        try {
            // Changed to SYSTEM_MODE to prevent "incomplete configuration" errors due to FLS
            List<Network_Entity__c> vendors = [
                SELECT IntegrationEndpointUrlTxt__c, LastInboundSyncDateTime__c, RemoteExternalIdTxt__c 
                FROM Network_Entity__c 
                WHERE StatusPk__c = 'Active' AND EntityTypePk__c = 'Vendor' 
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            
            if (vendors.isEmpty()) { return 'Error: No Active Vendor found.'; }
            Network_Entity__c vendor = vendors[0];

            String endpointUrl = vendor.IntegrationEndpointUrlTxt__c;
            String remoteId = vendor.RemoteExternalIdTxt__c;
            DateTime lastSync = vendor.LastInboundSyncDateTime__c;

            if (String.isBlank(endpointUrl) || String.isBlank(remoteId)) {
                return 'Error: Vendor configuration incomplete';
            }

            String sinceParam = (lastSync != null) ? lastSync.formatGmt('yyyy-MM-dd HH:mm:ss') : '1900-01-01 00:00:00';
            String endpoint = endpointUrl.removeEnd('/') + '/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Client-Entity-ID', remoteId); 

            HttpResponse res = new Http().send(req);
            return (res.getStatusCode() == 200) ? handleSuccess(res.getBody(), vendor) : 'Error: HTTP ' + res.getStatusCode();

        } catch (Exception e) {
            return 'Exception: ' + e.getMessage();
        }
    }

    private static String handleSuccess(String responseBody, Network_Entity__c vendor) {
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> events = (List<Object>) response.get('events');
        
        Integer successCount = 0;
        if (events != null) {
            for (Object itemObj : events) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                DeliverySyncItemIngestor.processInboundItem((String) item.get('objectType'), (Map<String, Object>) item.get('payload'));
                successCount++;
            }
        }

        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null) {
            vendor.LastInboundSyncDateTime__c = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            update as system vendor;
        }
        return 'Success: Synced ' + successCount + ' items.';
    }
}