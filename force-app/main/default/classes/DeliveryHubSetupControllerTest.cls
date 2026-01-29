@IsTest
private class DeliveryHubSetupControllerTest {

    @IsTest
    static void testGetStatusDisconnected() {
        // Run as a user who can see the Network Entity
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            Test.startTest();
            // FIX: Assign to the actual inner class type, not Map
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            Test.stopTest();

            // FIX: Access fields directly via dot notation
            System.assertEquals(false, result.isConnected, 'Should not be connected initially');
            System.assertNotEquals(null, result.requiredRemoteSite, 'Remote site URL should be returned');
        }
    }

    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            Test.startTest();
            // FIX: Method returns void, so just call it. Do not assign to String.
            DeliveryHubSetupController.connectToDefaultMothership();
            
            // Check status again
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            Test.stopTest();

            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            System.assertNotEquals(null, result.entity, 'Entity object should be returned');
            
            // Validate the Entity exists in DB
            Network_Entity__c created = [SELECT Id, Name FROM Network_Entity__c WHERE Id = :result.entity.Id];
            System.assert(created.Name.contains('Cloud Nimbus'), 'Name should match new branding');
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            // Create it once
            DeliveryHubSetupController.connectToDefaultMothership();

            Test.startTest();
            // Create it again (Should handle duplicates gracefully)
            DeliveryHubSetupController.connectToDefaultMothership();
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not duplicate entities');
        }
    }
}