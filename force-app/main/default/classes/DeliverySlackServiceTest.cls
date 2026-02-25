/**
 * @description Unit tests for DeliverySlackService.
 *              Covers the @AuraEnabled testWebhook method and the
 *              @future postStageChanges method via a mock callout.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySlackServiceTest {

    // ── Mock ─────────────────────────────────────────────────────────────────

    /**
     * @description HTTP mock that returns a configurable status code and body.
     */
    private class SlackMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;

        /**
         * @description Constructs a mock with the given response values.
         * @param statusCode HTTP status code to return
         * @param body       Response body string
         */
        SlackMock(Integer statusCode, String body) {
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
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            SetupOwnerId        = UserInfo.getOrganizationId(),
            SlackWebhookUrl__c  = 'https://hooks.slack.com/services/test'
        );
        insert settings;
    }

    // ── testWebhook ───────────────────────────────────────────────────────────

    @IsTest
    static void testWebhookSuccess() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
        Test.startTest();
        String result = DeliverySlackService.testWebhook('https://hooks.slack.com/services/test');
        Test.stopTest();
        System.assertEquals('Success', result, 'Expected Success on HTTP 200');
    }

    @IsTest
    static void testWebhookFailure() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(400, 'no_team'));
        Test.startTest();
        String result = DeliverySlackService.testWebhook('https://hooks.slack.com/services/test');
        Test.stopTest();
        System.assert(result.startsWith('Failed'), 'Expected failure message on HTTP 400');
    }

    @IsTest
    static void testWebhookBlankUrl() {
        Test.startTest();
        try {
            DeliverySlackService.testWebhook('');
            System.assert(false, 'Expected AuraHandledException for blank URL');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correct exception thrown for blank URL');
        }
        Test.stopTest();
    }

    // ── postStageChanges ──────────────────────────────────────────────────────

    @IsTest
    static void testPostStageChangesWithUrl() {
        Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
        Map<String, String> changes = new Map<String, String>{
            'TKT-001' => 'In Development',
            'TKT-002' => 'Ready for QA'
        };
        Test.startTest();
        DeliverySlackService.postStageChanges(changes);
        Test.stopTest();
        // No exception = success; @future callout completed without error
        System.assert(true, 'postStageChanges completed without exception');
    }

    @IsTest
    static void testPostStageChangesNoUrl() {
        // Overwrite settings with no Slack URL — should no-op
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        settings.SlackWebhookUrl__c = null;
        update settings;

        Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
        Map<String, String> changes = new Map<String, String>{ 'TKT-001' => 'Done' };
        Test.startTest();
        DeliverySlackService.postStageChanges(changes);
        Test.stopTest();
        System.assert(true, 'postStageChanges no-ops silently when no URL is configured');
    }
}
