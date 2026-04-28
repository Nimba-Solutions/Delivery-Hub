/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWebhookEventRouter — routing-rules parse,
 *               dotted-path lookup, handler dispatch, error paths. Uses an
 *               in-memory IntegrationProvider__mdt because CMT can't be
 *               inserted at runtime.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class DeliveryWebhookEventRouterTest {

    public class StubHandler implements IWebhookEventHandler {
        public WebhookHandlerResult handle(String eventType, Map<String, Object> payload) {
            return WebhookHandlerResult.ok('STUB_RESULT_ID');
        }
    }

    private static IntegrationProvider__mdt baseInbound() {
        IntegrationProvider__mdt p = new IntegrationProvider__mdt();
        p.DeveloperName = 'Test_Inbound';
        p.DirectionTxt__c = 'Inbound';
        p.SignatureAlgorithmTxt__c = 'None';
        p.EventTypeFieldPathTxt__c = 'type';
        p.RoutingRulesJsonTxt__c =
            '{"foo.event":"DeliveryWebhookEventRouterTest.StubHandler"}';
        p.EnabledDateTime__c = Datetime.now();
        return p;
    }

    @IsTest
    static void readDottedPathTopLevel() {
        Map<String, Object> payload = new Map<String, Object>{ 'type' => 'foo.event' };
        System.assertEquals('foo.event',
            DeliveryWebhookEventRouter.readDottedPath(payload, 'type'));
    }

    @IsTest
    static void readDottedPathNested() {
        Map<String, Object> payload = new Map<String, Object>{
            'data' => new Map<String, Object>{ 'event' => 'paid' }
        };
        System.assertEquals('paid',
            DeliveryWebhookEventRouter.readDottedPath(payload, 'data.event'));
    }

    @IsTest
    static void readDottedPathMissingReturnsNull() {
        System.assertEquals(null,
            DeliveryWebhookEventRouter.readDottedPath(
                new Map<String, Object>{ 'a' => 1 }, 'missing.path'));
    }

    @IsTest
    static void parseRoutingRulesValidJson() {
        IntegrationProvider__mdt p = baseInbound();
        Map<String, Object> rules = DeliveryWebhookEventRouter.parseRoutingRules(p);
        System.assertEquals('DeliveryWebhookEventRouterTest.StubHandler',
            String.valueOf(rules.get('foo.event')));
    }

    @IsTest
    static void parseRoutingRulesInvalidJsonReturnsNull() {
        IntegrationProvider__mdt p = baseInbound();
        p.RoutingRulesJsonTxt__c = '{not valid json}';
        System.assertEquals(null, DeliveryWebhookEventRouter.parseRoutingRules(p));
    }

    @IsTest
    static void instantiateUnknownClassReturnsNull() {
        System.assertEquals(null,
            DeliveryWebhookEventRouter.instantiate('Nonexistent_Class_Xyz_12345'));
    }

    @IsTest
    static void instantiateValidHandlerReturnsInstance() {
        IWebhookEventHandler handler = DeliveryWebhookEventRouter.instantiate(
            'DeliveryWebhookEventRouterTest.StubHandler');
        System.assertNotEquals(null, handler);
    }

    @IsTest
    static void dispatchHappyPathInvokesHandler() {
        IntegrationProvider__mdt p = baseInbound();
        Map<String, Object> payload = new Map<String, Object>{ 'type' => 'foo.event' };
        WebhookHandlerResult r = DeliveryWebhookEventRouter.dispatch(p, payload);
        System.assertEquals(true, r.success, 'Handler should fire and return ok');
        System.assertEquals('STUB_RESULT_ID', r.recordId);
    }

    @IsTest
    static void dispatchUnmappedEventReturnsIgnored() {
        IntegrationProvider__mdt p = baseInbound();
        Map<String, Object> payload = new Map<String, Object>{ 'type' => 'no.handler.for.this' };
        WebhookHandlerResult r = DeliveryWebhookEventRouter.dispatch(p, payload);
        System.assertEquals(true, r.success);
        System.assertEquals(200, r.httpStatus,
            'Unmapped event types are ignored, not retried');
    }

    @IsTest
    static void dispatchMissingEventTypeReturnsTerminal() {
        IntegrationProvider__mdt p = baseInbound();
        Map<String, Object> payload = new Map<String, Object>{ 'other' => 'x' };
        WebhookHandlerResult r = DeliveryWebhookEventRouter.dispatch(p, payload);
        System.assertEquals(false, r.success);
        System.assertEquals(400, r.httpStatus);
    }

    @IsTest
    static void findInboundReturnsNullForUnknown() {
        System.assertEquals(null,
            DeliveryWebhookEventRouter.findInbound('Nonexistent_Provider_99999'));
    }
}
