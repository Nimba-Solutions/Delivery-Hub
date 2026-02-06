@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        // Create the Mothership record required by SyncEngine
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://fake-endpoint.com'
        );
        insert vendor;
    }

    @IsTest
    static void testCaptureChangesInsert() {
        // Trigger SyncEngine
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium'
        );
        
        Test.startTest();
        insert t;
        Test.stopTest();

        // Verify Sync Item
        List<Sync_Item__c> items = [SELECT Id, ObjectTypePk__c, StatusPk__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item on insert');
        System.assertEquals('Ticket__c', items[0].ObjectTypePk__c);
    }

    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog'
        );
        insert t;
        
        // Clear insert sync item
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        t.WorkItemNameTxt__c = 'Updated Name';
        update t;
        Test.stopTest();

        // Verify update sync item
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item on update');
        System.assert(items[0].PayloadTxt__c.contains('Updated Name'), 'Payload should contain new value');
    }

    @IsTest
    static void testCaptureChangesChildLinking() {
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Parent Ticket',
            StageNamePk__c = 'Backlog'
        );
        insert t;
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment'
        );
        insert c;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, TicketId__c, ObjectTypePk__c FROM Sync_Item__c LIMIT 1];
        System.assert(!items.isEmpty(), 'Sync Item should be created for Comment');
        System.assertEquals('Ticket_Comment__c', items[0].ObjectTypePk__c);
        System.assertEquals(t.Id, items[0].TicketId__c, 'Sync Item should be linked to the Parent Ticket');
    }
    
    @IsTest
    static void testLoopPrevention() {
        SyncEngine.setSyncContext();
        
        Test.startTest();
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Ignored Ticket');
        insert t;
        Test.stopTest();
        
        Integer count = [SELECT COUNT() FROM Sync_Item__c];
        System.assertEquals(0, count, 'Should ignore changes when Sync Context is set');
    }
}