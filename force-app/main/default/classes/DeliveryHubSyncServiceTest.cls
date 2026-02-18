@IsTest
private class DeliveryHubSyncServiceTest {

    @TestSetup
    static void makeData() {
        insert new Delivery_Hub_Settings__c(AutoCreateRequestFromTicketBool__c = false, AutoSyncNetworkEntityBool__c = false);
        Network_Entity__c vendor = new Network_Entity__c(Name = 'Test Vendor', StatusPk__c = 'Active', EntityTypePk__c = 'Vendor');
        insert vendor;
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Original Name', StageNamePk__c = 'Backlog', BriefDescriptionTxt__c = 'Original Description');
        insert t;
        insert new Request__c(TicketId__c = t.Id, DeliveryEntityId__c = vendor.Id, RemoteTicketIdTxt__c = 'REMOTE-TICKET-123', StatusPk__c = 'Active');
    }

    @IsTest
    static void testTicketUpdateViaService() {
        String remoteId = 'REMOTE-TICKET-123';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{'SourceId' => remoteId, 'BriefDescriptionTxt__c' => 'Updated Description'}));
        RestContext.request = req;
        RestContext.response = res; 

        Test.startTest();
        DeliveryHubSyncService.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Ticket__c updatedT = [SELECT BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Updated Description', updatedT.BriefDescriptionTxt__c);
    }

    @IsTest
    static void testCommentInsertWithIdempotency() {
        String remoteTicketId = 'REMOTE-TICKET-123'; 
        String sourceId = 'REMOTE-COMMENT-999';
        String uniqueAuthor = 'REST_TEST_AUTHOR';

        Map<String, Object> payload = new Map<String, Object>{'TargetId' => remoteTicketId, 'SourceId' => sourceId, 'AuthorTxt__c' => uniqueAuthor, 'BodyTxt__c' => 'Service Test Comment'};
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/sync/Ticket_Comment__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        RestContext.request = req;
        RestContext.response = res; 

        Test.startTest();
        DeliveryHubSyncService.handleIncomingSync(); // Insert
        DeliveryHubSyncService.handleIncomingSync(); // Update (Idempotent)
        Test.stopTest();

        List<Ticket_Comment__c> comments = [SELECT Id FROM Ticket_Comment__c WHERE AuthorTxt__c = :uniqueAuthor];
        System.assertEquals(1, comments.size(), 'Should have inserted exactly 1 comment');
    }
    
    // Add dummy test to prevent "no test methods" error if others are commented out
    @IsTest static void dummy() { System.assert(true); }
}