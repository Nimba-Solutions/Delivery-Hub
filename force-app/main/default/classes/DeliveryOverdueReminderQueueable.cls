/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Queueable wrapper that executes overdue invoice reminder processing.
 *               Enqueued by DeliveryHubScheduler once per day at the configured hour.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryOverdueReminderQueueable implements Queueable {

    /**
     * @description Delegates to the overdue reminder service to evaluate overdue
     *              invoices and send escalating reminder emails.
     * @param context The QueueableContext provided by the platform.
     */
    public void execute(QueueableContext context) {
        DeliveryOverdueReminderService.processOverdueReminders();
    }
}
