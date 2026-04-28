/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Looks up the IntegrationProvider__mdt for an inbound webhook
 *               slug, parses the routing rules JSON, and instantiates the
 *               configured IWebhookEventHandler for the event type extracted
 *               from the payload.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryWebhookEventRouter {

    /**
     * @description Find the inbound provider by DeveloperName.
     * @param developerName URL slug from /webhook/&lt;DeveloperName&gt;.
     * @return Provider row, or null when no matching enabled inbound row exists.
     */
    public static IntegrationProvider__mdt findInbound(String developerName) {
        List<IntegrationProvider__mdt> hits = [
            SELECT DeveloperName, DirectionTxt__c, SignatureHeaderTxt__c,
                   SignatureSecretTxt__c, SignatureAlgorithmTxt__c,
                   EventTypeFieldPathTxt__c, RoutingRulesJsonTxt__c, EnabledDateTime__c
            FROM IntegrationProvider__mdt
            WHERE DeveloperName = :developerName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (hits.isEmpty()) { return null; }
        IntegrationProvider__mdt p = hits[0];
        if (p.EnabledDateTime__c == null) { return null; }
        if (p.DirectionTxt__c == null || !p.DirectionTxt__c.equalsIgnoreCase('Inbound')) {
            return null;
        }
        return p;
    }

    /**
     * @description Pull the event-type value out of the payload, look up the
     *              handler in the routing rules, instantiate it, and call
     *              handle().
     * @param provider Provider row (with routing rules JSON).
     * @param payload Decoded webhook body.
     * @return Result from the handler, or Ignored if no rule matched.
     */
    public static WebhookHandlerResult dispatch(
        IntegrationProvider__mdt provider,
        Map<String, Object> payload
    ) {
        String fieldPath = provider.EventTypeFieldPathTxt__c;
        if (String.isBlank(fieldPath)) {
            return WebhookHandlerResult.terminal(
                'EventTypeFieldPathTxt__c not configured on provider ' + provider.DeveloperName);
        }
        String eventType = readDottedPath(payload, fieldPath);
        if (String.isBlank(eventType)) {
            return WebhookHandlerResult.terminal(
                'No value at event-type path ' + fieldPath + ' in payload');
        }
        Map<String, Object> rules = parseRoutingRules(provider);
        if (rules == null || rules.isEmpty()) {
            return WebhookHandlerResult.terminal(
                'No routing rules configured on provider ' + provider.DeveloperName);
        }
        Object handlerName = rules.get(eventType);
        if (handlerName == null) {
            return WebhookHandlerResult.ignored('No handler for event type ' + eventType);
        }
        IWebhookEventHandler handler = instantiate(String.valueOf(handlerName));
        if (handler == null) {
            return WebhookHandlerResult.terminal(
                'Cannot resolve handler class ' + handlerName);
        }
        return handler.handle(eventType, payload);
    }

    @TestVisible
    private static Map<String, Object> parseRoutingRules(IntegrationProvider__mdt provider) {
        if (String.isBlank(provider.RoutingRulesJsonTxt__c)) { return null; }
        try {
            Object parsed = JSON.deserializeUntyped(provider.RoutingRulesJsonTxt__c);
            return parsed instanceof Map<String, Object>
                ? (Map<String, Object>) parsed
                : null;
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static String readDottedPath(Map<String, Object> payload, String dottedPath) {
        Object current = payload;
        for (String segment : dottedPath.split('\\.')) {
            if (!(current instanceof Map<String, Object>)) { return null; }
            current = ((Map<String, Object>) current).get(segment);
            if (current == null) { return null; }
        }
        return String.valueOf(current);
    }

    @TestVisible
    private static IWebhookEventHandler instantiate(String className) {
        Type t = Type.forName(className);
        if (t == null) {
            t = Type.forName('delivery', className);
        }
        if (t == null) { return null; }
        Object instance = t.newInstance();
        return instance instanceof IWebhookEventHandler
            ? (IWebhookEventHandler) instance
            : null;
    }
}
