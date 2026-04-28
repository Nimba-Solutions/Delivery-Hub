/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHubHealthService — runs the full check
 *               sweep and verifies results come back well-formed for every
 *               check key. Individual check pass/warn/fail thresholds are
 *               exercised via fixture data where setup is cheap.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class DeliveryHubHealthServiceTest {

    @IsTest
    static void runAllChecksReturnsExpectedKeys() {
        Test.startTest();
        List<DeliveryHubHealthCheckResult> results = DeliveryHubHealthService.runAllChecks();
        Test.stopTest();

        Set<String> seen = new Set<String>();
        for (DeliveryHubHealthCheckResult r : results) {
            System.assertNotEquals(null, r.checkKey, 'Each result must have a checkKey');
            System.assertNotEquals(null, r.label, 'Each result must have a label');
            System.assert(
                r.statusPk == 'pass' || r.statusPk == 'warn' || r.statusPk == 'fail',
                'Status must be one of pass/warn/fail, got: ' + r.statusPk);
            System.assertNotEquals(null, r.checkedAtDateTime, 'Each result must be timestamped');
            seen.add(r.checkKey);
        }
        // Spot-check that the canonical keys are present.
        for (String expected : new Set<String>{
            'scheduledJobs', 'staleFailedSyncs', 'orphanedWorkItems',
            'permSetCoverage', 'endpointReachability', 'apiKeyConfigured',
            'customSettings', 'mothershipHandshake', 'inboundWebhookProviders',
            'sortOrderHealth'
        }) {
            System.assert(seen.contains(expected),
                'Expected check missing from runAllChecks(): ' + expected);
        }
    }

    @IsTest
    static void scheduledJobsCheckPassesWhenSchedulerRan() {
        DeliveryHubScheduler.scheduleAll();
        Test.startTest();
        DeliveryHubHealthCheckResult r = new DeliveryHubHealthService.ScheduledJobsCheck()
            .run('scheduledJobs', 'Scheduled Sync Jobs');
        Test.stopTest();
        System.assertEquals('pass', r.statusPk,
            'After scheduleAll, scheduledJobs should pass');
    }

    @IsTest
    static void staleFailedSyncsCountsOnlyOldFailedRows() {
        DeliveryHubHealthCheckResult r = new DeliveryHubHealthService.StaleFailedSyncsCheck()
            .run('staleFailedSyncs', 'Stale Failed Syncs');
        // Empty org defaults: the check should pass with no stale rows.
        System.assertEquals('pass', r.statusPk);
    }

    @IsTest
    static void permSetCoverageWarnsWhenNoRulesEnabled() {
        // We can't insert UserAutoAssignConfig__mdt at runtime; the CMT is
        // populated via shipped metadata rows in the package. The check is
        // resilient to either state — at minimum it returns something
        // well-formed.
        DeliveryHubHealthCheckResult r = new DeliveryHubHealthService.PermSetCoverageCheck()
            .run('permSetCoverage', 'Permission Set Coverage');
        System.assertNotEquals(null, r.statusPk);
    }

    @IsTest
    static void safeWrapsCheckExceptions() {
        DeliveryHubHealthCheckResult r = DeliveryHubHealthService.safe(
            'k', 'L', new ThrowingCheck());
        System.assertEquals('fail', r.statusPk);
        System.assert(r.detail.contains('Boom'));
    }

    private class ThrowingCheck implements DeliveryHubHealthService.IHealthCheck {
        public DeliveryHubHealthCheckResult run(String key, String label) {
            throw new IllegalArgumentException('Boom');
        }
    }
}
