@isTest
private class DeliveryHubSyncHandlerTest {

    @testSetup
    static void setupData() {
        // 1. Create Network/Delivery Entity
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Node',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://example.com/api'
        );
        insert entity;

        // 2. Create Ticket
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket'
        );
        insert t;

        // --- FIX: SCORCHED EARTH POLICY ---
        // Delete ANY Requests that might have been auto-created by triggers/flows/settings
        // immediately after Ticket insertion. This ensures we start with 0 Requests.
        delete [SELECT Id FROM Request__c WHERE TicketId__c = :t.Id];

        // 3. Create MANUAL Active Request (The Only One We Want)
        Request__c r = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id,
            RemoteTicketIdTxt__c = 'REMOTE-100',
            StatusPk__c = 'Open'
        );
        insert r;
    }

    @isTest
    static void testValidCommentCreatesSyncItem() {
        // Clear artifact sync items from setup
        delete [SELECT Id FROM Sync_Item__c];

        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Outbound Test',
            JiraSyncStatusTxt__c = 'Pending' 
        );
        insert c;

        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, StatusPk__c, ObjectTypePk__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create exactly 1 Sync Item (1 Request)');
        System.assertEquals('Queued', items[0].StatusPk__c, 'Status should be Queued');
        System.assertEquals('Ticket_Comment__c', items[0].ObjectTypePk__c, 'Object Type match');
    }

    @isTest
    static void testSyncedCommentIgnored() {
        delete [SELECT Id FROM Sync_Item__c];
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        
        // Simulating an incoming sync (Status = Synced). Should NOT trigger outbound.
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Incoming Message',
            JiraSyncStatusTxt__c = 'Synced' 
        );
        insert c;

        Test.stopTest();

        Integer count = [SELECT Count() FROM Sync_Item__c];
        System.assertEquals(0, count, 'Should ignore incoming synced comments');
    }

    @isTest
    static void testInactiveRequestIgnored() {
        delete [SELECT Id FROM Sync_Item__c];
        
        // Set Request to Inactive
        Request__c r = [SELECT Id FROM Request__c LIMIT 1];
        r.StatusPk__c = 'Inactive';
        update r;

        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Hello?',
            JiraSyncStatusTxt__c = 'Pending'
        );
        insert c;

        Test.stopTest();

        Integer count = [SELECT Count() FROM Sync_Item__c];
        System.assertEquals(0, count, 'Should not create sync items for Inactive vendors');
    }

    @isTest
    static void testCommentUpdateCreatesSyncItem() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // 1. Insert original comment
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Original Text',
            JiraSyncStatusTxt__c = 'Pending'
        );
        insert c;
        
        // Clear the sync item from the insert so we can test the update cleanly
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        
        // 2. Update the comment body
        c.BodyTxt__c = 'Edited Text';
        update c;

        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create Sync Item on Update');
        System.assert(items[0].PayloadTxt__c.contains('Edited Text'), 'Payload should contain updated text');
    }
}