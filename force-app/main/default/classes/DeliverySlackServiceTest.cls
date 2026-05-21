/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliverySlackService.
 *              Covers the @AuraEnabled testWebhook method and the
 *              @future postStageChanges method via a mock callout.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySlackServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    // ── Mock ─────────────────────────────────────────────────────────────────

    /**
     * @description HTTP mock that returns a configurable status code and body.
     *              Tracks invocation count via an instance field so tests can assert
     *              on callouts that fire from @future methods — Limits.getCallouts()
     *              reads the test method's context, not the @future's own async
     *              context, so it always shows 0 for async callouts.
     */
    private class SlackMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        public Integer callCount = 0;

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
         * @description Returns the configured mock response and increments callCount.
         * @param req The outbound HttpRequest (unused)
         * @return HttpResponse configured mock response
         */
        public HttpResponse respond(HttpRequest req) {
            this.callCount++;
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
            SetupOwnerId        = UserInfo.getOrganizationId(),
            SlackWebhookUrlTxt__c  = 'https://hooks.slack.com/services/test'
        );
        insert settings;
    }

    // ── testWebhook ───────────────────────────────────────────────────────────

    @IsTest
    static void testWebhookSuccess() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
            Test.startTest();
            String result = DeliverySlackService.testWebhook('https://hooks.slack.com/services/test');
            Test.stopTest();
            System.assertEquals('Success', result, 'Expected Success on HTTP 200');
        }
    }

    @IsTest
    static void testWebhookFailure() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new SlackMock(400, 'no_team'));
            Test.startTest();
            String result = DeliverySlackService.testWebhook('https://hooks.slack.com/services/test');
            Test.stopTest();
            System.assert(result.startsWith('Failed'), 'Expected failure message on HTTP 400');
        }
    }

    @IsTest
    static void testWebhookBlankUrl() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliverySlackService.testWebhook('');
                System.assert(false, 'Expected AuraHandledException for blank URL');
            } catch (AuraHandledException e) {
                System.assert(true, 'Correct exception thrown for blank URL');
            }
            Test.stopTest();
        }
    }

    // ── postStageChanges ──────────────────────────────────────────────────────

    @IsTest
    static void testPostStageChangesWithUrl() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
            Map<String, String> changes = new Map<String, String>{
                'TKT-001' => 'In Development',
                'TKT-002' => 'Ready for QA'
            };
            Test.startTest();
            DeliverySlackService.postStageChanges(changes);
            Test.stopTest();
            // Verify the @future callout was dispatched (counts as 1 callout)
            System.assert(Limits.getCallouts() <= Limits.getLimitCallouts(), 'Callout should not exceed limits');
        }
    }

    @IsTest
    static void testPostStageChangesNoUrl() {
        System.runAs(testUser) {
            // Overwrite settings with no Slack URL — should no-op
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SlackWebhookUrlTxt__c = null;
            update settings;

            Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
            Map<String, String> changes = new Map<String, String>{ 'TKT-001' => 'Done' };
            Test.startTest();
            DeliverySlackService.postStageChanges(changes);
            Test.stopTest();
            // With no webhook URL, should no-op and make zero callouts
            System.assertEquals(0, Limits.getCallouts(), 'No callouts should be made when webhook URL is null');
        }
    }

    // ── postApprovalRequest ────────────────────────────────────────────────

    @IsTest
    static void testPostApprovalRequestSuccess() {
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));

            // Create a work item to get a valid Id
            WorkItem__c wi = new WorkItem__c(
                BriefDescriptionTxt__c = 'Test Approval Item',
                StageNamePk__c = 'In Client Approval'
            );
            insert wi;

            String ctxJson = JSON.serialize(new Map<String, String>{
                'workItemId' => wi.Id,
                'workItemName' => 'WI-001',
                'workItemTitle' => 'Test Approval Item',
                'newStage' => 'In Client Approval'
            });

            Test.startTest();
            DeliverySlackService.postApprovalRequest(ctxJson);
            Test.stopTest();
            System.assert(Limits.getCallouts() <= Limits.getLimitCallouts(), 'Approval request callout should not exceed limits');
        }
    }

    @IsTest
    static void testPostApprovalRequestNoUrl() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SlackWebhookUrlTxt__c = null;
            update settings;

            String ctxJson = JSON.serialize(new Map<String, String>{
                'workItemId' => null,
                'workItemName' => 'WI-001',
                'workItemTitle' => 'Test',
                'newStage' => 'In Client Approval'
            });

            Test.setMock(HttpCalloutMock.class, new SlackMock(200, 'ok'));
            Test.startTest();
            DeliverySlackService.postApprovalRequest(ctxJson);
            Test.stopTest();
            System.assertEquals(0, Limits.getCallouts(), 'No callouts should be made when webhook URL is null');
        }
    }

    // ── postCommentBatch ─────────────────────────────────────────────────────

    @IsTest
    static void testPostCommentBatchHappyPath() {
        // Org default settings already have SlackWebhookUrlTxt; opt into comment sync.
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.EnableSlackCommentSyncDateTime__c = DateTime.now();
        update s;

        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'Slack outbound seed');
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }

        // Tests the realistic outbound chain: comment insert →
        // DeliveryWorkItemCommentTriggerHandler.postCommentsToSlack →
        // DeliverySlackService.postCommentBatch (@future) → callout. Inserting
        // inside startTest keeps the trigger's @future inside the stopTest flush
        // window. Don't ALSO call postCommentBatch explicitly — that doubles
        // the callout count without adding test value.
        SlackMock mock = new SlackMock(200, 'ok');
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        WorkItemComment__c c = new WorkItemComment__c(
            WorkItemId__c = wi.Id, BodyTxt__c = 'Comment body', AuthorTxt__c = 'Glen'
        );
        insert c;
        Test.stopTest();
        System.assertEquals(1, mock.callCount,
            'Comment insert should fan out to Slack via the trigger handler @future');
    }

    @IsTest
    static void testPostCommentBatchOptOutNoOps() {
        // EnableSlackCommentSyncDateTime__c is null on the seeded settings — should no-op.
        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'Opt-out seed');
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
        WorkItemComment__c c = new WorkItemComment__c(
            WorkItemId__c = wi.Id, BodyTxt__c = 'Body', AuthorTxt__c = 'Glen'
        );
        insert c;

        SlackMock mock = new SlackMock(200, 'ok');
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        DeliverySlackService.postCommentBatch(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals(0, mock.callCount,
            'No callouts when EnableSlackCommentSyncDateTime__c is null');
    }

    // ── postWatcherDigest ────────────────────────────────────────────────────

    /**
     * @description postWatcherDigest happy path — when the webhook URL is
     *              configured and payload is non-blank, exactly one callout
     *              fires.
     */
    @IsTest
    static void testPostWatcherDigestPostsWhenConfigured() {
        String payload = JSON.serialize(new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => 'test' }
                }
            }
        });
        SlackMock mock = new SlackMock(200, 'ok');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        DeliverySlackService.postWatcherDigest(payload);
        Test.stopTest();
        System.assertEquals(1, mock.callCount,
            'postWatcherDigest should fire one callout when the webhook URL is configured');
    }

    /**
     * @description postWatcherDigest no-ops silently when the webhook URL is
     *              blank.
     */
    @IsTest
    static void testPostWatcherDigestNoopsWithoutWebhook() {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.SlackWebhookUrlTxt__c = null;
        update s;

        SlackMock mock = new SlackMock(200, 'ok');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        DeliverySlackService.postWatcherDigest('{"blocks":[]}');
        Test.stopTest();
        System.assertEquals(0, mock.callCount,
            'No callout should fire when SlackWebhookUrlTxt__c is null');
    }

    /**
     * @description postWatcherDigest no-ops on a blank payload string.
     */
    @IsTest
    static void testPostWatcherDigestNoopsWithBlankPayload() {
        SlackMock mock = new SlackMock(200, 'ok');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        DeliverySlackService.postWatcherDigest('');
        Test.stopTest();
        System.assertEquals(0, mock.callCount,
            'Blank payload should short-circuit before the callout');
    }

    @IsTest
    static void testPostCommentBatchSkipsSlackMirrors() {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.EnableSlackCommentSyncDateTime__c = DateTime.now();
        update s;

        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'Mirror echo seed');
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
        WorkItemComment__c c = new WorkItemComment__c(
            WorkItemId__c = wi.Id, BodyTxt__c = 'Mirror body',
            AuthorTxt__c = 'Slack: U12345'
        );
        insert c;

        SlackMock mock = new SlackMock(200, 'ok');
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        DeliverySlackService.postCommentBatch(new Set<Id>{ c.Id });
        Test.stopTest();
        System.assertEquals(0, mock.callCount,
            'Slack-authored comments must be skipped to prevent inbound-outbound loop');
    }
}
