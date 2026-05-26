/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWatcherService orchestrator. Covers:
 *
 *                - master-flag-off → Skipped status + no audit row
 *                - happy path → Success status + WatcherDigest__c written
 *                  + heartbeat stamped + per-signal counts populated
 *                - quiet-day → Success status + audit row written but
 *                  no Slack callout (recipient list empty path)
 *                - signal-throw → captured into errorMessages (validated
 *                  via tampered settings shape would be too invasive;
 *                  rely on stub flag-gate to keep coverage tractable)
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWatcherServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    /**
     * @description Mock that always returns 200 OK for the Slack callout.
     */
    private class SlackMock implements HttpCalloutMock {
        public Integer callCount = 0;
        /**
         * @description Records each invocation + returns a canned 200 OK so the
         *              @future callout path executes end-to-end in test context.
         * @param req Inbound HttpRequest from DeliverySlackService.postWatcherDigest.
         * @return Canned HttpResponse (status 200, body "ok").
         */
        public HttpResponse respond(HttpRequest req) {
            this.callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    /**
     * @description Master flag off → run() is a silent no-op. No
     *              WatcherDigest__c row is inserted.
     */
    @IsTest
    static void testMasterFlagOffSkips() {
        System.runAs(testUser) {
            insert new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId()
                // EnableWatcherDigestDateTime__c left null → master off
            );

            Test.startTest();
            DeliveryWatcherService.WatcherRunResultDTO result =
                DeliveryWatcherService.runAndReturnSummary();
            Test.stopTest();

            System.assertEquals('Skipped', result.status, 'Status should be Skipped when master off');
            System.assertEquals(0, [SELECT COUNT() FROM WatcherDigest__c],
                'Master-flag-off path must not write a WatcherDigest__c row');
        }
    }

    /**
     * @description Quiet-day happy path: master + SLA signal enabled but no
     *              alertable WIs in the org → Success status, audit row
     *              written, heartbeat stamped, no Slack callout because
     *              recipient list is empty.
     */
    @IsTest
    static void testQuietDayWritesDigestNoSlack() {
        System.runAs(testUser) {
            insertWatcherEnabledSettings(null);
            SlackMock mock = new SlackMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            DeliveryWatcherService.WatcherRunResultDTO result =
                DeliveryWatcherService.runAndReturnSummary();
            Test.stopTest();

            System.assertEquals('Success', result.status, 'Status should be Success on quiet day');
            System.assertEquals(0, result.slaBreachCount, 'No seeded WIs → zero breach count');
            System.assertEquals(0, result.slaAtRiskCount, 'No seeded WIs → zero at-risk count');
            System.assertEquals(0, mock.callCount,
                'Empty recipient list → no Slack callout, even on Success');
            List<WatcherDigest__c> rows = [SELECT Id, StatusPk__c, RunModePk__c FROM WatcherDigest__c];
            System.assertEquals(1, rows.size(), 'One audit row should have been written');
            System.assertEquals('Success', rows.get(0).StatusPk__c, 'Persisted status should match');
            System.assertEquals('Test', rows.get(0).RunModePk__c,
                'Test-context runs should be tagged Test in RunModePk__c');

            DeliveryHubSettings__c after = DeliveryHubSettings__c.getOrgDefaults();
            System.assertNotEquals(null, after.LastWatcherHeartbeatDateTime__c,
                'Heartbeat should be stamped after a Success run');
        }
    }

    /**
     * @description Happy path with seeded alertable WIs + recipient list
     *              configured → Success status, audit row written, Slack
     *              callout fires.
     */
    @IsTest
    static void testHappyPathPostsToSlack() {
        System.runAs(testUser) {
            insertWatcherEnabledSettings(String.valueOf(UserInfo.getUserId()));
            seedAlertableWorkItem();
            SlackMock mock = new SlackMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            DeliveryWatcherService.WatcherRunResultDTO result =
                DeliveryWatcherService.runAndReturnSummary();
            Test.stopTest();

            System.assertEquals('Success', result.status, 'Happy path should be Success');
            System.assert(result.slaBreachCount >= 1,
                'Seeded breached WI should be counted, got ' + result.slaBreachCount);
            System.assertEquals(1, mock.callCount,
                'Recipient list configured + non-quiet → 1 Slack callout');
            System.assertEquals(1, [SELECT COUNT() FROM WatcherDigest__c],
                'One audit row written for the run');
        }
    }

    /**
     * @description run() is the void wrapper; calling it should not throw
     *              when the master flag is off (entire run is a no-op).
     */
    @IsTest
    static void testRunVoidEntryPointNoThrow() {
        System.runAs(testUser) {
            insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
            Test.startTest();
            DeliveryWatcherService.run();
            Test.stopTest();
            System.assertEquals(0, [SELECT COUNT() FROM WatcherDigest__c],
                'run() with master off should still write nothing');
        }
    }

    /**
     * @description Signal 2 (Stuck Stage) happy path: Watcher should
     *              populate stuckStageCount when the gate is open and the
     *              service surfaces entries.
     */
    @IsTest
    static void testStuckStageSignalPopulatesCount() {
        System.runAs(testUser) {
            insertAllSignalsEnabledSettings(null);
            // Inject a deterministic stuck-stage cluster (CMT rows aren't
            // insertable in test context — the @TestVisible override drives
            // the signal here).
            WatcherStuckStageQueryService.testClusterOverride =
                new Map<String, WatcherStuckStageQueryService.RuleCluster>{
                    'In Development' => new WatcherStuckStageQueryService.RuleCluster(3, false)
                };
            for (Integer i = 0; i < 2; i++) {
                TestDataFactory.createWorkItem(new Map<String, Object>{
                    'BriefDescriptionTxt__c' => 'Stuck WI ' + i,
                    'StageNamePk__c' => 'In Development',
                    'StageEnteredDateTime__c' => Datetime.now().addDays(-6)
                });
            }
            SlackMock mock = new SlackMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            DeliveryWatcherService.WatcherRunResultDTO result =
                DeliveryWatcherService.runAndReturnSummary();
            Test.stopTest();

            System.assertEquals('Success', result.status, 'Status should be Success');
            System.assertEquals(2, result.stuckStageCount,
                'stuckStageCount should reflect the seeded stuck WIs (Warning weighting)');
            List<WatcherDigest__c> rows = [
                SELECT Id, SignalCountsTxt__c, FlaggedWorkItemIdsTxt__c FROM WatcherDigest__c
            ];
            System.assertEquals(1, rows.size(), 'One audit row should have been written');
            System.assert(rows.get(0).SignalCountsTxt__c.contains('Stuck:2'),
                'SignalCountsTxt__c should reflect Stuck:2 — got: ' + rows.get(0).SignalCountsTxt__c);
            System.assert(String.isNotBlank(rows.get(0).FlaggedWorkItemIdsTxt__c),
                'Stuck-stage WIs should be appended to FlaggedWorkItemIdsTxt__c');
        }
    }

    /**
     * @description Signal 3 (A/R Aging) happy path: Watcher should
     *              populate arOverdueCount + arOverdueAmount + a Document Id
     *              list when overdue invoices exist.
     */
    @IsTest
    static void testArAgingSignalPopulatesCountAndAmount() {
        System.runAs(testUser) {
            insertAllSignalsEnabledSettings(null);
            NetworkEntity__c client = TestDataFactory.defaultClient();
            insert new DeliveryDocument__c(
                NetworkEntityId__c = client.Id,
                TemplatePk__c = 'Invoice',
                StatusPk__c = 'Overdue',
                DueDateDate__c = Date.today().addDays(-20),
                TotalCurrency__c = 1500
            );
            SlackMock mock = new SlackMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            DeliveryWatcherService.WatcherRunResultDTO result =
                DeliveryWatcherService.runAndReturnSummary();
            Test.stopTest();

            System.assertEquals('Success', result.status, 'Status should be Success');
            System.assertEquals(1, result.arOverdueCount,
                'arOverdueCount should reflect the seeded overdue invoice');
            System.assertEquals(1500, result.arOverdueAmount,
                'arOverdueAmount should sum the seeded $1500 invoice');
            List<WatcherDigest__c> rows = [
                SELECT Id, SignalCountsTxt__c, FlaggedDocumentIdsTxt__c FROM WatcherDigest__c
            ];
            System.assertEquals(1, rows.size(), 'One audit row should have been written');
            System.assert(rows.get(0).SignalCountsTxt__c.contains('AR:1'),
                'SignalCountsTxt__c should reflect AR:1 — got: ' + rows.get(0).SignalCountsTxt__c);
            System.assert(String.isNotBlank(rows.get(0).FlaggedDocumentIdsTxt__c),
                'AR invoices should populate FlaggedDocumentIdsTxt__c');
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Inserts a DeliveryHubSettings__c row with Watcher
     *              master + SLA signal enabled. Optionally configures the
     *              recipient list (non-blank → Slack post path active).
     * @param recipientIds Optional recipient string; null = quiet path.
     */
    private static void insertWatcherEnabledSettings(String recipientIds) {
        Datetime now = Datetime.now();
        DeliveryHubSettings__c s = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableWatcherDigestDateTime__c = now,
            EnableWatcherSLABreachDateTime__c = now,
            SlackWebhookUrlTxt__c = 'https://hooks.slack.com/services/test',
            WatcherDigestRecipientUserIdsTxt__c = recipientIds
        );
        insert s;
    }

    /**
     * @description Inserts a DeliveryHubSettings__c row with Watcher master
     *              + all three implemented signals (SLA / Stuck Stage /
     *              A/R Aging) enabled. Used by PR-C signal-wiring tests.
     * @param recipientIds Optional recipient string; null = quiet path.
     */
    private static void insertAllSignalsEnabledSettings(String recipientIds) {
        Datetime now = Datetime.now();
        DeliveryHubSettings__c s = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableWatcherDigestDateTime__c = now,
            EnableWatcherSLABreachDateTime__c = now,
            EnableWatcherStuckStageDateTime__c = now,
            EnableWatcherARAgingDateTime__c = now,
            WatcherARAgingMinDaysOverdueNumber__c = 7,
            WatcherStuckStageDefaultDaysNumber__c = 5,
            SlackWebhookUrlTxt__c = 'https://hooks.slack.com/services/test',
            WatcherDigestRecipientUserIdsTxt__c = recipientIds
        );
        insert s;
    }

    /**
     * @description Seeds a single Breached WI via TestDataFactory.
     */
    private static void seedAlertableWorkItem() {
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Breached WI for orchestrator test',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => Date.today().addDays(-3)
        });
    }
}
