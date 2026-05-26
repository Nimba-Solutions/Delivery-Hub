/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Smoke test for WatcherFailedSyncTrendQueryService stub.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherFailedSyncTrendQueryServiceTest {

    /**
     * @description Verifies the stub returns an empty SignalResultDTO.
     */
    @IsTest
    static void testStubReturnsEmpty() {
        Test.startTest();
        SignalResultDTO result = WatcherFailedSyncTrendQueryService.query();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Stub should return a non-null DTO');
        System.assertEquals(WatcherFailedSyncTrendQueryService.SIGNAL_NAME, result.signalName,
            'signalName should be populated');
        System.assertEquals(0, result.primaryCount, 'Stub should report zero primary count');
    }
}
