@IsTest
private class DeliveryHubOutboundResourceTest {

    @TestSetup
    static void makeData() {
        // 1. Create Client Entity (The "Who")
        Network_Entity__c client = new Network_Entity__c(
            Name = 'Test Client Org',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Client',
            IntegrationEndpointUrlTxt__c = 'https://client.example.com'
        );
        insert client;

        // 2. Create Ticket assigned to this Client
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Client Ticket',
            ClientNetworkEntityId__c = client.Id, // IMPORTANT: The Link
            StageNamePk__c = 'Backlog'
        );
        insert t;

        // 3. Create Sync Item (The Data)
        // We manually insert this to simulate the Engine's work
        Sync_Item__c item = new Sync_Item__c(
            ObjectTypePk__c = 'Ticket__c',
            PayloadTxt__c = '{"Action":"Update", "Stage":"Backlog"}',
            TicketId__c = t.Id, // Link to Ticket -> Link to Client
            StatusPk__c = 'Queued'
        );
        insert item;
    }

    @IsTest
    static void testGetChangesSuccess() {
        Network_Entity__c client = [SELECT Id FROM Network_Entity__c LIMIT 1];

        Test.startTest();
        // Setup REST Context
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/v1/sync/changes';
        req.httpMethod = 'GET';
        req.addHeader('Client-Entity-ID', client.Id); // Authenticate
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        DeliveryHubOutboundResource.getChanges();
        Test.stopTest();

        // Verify
        System.assertEquals(200, res.statusCode);
        
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('Success', response.get('status'));
        //System.assertEquals(1, response.get('count'), 'Should find 1 Sync Item');
        
        //List<Object> events = (List<Object>) response.get('events');
        //Map<String, Object> event = (Map<String, Object>) events[0];
        //System.assertEquals('Ticket__c', event.get('objectType'));
    }

    @IsTest
    static void testGetChangesMissingHeader() {
        Test.startTest();
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/v1/sync/changes';
        req.httpMethod = 'GET';
        // Missing 'Client-Entity-ID' header
        
        RestContext.request = req;
        RestContext.response = res;
        
        DeliveryHubOutboundResource.getChanges();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}