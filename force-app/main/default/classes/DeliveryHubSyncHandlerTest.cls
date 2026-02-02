@isTest
private class DeliveryHubSyncHandlerTest {

    @testSetup
    static void setupData() {
        // 1. Create Network/Delivery Entity
        // NOTE: Using 'Network_Entity__c'. If your object is named differently, update this class name.
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Node',
            IntegrationEndpointUrlTxt__c = 'https://example.com/api'
        );
        insert entity;

        // 2. Create Ticket (REMOVED Name field because it is Auto-Number)
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket'
        );
        insert t;

        // 3. Create Active Request (The Connection)
        Request__c r = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id, // Ensure this lookup exists on Request__c
            RemoteTicketIdTxt__c = 'REMOTE-100',
            StatusPk__c = 'Open'
        );
        insert r;
    }

    @isTest
    static void testValidCommentCreatesSyncItem() {
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
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item');
        //System.assertEquals('Queued', items[0].StatusPk__c, 'Status should be Queued');
    }

    @isTest
    static void testSyncedCommentIgnored() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        
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
}