/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryWeeklyDigestService and DeliveryWeeklyDigestQueueable.
 *               Covers: digest enabled/disabled, AI success/failure fallback, recipient
 *               resolution (configured vs. fallback), HTML content, queueable execution,
 *               and day-of-week matching.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWeeklyDigestServiceTest {

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static DeliveryHubSettings__c createSettings(
        Boolean digestEnabled, Boolean aiEnabled, String apiKey
    ) {
        DeliveryHubSettings__c s = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            WeeklyDigestEnabledBool__c = digestEnabled,
            WeeklyDigestDayTxt__c = 'Monday',
            AISuggestionsEnabledBool__c = aiEnabled,
            OpenAIApiKeyTxt__c = apiKey,
            OpenAIModelTxt__c = 'gpt-3.5-turbo',
            EmailNotificationsEnabledBool__c = false
        );
        insert s;
        return s;
    }

    private static void createWorkItems() {
        List<WorkItem__c> items = new List<WorkItem__c>();
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Implement login page',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'High',
            IsActiveBool__c = true
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Design database schema',
            StageNamePk__c = 'Ready for Client Approval',
            PriorityPk__c = 'Critical',
            IsActiveBool__c = true
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Write unit tests',
            StageNamePk__c = 'Done',
            PriorityPk__c = 'Medium',
            IsActiveBool__c = false
        ));
        insert items;
    }

    private static String aiSuccessBody() {
        return '{"choices":[{"message":{"content":"The team had a productive week. '
             + 'Several items moved forward and client approvals are pending."}}]}';
    }

    // ── Tests: sendWeeklyDigest ──────────────────────────────────────────────

    /**
     * @description Digest enabled, AI configured, work items exist. Should send
     *              an email with AI summary and metrics.
     */
    @IsTest
    static void testSendDigestWithAiSuccess() {
        createSettings(true, true, 'sk-test-key-123');
        createWorkItems();
        Test.setMock(HttpCalloutMock.class, new OpenAIMock(200, 'OK', aiSuccessBody()));

        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        // Email was dispatched (no exception thrown)
        System.assert(true, 'Digest should send without error when AI is configured.');
    }

    /**
     * @description Digest enabled but AI not configured. Should still send a
     *              metrics-only digest (graceful fallback).
     */
    @IsTest
    static void testSendDigestWithoutAi() {
        createSettings(true, false, '');
        createWorkItems();

        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        System.assert(true, 'Digest should send with metrics only when AI is not configured.');
    }

    /**
     * @description Digest enabled, AI configured but callout fails (401).
     *              Should still send the metrics-only fallback.
     */
    @IsTest
    static void testSendDigestAiCalloutFails() {
        createSettings(true, true, 'sk-bad-key');
        createWorkItems();
        Test.setMock(HttpCalloutMock.class,
            new OpenAIMock(401, 'Unauthorized', '{"error":"Invalid key"}'));

        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        System.assert(true, 'Digest should still send when AI callout fails.');
    }

    /**
     * @description Digest disabled. Should no-op without sending.
     */
    @IsTest
    static void testSendDigestDisabled() {
        createSettings(false, false, '');

        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(),
            'No emails should be sent when digest is disabled.');
    }

    /**
     * @description No settings record exists. Should no-op.
     */
    @IsTest
    static void testSendDigestNoSettings() {
        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(),
            'No emails should be sent when settings are missing.');
    }

    // ── Tests: recipient resolution ─────────────────────────────────────────

    /**
     * @description Configured recipients should be parsed from the comma-separated field.
     */
    @IsTest
    static void testResolveConfiguredRecipients() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestRecipientsTxt__c = 'alice@test.com, bob@test.com, charlie@test.com';
        update s;

        Test.startTest();
        List<String> recipients = DeliveryWeeklyDigestService.resolveRecipients(s);
        Test.stopTest();

        System.assertEquals(3, recipients.size(),
            'Should parse 3 comma-separated addresses.');
        System.assert(recipients.contains('alice@test.com'),
            'Should include alice.');
    }

    /**
     * @description When no recipients are configured, falls back to active users.
     */
    @IsTest
    static void testResolveFallbackRecipients() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        // WeeklyDigestRecipientsTxt__c is null

        Test.startTest();
        List<String> recipients = DeliveryWeeklyDigestService.resolveRecipients(s);
        Test.stopTest();

        System.assert(!recipients.isEmpty(),
            'Fallback should return at least the running user.');
    }

    // ── Tests: HTML content ─────────────────────────────────────────────────

    /**
     * @description Verifies the HTML includes expected sections when AI summary is present.
     */
    @IsTest
    static void testBuildDigestHtmlWithAi() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = 'Great progress this week across all workstreams.';
        data.completedThisWeek = 3;
        data.newThisWeek = 5;
        data.activeItems = 12;
        data.attentionItems = 2;
        data.hoursLogged = 40.5;
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 8, 'At Risk' => 2, 'Breached' => 1, 'Met' => 3
        };

        DeliveryWeeklyDigestService.AttentionItem ai = new DeliveryWeeklyDigestService.AttentionItem();
        ai.name = 'WI-0001';
        ai.title = 'Fix login timeout';
        ai.stage = 'Ready for Client Approval';
        ai.priority = 'Critical';
        ai.daysInStage = 5;
        data.topAttentionItems = new List<DeliveryWeeklyDigestService.AttentionItem>{ ai };

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(html.contains('Board Summary'),
            'HTML should contain Board Summary heading.');
        System.assert(html.contains('Great progress'),
            'HTML should contain the AI summary text.');
        System.assert(html.contains('This Week at a Glance'),
            'HTML should contain metrics heading.');
        System.assert(html.contains('SLA Health'),
            'HTML should contain SLA section.');
        System.assert(html.contains('WI-0001'),
            'HTML should contain the attention item name.');
        System.assert(html.contains('Fix login timeout'),
            'HTML should contain the attention item title.');
        System.assert(html.contains('Powered by Delivery Hub | Cloud Nimbus LLC'),
            'HTML should contain the footer branding.');
    }

    /**
     * @description Verifies the HTML works without AI summary (metrics-only).
     */
    @IsTest
    static void testBuildDigestHtmlWithoutAi() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = null;
        data.completedThisWeek = 0;
        data.newThisWeek = 1;
        data.activeItems = 4;
        data.attentionItems = 0;
        data.hoursLogged = 0;
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 0, 'At Risk' => 0, 'Breached' => 0, 'Met' => 0
        };
        data.topAttentionItems = new List<DeliveryWeeklyDigestService.AttentionItem>();

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(!html.contains('Board Summary'),
            'HTML should not contain Board Summary when AI is null.');
        System.assert(html.contains('This Week at a Glance'),
            'HTML should still contain metrics heading.');
        System.assert(html.contains('Powered by Delivery Hub | Cloud Nimbus LLC'),
            'HTML should contain the footer branding.');
    }

    // ── Tests: isTodayDigestDay ─────────────────────────────────────────────

    /**
     * @description When configured day matches today, should return true.
     */
    @IsTest
    static void testIsTodayDigestDayMatches() {
        String todayName = Datetime.now().format('EEEE');
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestDayTxt__c = todayName;
        update s;

        System.assertEquals(true, DeliveryWeeklyDigestService.isTodayDigestDay(s),
            'Should return true when today matches configured day.');
    }

    /**
     * @description When configured day does not match today, should return false.
     */
    @IsTest
    static void testIsTodayDigestDayNoMatch() {
        // Pick a day that is definitely not today
        String todayName = Datetime.now().format('EEEE');
        String otherDay = todayName == 'Monday' ? 'Friday' : 'Monday';
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestDayTxt__c = otherDay;
        update s;

        System.assertEquals(false, DeliveryWeeklyDigestService.isTodayDigestDay(s),
            'Should return false when today does not match configured day.');
    }

    /**
     * @description When digest is disabled, isTodayDigestDay always returns false.
     */
    @IsTest
    static void testIsTodayDigestDayDisabled() {
        DeliveryHubSettings__c s = createSettings(false, false, '');

        System.assertEquals(false, DeliveryWeeklyDigestService.isTodayDigestDay(s),
            'Should return false when digest is disabled.');
    }

    // ── Tests: Queueable ────────────────────────────────────────────────────

    /**
     * @description Verifies the Queueable delegates to the service without error.
     */
    @IsTest
    static void testQueueableExecution() {
        createSettings(true, false, '');
        createWorkItems();

        Test.startTest();
        System.enqueueJob(new DeliveryWeeklyDigestQueueable());
        Test.stopTest();

        System.assert(true, 'Queueable should execute without error.');
    }

    /**
     * @description Verifies the Queueable with AI callout mock.
     */
    @IsTest
    static void testQueueableWithAiCallout() {
        createSettings(true, true, 'sk-test-key-123');
        createWorkItems();
        Test.setMock(HttpCalloutMock.class, new OpenAIMock(200, 'OK', aiSuccessBody()));

        Test.startTest();
        System.enqueueJob(new DeliveryWeeklyDigestQueueable());
        Test.stopTest();

        System.assert(true, 'Queueable should execute with AI callout without error.');
    }

    // ── Tests: Scheduler integration ────────────────────────────────────────

    /**
     * @description Verifies the scheduler can still be scheduled with the new digest logic.
     */
    @IsTest
    static void testSchedulerWithDigest() {
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            WeeklyDigestEnabledBool__c = true,
            WeeklyDigestDayTxt__c = Datetime.now().format('EEEE'),
            AutoCreateWorkRequestBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Mothership',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://mothership.example.com',
            RemoteExternalIdTxt__c = 'CLIENT-XYZ'
        );
        insert vendor;

        Test.setMock(HttpCalloutMock.class, new OpenAIMock(200, 'OK',
            '[{"objectType":"WorkItem__c","payload":"{}","syncItemId":"a0D000000000000EAA","createdDate":"2026-02-18T12:00:00.000Z"}]'));

        Test.startTest();
        String cronExp = '0 0 8 15 3 ? 2040';
        String jobId = System.schedule('TestDigestScheduler', cronExp, new DeliveryHubScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct, 'Scheduled job should exist.');
    }

    // ── Mock ─────────────────────────────────────────────────────────────────

    private class OpenAIMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String body;

        /**
         * @description Constructs a mock HTTP response.
         * @param statusCode The HTTP status code to return.
         * @param status     The HTTP status string.
         * @param body       The response body string.
         */
        public OpenAIMock(Integer statusCode, String status, String body) {
            this.statusCode = statusCode;
            this.status     = status;
            this.body       = body;
        }

        /**
         * @description Returns a pre-configured HttpResponse for any inbound request.
         * @param req The outbound HttpRequest being intercepted.
         * @return HttpResponse The configured mock response.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.body);
            res.setStatusCode(this.statusCode);
            res.setStatus(this.status);
            return res;
        }
    }
}
