@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        insert new Delivery_Hub_Settings__c(AutoCreateRequestFromTicketBool__c = false);
        Network_Entity__c vendor = new Network_Entity__c(Name = 'M', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active', IntegrationEndpointUrlTxt__c = 'https://f.com');
        insert vendor;
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'T', StageNamePk__c = 'Backlog', BriefDescriptionTxt__c = 'Orig');
        insert t;
        insert new Request__c(TicketId__c = t.Id, DeliveryEntityId__c = vendor.Id, StatusPk__c = 'Active', RemoteTicketIdTxt__c = 'REMOTE-101');
    }

    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        delete [SELECT Id FROM Sync_Item__c]; 

        Test.startTest();
        t.BriefDescriptionTxt__c = 'New Desc';
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c];
        System.assert(items.size() >= 1, 'Should create sync item on update');
    }

    @IsTest
    static void testSmartRoutingEchoPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT RemoteTicketIdTxt__c FROM Request__c LIMIT 1];

        // 1. Block the origin
        SyncEngine.ignoreOrigin(req.RemoteTicketIdTxt__c); 
        delete [SELECT Id FROM Sync_Item__c]; 

        // 2. Direct logic call to prove suppression
        t.BriefDescriptionTxt__c = 'Echo Update';
        Test.startTest();
        SyncEngine.captureChanges(new List<SObject>{t}, null, new Set<String>{'BriefDescriptionTxt__c'});
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c];
        Boolean foundEcho = false;
        for(Sync_Item__c item : items) {
            if (item.PayloadTxt__c != null && item.PayloadTxt__c.contains('Echo Update')) { foundEcho = true; }
        }
        System.assertEquals(false, foundEcho, 'Should NOT create sync item for blocked origin ');
    }
}