/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Queueable wrapper that executes the weekly digest email send.
 *               Implements Database.AllowsCallouts because the AI summary calls
 *               the OpenAI API. Enqueued by DeliveryHubScheduler on the configured
 *               digest day.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryWeeklyDigestQueueable implements Queueable, Database.AllowsCallouts {

    /**
     * @description Delegates to the digest service to gather data, build the email,
     *              and send it to configured recipients.
     * @param context The QueueableContext provided by the platform.
     */
    public void execute(QueueableContext context) {
        DeliveryWeeklyDigestService.sendWeeklyDigest();
    }
}
