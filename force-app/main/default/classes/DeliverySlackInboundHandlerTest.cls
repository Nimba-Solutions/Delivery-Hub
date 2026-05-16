/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliverySlackInboundHandler (Slack message → WI comment).
 *               Exercises the handle() method directly with synthesized Slack
 *               event_callback envelopes — no HTTP roundtrip required since
 *               the handler is a pure dispatcher.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySlackInboundHandlerTest {

    private static WorkItem__c seedWorkItem(String briefDesc) {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = briefDesc,
            StatusPk__c = 'Active',
            StageNamePk__c = 'In Development',
            ActivatedDateTime__c = DateTime.now()
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
        return [SELECT Id, Name FROM WorkItem__c WHERE Id = :wi.Id LIMIT 1];
    }

    private static Map<String, Object> buildEnvelope(String wiNameOrText, String userId) {
        return new Map<String, Object>{
            'type' => 'event_callback',
            'event' => new Map<String, Object>{
                'type' => 'message',
                'channel' => 'C12345',
                'user' => userId,
                'text' => wiNameOrText
            }
        };
    }

    @IsTest
    static void testIgnoreNonEventCallback() {
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        WebhookHandlerResult r = h.handle('url_verification',
            new Map<String, Object>{ 'type' => 'url_verification', 'challenge' => 'abc' });
        System.assertEquals(true, r.success);
        System.assertEquals(200, r.httpStatus);
        System.assert(r.message.startsWith('Ignored'),
            'Non-event_callback envelopes must be ignored gracefully');
    }

    @IsTest
    static void testIgnoreMissingEventBlock() {
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        WebhookHandlerResult r = h.handle('event_callback',
            new Map<String, Object>{ 'type' => 'event_callback' });
        System.assertEquals(false, r.success);
        System.assertEquals(400, r.httpStatus);
    }

    @IsTest
    static void testIgnoreNonMessageInnerType() {
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        Map<String, Object> envelope = new Map<String, Object>{
            'type' => 'event_callback',
            'event' => new Map<String, Object>{
                'type' => 'channel_join',
                'channel' => 'C12345',
                'user' => 'U999'
            }
        };
        WebhookHandlerResult r = h.handle('event_callback', envelope);
        System.assertEquals(true, r.success);
        System.assert(r.message.contains('not yet handled'));
    }

    @IsTest
    static void testIgnoreBotMessage() {
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        Map<String, Object> envelope = new Map<String, Object>{
            'type' => 'event_callback',
            'event' => new Map<String, Object>{
                'type' => 'message',
                'channel' => 'C12345',
                'user' => 'U999',
                'text' => 'T-0001 update from bot',
                'bot_id' => 'B12345'
            }
        };
        WebhookHandlerResult r = h.handle('event_callback', envelope);
        System.assert(r.message.contains('echo-suppression'),
            'Bot messages must be dropped to break the inbound-outbound loop');
    }

    @IsTest
    static void testIgnoreNoWiNameInText() {
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        Map<String, Object> envelope = buildEnvelope('Just a stray Slack message', 'U999');
        WebhookHandlerResult r = h.handle('event_callback', envelope);
        System.assert(r.message.contains('No WorkItem name'));
    }

    @IsTest
    static void testIgnoreWiNameNotFound() {
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        Map<String, Object> envelope = buildEnvelope('T-99999 doesn\'t exist', 'U999');
        WebhookHandlerResult r = h.handle('event_callback', envelope);
        System.assert(r.message.contains('No WorkItem with Name'));
    }

    @IsTest
    static void testCreateCommentOnRealWi() {
        WorkItem__c wi = seedWorkItem('Slack inbound roundtrip test');
        String wiName = wi.Name;
        DeliverySlackInboundHandler h = new DeliverySlackInboundHandler();
        Map<String, Object> envelope = buildEnvelope(
            wiName + ': Status check — can someone update?', 'U12345');
        WebhookHandlerResult r;
        Test.startTest();
            r = h.handle('event_callback', envelope);
        Test.stopTest();
        System.assertEquals(true, r.success);
        System.assertEquals(200, r.httpStatus);
        System.assertNotEquals(null, r.recordId);
        WorkItemComment__c c = [
            SELECT Id, BodyTxt__c, AuthorTxt__c, SourcePk__c, WorkItemId__c
            FROM WorkItemComment__c WHERE Id = :r.recordId LIMIT 1
        ];
        System.assertEquals(wi.Id, c.WorkItemId__c);
        System.assertEquals('API', c.SourcePk__c, 'v1 sources from API picklist value');
        System.assert(c.AuthorTxt__c.startsWith('Slack'),
            'Author tag must start with Slack so outbound trigger drops it as a mirror');
        System.assert(c.BodyTxt__c.contains('Status check'));
        System.assert(c.BodyTxt__c.contains('via Slack channel C12345'),
            'Channel-of-origin footer must be present so operators can trace the source');
    }

    @IsTest
    static void testWiNamePatternHandlesCaseAndPunctuation() {
        // Pattern is case-insensitive and tolerates surrounding punctuation
        System.assertEquals('T-0001',
            DeliverySlackInboundHandler.extractWorkItemName('t-0001 needs review'));
        System.assertEquals('T-1234',
            DeliverySlackInboundHandler.extractWorkItemName('Hey team T-1234: thoughts?'));
        System.assertEquals('T-987654',
            DeliverySlackInboundHandler.extractWorkItemName('See T-987654 for details'));
        System.assertEquals(null,
            DeliverySlackInboundHandler.extractWorkItemName('No ticket here'));
        System.assertEquals(null,
            DeliverySlackInboundHandler.extractWorkItemName(''));
        // 2-digit tickets are below the minimum (3-6 digits) so they don't match
        System.assertEquals(null,
            DeliverySlackInboundHandler.extractWorkItemName('T-01 is too short'));
    }
}
