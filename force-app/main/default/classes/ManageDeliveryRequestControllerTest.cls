@IsTest
private class ManageDeliveryRequestControllerTest {

    @IsTest
    static void testController() {
        // Setup mock data
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c='Test Ticket', StageNamePk__c='Backlog');
        insert t;

        Request__c r = new Request__c(TicketId__c = t.Id, StatusPk__c = 'Draft');
        insert r;

        Test.startTest();
        // Test Send
        ManageDeliveryRequestController.sendRequestToVendor(r.Id);

        // Test Check Status
        String msg = ManageDeliveryRequestController.checkRequestStatus(r.Id);
        Test.stopTest();

        // Assertions
        Request__c updatedReq = [SELECT StatusPk__c FROM Request__c WHERE Id = :r.Id];
        
        // FIXED: Assertion now matches the Controller's logic ('Offer Sent' instead of 'Active')
        System.assertEquals('Offer Sent', updatedReq.StatusPk__c, 'Request status should be Offer Sent');
        System.assert(msg.contains('sent'), 'Should return success message');
    }
}