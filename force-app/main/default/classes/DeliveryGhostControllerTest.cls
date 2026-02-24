@IsTest
private class DeliveryGhostControllerTest {

    @IsTest
    static void testCreateQuickRequest() {
        // 1. Create a dummy record to get a REAL ID (Satisfies 'AvoidHardcodingId')
        Account mockRecord = new Account(Name = 'Test Context Account');
        insert mockRecord;

        // 2. Setup context data using the real ID
        Map<String, String> contextMap = new Map<String, String>{
            'url' => 'https://salesforce.com/test',
            'browser' => 'Chrome Test Agent',
            'objectName' => 'Account',
            'recordId' => mockRecord.Id // Dynamic ID
        };
        String contextJson = JSON.serialize(contextMap);

        Test.startTest();
        // Pass 'Bug' as the 5th argument
        Id ticketId = DeliveryGhostController.createQuickRequest(
            'Test Issue', 
            'Something is broken', 
            'High', 
            contextJson, 
            'Bug' 
        );
        Test.stopTest();

        // 3. Verify Ticket Created
        Ticket__c t = [SELECT BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c FROM Ticket__c WHERE Id = :ticketId LIMIT 1];
        
        System.assertEquals('[Bug] Test Issue', t.BriefDescriptionTxt__c, 'Work Item Name should include [Bug] prefix');
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
        // Just verify it doesn't throw an exception
        DeliveryGhostController.logUserActivity('Navigation', contextJson);
        Test.stopTest();
        
        // Since the method only debugs, no assertion needed other than clean execution.
        // If you had a real logging object, you would query it here.
    }
}