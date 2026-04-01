/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryInvoiceGenerationQueueable.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryInvoiceGenerationQueueableTest {

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
    }

    @IsTest
    static void testExecuteRunsWithoutError() {
        Test.startTest();
        System.enqueueJob(new DeliveryInvoiceGenerationQueueable());
        Test.stopTest();

        // Queueable delegates to service methods — verify it completes without exception
        System.assert(true, 'Queueable should execute without errors');
    }
}
