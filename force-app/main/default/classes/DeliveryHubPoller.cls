/**
 * @description Schedulable class to trigger the Delivery Hub Poller.
 * Runs in the background to keep the Client Org in sync with the Mothership.
 */
public class DeliveryHubScheduler implements Schedulable {

    /**
     * @description Schedulable execute method. 
     * Delegates to an async method immediately to allow for HTTP Callouts.
     * @param sc The SchedulableContext (standard system parameter).
     */
    public void execute(SchedulableContext sc) {
        runSyncAsync();
    }

    /**
     * @description Future method to perform the HTTP Callout to the Mothership.
     * Required because SchedulableContext cannot perform synchronous callouts.
     */
    @future(callout=true)
    public static void runSyncAsync() {
        String result = DeliveryHubPoller.pollUpdates();
        
        if (!result.contains('Success') && !result.contains('Synced 0 items')) {
            System.debug(LoggingLevel.ERROR, 'Delivery Hub Sync Failed: ' + result);
        }
    }
}

/**
 * @description Poller logic to fetch delta updates from the Mothership.
 * Uses OrgIdTxt__c from Metadata to identify the correct Vendor record.
 */
public without sharing class DeliveryHubPoller {

    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation, PMD.ApexSOQLInjection')
    @AuraEnabled
    public static String pollUpdates() {
        try {
            String ns = getNamespace();
            
            // 1. Get Mothership Config to find the SPECIFIC record (Prevents duplication issues)
            Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
            
            // If we don't have metadata, we can't safely know which Vendor is the 'Mothership'
            if (config == null) {
                return 'Error: Custom Metadata configuration missing.';
            }

            // 2. DYNAMIC SOQL - Query by the unique OrgId anchor
            String query = 'SELECT Id, ' + 
                           ns + 'IntegrationEndpointUrlTxt__c, ' + 
                           ns + 'LastInboundSyncDateTime__c, ' + 
                           ns + 'RemoteExternalIdTxt__c ' +
                           'FROM ' + ns + 'Network_Entity__c ' +
                           'WHERE ' + ns + 'StatusPk__c = \'Active\' ' +
                           'AND ' + ns + 'Name LIKE \'Cloud Nimbus LLC%\' ' +
                           'LIMIT 1';

            List<SObject> results = Database.query(query);
            
            if (results.isEmpty()) {
                return 'Error: No Active Mothership Vendor found. Run Setup first.';
            }
            SObject vendor = results[0];

            // 3. GET FIELDS DYNAMICALLY
            String endpointUrl = (String) vendor.get(ns + 'IntegrationEndpointUrlTxt__c');
            String remoteId = (String) vendor.get(ns + 'RemoteExternalIdTxt__c');
            DateTime lastSync = (DateTime) vendor.get(ns + 'LastInboundSyncDateTime__c');

            if (String.isBlank(endpointUrl)) {
                return 'Error: Vendor URL missing';
            }
            if (String.isBlank(remoteId)) {
                return 'Error: Remote ID (My ID) missing on Vendor record';
            }

            // 4. PREPARE REQUEST
            String sinceParam = (lastSync != null) 
                ? lastSync.formatGmt('yyyy-MM-dd HH:mm:ss')
                : '1900-01-01 00:00:00';

            // Ensure no double slashes
            if (endpointUrl.endsWith('/')) {
                endpointUrl = endpointUrl.removeEnd('/');
            }

            String endpoint = endpointUrl + '/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8');
            
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

    private static String handleSuccess(String responseBody, Network_Entity__c vendor, String ns) {
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> events = (List<Object>) response.get('events');
        
        // Process the individual payloads
        Integer successCount = (events != null) ? processEvents(events) : 0;

        // Update the High Water Mark (Last Sync Date)
        String serverTimeStr = (String) response.get('latestServerTime');
        if (serverTimeStr != null) {
            // Using JSON deserialize to handle the ISO format correctly
            DateTime dt = (DateTime) JSON.deserialize('"' + serverTimeStr + '"', DateTime.class);
            vendor.put(ns + 'LastInboundSyncDateTime__c', dt);
            
            // Bypass CRUD for system-level sync update
            Database.update(vendor, AccessLevel.SYSTEM_MODE);
        }
        
        return 'Success: Synced ' + successCount + ' items.';
    }

    private static Integer processEvents(List<Object> events) {
        Integer count = 0;
        for (Object itemObj : events) {
            Map<String, Object> item = (Map<String, Object>) itemObj;
            try {
                // Delegate to the service that handles record upserts/updates
                DeliveryHubSyncService.processSync(
                    (String) item.get('objectType'), 
                    (Map<String, Object>) item.get('payload')
                );
                count++;
            } catch(Exception e) {
                System.debug(LoggingLevel.ERROR, 'Individual Record Sync Error: ' + e.getMessage());
            }
        }
        return count;
    }
}