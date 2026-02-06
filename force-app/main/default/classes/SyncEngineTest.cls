@IsTest
private class SyncEngineTest {

    @TestSetup
    static void makeData() {
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 5,
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;
        // CLEANUP: Delete noise
        delete [SELECT Id FROM Sync_Item__c];
    }

    @IsTest
    static void testCaptureChangesInsert() {
        Ticket__c newTicket = new Ticket__c(
            WorkItemNameTxt__c = 'Fresh Ticket',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 10
        );

        Test.startTest();
        insert newTicket; 
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id, PayloadTxt__c, ObjectTypePk__c, TicketId__c, SourceEventTimestampDateTime__c FROM Sync_Item__c WHERE TicketId__c = :newTicket.Id];
        System.assertEquals(1, items.size(), 'Should create 1 Sync Item');
        
        // NEW: Verify Source Timestamp
        System.assertNotEquals(null, items[0].SourceEventTimestampDateTime__c, 'Source Timestamp should be populated');
        // It should be very close to now (within seconds)
        Long diff = Math.abs(System.now().getTime() - items[0].SourceEventTimestampDateTime__c.getTime());
        System.assert(diff < 5000, 'Timestamp should be recent (within 5s)');

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(items[0].PayloadTxt__c);
        System.assertEquals('Create', payload.get('Action'));
    }

    @IsTest
    static void testCaptureChangesUpdate() {
        Ticket__c t = [SELECT Id, StageNamePk__c FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        t.StageNamePk__c = 'In Development';
        update t; 
        Test.stopTest();

        Sync_Item__c item = [SELECT PayloadTxt__c, SourceEventTimestampDateTime__c FROM Sync_Item__c WHERE TicketId__c = :t.Id LIMIT 1];
        
        System.assertNotEquals(null, item.SourceEventTimestampDateTime__c, 'Update should also capture timestamp');
        
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
        System.assertEquals('In Development', payload.get('StageNamePk__c'));
    }

    @IsTest
    static void testCaptureChangesNoChange() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.startTest();
        t.WorkItemNameTxt__c = 'Changed Name but not monitored';
        update t; 
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c];
        System.assertEquals(0, items.size());
    }

    @IsTest
    static void testCaptureChangesChildLinking() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Comment'
        );
        insert comment; 
        
        List<SObject> newRecords = new List<SObject>{ comment };
        Set<String> monitoredFields = new Set<String>{'BodyTxt__c'};

        Test.startTest();
        SyncEngine.captureChanges(newRecords, null, monitoredFields);
        Test.stopTest();

        Sync_Item__c item = [SELECT ObjectTypePk__c, TicketId__c FROM Sync_Item__c WHERE ObjectTypePk__c = 'Ticket_Comment__c' LIMIT 1];
        System.assertEquals(t.Id, item.TicketId__c, 'Parent ID should be linked');
    }
    
    @IsTest
    static void testCaptureChangesInvalidFieldGracefulFail() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        List<SObject> newRecords = new List<SObject>{ t };
        Set<String> badFields = new Set<String>{'NonExistentField__c'};

        Test.startTest();
        try {
            SyncEngine.captureChanges(newRecords, null, badFields);
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception');
        }
        Test.stopTest();
        System.assert(true);
    }
}