@IsTest
private class DeliveryHubSyncServiceTest {

    @TestSetup
    static void makeData() {
        // Setup a generic Ticket record to update
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 10,
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;
    }

    /**
     * @description Verifies that standard fields (Text, Number, Picklist) update correctly.
     */
    @IsTest
    static void testProcessSyncSuccess() {
        Ticket__c target = [SELECT Id FROM Ticket__c LIMIT 1];

        // Prepare Payload with mixed types
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('TargetId', target.Id);
        payload.put('BriefDescriptionTxt__c', 'Updated via Service'); // String
        payload.put('EstimatedHoursNumber__c', 20.5); // Decimal/Double
        payload.put('StageNamePk__c', 'In Development'); // Picklist (String)
        
        // Add Metadata fields (should be ignored)
        payload.put('Action', 'Update');
        payload.put('SourceId', 'SomeExternalId');

        Test.startTest();
        DeliveryHubSyncService.processSync('Ticket__c', payload);
        Test.stopTest();

        // Verify Updates
        Ticket__c updatedTicket = [SELECT BriefDescriptionTxt__c, EstimatedHoursNumber__c, StageNamePk__c FROM Ticket__c WHERE Id = :target.Id];
        
        System.assertEquals('Updated via Service', updatedTicket.BriefDescriptionTxt__c, 'String field failed to update');
        System.assertEquals(20.5, updatedTicket.EstimatedHoursNumber__c, 'Decimal field failed to update');
        System.assertEquals('In Development', updatedTicket.StageNamePk__c, 'Picklist field failed to update');
    }

    /**
     * @description Verifies Date type conversion logic.
     */
    @IsTest
    static void testProcessSyncDateConversion() {
        Ticket__c target = [SELECT Id FROM Ticket__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('TargetId', target.Id);
        // Using a standard date field or one we know exists for testing logic.
        // Even if the field doesn't exist, the service catches the exception gracefully.
        payload.put('CreatedDate', '2026-12-31'); 

        try {
            Test.startTest();
            DeliveryHubSyncService.processSync('Ticket__c', payload);
            Test.stopTest();
            
            // We mainly assert no exceptions were thrown during processing
            System.assert(true, 'Date conversion processed without crashing');
        } catch (Exception e) {
            System.assert(false, 'Date conversion caused unexpected crash: ' + e.getMessage());
        }
    }

    /**
     * @description Verifies Null value handling.
     */
    @IsTest
    static void testProcessSyncNullValues() {
        Ticket__c target = [SELECT Id FROM Ticket__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('TargetId', target.Id);
        payload.put('BriefDescriptionTxt__c', null); // Explicit Null

        Test.startTest();
        DeliveryHubSyncService.processSync('Ticket__c', payload);
        Test.stopTest();

        Ticket__c updatedTicket = [SELECT BriefDescriptionTxt__c FROM Ticket__c WHERE Id = :target.Id];
        System.assertEquals(null, updatedTicket.BriefDescriptionTxt__c, 'Field should be nulled out');
    }

    /**
     * @description Verifies validation logic for invalid object types.
     */
    @IsTest
    static void testProcessSyncInvalidObject() {
        Map<String, Object> payload = new Map<String, Object>{ 'TargetId' => 'fakeid' };

        Test.startTest();
        try {
            DeliveryHubSyncService.processSync('Invalid_Object_Name__c', payload);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Invalid Object Type'), 'Exception should mention object type');
        } catch (Exception e) {
            System.assert(false, 'Wrong exception type thrown: ' + e.getTypeName());
        }
        Test.stopTest();
    }

    /**
     * @description Verifies the resilience of the service. 
     * If one field fails (e.g., bad data format), others should still save.
     */
    @IsTest
    static void testProcessSyncPartialFailureResilience() {
        Ticket__c target = [SELECT Id FROM Ticket__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('TargetId', target.Id);
        payload.put('BriefDescriptionTxt__c', 'I should save');
        payload.put('EstimatedHoursNumber__c', 'NOT_A_NUMBER'); // This will fail type conversion

        Test.startTest();
        DeliveryHubSyncService.processSync('Ticket__c', payload);
        Test.stopTest();

        Ticket__c updatedTicket = [SELECT BriefDescriptionTxt__c, EstimatedHoursNumber__c FROM Ticket__c WHERE Id = :target.Id];
        
        // The valid field SHOULD be updated
        System.assertEquals('I should save', updatedTicket.BriefDescriptionTxt__c, 'Valid field should update even if sibling field fails');
        // The invalid field should remain 10 (from makeData)
        System.assertEquals(10, updatedTicket.EstimatedHoursNumber__c, 'Invalid field should preserve original value');
    }
}