@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        // 1. Settings
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false, 
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Vendor
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'M', 
            EntityTypePk__c = 'Vendor', 
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://f.com'
        );
        insert vendor;

        // 3. Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'T', 
            StageNamePk__c = 'Backlog', 
            BriefDescriptionTxt__c = 'Orig'
        );
        insert t;

        // 4. Request Bridge
        // Note: This insert often fires triggers that create Sync_Items__c immediately
        insert new Request__c(
            TicketId__c = t.Id, 
            DeliveryEntityId__c = vendor.Id, 
            StatusPk__c = 'Active', 
            RemoteTicketIdTxt__c = 'REMOTE-101'
        );
    }

    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        delete [SELECT Id FROM Sync_Item__c]; // Clear Setup noise

        Test.startTest();
        t.BriefDescriptionTxt__c = 'New Desc';
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c];
        System.assert(items.size() >= 1, 'Should create at least 1 sync item on update');
    }
    
    @IsTest
    static void testSmartRoutingEchoPrevention() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        
        // Ensure every active route for this ticket is in the block list
        List<Request__c> reqs = [SELECT RemoteTicketIdTxt__c FROM Request__c WHERE TicketId__c = :t.Id];
        
        Test.startTest();
        for (Request__c r : reqs) {
            if (r.RemoteTicketIdTxt__c != null) {
                SyncEngine.ignoreOrigin(r.RemoteTicketIdTxt__c); 
            }
        }
        
        // Nuclear cleanup: clear any items created by triggers during setup
        delete [SELECT Id FROM Sync_Item__c]; 

        t.BriefDescriptionTxt__c = 'Echo Update';
        SyncEngine.captureChanges(
            new List<SObject>{t}, 
            null, 
            new Set<String>{'BriefDescriptionTxt__c'}
        );
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c];
        System.assertEquals(0, items.size(), 'Engine should have ignored the record because origins were blocked or invalid.');
    }
}