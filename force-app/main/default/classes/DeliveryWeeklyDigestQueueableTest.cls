/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWeeklyDigestQueueable.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWeeklyDigestQueueableTest {

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
    }

    @IsTest
    static void testExecuteRunsWithoutError() {
        Test.startTest();
        System.enqueueJob(new DeliveryWeeklyDigestQueueable());
        Test.stopTest();

        System.assert(true, 'Queueable should execute without errors');
    }
}
