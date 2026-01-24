@IsTest
private class HubSetupControllerTest {

    @IsTest
    static void testGetStatusDisconnected() {
        // Run as a user who can see the Network Entity
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = HubSetupController.getSetupStatus();
            Test.stopTest();

            System.assertEquals(false, result.get('isConnected'));
            System.assert(result.containsKey('requiredRemoteSite'));
        }
    }

    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            Test.startTest();
            String entityId = HubSetupController.connectToDefaultMothership();
            
            // Check status again
            Map<String, Object> result = HubSetupController.getSetupStatus();
            Test.stopTest();

            System.assertNotEquals(null, entityId);
            System.assertEquals(true, result.get('isConnected'));
            
            // Validate the Entity
            Network_Entity__c created = [SELECT Name FROM Network_Entity__c WHERE Id = :entityId];
            System.assert(created.Name.contains('Nimba'));
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(testUser) {
            // Create it once
            HubSetupController.connectToDefaultMothership();

            Test.startTest();
            // Create it again (Should return existing ID)
            String entityId = HubSetupController.connectToDefaultMothership();
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c];
            System.assertEquals(1, count, 'Should not duplicate entities');
        }
    }
}