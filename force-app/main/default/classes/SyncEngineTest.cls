@IsTest
private class SyncEngineTest {

    @TestSetup
    static void makeData() {
        // Create a Ticket to use in update tests
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 5,
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;
    }

    /**
     * @description Test SCENARIO 1: INSERT
     * Verifies that inserting a new record creates a "Create" sync item with all monitored fields.
     */
    @IsTest
    static void testCaptureChangesInsert() {
        // Generate a fake ID dynamically to satisfy PMD
        String keyPrefix = Ticket__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = (Id)(keyPrefix + '000000000001AAA');

        // Prepare new record data (InMemory, simulating Trigger.new)
        Ticket__c newTicket = new Ticket__c(
            Id = fakeId, 
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 10
        );

        List<SObject> newRecords = new List<SObject>{ newTicket };
        Map<Id, SObject> oldMap = null; // Null for Insert
        Set<String> fields = new Set<String>{'StageNamePk__c', 'EstimatedHoursNumber__c'};

        Test.startTest();
        SyncEngine.captureChanges(newRecords, oldMap, fields);
        Test.stopTest();

        // Validate
        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c, ObjectTypePk__c, TicketId__c FROM Sync_Item__c];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item');
        
        Sync_Item__c item = items[0];
        System.assertEquals('Ticket__c', item.ObjectTypePk__c);
        // Verify Intelligent Parent Linking for Ticket
        System.assertEquals(newTicket.Id, item.TicketId__c, 'Should link TicketId for Ticket objects');

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
        Ticket__c original = [SELECT Id, StageNamePk__c, EstimatedHoursNumber__c FROM Ticket__c LIMIT 1];
        
        // Simulate Trigger.old and Trigger.new
        Ticket__c oldVer = original.clone(true, true, true, true);
        Ticket__c newVer = original.clone(true, true, true, true);
        
        // Modify ONE field
        newVer.StageNamePk__c = 'In Development';
        // EstimatedHoursNumber__c remains 5 (unchanged)

        List<SObject> newRecords = new List<SObject>{ newVer };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ original.Id => oldVer };
        Set<String> fields = new Set<String>{'StageNamePk__c', 'EstimatedHoursNumber__c'};

        Test.startTest();
        SyncEngine.captureChanges(newRecords, oldMap, fields);
        Test.stopTest();

        // Validate
        Sync_Item__c item = [SELECT PayloadTxt__c FROM Sync_Item__c LIMIT 1];
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
        
        System.assertEquals('Update', payload.get('Action'));
        System.assertEquals('In Development', payload.get('StageNamePk__c'), 'Changed field should be present');
        System.assertEquals(null, payload.get('EstimatedHoursNumber__c'), 'Unchanged field should NOT be in payload');
    }

    /**
     * @description Test SCENARIO: NO CHANGE
     * Verifies that if monitored fields don't change, no Sync Item is created.
     */
    @IsTest
    static void testCaptureChangesNoChange() {
        Ticket__c original = [SELECT Id, StageNamePk__c FROM Ticket__c LIMIT 1];
        
        Ticket__c oldVer = original.clone(true, true, true, true);
        Ticket__c newVer = original.clone(true, true, true, true);
        
        // Change a field that is NOT in the monitored set
        newVer.WorkItemNameTxt__c = 'Changed Name but we do not care';

        List<SObject> newRecords = new List<SObject>{ newVer };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ original.Id => oldVer };
        Set<String> monitoredFields = new Set<String>{'StageNamePk__c'}; // We only care about Stage

        Test.startTest();
        SyncEngine.captureChanges(newRecords, oldMap, monitoredFields);
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
        
        // Generate fake ID for Comment
        String keyPrefix = Ticket_Comment__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeCommentId = (Id)(keyPrefix + '000000000001AAA');

        // Create a Comment (InMemory)
        Ticket_Comment__c comment = new Ticket_Comment__c(
            Id = fakeCommentId,
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment'
        );

        List<SObject> newRecords = new List<SObject>{ comment };
        Set<String> fields = new Set<String>{'BodyTxt__c'};

        Test.startTest();
        // Insert scenario
        SyncEngine.captureChanges(newRecords, null, fields);
        Test.stopTest();

        Sync_Item__c item = [SELECT ObjectTypePk__c, TicketId__c FROM Sync_Item__c LIMIT 1];
        System.assertEquals('Ticket_Comment__c', item.ObjectTypePk__c);
        System.assertEquals(t.Id, item.TicketId__c, 'Should correctly link parent Ticket ID from child record');
    }
    
    /**
     * @description Resilience Test: Graceful handling of missing/inaccessible fields.
     */
    @IsTest
    static void testCaptureChangesInvalidFieldGracefulFail() {
        String keyPrefix = Ticket__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = (Id)(keyPrefix + '000000000001AAA');

        Ticket__c newTicket = new Ticket__c(Id = fakeId);
        List<SObject> newRecords = new List<SObject>{ newTicket };
        
        // Pass a garbage field name
        Set<String> fields = new Set<String>{'NonExistentField__c'};

        Test.startTest();
        try {
            SyncEngine.captureChanges(newRecords, null, fields);
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for invalid fields, just skip them');
        }
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT PayloadTxt__c FROM Sync_Item__c];
        // It might create an item with just "Action: Create" and no fields, or skip it.
        // As long as it didn't crash, the test passes. 
        if (!items.isEmpty()) {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(items[0].PayloadTxt__c);
            System.assertEquals('Create', payload.get('Action'));
        }
    }
}