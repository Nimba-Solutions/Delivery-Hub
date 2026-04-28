/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Contract for inbound-webhook handlers dispatched by
 *               DeliveryWebhookEventRouter. One handler per kind of work
 *               (e.g. Stripe payment, GitHub release, QuickBooks invoice).
 *               Subscribers add their own handlers and reference them in
 *               an IntegrationProvider__mdt RoutingRulesJsonTxt__c row.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface IWebhookEventHandler {

    /**
     * @description Process one decoded webhook event.
     * @param eventType The event-type string extracted from the payload
     *                  (per IntegrationProvider__mdt.EventTypeFieldPathTxt__c).
     * @param payload The deserialized JSON body as a Map.
     * @return WebhookHandlerResult describing the outcome — used by the
     *         receiver to choose response status and body.
     */
    WebhookHandlerResult handle(String eventType, Map<String, Object> payload);
}
