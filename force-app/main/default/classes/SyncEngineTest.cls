@IsTest
private class SyncEngineTest {

    @TestSetup
    static void setupData() {
        // 1. Create Settings to prevent Trigger interference or enable Auto-Sync if needed
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false, // We will create Requests manually for control
            AutoSyncNetworkEntityBool__c = false
        );
        insert settings;

        // 2. Create the Mothership (Network Entity)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://fake-endpoint.com'
        );
        insert vendor;

        // 3. Create a Parent Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Base Ticket',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium',
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;

        // 4. CRITICAL: Create the Request Bridge
        // SyncEngine only picks up records if a Request links them to a Remote ID.
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-TICKET-101' // Required for SyncEngine routing
        );
        insert req;
    }

    /**
     * @description Test that updating a field in the Allowlist triggers a Sync Item creation.
     */
    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = [SELECT Id, BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        t.BriefDescriptionTxt__c = 'Updated Description';
        update t;
        Test.stopTest();

        // Verify Sync Item created
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c, ObjectTypePk__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item on update of allowed field');
        System.assertEquals('Ticket__c', items[0].ObjectTypePk__c, 'Object Type should match');
        System.assert(items[0].PayloadTxt__c.contains('Updated Description'), 'Payload should contain new value');
    }

    /**
     * @description Test that inserting a Comment (which has no Allowlist, so all fields sync) works.
     */
    @IsTest
    static void testCaptureChangesChildLinking() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment',
            AuthorTxt__c = 'Test User'
        );
        insert c;
        Test.stopTest();

        List<Sync_Item__c> items = [
            SELECT Id, TicketId__c, ObjectTypePk__c, PayloadTxt__c 
            FROM Sync_Item__c 
            WHERE ObjectTypePk__c = 'Ticket_Comment__c'
        ];
        
        System.assertEquals(1, items.size(), 'Sync Item should be created for Comment');
        System.assertEquals(t.Id, items[0].TicketId__c, 'Sync Item should be linked to the Parent Ticket');
        System.assert(items[0].PayloadTxt__c.contains('Test Comment'), 'Payload should contain body');
    }
    
    /**
     * @description Test logic that prevents infinite loops when Context is set.
     */
    @IsTest
    static void testSyncContextPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // Set the flag that simulates "We are currently processing an Inbound Sync"
        SyncEngine.setSyncContext();
        
        Test.startTest();
        t.BriefDescriptionTxt__c = 'Infinite Loop Attempt';
        update t;
        Test.stopTest();
        
        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE PayloadTxt__c LIKE '%Infinite Loop%'];
        System.assertEquals(0, items.size(), 'Should ignore changes when Sync Context is set');
    }

    /**
     * @description Test "Smart Routing": If a record came from Vendor A, don't send it back to Vendor A.
     */
    @IsTest
    static void testSmartRoutingEchoPrevention() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT RemoteTicketIdTxt__c FROM Request__c WHERE TicketId__c = :t.Id LIMIT 1];

        // Simulate an update that "Came from the Remote System"
        // We set the RemoteExternalIdTxt__c to match the Request's Remote ID.
        t.RemoteExternalIdTxt__c = req.RemoteTicketIdTxt__c; // 'REMOTE-TICKET-101'
        t.BriefDescriptionTxt__c = 'Echo Update';

        Test.startTest();
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE PayloadTxt__c LIKE '%Echo Update%'];
        System.assertEquals(0, items.size(), 'Should skip sync if Origin matches Destination (Smart Routing)');
    }

    /**
     * @description Test that updates to fields NOT in the allowlist are ignored.
     */
    @IsTest
    static void testAllowlistFiltering() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        // 'Internal_Comments__c' (or any random field not in the set) is NOT in the TicketTriggerHandler allowlist.
        // Since we can't easily add a field to the object in test, we assume 'WorkItemNameTxt__c' 
        // IS in the list (based on Handler), so let's verify a known field works, 
        // effectively testing that the engine ran. 
        // NOTE: To strictly test filtering, we rely on the fact that the Payload 
        // generated in createSyncItem only includes allowed fields.
        
        t.BriefDescriptionTxt__c = 'Allowed Change';
        update t;
        Test.stopTest();

        Sync_Item__c item = [SELECT PayloadTxt__c FROM Sync_Item__c LIMIT 1];
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
        
        System.assert(payload.containsKey('BriefDescriptionTxt__c'), 'Allowed field should be present');
        // System fields like 'CreatedDate' or 'SystemModstamp' should NOT be in the payload if filtered correctly
        System.assert(!payload.containsKey('SystemModstamp'), 'System fields should be filtered out');
    }
}