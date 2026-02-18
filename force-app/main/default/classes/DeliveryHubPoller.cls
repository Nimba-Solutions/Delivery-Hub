/**
 * @description Poller logic to fetch delta updates from the Mothership.
 * Uses the Network_Entity__c record to manage the sync "High Water Mark".
 */
public without sharing class DeliveryHubPoller {

    /**
     * @description Detects the namespace prefix for namespaced scratch orgs.
     * @return String prefix (e.g., 'delivery__') or empty string.
     */
    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    /**
     * @description Main entry point for polling updates. Fetches changes since the last sync.
     * @return String Status message indicating success or specific error details.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation, PMD.ApexSOQLInjection')
    @AuraEnabled
    public static String pollUpdates() {
        try {
            String ns = getNamespace();

            // 1. DYNAMIC SOQL to find the Active Mothership/Vendor
            String query = 'SELECT Id, ' + 
                           ns + 'IntegrationEndpointUrlTxt__c, ' + 
                           ns + 'LastInboundSyncDateTime__c, ' + 
                           ns + 'RemoteExternalIdTxt__c ' +
                           'FROM ' + ns + 'Network_Entity__c ' +
                           'WHERE ' + ns + 'StatusPk__c = \'Active\' ' +
                           'AND ' + ns + 'EntityTypePk__c = \'Vendor\' ' +
                           'LIMIT 1';

            List<SObject> results = Database.query(query);
            
            if (results.isEmpty()) {
                return 'Error: No Active Vendor found.';
            }
            SObject vendor = results[0];

            // 2. Extract configuration fields
            String endpointUrl = (String) vendor.get(ns + 'IntegrationEndpointUrlTxt__c');
            String remoteId = (String) vendor.get(ns + 'RemoteExternalIdTxt__c');
            DateTime lastSync = (DateTime) vendor.get(ns + 'LastInboundSyncDateTime__c');

            if (String.isBlank(endpointUrl)) {
                return 'Error: Vendor URL missing';
            }
            if (String.isBlank(remoteId)) {
                return 'Error: Remote ID (My ID) missing on Vendor record';
            }

            // 3. Prepare the "Since" parameter for delta sync
            String sinceParam = (lastSync != null) 
                ? lastSync.formatGmt('yyyy-MM-dd HH:mm:ss')
                : '1900-01-01 00:00:00';

            if (endpointUrl.endsWith('/')) {
                endpointUrl = endpointUrl.removeEnd('/');
            }
            
            String endpoint = endpointUrl + '/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8');
            
            // 4. Perform the HTTP GET
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Client-Entity-ID', remoteId); 
            req.setTimeout(60000);

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

    /**
     * @description Processes a successful response and updates the sync timestamp.
     * @param responseBody Raw JSON response from the Mothership.
     * @param vendor The Network_Entity__c record being updated.
     * @param ns The detected namespace prefix.
     * @return String status summary.
     */
    private static String handleSuccess(String responseBody, Network_Entity__c vendor, String ns) {
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> events = (List<Object>) response.get('events');
        
        Integer successCount = (events != null) ? processEvents(events) : 0;

        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null && (successCount > 0 || events == null || events.isEmpty())) {
            DateTime dt = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            vendor.put(ns + 'LastInboundSyncDateTime__c', dt);
            Database.update(vendor, AccessLevel.SYSTEM_MODE);
        }
        return 'Success: Synced ' + successCount + ' items.';
    }

    /**
     * @description Iterates through events and hands them off to the Ingestor logic.
     * @param events List of event objects from the Mothership.
     * @return Integer number of successfully processed events.
     */
    private static Integer processEvents(List<Object> events) {
        Integer count = 0;
        for (Object itemObj : events) {
            Map<String, Object> item = (Map<String, Object>) itemObj;
            try {
                // FIXED: Pointing to the new ingestor class and method
                DeliverySyncItemIngestor.processInboundItem(
                    (String) item.get('objectType'), 
                    (Map<String, Object>) item.get('payload')
                );
                count++;
            } catch(Exception e) {
                System.debug(LoggingLevel.ERROR, 'Sync Record Error: ' + e.getMessage());
            }
        }
        return count;
    }
}