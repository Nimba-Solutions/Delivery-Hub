/**
 * @description Test class for SyncEngine.
 * V2 Architecture: Tests bidirectional DAG routing and echo suppression.
 * Uses Apex-level filtering to isolate assertions from async trigger noise, bypassing SOQL Long Text limits.
 */
@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        // 1. Settings
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false, 
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Network Entities (The DAG Edges)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Downstream Vendor', 
            EntityTypePk__c = 'Vendor', 
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://vendor.com'
        );
        Network_Entity__c client = new Network_Entity__c(
            Name = 'Upstream Client', 
            EntityTypePk__c = 'Client', 
            StatusPk__c = 'Active'
        );
        insert new List<Network_Entity__c>{vendor, client};

        // 3. Ticket (With Upstream Edge mapped)
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'T', 
            StageNamePk__c = 'Backlog', 
            BriefDescriptionTxt__c = 'Orig',
            ClientNetworkEntityId__c = client.Id // The Upstream Map
        );
        insert t;

        // 4. Request Bridge (The Downstream Edge)
        insert new Request__c(
            TicketId__c = t.Id, 
            DeliveryEntityId__c = vendor.Id, 
            StatusPk__c = 'Active', 
            RemoteTicketIdTxt__c = 'REMOTE-101'
        );
    }

    @IsTest
    static void testCaptureChangesUpdateFansOutBidirectionally() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        delete [SELECT Id FROM Sync_Item__c]; // Clear setup trigger noise

        Test.startTest();
        t.BriefDescriptionTxt__c = 'New Desc';
        update t; // Should trigger captureChanges
        Test.stopTest();

        // STRICT APEX FILTER: Long Text Areas cannot be filtered in SOQL.
        List<Sync_Item__c> allItems = [SELECT Id, RequestId__c, PayloadTxt__c FROM Sync_Item__c];
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        for (Sync_Item__c si : allItems) {
            if (si.PayloadTxt__c != null && si.PayloadTxt__c.contains('New Desc')) {
                items.add(si);
            }
        }
        
        // V2 Expects 2 items: 1 downstream (Push), 1 upstream (Hub stage)
        System.assertEquals(2, items.size(), 'Should create two sync items: one upstream, one downstream.');
        
        Integer pushCount = 0;
        Integer hubCount = 0;
        for (Sync_Item__c si : items) {
            if (si.RequestId__c != null) {
                pushCount++;
            } else {
                hubCount++;
            }
        }
        System.assertEquals(1, pushCount, 'One item should be targeted downstream (Push)');
        System.assertEquals(1, hubCount, 'One item should be staged upstream (Hub/Pull)');
    }
    
    @IsTest
    static void testSmartRoutingBlocksDownstreamEcho() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT Id FROM Request__c WHERE TicketId__c = :t.Id LIMIT 1];
        
        delete [SELECT Id FROM Sync_Item__c]; // Clear setup noise

        Test.startTest();
        // Simulate Ingestor receiving a payload from the Vendor (Downstream)
        SyncEngine.ignoreOrigin(req.Id); 

        t.BriefDescriptionTxt__c = 'Downstream Echo Update';
        SyncEngine.captureChanges(
            new List<SObject>{t}, 
            null, 
            new Set<String>{'BriefDescriptionTxt__c'}
        );
        Test.stopTest();

        // STRICT APEX FILTER
        List<Sync_Item__c> allItems = [SELECT Id, RequestId__c, PayloadTxt__c FROM Sync_Item__c];
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        for (Sync_Item__c si : allItems) {
            if (si.PayloadTxt__c != null && si.PayloadTxt__c.contains('Downstream Echo Update')) {
                items.add(si);
            }
        }
        
        System.assertEquals(1, items.size(), 'Engine should have blocked the downstream route and only staged the upstream one.');
        System.assertEquals(null, items[0].RequestId__c, 'The created item should be the upstream Hub item (RequestId == null).');
    }

    @IsTest
    static void testSmartRoutingBlocksUpstreamEcho() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c, ClientNetworkEntityId__c FROM Ticket__c LIMIT 1];
        
        delete [SELECT Id FROM Sync_Item__c]; // Clear setup noise

        Test.startTest();
        // Simulate Ingestor receiving a payload from the Client (Upstream)
        SyncEngine.ignoreOrigin(t.ClientNetworkEntityId__c); 

        t.BriefDescriptionTxt__c = 'Upstream Echo Update';
        SyncEngine.captureChanges(
            new List<SObject>{t}, 
            null, 
            new Set<String>{'BriefDescriptionTxt__c'}
        );
        Test.stopTest();

        // STRICT APEX FILTER
        List<Sync_Item__c> allItems = [SELECT Id, RequestId__c, PayloadTxt__c FROM Sync_Item__c];
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        for (Sync_Item__c si : allItems) {
            if (si.PayloadTxt__c != null && si.PayloadTxt__c.contains('Upstream Echo Update')) {
                items.add(si);
            }
        }
        
        System.assertEquals(1, items.size(), 'Engine should have blocked the upstream route and only created the downstream push.');
        System.assertNotEquals(null, items[0].RequestId__c, 'The created item should be the downstream Push item (RequestId != null).');
    }
}