public without sharing class DeliveryHubPoller {

    // Helper: Detects if we are in a Managed Package ('delivery__') or Scratch Org ('')
    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    // FIX: Added 'PMD.ApexSOQLInjection' to suppress the false positive on dynamic query
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation, PMD.ApexSOQLInjection')
    @AuraEnabled
    public static String pollUpdates() {
        try {
            String ns = getNamespace();

            // 1. DYNAMIC SOQL
            String query = 'SELECT Id, ' + 
                           ns + 'IntegrationEndpointUrlTxt__c, ' + 
                           ns + 'LastInboundSyncDateTime__c, ' + 
                           ns + 'RemoteExternalIdTxt__c ' +
                           'FROM ' + ns + 'Network_Entity__c ' +
                           'WHERE ' + ns + 'StatusPk__c = \'Active\' ' +
                           'AND ' + ns + 'EntityTypePk__c = \'Vendor\' ' +
                           'LIMIT 1';

            List<SObject> results = Database.query(query);
            
            // FIX: Added curly braces
            if (results.isEmpty()) {
                return 'Error: No Active Vendor found.';
            }
            SObject vendor = results[0];

            // 2. GET FIELDS DYNAMICALLY
            String endpointUrl = (String) vendor.get(ns + 'IntegrationEndpointUrlTxt__c');
            String remoteId = (String) vendor.get(ns + 'RemoteExternalIdTxt__c');
            DateTime lastSync = (DateTime) vendor.get(ns + 'LastInboundSyncDateTime__c');

            // FIX: Added curly braces
            if (String.isBlank(endpointUrl)) {
                return 'Error: Vendor URL missing';
            }
            if (String.isBlank(remoteId)) {
                return 'Error: Remote ID (My ID) missing on Vendor record';
            }

            // 3. PREPARE REQUEST
            String sinceParam = (lastSync != null) 
                ? lastSync.formatGmt('yyyy-MM-dd HH:mm:ss')
                : '1900-01-01 00:00:00';

            String endpoint = endpointUrl + '/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Client-Entity-ID', remoteId); 
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId()); 

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return handleSuccess(res.getBody(), (Network_Entity__c)vendor, ns);
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
        Integer successCount = processEvents(events);

        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null) {
            DateTime dt = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            
            // Dynamic Update
            vendor.put(ns + 'LastInboundSyncDateTime__c', dt);
            Database.update(vendor, AccessLevel.SYSTEM_MODE);
        }
        return 'Success: Synced ' + successCount + ' items.';
    }

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