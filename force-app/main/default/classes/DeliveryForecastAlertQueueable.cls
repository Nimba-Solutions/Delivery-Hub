/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Thin queueable wrapper around DeliveryForecastAlertService.runSweep.
 *              Enqueued from DeliveryHubScheduler.enqueueForecastAlertsIfDue at
 *              8 GMT once per day when the feature is enabled. Mirrors
 *              DeliveryOverdueReminderQueueable shape.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class DeliveryForecastAlertQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext qc) {
        try {
            DeliveryForecastAlertService.runSweep();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryForecastAlertQueueable] sweep failed: ' + e.getMessage());
        }
    }
}
