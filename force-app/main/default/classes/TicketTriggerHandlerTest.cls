@IsTest
public class TicketTriggerHandlerTest {

    @TestSetup
    static void setup() {
        // 1. Configure Settings (Enable Auto-Request Creation)
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = true, 
            AutoSyncNetworkEntityBool__c = false // Keep false to avoid async callout complexity in simple tests
        );
        insert settings;

        // 2. Create Vendor (Mothership)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://fake-endpoint.com'
        );
        insert vendor;

        // 3. Create Tickets for Dependency Logic
        List<Ticket__c> tickets = new List<Ticket__c>{
            new Ticket__c(BriefDescriptionTxt__c = 'Blocker Ticket', StatusPk__c = 'In Progress', StageNamePk__c = 'In Development'),
            new Ticket__c(BriefDescriptionTxt__c = 'Blocked Ticket', StatusPk__c = 'In Progress', StageNamePk__c = 'Backlog')
        };
        insert tickets;

        Ticket__c blocker = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocker Ticket'];
        Ticket__c blocked = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocked Ticket'];

        // 4. Create Dependency
        insert new Ticket_Dependency__c(
            Blocked_Ticket__c = blocked.Id,
            Blocking_Ticket__c = blocker.Id,
            TypePk__c = 'Blocks'
        );
    }

    /**
     * @description Test that inserting a Ticket auto-creates a Request__c record (Bridge).
     */
    @IsTest
    static void testBridgeCreationOnInsert() {
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'New Feature',
            StatusPk__c = 'New',
            BriefDescriptionTxt__c = 'Auto Request Test'
        );

        Test.startTest();
        insert t;
        Test.stopTest();

        // Verify Request created
        List<Request__c> requests = [SELECT Id, TicketId__c, DeliveryEntityId__r.Name FROM Request__c WHERE TicketId__c = :t.Id];
        System.assertEquals(1, requests.size(), 'A Request should be auto-created for the new ticket.');
        System.assertEquals('Mothership', requests[0].DeliveryEntityId__r.Name, 'Request should link to the Active Vendor.');
    }

    /**
     * @description Test that Updating a ticket triggers the SyncEngine.
     * Note: SyncEngine only creates items if a Request with a Remote ID exists.
     */
    @IsTest
    static void testSyncEngineIntegrationOnUpdate() {
        // Setup: Get a ticket and Manually "Connect" it (Simulate a successful Request handshake)
        Ticket__c t = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocker Ticket' LIMIT 1];
        Network_Entity__c vendor = [SELECT Id FROM Network_Entity__c LIMIT 1];
        
        // Create the active connection required by SyncEngine
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-123'
        );
        insert req;

        Test.startTest();
        // Update a field in the Allowlist
        t.BriefDescriptionTxt__c = 'Updated Description for Sync';
        update t;
        Test.stopTest();

        // Verify Sync Item created
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c FROM Sync_Item__c WHERE TicketId__c = :t.Id];
        System.assertEquals(1, items.size(), 'Sync Engine should create a Sync Item on update.');
        System.assert(items[0].PayloadTxt__c.contains('Updated Description for Sync'), 'Payload should contain change.');
    }

    /**
     * @description Test Blocking Logic: Cannot move to 'In Development' if blocked.
     * PMD Fix: Renamed to remove underscore.
     */
    @IsTest
    static void testBeforeUpdateBlocksOnDependency() {
        Ticket__c blocked = [SELECT Id, StageNamePk__c FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocked Ticket' LIMIT 1];
        
        Test.startTest();
        try {
            blocked.StageNamePk__c = 'In Development'; // Active Stage
            update blocked;
            System.assert(false, 'Should have thrown an exception due to blocker.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('blocked by ticket'), 'Error message should mention blocking.');
        }
        Test.stopTest();
    }

    /**
     * @description Test Blocking Logic: CAN move if blocker is resolved.
     * PMD Fix: Renamed to remove underscore.
     */
    @IsTest
    static void testBeforeUpdateAllowsUpdateWhenResolved() {
        Ticket__c blocker = [SELECT Id, StageNamePk__c FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocker Ticket' LIMIT 1];
        Ticket__c blocked = [SELECT Id, StageNamePk__c FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocked Ticket' LIMIT 1];

        // 1. Resolve Blocker
        blocker.StageNamePk__c = 'Done';
        update blocker;

        Test.startTest();
        // 2. Move Blocked Ticket
        blocked.StageNamePk__c = 'In Development';
        Database.SaveResult res = Database.update(blocked, false);
        Test.stopTest();

        System.assert(res.isSuccess(), 'Update should succeed once blocker is Done.');
    }
}