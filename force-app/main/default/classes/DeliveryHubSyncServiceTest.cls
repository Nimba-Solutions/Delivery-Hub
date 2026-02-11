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