/**
 * @description Robust poller that handles namespace-prefixed fields automatically.
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
            String ns = getNamespacePrefix();
            
            // Use Dynamic SOQL to guarantee correct field resolution in namespaced orgs
            String query = 'SELECT Id, ' + ns + 'IntegrationEndpointUrlTxt__c, ' + ns + 'LastInboundSyncDateTime__c, ' + ns + 'RemoteExternalIdTxt__c ' +
                           'FROM ' + ns + 'Network_Entity__c ' +
                           'WHERE ' + ns + 'StatusPk__c = \'Active\' AND ' + ns + 'EntityTypePk__c = \'Vendor\' ' +
                           'LIMIT 1';

            // AccessLevel.SYSTEM_MODE ensures we get the data regardless of User permissions
            List<SObject> vendors = Database.query(query, AccessLevel.SYSTEM_MODE);
            
            if (vendors.isEmpty()) { return 'Error: No Active Vendor found.'; }
            SObject vendor = vendors[0];

            String endpointUrl = (String) vendor.get(ns + 'IntegrationEndpointUrlTxt__c');
            String remoteId = (String) vendor.get(ns + 'RemoteExternalIdTxt__c');
            DateTime lastSync = (DateTime) vendor.get(ns + 'LastInboundSyncDateTime__c');

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
            return (res.getStatusCode() == 200) ? handleSuccess(res.getBody(), (Network_Entity__c)vendor, ns) : 'Error: HTTP ' + res.getStatusCode();

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
                DeliverySyncItemIngestor.processInboundItem((String) item.get('objectType'), (Map<String, Object>) item.get('payload'));
                successCount++;
            }
        }

        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null) {
            DateTime dt = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            vendor.put(ns + 'LastInboundSyncDateTime__c', dt);
            Database.update(vendor, AccessLevel.SYSTEM_MODE);
        }
        return 'Success: Synced ' + successCount + ' items.';
    }
}