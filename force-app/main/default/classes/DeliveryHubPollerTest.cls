@IsTest
private class DeliveryHubPollerTest {

    @TestSetup
    static void makeData() {
        // 1. Setup Settings
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Create Active Vendor (Mothership)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership HQ',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://mothership.example.com',
            RemoteExternalIdTxt__c = 'CLIENT-123' 
        );
        insert vendor;

        // 3. Setup local Ticket to be updated by the Poller
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Poll Test Ticket',
            StageNamePk__c = 'Backlog'
        );
        insert t;

        // 4. Setup the Ledger bridge
        insert new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'MOTHERSHIP-TKT-001'
        );
    }

    /**
     * @description Happy Path: Verifies that the poller successfully fetches changes,
     * updates the local record via the Ingestor, and marks the sync timestamp.
     */
    @IsTest
    static void testPollUpdatesSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

        Test.startTest();
        String result = DeliveryHubPoller.pollUpdates();
        Test.stopTest();

        // 1. Verify Return Message
        System.assert(result.contains('Success'), 'Result should indicate success: ' + result);
        System.assert(result.contains('Synced 1 items'), 'Result should confirm 1 item was processed');

        // 2. Verify Sync Timestamp on Vendor
        Network_Entity__c vendor = [SELECT LastInboundSyncDateTime__c FROM Network_Entity__c LIMIT 1];
        System.assertNotEquals(null, vendor.LastInboundSyncDateTime__c, 'Timestamp should be updated after successful sync.');

        // 3. Verify the Ticket was actually updated by the Ingestor
        Ticket__c updatedT = [SELECT StageNamePk__c FROM Ticket__c LIMIT 1];
        System.assertEquals('In Development', updatedT.StageNamePk__c, 'Ticket stage should have been updated by the mock payload.');
    }
    
    /**
     * @description Mock implementation for HTTP Success response
     */
    public class MockResponseSuccess implements HttpCalloutMock {
        /**
         * @description Respond with a payload containing 1 Ticket update.
         * @param req The HTTP request
         * @return The HTTP response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Payload uses SourceId to match the RemoteTicketIdTxt__c in the ledger
            String jsonBody = '{' +
                '"status": "Success",' +
                '"latestServerTime": "2026-02-18T12:00:00.000Z",' +
                '"events": [' +
                    '{' +
                        '"objectType": "Ticket__c",' +
                        '"payload": {' +
                            '"SourceId": "MOTHERSHIP-TKT-001",' +
                            '"StageNamePk__c": "In Development"' +
                        '}' +
                    '}' +
                ']' +
            '}';
            
            res.setBody(jsonBody);
            return res;
        }
    }
}