/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryOverdueReminderQueueable.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryOverdueReminderQueueableTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
    }

    @IsTest
    static void testExecuteRunsWithoutError() {
        System.runAs(testUser) {
            Test.startTest();
            System.enqueueJob(new DeliveryOverdueReminderQueueable());
            Test.stopTest();

            System.assert(true, 'Queueable should execute without errors');
        }
    }
}
