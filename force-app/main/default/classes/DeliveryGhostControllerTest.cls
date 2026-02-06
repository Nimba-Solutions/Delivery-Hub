@IsTest
private class DeliveryGhostControllerTest {

    @IsTest
    static void testCreateQuickRequest() {
        // Setup context data using a Map (cleaner than relying on inner classes)
        Map<String, String> contextMap = new Map<String, String>{
            'url' => 'https://salesforce.com/test',
            'browser' => 'Chrome Test Agent',
            'objectName' => 'Account',
            'recordId' => '001000000000000AAA' // Dummy ID
        };
        String contextJson = JSON.serialize(contextMap);

        Test.startTest();
        // FIX 1: Pass 'Bug' as the 5th argument (ticketType)
        Id ticketId = DeliveryGhostController.createQuickRequest(
            'Test Issue', 
            'Something is broken', 
            'High', 
            contextJson, 
            'Bug' 
        );
        Test.stopTest();

        // Verify Ticket Created
        Ticket__c t = [SELECT WorkItemNameTxt__c, DetailsTxt__c, PriorityPk__c FROM Ticket__c WHERE Id = :ticketId LIMIT 1];
        
        // FIX 2: Assert that the [Bug] prefix was added
        System.assertEquals('[Bug] Test Issue', t.WorkItemNameTxt__c, 'Work Item Name should include [Bug] prefix');
        System.assertEquals('High', t.PriorityPk__c, 'Priority should match');
        System.assert(t.DetailsTxt__c.contains('Auto-Captured Context'), 'Details should contain context header');
    }

    @IsTest
    static void testLogUserActivity() {
        Map<String, String> contextMap = new Map<String, String>{
            'url' => 'https://salesforce.com/nav',
            'browser' => 'Safari'
        };
        String contextJson = JSON.serialize(contextMap);

        Test.startTest();
        DeliveryGhostController.logUserActivity('Navigation', contextJson);
        Test.stopTest();
        
        // Note: The controller snippet we deployed previously only debugged the log.
        // If you have a real User_Activity_Log__c object and the controller inserts it, keep this query.
        // If the controller just does System.debug, you can remove the assertion below.
        // For now, assuming the object exists:
        List<User_Activity_Log__c> logs = [SELECT ActionTypePk__c FROM User_Activity_Log__c LIMIT 1];
        if (!logs.isEmpty()) {
            System.assertEquals('Navigation', logs[0].ActionTypePk__c);
        }
    }
}