@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        // CRITICAL: SyncEngine now requires an Active Vendor to function.
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
        // 1. Create a Ticket (should trigger SyncEngine)
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium'
        );
        
        Test.startTest();
        insert t;
        Test.stopTest();

        // 2. Verify Sync Item created
        List<Sync_Item__c> items = [SELECT Id, ObjectTypePk__c, StatusPk__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item on insert');
        System.assertEquals('Ticket__c', items[0].ObjectTypePk__c);
        System.assertEquals('Queued', items[0].StatusPk__c);
    }

    @IsTest
    static void testCaptureChangesUpdate() {
        // 1. Create Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog'
        );
        insert t;
        
        // Clear initial sync item from insert
        delete [SELECT Id FROM Sync_Item__c];

        // 2. Update Ticket
        Test.startTest();
        t.WorkItemNameTxt__c = 'Updated Name';
        update t;
        Test.stopTest();

        // 3. Verify Sync Item created
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item on update');
        System.assert(items[0].PayloadTxt__c.contains('Updated Name'), 'Payload should contain new value');
    }

    @IsTest
    static void testCaptureChangesChildLinking() {
        // 1. Create Parent Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Parent Ticket',
            StageNamePk__c = 'Backlog'
        );
        insert t;

        // Clear initial sync item
        delete [SELECT Id FROM Sync_Item__c];

        // 2. Create Comment (should link to Ticket)
        Test.startTest();
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment'
        );
        insert c;
        Test.stopTest();

        // 3. Verify Sync Item uses Parent ID
        Sync_Item__c item = [SELECT Id, TicketId__c, ObjectTypePk__c FROM Sync_Item__c LIMIT 1];
        System.assertEquals('Ticket_Comment__c', item.ObjectTypePk__c);
        System.assertEquals(t.Id, item.TicketId__c, 'Sync Item should be linked to the Parent Ticket');
    }
    
    @IsTest
    static void testLoopPrevention() {
        // 1. Set the "Echo Prevention" flag
        SyncEngine.setSyncContext();
        
        Test.startTest();
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Ignored Ticket');
        insert t;
        Test.stopTest();
        
        // 2. Verify NO Sync Item created
        Integer count = [SELECT COUNT() FROM Sync_Item__c];
        System.assertEquals(0, count, 'Should ignore changes when Sync Context is set');
    }
}