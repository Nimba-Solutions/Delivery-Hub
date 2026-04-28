/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Stripe webhook handler. Maps Stripe charge.succeeded /
 *               payment_intent.succeeded events to a DeliveryTransaction__c
 *               via DeliveryDocPaymentService.recordPayment, which in turn
 *               auto-flips the parent DeliveryDocument__c to Paid when totals
 *               match.
 *
 *               Document linkage: the Stripe object's metadata.document_id
 *               must be set when generating the Checkout Session / Payment
 *               Intent. The outbound IntegrationProvider__mdt template for
 *               Stripe should always inject {{document_id}} into metadata so
 *               this lookup succeeds round-trip.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier')
global with sharing class DeliveryStripePaymentHandler implements IWebhookEventHandler {

    private static final Set<String> SUPPORTED = new Set<String>{
        'charge.succeeded',
        'payment_intent.succeeded'
    };

    /**
     * @description Process a Stripe webhook event.
     * @param eventType The Stripe "type" field value.
     * @param payload The decoded event body.
     * @return ok with the new DeliveryTransaction__c Id on success,
     *         ignored for unsupported types, terminal on bad config.
     */
    global WebhookHandlerResult handle(String eventType, Map<String, Object> payload) {
        if (!SUPPORTED.contains(eventType)) {
            return WebhookHandlerResult.ignored('Unsupported Stripe event ' + eventType);
        }
        Map<String, Object> dataObject = extractDataObject(payload);
        if (dataObject == null) {
            return WebhookHandlerResult.terminal('Stripe event missing data.object');
        }
        String documentIdRaw = readDocumentId(dataObject);
        if (String.isBlank(documentIdRaw)) {
            return WebhookHandlerResult.terminal(
                'Stripe metadata.document_id missing — cannot link payment to a DeliveryDocument__c');
        }
        Id documentId;
        try {
            documentId = Id.valueOf(documentIdRaw);
        } catch (System.StringException e) {
            return WebhookHandlerResult.terminal(
                'metadata.document_id is not a valid Salesforce Id: ' + documentIdRaw);
        }
        Decimal amount = readAmount(dataObject);
        if (amount == null || amount <= 0) {
            return WebhookHandlerResult.terminal(
                'Stripe event amount missing or non-positive');
        }
        String chargeId = readChargeId(dataObject);
        try {
            DeliveryDocPaymentService.recordPayment(
                documentId,
                amount,
                Date.today(),
                'Stripe ' + eventType + ' / ' + (chargeId == null ? 'no-id' : chargeId)
            );
        } catch (Exception e) {
            return WebhookHandlerResult.retryable(
                'recordPayment failed: ' + e.getMessage());
        }
        return WebhookHandlerResult.ok(documentIdRaw);
    }

    @TestVisible
    private static Map<String, Object> extractDataObject(Map<String, Object> payload) {
        Object dataNode = payload.get('data');
        if (!(dataNode instanceof Map<String, Object>)) { return null; }
        Object obj = ((Map<String, Object>) dataNode).get('object');
        return obj instanceof Map<String, Object> ? (Map<String, Object>) obj : null;
    }

    @TestVisible
    private static String readDocumentId(Map<String, Object> dataObject) {
        Object metadata = dataObject.get('metadata');
        if (!(metadata instanceof Map<String, Object>)) { return null; }
        Object docId = ((Map<String, Object>) metadata).get('document_id');
        return docId == null ? null : String.valueOf(docId);
    }

    /**
     * @description Stripe reports amounts in the smallest currency unit
     *              (cents for USD). Convert to the major unit DH stores.
     * @param dataObject The Stripe data.object Map.
     * @return Amount as a Decimal in the major currency unit, or null if absent.
     */
    @TestVisible
    private static Decimal readAmount(Map<String, Object> dataObject) {
        Object raw = dataObject.containsKey('amount_received')
            ? dataObject.get('amount_received')
            : dataObject.get('amount');
        if (raw == null) { return null; }
        Decimal cents;
        if (raw instanceof Decimal) {
            cents = (Decimal) raw;
        } else if (raw instanceof Integer) {
            cents = Decimal.valueOf((Integer) raw);
        } else if (raw instanceof Long) {
            cents = Decimal.valueOf((Long) raw);
        } else {
            try {
                cents = Decimal.valueOf(String.valueOf(raw));
            } catch (Exception e) {
                return null;
            }
        }
        return cents.divide(100, 2);
    }

    @TestVisible
    private static String readChargeId(Map<String, Object> dataObject) {
        Object id = dataObject.get('id');
        return id == null ? null : String.valueOf(id);
    }
}
