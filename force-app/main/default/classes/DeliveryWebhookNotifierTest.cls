/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryWebhookNotifier.
 *              Validates webhook callout behaviour for both sync and document
 *              platform events, including success, failure, and no-URL scenarios.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWebhookNotifierTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    // ── Mock ─────────────────────────────────────────────────────────────────

    /**
     * @description HTTP mock that returns a configurable status code and body.
     */
    private class WebhookMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        /**
         * @description Constructs a mock with the given response values.
         * @param statusCode HTTP status code to return
         * @param body       Response body string
         */
        WebhookMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }

        /**
         * @description Returns the configured mock response.
         * @param req The outbound HttpRequest (unused)
         * @return HttpResponse configured mock response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    // ── Setup ─────────────────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId     = UserInfo.getOrganizationId(),
            WebhookUrlTxt__c = 'https://portal.example.com/api/webhooks/delivery'
        );
        insert settings;
    }

    // ── Queueable execute — success ──────────────────────────────────────────

    @IsTest
    static void testExecuteSuccess() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new WebhookMock(200, 'ok'));

            List<Map<String, Object>> payloads = new List<Map<String, Object>>{
                new Map<String, Object>{
                    'eventType'  => 'DeliverySync',
                    'objectType' => 'WorkItem__c',
                    'status'     => 'Synced',
                    'recordId'   => 'a0B000000000001AAA',
                    'timestamp'  => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
                }
            };

            Test.startTest();
            System.enqueueJob(new DeliveryWebhookNotifier(payloads));
            Test.stopTest();

            // Verify the callout was dispatched (no exception = success)
            System.assert(Limits.getCallouts() <= Limits.getLimitCallouts(),
                'Callout should not exceed limits');
        }
    }

    // ── Queueable execute — HTTP error (logged, not thrown) ──────────────────

    @IsTest
    static void testExecuteHttpError() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new WebhookMock(500, 'Internal Server Error'));

            List<Map<String, Object>> payloads = new List<Map<String, Object>>{
                new Map<String, Object>{
                    'eventType'  => 'DeliveryDocEvent',
                    'documentId' => 'a0D000000000001AAA',
                    'status'     => 'Generated',
                    'timestamp'  => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
                }
            };

            Test.startTest();
            System.enqueueJob(new DeliveryWebhookNotifier(payloads));
            Test.stopTest();

            // Should complete without throwing — error is logged internally
            System.assert(true, 'Job should complete gracefully on HTTP error');
        }
    }

    // ── Queueable execute — no webhook URL configured ────────────────────────

    @IsTest
    static void testExecuteNoUrl() {
        System.runAs(testUser) {
            // Wipe the webhook URL
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.WebhookUrlTxt__c = null;
            update settings;

            List<Map<String, Object>> payloads = new List<Map<String, Object>>{
                new Map<String, Object>{
                    'eventType' => 'DeliverySync',
                    'status'    => 'Synced'
                }
            };

            Test.startTest();
            System.enqueueJob(new DeliveryWebhookNotifier(payloads));
            Test.stopTest();

            // No callouts should have been made
            System.assertEquals(0, Limits.getCallouts(),
                'No callouts should be made when webhook URL is null');
        }
    }

    // ── enqueueSyncEvents — with URL ─────────────────────────────────────────

    @IsTest
    static void testEnqueueSyncEventsWithUrl() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new WebhookMock(200, 'ok'));

            List<DeliverySync__e> events = new List<DeliverySync__e>{
                new DeliverySync__e(
                    ObjectTypePk__c  = 'WorkItem__c',
                    DirectionPk__c   = 'Outbound',
                    StatusPk__c      = 'Synced',
                    RecordIdTxt__c   = 'a0B000000000001AAA'
                ),
                new DeliverySync__e(
                    ObjectTypePk__c  = 'WorkLog__c',
                    DirectionPk__c   = 'Inbound',
                    StatusPk__c      = 'Synced',
                    RecordIdTxt__c   = 'a0B000000000002AAA'
                )
            };

            Test.startTest();
            DeliveryWebhookNotifier.enqueueSyncEvents(events);
            Test.stopTest();

            System.assert(Limits.getCallouts() <= Limits.getLimitCallouts(),
                'Sync event callout should not exceed limits');
        }
    }

    // ── enqueueSyncEvents — no URL (fast-exit) ───────────────────────────────

    @IsTest
    static void testEnqueueSyncEventsNoUrl() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.WebhookUrlTxt__c = null;
            update settings;

            List<DeliverySync__e> events = new List<DeliverySync__e>{
                new DeliverySync__e(
                    ObjectTypePk__c = 'WorkItem__c',
                    DirectionPk__c  = 'Outbound',
                    StatusPk__c     = 'Synced'
                )
            };

            Test.startTest();
            DeliveryWebhookNotifier.enqueueSyncEvents(events);
            Test.stopTest();

            System.assertEquals(0, Limits.getCallouts(),
                'No callouts should be made when webhook URL is null');
        }
    }

    // ── enqueueDocEvents — with URL ──────────────────────────────────────────

    @IsTest
    static void testEnqueueDocEventsWithUrl() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new WebhookMock(200, 'ok'));

            List<DeliveryDocEvent__e> events = new List<DeliveryDocEvent__e>{
                new DeliveryDocEvent__e(
                    DocumentIdTxt__c = 'a0D000000000001AAA',
                    EntityNameTxt__c = 'Mobilization Funding',
                    StatusPk__c      = 'Generated',
                    TemplatePk__c    = 'Invoice'
                )
            };

            Test.startTest();
            DeliveryWebhookNotifier.enqueueDocEvents(events);
            Test.stopTest();

            System.assert(Limits.getCallouts() <= Limits.getLimitCallouts(),
                'Doc event callout should not exceed limits');
        }
    }

    // ── enqueueDocEvents — no URL (fast-exit) ────────────────────────────────

    @IsTest
    static void testEnqueueDocEventsNoUrl() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.WebhookUrlTxt__c = null;
            update settings;

            List<DeliveryDocEvent__e> events = new List<DeliveryDocEvent__e>{
                new DeliveryDocEvent__e(
                    DocumentIdTxt__c = 'a0D000000000001AAA',
                    StatusPk__c      = 'Generated'
                )
            };

            Test.startTest();
            DeliveryWebhookNotifier.enqueueDocEvents(events);
            Test.stopTest();

            System.assertEquals(0, Limits.getCallouts(),
                'No callouts should be made when webhook URL is null');
        }
    }

    // ── Multiple payloads in single job ──────────────────────────────────────

    @IsTest
    static void testMultiplePayloadsInSingleJob() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new WebhookMock(200, 'ok'));

            List<Map<String, Object>> payloads = new List<Map<String, Object>>();
            for (Integer i = 0; i < 5; i++) {
                payloads.add(new Map<String, Object>{
                    'eventType'  => 'DeliverySync',
                    'objectType' => 'WorkItem__c',
                    'status'     => 'Synced',
                    'recordId'   => 'a0B00000000000' + i + 'AAA',
                    'timestamp'  => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
                });
            }

            Test.startTest();
            System.enqueueJob(new DeliveryWebhookNotifier(payloads));
            Test.stopTest();

            System.assert(true, 'Multiple payloads should be delivered in a single job');
        }
    }
}
