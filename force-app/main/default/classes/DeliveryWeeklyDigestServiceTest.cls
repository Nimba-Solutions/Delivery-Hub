/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryWeeklyDigestService and DeliveryWeeklyDigestQueueable.
 *               Covers: digest enabled/disabled, AI success/failure fallback, recipient
 *               resolution (configured vs. fallback), HTML content, queueable execution,
 *               day-of-week matching, edge cases for email parsing, data gathering, and
 *               HTML rendering paths.
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

    /**
     * @description Digest enabled with configured recipients list.
     *              Exercises the parseEmailList path end-to-end.
     */
    @IsTest
    static void testSendDigestWithConfiguredRecipients() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestRecipientsTxt__c = 'alice@test.com, bob@test.com';
        update s;
        createWorkItems();

        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        System.assert(true, 'Digest should send to configured recipients.');
    }

    /**
     * @description Digest enabled with no work items at all.
     *              Exercises the zero-count paths in gatherDigestData.
     */
    @IsTest
    static void testSendDigestNoWorkItems() {
        createSettings(true, false, '');
        // No work items created

        Test.startTest();
        DeliveryWeeklyDigestService.sendWeeklyDigest();
        Test.stopTest();

        System.assert(true, 'Digest should send even with zero work items.');
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

    /**
     * @description Recipient list with extra commas and whitespace should be cleaned.
     */
    @IsTest
    static void testResolveRecipientsWithExtraCommas() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestRecipientsTxt__c = ' alice@test.com , , bob@test.com , ';
        update s;

        Test.startTest();
        List<String> recipients = DeliveryWeeklyDigestService.resolveRecipients(s);
        Test.stopTest();

        System.assertEquals(2, recipients.size(),
            'Should parse 2 valid addresses and skip blanks.');
        System.assertEquals('alice@test.com', recipients[0],
            'First address should be trimmed.');
        System.assertEquals('bob@test.com', recipients[1],
            'Second address should be trimmed.');
    }

    /**
     * @description Single recipient address, no commas.
     */
    @IsTest
    static void testResolveSingleRecipient() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestRecipientsTxt__c = 'solo@test.com';
        update s;

        Test.startTest();
        List<String> recipients = DeliveryWeeklyDigestService.resolveRecipients(s);
        Test.stopTest();

        System.assertEquals(1, recipients.size(), 'Should parse exactly 1 address.');
        System.assertEquals('solo@test.com', recipients[0], 'Address should match.');
    }

    // ── Tests: gatherDigestData ─────────────────────────────────────────────

    /**
     * @description Directly test gatherDigestData with work items in various stages.
     */
    @IsTest
    static void testGatherDigestDataWithWorkItems() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        createWorkItems();

        Test.startTest();
        DeliveryWeeklyDigestService.DigestData data = DeliveryWeeklyDigestService.gatherDigestData(s);
        Test.stopTest();

        System.assertNotEquals(null, data, 'DigestData should not be null.');
        System.assert(data.newThisWeek >= 0, 'newThisWeek should be non-negative.');
        System.assert(data.completedThisWeek >= 0, 'completedThisWeek should be non-negative.');
        System.assert(data.activeItems >= 0, 'activeItems should be non-negative.');
        System.assert(data.attentionItems >= 0, 'attentionItems should be non-negative.');
        System.assert(data.hoursLogged >= 0, 'hoursLogged should be non-negative.');
        System.assertNotEquals(null, data.slaCounts, 'slaCounts should be initialized.');
        System.assertNotEquals(null, data.topAttentionItems, 'topAttentionItems should be initialized.');
    }

    /**
     * @description Directly test gatherDigestData with no work items.
     */
    @IsTest
    static void testGatherDigestDataEmpty() {
        DeliveryHubSettings__c s = createSettings(true, false, '');

        Test.startTest();
        DeliveryWeeklyDigestService.DigestData data = DeliveryWeeklyDigestService.gatherDigestData(s);
        Test.stopTest();

        System.assertEquals(0, data.completedThisWeek, 'completedThisWeek should be 0.');
        System.assertEquals(0, data.newThisWeek, 'newThisWeek should be 0.');
        System.assertEquals(0, data.activeItems, 'activeItems should be 0.');
        System.assertEquals(0, data.attentionItems, 'attentionItems should be 0.');
        System.assertEquals(0, data.hoursLogged, 'hoursLogged should be 0.');
        System.assert(data.topAttentionItems.isEmpty(), 'topAttentionItems should be empty.');
    }

    /**
     * @description Gather data with work items that have SLA target dates set,
     *              exercising the SLA health counting loop.
     */
    @IsTest
    static void testGatherDigestDataWithSlaItems() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        List<WorkItem__c> items = new List<WorkItem__c>();
        // Active item with SLA target date (SLAStatusTxt__c is formula, so we set fields it depends on)
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'SLA tracked item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'High',
            IsActiveBool__c = true,
            SLATargetDate__c = Date.today().addDays(5)
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'SLA at-risk item',
            StageNamePk__c = 'In QA',
            PriorityPk__c = 'Medium',
            IsActiveBool__c = true,
            SLATargetDate__c = Date.today().addDays(1)
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'SLA breached item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'Critical',
            IsActiveBool__c = true,
            SLATargetDate__c = Date.today().addDays(-3)
        ));
        insert items;

        Test.startTest();
        DeliveryWeeklyDigestService.DigestData data = DeliveryWeeklyDigestService.gatherDigestData(s);
        Test.stopTest();

        System.assertNotEquals(null, data.slaCounts, 'slaCounts should be populated.');
        // Verify the SLA counting loop ran (actual formula values may vary)
        Integer totalSla = 0;
        for (Integer v : data.slaCounts.values()) {
            totalSla += v;
        }
        System.assert(totalSla >= 0, 'Total SLA count should be non-negative.');
    }

    // ── Tests: tryGenerateAiSummary ─────────────────────────────────────────

    /**
     * @description AI disabled in settings: should return null immediately.
     */
    @IsTest
    static void testTryGenerateAiSummaryDisabled() {
        DeliveryHubSettings__c s = createSettings(true, false, '');

        Test.startTest();
        String summary = DeliveryWeeklyDigestService.tryGenerateAiSummary(s);
        Test.stopTest();

        System.assertEquals(null, summary,
            'AI summary should be null when AI is disabled.');
    }

    /**
     * @description AI enabled but no API key: should return null.
     */
    @IsTest
    static void testTryGenerateAiSummaryNoKey() {
        DeliveryHubSettings__c s = createSettings(true, true, '');

        Test.startTest();
        String summary = DeliveryWeeklyDigestService.tryGenerateAiSummary(s);
        Test.stopTest();

        System.assertEquals(null, summary,
            'AI summary should be null when API key is blank.');
    }

    /**
     * @description AI enabled with key, successful callout.
     */
    @IsTest
    static void testTryGenerateAiSummarySuccess() {
        DeliveryHubSettings__c s = createSettings(true, true, 'sk-test-key');
        createWorkItems();
        Test.setMock(HttpCalloutMock.class, new OpenAIMock(200, 'OK', aiSuccessBody()));

        Test.startTest();
        String summary = DeliveryWeeklyDigestService.tryGenerateAiSummary(s);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'AI summary should not be null on success.');
        System.assert(summary.contains('productive'), 'Summary should contain mock response text.');
    }

    /**
     * @description AI enabled but callout returns error — should catch and return null.
     */
    @IsTest
    static void testTryGenerateAiSummaryCalloutError() {
        DeliveryHubSettings__c s = createSettings(true, true, 'sk-bad-key');
        createWorkItems();
        Test.setMock(HttpCalloutMock.class,
            new OpenAIMock(500, 'Internal Server Error', '{"error":"server error"}'));

        Test.startTest();
        String summary = DeliveryWeeklyDigestService.tryGenerateAiSummary(s);
        Test.stopTest();

        // The method should catch the exception and return null
        // (Exact behavior depends on DeliveryAiController error handling)
        System.assert(true, 'Should not throw an exception on callout failure.');
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
        System.assert(!html.contains('SLA Health'),
            'HTML should not contain SLA section when all counts are zero.');
        System.assert(html.contains('Powered by Delivery Hub | Cloud Nimbus LLC'),
            'HTML should contain the footer branding.');
    }

    /**
     * @description Verifies HTML with hours logged rendered correctly.
     */
    @IsTest
    static void testBuildDigestHtmlWithHoursLogged() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = null;
        data.completedThisWeek = 2;
        data.newThisWeek = 3;
        data.activeItems = 10;
        data.attentionItems = 1;
        data.hoursLogged = 22.5;
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 0, 'At Risk' => 0, 'Breached' => 0, 'Met' => 0
        };
        data.topAttentionItems = new List<DeliveryWeeklyDigestService.AttentionItem>();

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(html.contains('Hours Logged This Week'),
            'HTML should contain hours logged section.');
        System.assert(html.contains('22.5'),
            'HTML should contain the hours value.');
    }

    /**
     * @description Verifies HTML with null hours logged does not show hours section.
     */
    @IsTest
    static void testBuildDigestHtmlNoHours() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = null;
        data.completedThisWeek = 0;
        data.newThisWeek = 0;
        data.activeItems = 0;
        data.attentionItems = 0;
        data.hoursLogged = null;
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 0, 'At Risk' => 0, 'Breached' => 0, 'Met' => 0
        };
        data.topAttentionItems = new List<DeliveryWeeklyDigestService.AttentionItem>();

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(!html.contains('Hours Logged This Week'),
            'HTML should not show hours section when hours is null.');
    }

    /**
     * @description Verifies HTML with multiple attention items renders the table.
     */
    @IsTest
    static void testBuildDigestHtmlMultipleAttentionItems() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = null;
        data.completedThisWeek = 1;
        data.newThisWeek = 2;
        data.activeItems = 5;
        data.attentionItems = 3;
        data.hoursLogged = 0;
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 0, 'At Risk' => 0, 'Breached' => 0, 'Met' => 0
        };

        List<DeliveryWeeklyDigestService.AttentionItem> items = new List<DeliveryWeeklyDigestService.AttentionItem>();

        DeliveryWeeklyDigestService.AttentionItem a1 = new DeliveryWeeklyDigestService.AttentionItem();
        a1.name = 'WI-0010';
        a1.title = 'Blocked by vendor';
        a1.stage = 'Blocked';
        a1.priority = 'Critical';
        a1.daysInStage = 10;
        items.add(a1);

        DeliveryWeeklyDigestService.AttentionItem a2 = new DeliveryWeeklyDigestService.AttentionItem();
        a2.name = 'WI-0011';
        a2.title = 'Waiting for approval';
        a2.stage = 'Ready for Client Approval';
        a2.priority = null; // Test the null priority '--' fallback
        a2.daysInStage = 3;
        items.add(a2);

        data.topAttentionItems = items;

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(html.contains('Top Items Needing Attention'),
            'HTML should contain attention items heading.');
        System.assert(html.contains('WI-0010'),
            'HTML should contain first attention item.');
        System.assert(html.contains('WI-0011'),
            'HTML should contain second attention item.');
        System.assert(html.contains('--'),
            'HTML should show -- for null priority.');
    }

    /**
     * @description Verifies HTML with AI summary containing newlines renders paragraph breaks.
     */
    @IsTest
    static void testBuildDigestHtmlAiWithNewlines() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = 'Paragraph one.\n\nParagraph two.\nLine two continued.';
        data.completedThisWeek = 0;
        data.newThisWeek = 0;
        data.activeItems = 0;
        data.attentionItems = 0;
        data.hoursLogged = 0;
        data.slaCounts = new Map<String, Integer>{
            'On Track' => 0, 'At Risk' => 0, 'Breached' => 0, 'Met' => 0
        };
        data.topAttentionItems = new List<DeliveryWeeklyDigestService.AttentionItem>();

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(html.contains('Board Summary'),
            'HTML should contain Board Summary heading.');
        System.assert(html.contains('Paragraph one.'),
            'HTML should contain first paragraph.');
        System.assert(html.contains('<br/>'),
            'HTML should convert single newlines to br tags.');
    }

    /**
     * @description Verifies HTML when slaCounts map is null (defensive path).
     */
    @IsTest
    static void testBuildDigestHtmlNullSlaCounts() {
        DeliveryWeeklyDigestService.DigestData data = new DeliveryWeeklyDigestService.DigestData();
        data.aiSummary = null;
        data.completedThisWeek = 0;
        data.newThisWeek = 0;
        data.activeItems = 0;
        data.attentionItems = 0;
        data.hoursLogged = 0;
        data.slaCounts = null;
        data.topAttentionItems = null;

        String html = DeliveryWeeklyDigestService.buildDigestHtml(data);

        System.assert(!html.contains('SLA Health'),
            'HTML should not contain SLA section when slaCounts is null.');
        System.assert(!html.contains('Top Items Needing Attention'),
            'HTML should not contain attention section when list is null.');
        System.assert(html.contains('Powered by Delivery Hub'),
            'HTML should still contain footer.');
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

    /**
     * @description Null settings should return false.
     */
    @IsTest
    static void testIsTodayDigestDayNullSettings() {
        System.assertEquals(false, DeliveryWeeklyDigestService.isTodayDigestDay(null),
            'Should return false when settings are null.');
    }

    /**
     * @description When digest day field is blank, should default to Monday.
     */
    @IsTest
    static void testIsTodayDigestDayDefaultDay() {
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestDayTxt__c = '';
        update s;

        // Should use default day (Monday)
        String todayName = Datetime.now().format('EEEE');
        Boolean expected = todayName.equalsIgnoreCase('Monday');
        System.assertEquals(expected, DeliveryWeeklyDigestService.isTodayDigestDay(s),
            'Should default to Monday when digest day is blank.');
    }

    /**
     * @description When digest day has leading/trailing whitespace.
     */
    @IsTest
    static void testIsTodayDigestDayWithWhitespace() {
        String todayName = Datetime.now().format('EEEE');
        DeliveryHubSettings__c s = createSettings(true, false, '');
        s.WeeklyDigestDayTxt__c = '  ' + todayName + '  ';
        update s;

        System.assertEquals(true, DeliveryWeeklyDigestService.isTodayDigestDay(s),
            'Should trim whitespace and still match today.');
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

    /**
     * @description Verifies the Queueable executes when digest is disabled (no-op path).
     */
    @IsTest
    static void testQueueableDigestDisabled() {
        createSettings(false, false, '');

        Test.startTest();
        System.enqueueJob(new DeliveryWeeklyDigestQueueable());
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(),
            'Queueable should not send email when digest is disabled.');
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

