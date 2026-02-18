@IsTest
private class DeliveryHubPollerTest {

    @TestSetup
    static void makeData() {
        insert new Delivery_Hub_Settings__c(AutoCreateRequestFromTicketBool__c = false, AutoSyncNetworkEntityBool__c = false);
        Network_Entity__c vendor = new Network_Entity__c(Name = 'Mothership HQ', StatusPk__c = 'Active', EntityTypePk__c = 'Vendor', RemoteExternalIdTxt__c = 'CLIENT-123');
        insert vendor;
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Poll Test Ticket', StageNamePk__c = 'Backlog');
        insert t;
        insert new Request__c(TicketId__c = t.Id, DeliveryEntityId__c = vendor.Id, StatusPk__c = 'Active', RemoteTicketIdTxt__c = 'MOTHERSHIP-TKT-001');
    }

    @IsTest
    static void testPollUpdatesSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());
        Test.startTest();
        String result = DeliveryHubPoller.pollUpdates();
        Test.stopTest();
        
        System.assert(result.contains('Success'), 'Result should indicate success: ' + result);
        Ticket__c updatedT = [SELECT StageNamePk__c FROM Ticket__c LIMIT 1];
        System.assertEquals('In Development', updatedT.StageNamePk__c, 'Ticket stage should have been updated by the mock payload');
    }
    
    public class MockResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Ingestor maps "StageNamePk__c" -> "delivery__StageNamePk__c"
            String jsonBody = '{"status": "Success", "latestServerTime": "2026-02-18T12:00:00.000Z", "events": [{"objectType": "Ticket__c", "payload": {"SourceId": "MOTHERSHIP-TKT-001", "StageNamePk__c": "In Development"}}]}';
            res.setBody(jsonBody);
            return res;
        }
    }
}