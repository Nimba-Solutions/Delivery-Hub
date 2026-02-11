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

}