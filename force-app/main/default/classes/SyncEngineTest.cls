@IsTest
private class SyncEngineTest {

    @TestSetup
    static void makeData() {
        // Create a Ticket. This WILL fire the Trigger and create a Sync_Item__c.
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 5,
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;

        // CLEANUP: Delete the noise (Sync Item created by makeData) so tests start fresh
        delete [SELECT Id FROM Sync_Item__c];
    }

    /**
     * @description Test SCENARIO 1: INSERT
     * Verifies that inserting a new record creates a "Create" sync item.
     */
    @IsTest
    static void testCaptureChangesInsert() {
        // Use Real DML to pass referential integrity checks on Sync_Item__c.TicketId__c
        Ticket__c newTicket = new Ticket__c(
            WorkItemNameTxt__c = 'Fresh Ticket',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 10
        );

        Test.startTest();
        // Insert fires the Trigger -> SyncEngine.captureChanges
        insert newTicket; 
        Test.stopTest();

        // Validate
        // Filter by the new ticket ID to avoid any ghost data
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c, ObjectTypePk__c, TicketId__c FROM Sync_Item__c WHERE TicketId__c = :newTicket.Id];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item for the new record');
        
        Sync_Item__c item = items[0];
        System.assertEquals('Ticket__c', item.ObjectTypePk__c);
        System.assertEquals(newTicket.Id, item.TicketId__c);

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
        System.assertEquals('Create', payload.get('Action'));
        System.assertEquals(10, payload.get('EstimatedHoursNumber__c'));
    }

    /**
     * @description Test SCENARIO 2: UPDATE (Delta)
     * Verifies that updating a record captures ONLY the changed fields.
     */
    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = [SELECT Id, StageNamePk__c FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        t.StageNamePk__c = 'In Development';
        update t; // Fires Trigger -> SyncEngine
        Test.stopTest();

        // Validate
        Sync_Item__c item = [SELECT PayloadTxt__c FROM Sync_Item__c WHERE TicketId__c = :t.Id LIMIT 1];
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
        
        System.assertEquals('Update', payload.get('Action'));
        System.assertEquals('In Development', payload.get('StageNamePk__c'), 'Changed field should be present');
        System.assertEquals(false, payload.containsKey('EstimatedHoursNumber__c'), 'Unchanged field should NOT be in payload');
    }

    /**
     * @description Test SCENARIO: NO CHANGE
     * Verifies that if monitored fields don't change, no Sync Item is created.
     */
    @IsTest
    static void testCaptureChangesNoChange() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        t.WorkItemNameTxt__c = 'Changed Name but not monitored';
        update t; 
        Test.stopTest();

        // Validate
        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c];
        System.assertEquals(0, items.size(), 'Should not create Sync Item if monitored fields did not change');
    }

    /**
     * @description Test SCENARIO: CHILD OBJECT LINKING
     * Verifies that a child object (Comment) correctly populates the TicketId__c lookup.
     */
    @IsTest
    static void testCaptureChangesChildLinking() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment'
        );

        Test.startTest();
        insert comment; // Trigger fires
        Test.stopTest();

        // Use ObjectType filter to distinguish from any Ticket syncs
        Sync_Item__c item = [SELECT ObjectTypePk__c, TicketId__c FROM Sync_Item__c WHERE ObjectTypePk__c = 'Ticket_Comment__c' LIMIT 1];
        System.assertEquals(t.Id, item.TicketId__c, 'Should correctly link parent Ticket ID from child record');
    }
    
    /**
     * @description Resilience Test: Graceful handling of missing/inaccessible fields.
     */
    @IsTest
    static void testCaptureChangesInvalidFieldGracefulFail() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // We simulate the engine call directly to pass invalid fields
        // (Triggers verify fields, so we can't do this via DML)
        List<SObject> newRecords = new List<SObject>{ t };
        Set<String> badFields = new Set<String>{'NonExistentField__c'};

        Test.startTest();
        try {
            // Call engine manually
            SyncEngine.captureChanges(newRecords, null, badFields);
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for invalid fields, just skip them. Error: ' + e.getMessage());
        }
        Test.stopTest();

        // It should run without crashing.
        // It might create a SyncItem with just "Create/Update" and no data, or nothing. Both are fine.
        // We mainly assert it didn't throw.
        System.assert(true);
    }
}