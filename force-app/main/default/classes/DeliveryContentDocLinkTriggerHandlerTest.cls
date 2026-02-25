/**
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryContentDocLinkTriggerHandlerTest {

    @IsTest
    static void testHandleAfterInsertWithTicket() {
        // 1. Prevent infinite test queues
        DeliverySyncEngine.isSyncContext = false; // Ensure it's false to allow outbound sync
        
        // 2. Setup Routing Data (This is what was missing!)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            IntegrationEndpointUrlTxt__c = 'https://example.com/api',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor'
        );
        insert vendor;

        Ticket__c ticket = new Ticket__c();
        insert ticket;

        Request__c req = new Request__c(
            TicketId__c = ticket.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteTicketIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'Open'
        );
        insert req;

        // 3. Setup File
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test file body')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        // 4. Attach File to Ticket
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = ticket.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        insert link; 
        Test.stopTest();

        // 5. Verify the Unified Ledger successfully generated an item!
        List<Sync_Item__c> items = [SELECT Id, ObjectTypePk__c FROM Sync_Item__c WHERE ObjectTypePk__c = 'ContentVersion'];
        System.assertEquals(1, items.size(), 'Should have generated exactly 1 Sync Item for the attached file');
    }

    @IsTest
    static void testHandleAfterInsertNonTicketRecord() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Another File',
            PathOnClient = 'AnotherFile.txt',
            VersionData = Blob.valueOf('Another file body')
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        insert link;
        Test.stopTest();

        // Should completely ignore files attached to Accounts
        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE ObjectTypePk__c = 'ContentVersion'];
        System.assertEquals(0, items.size(), 'Should not generate a Sync Item for non-ticket files');
    }
}