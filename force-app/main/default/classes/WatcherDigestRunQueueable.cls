/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Thin queueable wrapper around DeliveryWatcherService.run().
 *              Enqueued by DeliveryHubScheduler.enqueueWatcherDigestIfDue at
 *              the configured GMT hour once per day. Implements
 *              Database.AllowsCallouts so the orchestrator's downstream
 *              DeliverySlackService.postWatcherDigest @future callout chain
 *              is permitted in the same job. Mirrors
 *              DeliveryForecastAlertQueueable shape.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class WatcherDigestRunQueueable implements Queueable, Database.AllowsCallouts {

    /**
     * @description Queueable entry point. Delegates to the orchestrator and
     *              swallows any exception so the queueable doesn't crash
     *              loudly in the org's job monitor — failures are already
     *              captured in WatcherDigest__c.ErrorMessageTxt__c.
     * @param qc Queueable context (unused).
     */
    public void execute(QueueableContext qc) {
        try {
            DeliveryWatcherService.run();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[WatcherDigestRunQueueable] run failed: ' + e.getMessage());
        }
    }
}
