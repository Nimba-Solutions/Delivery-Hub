/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Smoke test for WatcherUnhappySignalQueryService stub. PR-B
 *              ships this signal as a flag-gated empty result; the test
 *              just asserts the stub responds with an empty SignalResultDTO.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherUnhappySignalQueryServiceTest {

    /**
     * @description Verifies the stub returns a non-null result with empty
     *              entries and zero counts.
     */
    @IsTest
    static void testStubReturnsEmpty() {
        Test.startTest();
        SignalResultDTO result = WatcherUnhappySignalQueryService.query();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Stub should return a non-null DTO');
        System.assertEquals(WatcherUnhappySignalQueryService.SIGNAL_NAME, result.signalName,
            'signalName should be populated even for an empty result');
        System.assertEquals(0, result.primaryCount, 'Stub should report zero primary count');
        System.assertEquals(0, result.secondaryCount, 'Stub should report zero secondary count');
        System.assertEquals(0, result.topEntries.size(), 'Stub should not surface entries');
        System.assertEquals(null, result.errorMessage, 'Stub should not populate an error');
    }
}
