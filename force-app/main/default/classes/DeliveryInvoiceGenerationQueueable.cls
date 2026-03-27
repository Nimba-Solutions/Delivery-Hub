/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Queueable wrapper that executes automated invoice generation
 *               and overdue invoice marking. Enqueued by DeliveryHubScheduler
 *               when the invoice generation feature is enabled and has not
 *               already run today.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryInvoiceGenerationQueueable implements Queueable {

    /**
     * @description Delegates to the invoice generation service to process
     *              billing-enabled entities and mark overdue invoices.
     * @param context The QueueableContext provided by the platform.
     */
    public void execute(QueueableContext context) {
        DeliveryInvoiceGenerationService.generateScheduledDocuments();
        DeliveryInvoiceGenerationService.markOverdueInvoices();
    }
}
