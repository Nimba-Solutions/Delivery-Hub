@IsTest
private class DeliveryGhostControllerTest {

    @IsTest
    static void testCreateQuickRequest() {
        // Create a dummy record to generate a real ID
        Account mockRecord = new Account(Name = 'Test Context Account');
        insert mockRecord;

        // Setup context data
        DeliveryGhostController.ContextWrapper context = new DeliveryGhostController.ContextWrapper();
        context.url = 'https://salesforce.com/test';
        context.browser = 'Chrome Test Agent';
        context.objectName = 'Account';
        context.recordId = mockRecord.Id; 

        String contextJson = JSON.serialize(context);

        Test.startTest();
        // Pass priority 'High'
        Id ticketId = DeliveryGhostController.createQuickRequest('Test Bug', 'Something is broken', 'High', contextJson);
        Test.stopTest();

        // Verify Ticket Created
        Ticket__c t = [SELECT WorkItemNameTxt__c, DetailsTxt__c, PriorityPk__c FROM Ticket__c WHERE Id = :ticketId LIMIT 1];
        System.assertEquals('Test Bug', t.WorkItemNameTxt__c, 'Work Item Name should match');
        System.assertEquals('High', t.PriorityPk__c, 'Priority should match');
        System.assert(t.DetailsTxt__c.contains('<b>--- AUTO-GENERATED CONTEXT ---</b>'), 'Details should contain context header');
    }

    @IsTest
    static void testLogUserActivity() {
        Account mockRecord = new Account(Name = 'Test Context Account');
        insert mockRecord;

        DeliveryGhostController.ContextWrapper context = new DeliveryGhostController.ContextWrapper();
        context.url = 'https://salesforce.com/nav';
        context.browser = 'Safari';
        context.objectName = 'Opportunity';
        context.recordId = mockRecord.Id; 

        String contextJson = JSON.serialize(context);

        Test.startTest();
        DeliveryGhostController.logUserActivity('Navigation', contextJson);
        Test.stopTest();

        User_Activity_Log__c log = [SELECT ActionTypePk__c FROM User_Activity_Log__c LIMIT 1];
        System.assertEquals('Navigation', log.ActionTypePk__c);
    }
}