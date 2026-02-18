@IsTest
private class TicketCommentTriggerHandlerTest {

    @TestSetup
    static void setup() {
        // 1. Create Settings (Avoid auto-async logic during setup)
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false, 
            AutoSyncNetworkEntityBool__c = false
        );
        insert settings;

        // 2. Create Vendor
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://fake-endpoint.com'
        );
        insert vendor;

        // 3. Create Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'Backlog',
            BriefDescriptionTxt__c = 'Comment Test Parent'
        );
        insert t;

        // 4. Create Active Request (Required for SyncEngine to route comments)
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-PARENT-101'
        );
        insert req;
    }

    /**
     * @description Test that inserting a comment creates a Sync_Item__c via the Handler -> Engine.
     */
    @IsTest
    static void testInsertSyncsComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Hello World',
            AuthorTxt__c = 'Test User'
        );
        insert c;
        Test.stopTest();

        // Verify Sync Item
        List<Sync_Item__c> items = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, TicketId__c 
            FROM Sync_Item__c 
            WHERE ObjectTypePk__c = 'Ticket_Comment__c'
        ];

        System.assertEquals(1, items.size(), 'Should create 1 Sync Item for the comment insert');
        System.assertEquals(t.Id, items[0].TicketId__c, 'Should be linked to parent ticket');
        System.assert(items[0].PayloadTxt__c.contains('Hello World'), 'Payload should contain body');
    }

    /**
     * @description Test that updating the comment body triggers a new Sync Item.
     */
    @IsTest
    static void testUpdateSyncsComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Original',
            AuthorTxt__c = 'User'
        );
        insert c;
        
        // Clear insert logs
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        c.BodyTxt__c = 'Edited Comment';
        update c;
        Test.stopTest();

        // Verify Update Sync Item
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item for the update');
        System.assert(items[0].PayloadTxt__c.contains('Edited Comment'), 'Payload should contain new body');
    }
}