/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test for WatcherDigestRunQueueable. Asserts the queueable
 *              calls DeliveryWatcherService.run() — verified indirectly via
 *              the digest row insertion path.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherDigestRunQueueableTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    /**
     * @description Master-flag-off run via the queueable should not insert
     *              a WatcherDigest__c row and must not throw. Proves the
     *              queueable hands control to the service.
     */
    @IsTest
    static void testQueueableMasterOffNoOps() {
        System.runAs(testUser) {
            insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
            Test.startTest();
            System.enqueueJob(new WatcherDigestRunQueueable());
            Test.stopTest();
            System.assertEquals(0, [SELECT COUNT() FROM WatcherDigest__c],
                'Master-off queueable run should not write an audit row');
        }
    }

    /**
     * @description Happy-path queueable run with master + SLA flags on
     *              should produce exactly one WatcherDigest__c row.
     */
    @IsTest
    static void testQueueableWritesDigestWhenEnabled() {
        System.runAs(testUser) {
            Datetime now = Datetime.now();
            insert new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                EnableWatcherDigestDateTime__c = now,
                EnableWatcherSLABreachDateTime__c = now
            );
            Test.startTest();
            System.enqueueJob(new WatcherDigestRunQueueable());
            Test.stopTest();
            System.assertEquals(1, [SELECT COUNT() FROM WatcherDigest__c],
                'Enabled queueable run should write exactly one audit row');
        }
    }
}
