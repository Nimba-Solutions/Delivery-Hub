@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false, 
            AutoSyncNetworkEntityBool__c = false
        );
        insert settings;

        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://fake-endpoint.com'
        );
        insert vendor;

        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Base Ticket',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium',
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;

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
        delete [SELECT Id FROM Sync_Item__c]; // Clear noise

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Updated Description';
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c, ObjectTypePk__c FROM Sync_Item__c];
        System.assert(items.size() >= 1, 'Should create at least 1 Sync Item on update');
        
        String objType = items[0].ObjectTypePk__c.replace('delivery__', '');
        System.assertEquals('Ticket__c', objType, 'Object Type should be Ticket__c');
    }

    @IsTest
    static void testSmartRoutingEchoPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT RemoteTicketIdTxt__c FROM Request__c WHERE TicketId__c = :t.Id LIMIT 1];
<<<<<<< HEAD

        // 1. Setup origin block
        SyncEngine.ignoreOrigin(req.RemoteTicketIdTxt__c); 
        delete [SELECT Id FROM Sync_Item__c]; // Clear noise

        // 2. Use direct Unit Test approach to isolate SyncEngine logic from Trigger noise
=======
    
        // 1. Tell Engine to ignore this Origin (Simulating Inbound process)
        SyncEngine.ignoreOrigin(req.RemoteTicketIdTxt__c); 
        
        // 2. Clear ANY items created by the @TestSetup or previous steps
        delete [SELECT Id FROM Sync_Item__c];
    
        // 3. Manually invoke captureChanges to bypass TriggerHandler automation
        // This proves the logic inside SyncEngine works without noise from the rest of the handler
>>>>>>> 2b6345bf9e6a6a264b20eafa98bf36de6884cad3
        t.BriefDescriptionTxt__c = 'Echo Update';
        Set<String> allowList = new Set<String>{'BriefDescriptionTxt__c'};
        
        Test.startTest();
        SyncEngine.captureChanges(new List<SObject>{t}, null, allowList);
        Test.stopTest();
<<<<<<< HEAD

=======
    
        // 4. Verify no item was created
>>>>>>> 2b6345bf9e6a6a264b20eafa98bf36de6884cad3
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        Boolean foundEcho = false;
        for(Sync_Item__c item : items) {
            if (item.PayloadTxt__c != null && item.PayloadTxt__c.contains('Echo Update')) {
                foundEcho = true;
            }
        }
        System.assertEquals(false, foundEcho, 'Should skip sync when Origin is blocked via ignoreOrigin');
    }
    
    @IsTest
    static void testSyncContextPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        SyncEngine.setSyncContext();
        
        Test.startTest();
        t.BriefDescriptionTxt__c = 'Context Block Test';
        update t;
        Test.stopTest();
        
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        Boolean foundUpdate = false;
        for (Sync_Item__c item : items) {
            if (item.PayloadTxt__c != null && item.PayloadTxt__c.contains('Context Block Test')) {
                foundUpdate = true;
            }
        }
        System.assertEquals(false, foundUpdate, 'Should ignore changes when Sync Context is set');
    }
}