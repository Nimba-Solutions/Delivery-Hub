/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Smoke test for WatcherUpcomingSignoffQueryService stub.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherUpcomingSignoffQueryServiceTest {

    /**
     * @description Verifies the stub returns an empty SignalResultDTO.
     */
    @IsTest
    static void testStubReturnsEmpty() {
        Test.startTest();
        SignalResultDTO result = WatcherUpcomingSignoffQueryService.query();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Stub should return a non-null DTO');
        System.assertEquals(WatcherUpcomingSignoffQueryService.SIGNAL_NAME, result.signalName,
            'signalName should be populated');
        System.assertEquals(0, result.primaryCount, 'Stub should report zero primary count');
        System.assertEquals(0, result.topEntries.size(), 'Stub should not surface entries');
    }
}
