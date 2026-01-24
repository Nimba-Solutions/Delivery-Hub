@IsTest
private class DeliveryGhostControllerTest {

    @IsTest
    static void testCreateQuickRequest() {
        // Setup context data
        DeliveryGhostController.ContextWrapper context = new DeliveryGhostController.ContextWrapper();
        context.url = 'https://salesforce.com/test';
        context.browser = 'Chrome Test Agent';
        context.objectName = 'Account';
        context.recordId = '001000000000000AAA';

        Test.startTest();
        // Call the method (it now creates a Ticket__c)
        DeliveryGhostController.createQuickRequest('Test Bug', 'Something is broken', context);
        Test.stopTest();

        // Verify Ticket Created
        Ticket__c t = [SELECT WorkItemNameTxt__c, DetailsTxt__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Test Bug', t.WorkItemNameTxt__c);
        // Verify Rich Text formatting
        System.assert(t.DetailsTxt__c.contains('<b>--- AUTO-GENERATED CONTEXT ---</b>'));
        System.assert(t.DetailsTxt__c.contains('Chrome Test Agent'));
    }

    @IsTest
    static void testLogUserActivity() {
        DeliveryGhostController.ContextWrapper context = new DeliveryGhostController.ContextWrapper();
        context.url = 'https://salesforce.com/nav';
        context.browser = 'Safari';
        context.objectName = 'Opportunity';
        context.recordId = '006000000000000AAA';

        Test.startTest();
        DeliveryGhostController.logUserActivity('Navigation', context);
        Test.stopTest();

        User_Activity_Log__c log = [SELECT ActionTypePk__c FROM User_Activity_Log__c LIMIT 1];
        System.assertEquals('Navigation', log.ActionTypePk__c);
    }
}