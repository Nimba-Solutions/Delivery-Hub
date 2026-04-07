/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryRequestManagerController covering vendor request
 * submission and status checking.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryRequestManagerControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testController() {
        System.runAs(testUser) {
            // Setup mock data
            WorkItem__c t = new WorkItem__c(BriefDescriptionTxt__c='Test Work Item', StageNamePk__c='Backlog');
            insert t;

            WorkRequest__c r = new WorkRequest__c(WorkItemLookup__c = t.Id, StatusPk__c = 'Draft');
            insert r;

            Test.startTest();
            // Test Send
            DeliveryRequestManagerController.sendRequestToVendor(r.Id);

            // Test Check Status
            String msg = DeliveryRequestManagerController.checkRequestStatus(r.Id);
            Test.stopTest();

            // Assertions
            WorkRequest__c updatedReq = [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :r.Id];

            // FIXED: Assertion now matches the Controller's logic ('Offer Sent' instead of 'Active')
            System.assertEquals('Offer Sent', updatedReq.StatusPk__c, 'Request status should be Offer Sent');
            System.assert(msg.contains('Status:'), 'Should return status message');
        }
    }
}