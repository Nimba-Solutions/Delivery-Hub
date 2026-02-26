/**
 * @description Test class for DeliveryHubPoller.
 * Uses dynamic field population to ensure data is created correctly in namespaced environments.
 * V2 Architecture: Uses direct JSON array parsing and stringified payload processing.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubPollerTest {

    // Helper to get the Org's namespace prefix
    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    @TestSetup
    static void makeData() {
        String ns = getNamespace();

        // 1. Setup Settings (Dynamic SObject to handle namespace)
        SObject settings = (SObject) Type.forName(ns + 'Delivery_Hub_Settings__c').newInstance();
        settings.put(ns + 'AutoCreateRequestFromTicketBool__c', false);
        settings.put(ns + 'AutoSyncNetworkEntityBool__c', false);
        insert settings;

        // 2. Create Active Vendor (Mothership) - FORCED POPULATION
        SObject vendor = (SObject) Type.forName(ns + 'Network_Entity__c').newInstance();
        vendor.put('Name', 'Mothership HQ');
        vendor.put(ns + 'StatusPk__c', 'Active');
        vendor.put(ns + 'EntityTypePk__c', 'Vendor');
        // This is the field that was failing to populate:
        vendor.put(ns + 'IntegrationEndpointUrlTxt__c', 'https://mothership.example.com');
        vendor.put(ns + 'RemoteExternalIdTxt__c', 'CLIENT-123');
        insert vendor;

        // 3. Setup local Ticket
        SObject t = (SObject) Type.forName(ns + 'WorkItem__c').newInstance();
        t.put(ns + 'BriefDescriptionTxt__c', 'Poll Test Ticket');
        t.put(ns + 'StageNamePk__c', 'Backlog');
        insert t;

        // 4. Setup the Ledger bridge
        SObject req = (SObject) Type.forName(ns + 'WorkRequest__c').newInstance();
        req.put(ns + 'WorkItemId__c', t.get('Id'));
        req.put(ns + 'DeliveryEntityId__c', vendor.get('Id'));
        req.put(ns + 'StatusPk__c', 'Active');
        req.put(ns + 'RemoteTicketIdTxt__c', 'MOTHERSHIP-TKT-001');
        insert req;
    }

    @IsTest
    static void testPollUpdatesSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

        Test.startTest();
        String result = DeliveryHubPoller.pollUpdates();
        Test.stopTest();

        // 1. Verify Return Message
        System.assert(result.contains('Success'), 'Result should indicate success: ' + result);
        System.assert(result.contains('Synced 1 items'), 'Result should confirm 1 item was processed');

        // 2. Verify Data Update (Dynamic Query to be safe)
        String ns = getNamespace();
        String q = 'SELECT ' + ns + 'StageNamePk__c FROM ' + ns + 'WorkItem__c LIMIT 1';
        SObject updatedT = Database.query(q);
        
        System.assertEquals('In Development', (String)updatedT.get(ns + 'StageNamePk__c'), 'Ticket stage should have been updated by the mock payload.');
    }
    
    public class MockResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // V2 ARCHITECTURE: Payload is now a direct JSON array.
            // Notice the inner "payload" value is escaped as a string, matching the Vendor's database storage format.
            String jsonBody = '[' +
                '{' +
                    '"objectType": "WorkItem__c",' +
                    '"payload": "{\\"SourceId\\": \\"MOTHERSHIP-TKT-001\\", \\"StageNamePk__c\\": \\"In Development\\"}",' +
                    '"syncItemId": "a0D000000000000EAA",' +
                    '"createdDate": "2026-02-18T12:00:00.000Z"' +
                '}' +
            ']';
            
            res.setBody(jsonBody);
            return res;
        }
    }
}