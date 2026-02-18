@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        // 1. Create Settings
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
            WorkItemNameTxt__c = 'Base Ticket',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium',
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;

        // 4. Create Request Bridge
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-TICKET-101'
        );
        insert req;
    }

    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        
        // CLEANUP: Delete any sync items created during setup (e.g. from Insert triggers)
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Updated Description';
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c, ObjectTypePk__c, StatusPk__c FROM Sync_Item__c];
        
        // We expect at least one. If Flows cause recursion, we might get duplicates,
        // but we verify the FIRST one is correct.
        System.assert(items.size() >= 1, 'Should create at least 1 Sync Item on update');
        
        String objType = items[0].ObjectTypePk__c.replace('delivery__', '');
        System.assertEquals('Ticket__c', objType, 'Object Type should be Ticket__c');
        System.assert(items[0].PayloadTxt__c.contains('Updated Description'), 'Payload should contain new value');
    }

    @IsTest
    static void testCaptureChangesChildLinking() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // CLEANUP
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment',
            AuthorTxt__c = 'Test User'
        );
        insert c;
        Test.stopTest();

        List<Sync_Item__c> allItems = [
            SELECT Id, TicketId__c, ObjectTypePk__c, PayloadTxt__c 
            FROM Sync_Item__c 
        ];
        
        Sync_Item__c commentItem = null;
        for(Sync_Item__c item : allItems) {
            if(item.ObjectTypePk__c.contains('Ticket_Comment__c')) {
                commentItem = item;
                break;
            }
        }
        
        System.assertNotEquals(null, commentItem, 'Sync Item should be created for Comment');
        System.assertEquals(t.Id, commentItem.TicketId__c, 'Sync Item should be linked to the Parent Ticket');
        System.assert(commentItem.PayloadTxt__c.contains('Test Comment'), 'Payload should contain body');
    }
    
    @IsTest
    static void testSyncContextPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // This stops ALL syncs (Nuclear Option)
        SyncEngine.setSyncContext();
        
        Test.startTest();
        t.BriefDescriptionTxt__c = 'Infinite Loop Attempt';
        update t;
        Test.stopTest();
        
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        Boolean foundLoop = false;
        for (Sync_Item__c item : items) {
            if (item.PayloadTxt__c.contains('Infinite Loop')) {
                foundLoop = true;
            }
        }
        System.assertEquals(false, foundLoop, 'Should ignore changes when Sync Context is set');
    }

    @IsTest
    static void testSmartRoutingEchoPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT RemoteTicketIdTxt__c FROM Request__c WHERE TicketId__c = :t.Id LIMIT 1];

        // LEDGER SIMULATION: 
        // We tell the Engine "This update is coming from REMOTE-TICKET-101".
        // It should therefore NOT send an update back to REMOTE-TICKET-101.
        SyncEngine.ignoreOrigin(req.RemoteTicketIdTxt__c); 
        
        t.BriefDescriptionTxt__c = 'Echo Update';

        Test.startTest();
        update t;
        Test.stopTest();

        // Check: Did we create a sync item for this update?
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        Boolean foundEcho = false;
        for(Sync_Item__c item : items) {
            if (item.PayloadTxt__c.contains('Echo Update')) {
                foundEcho = true;
            }
        }
        
        System.assertEquals(false, foundEcho, 'Should skip sync if Origin matches Destination (Smart Routing)');
    }

    @IsTest
    static void testAllowlistFiltering() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Allowed Change';
        update t;
        Test.stopTest();

        Sync_Item__c item = [SELECT PayloadTxt__c FROM Sync_Item__c LIMIT 1];
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
        
        System.assert(payload.containsKey('BriefDescriptionTxt__c') || payload.containsKey('delivery__BriefDescriptionTxt__c'), 
            'Allowed field should be present');
        
        System.assert(!payload.containsKey('SystemModstamp'), 'System fields should be filtered out');
    }
}