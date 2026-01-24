@IsTest
private class DeliveryGhostControllerTest {

    @IsTest
    static void testCreateQuickRequest() {
        // Create a dummy record to generate a real ID (Satisfies PMD AvoidHardcodingId)
        Account mockRecord = new Account(Name = 'Test Context Account');
        insert mockRecord;

        // Setup context data
        DeliveryGhostController.ContextWrapper context = new DeliveryGhostController.ContextWrapper();
        context.url = 'https://salesforce.com/test';
        context.browser = 'Chrome Test Agent';
        context.objectName = 'Account';
        context.recordId = mockRecord.Id; // Use real ID

        Test.startTest();
        // Call the method
        DeliveryGhostController.createQuickRequest('Test Bug', 'Something is broken', context);
        Test.stopTest();

        // Verify Ticket Created
        Ticket__c t = [SELECT WorkItemNameTxt__c, DetailsTxt__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Test Bug', t.WorkItemNameTxt__c, 'Work Item Name should match');
        System.assert(t.DetailsTxt__c.contains('<b>--- AUTO-GENERATED CONTEXT ---</b>'), 'Details should contain context header');
        System.assert(t.DetailsTxt__c.contains('Chrome Test Agent'), 'Details should contain browser info');
    }

    @IsTest
    static void testLogUserActivity() {
        // Create a dummy record to generate a real ID
        Account mockRecord = new Account(Name = 'Test Context Account');
        insert mockRecord;

        DeliveryGhostController.ContextWrapper context = new DeliveryGhostController.ContextWrapper();
        context.url = 'https://salesforce.com/nav';
        context.browser = 'Safari';
        context.objectName = 'Opportunity';
        context.recordId = mockRecord.Id; // Use real ID

        Test.startTest();
        DeliveryGhostController.logUserActivity('Navigation', context);
        Test.stopTest();

        User_Activity_Log__c log = [SELECT ActionTypePk__c FROM User_Activity_Log__c LIMIT 1];
        System.assertEquals('Navigation', log.ActionTypePk__c, 'Action Type should be Navigation');
    }
}