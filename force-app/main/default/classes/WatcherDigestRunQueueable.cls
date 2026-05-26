/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Thin queueable wrapper around DeliveryWatcherService.run().
 *              Enqueued by DeliveryHubScheduler.enqueueWatcherDigestIfDue at
 *              the configured GMT hour once per day. Implements
 *              Database.AllowsCallouts so the orchestrator's downstream
 *              DeliverySlackService.postWatcherDigest synchronous callout is
 *              permitted in the same job. (postWatcherDigest used to be
 *              @future; promoted to synchronous so the WatcherDigest__c
 *              StatusPk__c reflects actual Slack delivery outcome — closes
 *              Flow 8 #3 audit gap.) Mirrors DeliveryForecastAlertQueueable shape.
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
