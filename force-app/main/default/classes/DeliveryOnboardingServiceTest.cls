/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryOnboardingService. Covers:
 *                 - getTrack returns the bundle (or null when track missing)
 *                 - getProgress returns an initialised DTO when no row exists
 *                 - markLessonComplete writes the JSON list + isComplete stays
 *                   false while the quiz / checklist gates are unmet
 *                 - submitQuiz increments attempts, sets score, stamps
 *                   QuizLastAttemptDateTime__c, and sets CompletedDateTime__c
 *                   when threshold AND lessons AND required checklist are met
 *                 - verifyChecklistItem (manual path) writes the JSON map
 *                 - JSON helpers tolerate null / malformed input
 *
 *               __mdt records ARE available in test context without
 *               seeAllData=true. Tests that depend on specific seeded records
 *               use the Invoice_Generation_Track shape this PR ships; tests
 *               that would break on an empty-org scratch return early.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryOnboardingServiceTest {

    private static final String INVOICE_TRACK = 'Invoice_Generation_Track';

    @IsTest
    static void testGetTrackReturnsNullForBlankInput() {
        Test.startTest();
        DeliveryOnboardingService.TrackBundleDTO bundle =
            DeliveryOnboardingService.getTrack(null);
        Test.stopTest();
        System.assertEquals(null, bundle, 'Null track name should return null bundle');
    }

    @IsTest
    static void testGetTrackReturnsNullForUnknownTrack() {
        Test.startTest();
        DeliveryOnboardingService.TrackBundleDTO bundle =
            DeliveryOnboardingService.getTrack('Track_That_Does_Not_Exist_xyz');
        Test.stopTest();
        System.assertEquals(null, bundle,
            'Unknown track DeveloperName should return null, not throw');
    }

    @IsTest
    static void testGetTrackReturnsBundleForSeededTrack() {
        Integer tracks = [SELECT COUNT() FROM OnboardingTrack__mdt WHERE DeveloperName = :INVOICE_TRACK];
        if (tracks == 0) {
            return; // Empty-org tolerance — seed not deployed yet.
        }

        Test.startTest();
        DeliveryOnboardingService.TrackBundleDTO bundle =
            DeliveryOnboardingService.getTrack(INVOICE_TRACK);
        Test.stopTest();

        System.assertNotEquals(null, bundle, 'Bundle should not be null for seeded track');
        System.assertNotEquals(null, bundle.track, 'Track header should be present');
        System.assertEquals(INVOICE_TRACK, bundle.track.developerName,
            'Track developerName should round-trip');
        System.assertNotEquals(null, bundle.lessons, 'Lessons list should not be null');
        System.assert(bundle.lessons.size() >= 1,
            'Invoice_Generation_Track ships with at least one lesson');
        System.assertNotEquals(null, bundle.quiz, 'Quiz should be present');
        System.assertNotEquals(null, bundle.checklist, 'Checklist list should not be null');
    }

    @IsTest
    static void testGetProgressReturnsInitialisedDtoWhenNoRow() {
        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto =
            DeliveryOnboardingService.getProgress('Some_Track');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'Progress DTO should never be null for a valid track name');
        System.assertEquals('Some_Track', dto.track, 'Track propagates onto initialised DTO');
        System.assertEquals(UserInfo.getUserId(), dto.userId,
            'userId on the initialised DTO is the running user');
        System.assertEquals(false, dto.isComplete,
            'Initialised DTO must report isComplete=false');
        System.assertEquals(null, dto.progressId,
            'Initialised DTO has no progressId (no row yet)');
    }

    @IsTest
    static void testGetProgressReadsExistingRow() {
        OnboardingProgress__c row = TestDataFactory.newOnboardingProgress(new Map<String, Object>{
            'TrackTxt__c' => 'Existing_Track',
            'QuizScoreNumber__c' => 3,
            'QuizAttemptsNumber__c' => 1
        });

        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto =
            DeliveryOnboardingService.getProgress('Existing_Track');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should not be null');
        System.assertEquals(row.Id, dto.progressId, 'progressId should match inserted row');
        System.assertEquals(3, dto.quizScore, 'Quiz score should propagate');
        System.assertEquals(1, dto.quizAttempts, 'Quiz attempts should propagate');
    }

    @IsTest
    static void testMarkLessonCompleteWritesJsonAndKeepsTrackIncomplete() {
        Integer tracks = [SELECT COUNT() FROM OnboardingTrack__mdt WHERE DeveloperName = :INVOICE_TRACK];
        if (tracks == 0) {
            return; // Empty-org tolerance.
        }
        List<OnboardingLesson__mdt> lessons = [
            SELECT DeveloperName FROM OnboardingLesson__mdt
            WHERE TrackTxt__c = :INVOICE_TRACK LIMIT 1
        ];
        if (lessons.isEmpty()) {
            return; // Empty-org tolerance — track seeded but no lessons.
        }
        String lessonName = lessons.get(0).DeveloperName;

        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto =
            DeliveryOnboardingService.markLessonComplete(INVOICE_TRACK, lessonName);
        Test.stopTest();

        System.assertNotEquals(null, dto.lessonsCompletedJson,
            'Lessons-completed JSON should be populated after marking one lesson');
        System.assert(dto.lessonsCompletedJson.contains(lessonName),
            'Lesson DeveloperName should appear in the JSON: ' + dto.lessonsCompletedJson);
        System.assertEquals(false, dto.isComplete,
            'Track cannot be complete from a single lesson alone — quiz + remaining lessons gate it');
    }

    @IsTest
    static void testSubmitQuizIncrementsAttemptsAndStampsScore() {
        Integer tracks = [SELECT COUNT() FROM OnboardingTrack__mdt WHERE DeveloperName = :INVOICE_TRACK];
        if (tracks == 0) {
            return;
        }

        Test.startTest();
        DeliveryOnboardingService.ProgressDTO firstTry =
            DeliveryOnboardingService.submitQuiz(INVOICE_TRACK, 2);
        DeliveryOnboardingService.ProgressDTO secondTry =
            DeliveryOnboardingService.submitQuiz(INVOICE_TRACK, 5);
        Test.stopTest();

        System.assertEquals(1, firstTry.quizAttempts, 'First attempt sets count to 1');
        System.assertEquals(2, firstTry.quizScore, 'First score recorded');
        System.assertNotEquals(null, firstTry.quizLastAttemptDateTime,
            'Quiz last-attempt timestamp should be stamped');
        System.assertEquals(2, secondTry.quizAttempts, 'Second attempt increments count to 2');
        System.assertEquals(5, secondTry.quizScore, 'Latest score overwrites prior');
    }

    @IsTest
    static void testSubmitQuizRejectsNegativeScore() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryOnboardingService.submitQuiz(INVOICE_TRACK, -1);
        } catch (AuraHandledException ahe) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Negative score must throw AuraHandledException');
    }

    @IsTest
    static void testSubmitQuizCompletesTrackWhenAllGatesMet() {
        Integer tracks = [SELECT COUNT() FROM OnboardingTrack__mdt WHERE DeveloperName = :INVOICE_TRACK];
        if (tracks == 0) {
            return;
        }
        List<OnboardingLesson__mdt> lessons = [
            SELECT DeveloperName FROM OnboardingLesson__mdt WHERE TrackTxt__c = :INVOICE_TRACK
        ];
        List<OnboardingChecklistItem__mdt> requiredItems = [
            SELECT DeveloperName FROM OnboardingChecklistItem__mdt
            WHERE TrackTxt__c = :INVOICE_TRACK AND RequiredDateTime__c != null
        ];
        List<OnboardingQuiz__mdt> quizzes = [
            SELECT PassThresholdNumber__c FROM OnboardingQuiz__mdt
            WHERE TrackTxt__c = :INVOICE_TRACK LIMIT 1
        ];
        if (lessons.isEmpty() || quizzes.isEmpty()) {
            return; // Empty-org tolerance.
        }

        // Mark every lesson complete first.
        DeliveryOnboardingService.ProgressDTO dto = null;
        for (OnboardingLesson__mdt l : lessons) {
            dto = DeliveryOnboardingService.markLessonComplete(INVOICE_TRACK, l.DeveloperName);
        }
        // PR 4: SoqlQuery + RestCall checklist items now actually evaluate
        // their VerificationQueryTxt__c. Seed the data each required item
        // queries for so they pass; Manual items still short-circuit.
        seedDataForChecklistItems(requiredItems);
        // Verify every required checklist item.
        for (OnboardingChecklistItem__mdt c : requiredItems) {
            dto = DeliveryOnboardingService.verifyChecklistItem(INVOICE_TRACK, c.DeveloperName);
        }
        // Submit a passing quiz.
        Decimal threshold = quizzes.get(0).PassThresholdNumber__c == null ? 0 : quizzes.get(0).PassThresholdNumber__c;

        Test.startTest();
        dto = DeliveryOnboardingService.submitQuiz(INVOICE_TRACK, threshold);
        Test.stopTest();

        System.assertEquals(true, dto.isComplete,
            'Track should be complete when threshold + lessons + required checklist all satisfied');
        System.assertNotEquals(null, dto.completedDateTime,
            'CompletedDateTime__c should be stamped');
    }

    @IsTest
    static void testVerifyChecklistItemManualPath() {
        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto =
            DeliveryOnboardingService.verifyChecklistItem('Existing_Track', 'item_1');
        Test.stopTest();

        System.assertNotEquals(null, dto.checklistStateJson,
            'Checklist JSON should be populated after a manual attest');
        System.assert(dto.checklistStateJson.contains('item_1'),
            'Item DeveloperName must appear in the JSON: ' + dto.checklistStateJson);
        System.assert(dto.checklistStateJson.contains('verifiedAt'),
            'Manual attest must record a verifiedAt timestamp');
    }

    @IsTest
    static void testMarkLessonCompleteRejectsBlankInput() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryOnboardingService.markLessonComplete('', 'x');
        } catch (AuraHandledException ahe) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Blank track must throw');
    }

    @IsTest
    static void testGetProgressBlankInputReturnsNull() {
        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto =
            DeliveryOnboardingService.getProgress('');
        Test.stopTest();
        System.assertEquals(null, dto, 'Blank track name should return null progress');
    }

    // ────────────────────────────────────────────────────────────────────
    // PR 4 — isTrackComplete(trackName, userId) gate hook coverage
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testIsTrackCompleteReturnsTrueForCompletedTrack() {
        OnboardingProgress__c row = TestDataFactory.newOnboardingProgress(new Map<String, Object>{
            'TrackTxt__c' => 'Done_Track',
            'CompletedDateTime__c' => Datetime.now().addMinutes(-1)
        });

        Test.startTest();
        Boolean done = DeliveryOnboardingService.isTrackComplete('Done_Track', row.UserLookup__c);
        Test.stopTest();

        System.assertEquals(true, done,
            'isTrackComplete must return true when CompletedDateTime__c is populated.');
    }

    @IsTest
    static void testIsTrackCompleteReturnsFalseForIncompleteTrack() {
        OnboardingProgress__c row = TestDataFactory.newOnboardingProgress(new Map<String, Object>{
            'TrackTxt__c' => 'In_Progress_Track',
            'CompletedDateTime__c' => null
        });

        Test.startTest();
        Boolean done = DeliveryOnboardingService.isTrackComplete('In_Progress_Track', row.UserLookup__c);
        Test.stopTest();

        System.assertEquals(false, done,
            'isTrackComplete must return false when CompletedDateTime__c is null.');
    }

    @IsTest
    static void testIsTrackCompleteReturnsTrueForBlankTrackName() {
        Test.startTest();
        Boolean blankNull = DeliveryOnboardingService.isTrackComplete(null, UserInfo.getUserId());
        Boolean blankEmpty = DeliveryOnboardingService.isTrackComplete('', UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(true, blankNull,
            'Null track name means "no gate required" — must return true.');
        System.assertEquals(true, blankEmpty,
            'Blank track name means "no gate required" — must return true.');
    }

    @IsTest
    static void testIsTrackCompleteReturnsFalseForMissingProgress() {
        // No OnboardingProgress__c row exists for this synthetic track + user.
        Test.startTest();
        Boolean done = DeliveryOnboardingService.isTrackComplete(
            'Missing_Track_xyz', UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(false, done,
            'Missing progress row must return false (user has not started the track).');
    }

    // ────────────────────────────────────────────────────────────────────
    // PR 4 — external verification evaluator coverage
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Walks the required checklist items for a track and seeds
     *              whatever each evaluator queries for. Today only SoqlQuery
     *              items seeded by the Invoice_Generation_Track shipped seed
     *              need extra data (a creator-owned approved WorkLog__c).
     *              Manual items short-circuit; RestCall items would need a
     *              setMock and are not in the shipped seed; WebhookReceived
     *              items are not yet supported.
     * @param items Required OnboardingChecklistItem__mdt rows for the track.
     */
    private static void seedDataForChecklistItems(List<OnboardingChecklistItem__mdt> items) {
        // The currently-shipped SoqlQuery row (IG_Track_02_ApprovedWorkLog)
        // expects an approved WorkLog__c authored by the running user. Build
        // one through TestDataFactory so the evaluator sees a non-empty result.
        Set<String> names = new Set<String>();
        for (OnboardingChecklistItem__mdt c : items) {
            names.add(c.DeveloperName);
        }
        List<OnboardingChecklistItem__mdt> fullRows = [
            SELECT DeveloperName, VerificationMethodPk__c, VerificationQueryTxt__c
            FROM OnboardingChecklistItem__mdt
            WHERE DeveloperName IN :names
        ];
        Boolean needsWorkLog = false;
        for (OnboardingChecklistItem__mdt full : fullRows) {
            String method = full.VerificationMethodPk__c;
            String query = full.VerificationQueryTxt__c;
            if (method == 'SoqlQuery' && query != null && query.contains('WorkLog__c')) {
                needsWorkLog = true;
            }
        }
        if (needsWorkLog) {
            WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{});
            TestDataFactory.createWorkLog(
                wi.Id, 1, Date.today(),
                new Map<String, Object>{ 'ApprovedDateTime__c' => Datetime.now() }
            );
        }
    }

    @IsTest
    static void testVerifyChecklistItemSoqlQueryPasses() {
        // Seed a row the evaluator's query will return.
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{});
        WorkLog__c log = TestDataFactory.createWorkLog(
            wi.Id, 1, Date.today(),
            new Map<String, Object>{ 'ApprovedDateTime__c' => Datetime.now() }
        );

        // Evaluate the canonical SoqlQuery branch via the public dispatch.
        // The Invoice_Generation_Track seed ships an IG_Track_02_ApprovedWorkLog
        // row whose query selects WorkLog__c where CreatedById = :currentUserId.
        Integer rows = [SELECT COUNT() FROM OnboardingChecklistItem__mdt
                        WHERE DeveloperName = 'IG_Track_02_ApprovedWorkLog'];
        if (rows == 0) {
            return; // Empty-org tolerance.
        }
        // Sanity check: the row we just inserted matches the seeded query.
        List<WorkLog__c> backing = [
            SELECT Id FROM WorkLog__c
            WHERE ApprovedDateTime__c != null AND CreatedById = :UserInfo.getUserId()
            LIMIT 1
        ];
        System.assertEquals(1, backing.size(), 'Test setup should have inserted exactly one matching WorkLog__c');
        System.assertNotEquals(null, log.Id, 'Inserted log should have an Id');

        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto = DeliveryOnboardingService.verifyChecklistItem(
            'Invoice_Generation_Track', 'IG_Track_02_ApprovedWorkLog');
        Test.stopTest();

        System.assertNotEquals(null, dto.checklistStateJson,
            'Checklist JSON should be populated after a successful SoqlQuery eval');
        System.assert(dto.checklistStateJson.contains('IG_Track_02_ApprovedWorkLog'),
            'Item DeveloperName must appear in JSON: ' + dto.checklistStateJson);
        System.assert(dto.checklistStateJson.contains('SoqlQuery'),
            'JSON should record which method ran: ' + dto.checklistStateJson);
    }

    @IsTest
    static void testVerifyChecklistItemSoqlQueryFailsWhenNoRows() {
        // Do NOT seed any WorkLog__c. The seeded query returns 0 rows.
        Integer rows = [SELECT COUNT() FROM OnboardingChecklistItem__mdt
                        WHERE DeveloperName = 'IG_Track_02_ApprovedWorkLog'];
        if (rows == 0) {
            return; // Empty-org tolerance.
        }

        Boolean threw = false;
        String message = null;
        Test.startTest();
        try {
            DeliveryOnboardingService.verifyChecklistItem(
                'Invoice_Generation_Track', 'IG_Track_02_ApprovedWorkLog');
        } catch (AuraHandledException ahe) {
            threw = true;
            message = ahe.getMessage();
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Empty SOQL result must throw AuraHandledException');
        System.assertNotEquals(null, message, 'AuraHandledException must carry a message');
    }

    @IsTest
    static void testEvaluateSoqlQueryHandlesQueryException() {
        // Direct unit test of the evaluator with a broken query. Goes around
        // the public dispatcher so we don't need a real mdt row with a bad query.
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateSoqlQuery(
                'SELECT NoSuchField__c FROM NoSuchObject__c LIMIT 1');
        System.assertEquals(false, outcome.passed, 'Broken SOQL must fail');
        System.assertEquals('SoqlQuery', outcome.method, 'Method should still be SoqlQuery');
        System.assertNotEquals(null, outcome.message,
            'Outcome must carry a friendly message');
    }

    @IsTest
    static void testEvaluateSoqlQueryRejectsBlankTemplate() {
        DeliveryOnboardingService.EvaluatorOutcome outcomeNull =
            DeliveryOnboardingService.evaluateSoqlQuery(null);
        DeliveryOnboardingService.EvaluatorOutcome outcomeEmpty =
            DeliveryOnboardingService.evaluateSoqlQuery('   ');
        System.assertEquals(false, outcomeNull.passed, 'Null query must fail');
        System.assertEquals(false, outcomeEmpty.passed, 'Blank query must fail');
    }

    @IsTest
    static void testEvaluateSoqlQuerySubstitutesCurrentUserTokens() {
        // {currentUserId} token substitution path — admins can use literal
        // substitution as an alternative to native :currentUserId bind syntax.
        // The query selects User WHERE Id = literal-substituted current user id.
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateSoqlQuery(
                'SELECT Id FROM User WHERE Id = \'{currentUserId}\' LIMIT 1');
        System.assertEquals(true, outcome.passed,
            'Literal {currentUserId} substitution must resolve to the running user');
    }

    // ── RestCall evaluator ───────────────────────────────────────────────

    /**
     * @description HttpCalloutMock that returns a configurable status code +
     *              body and counts invocations. Mirrors the SlackMock pattern.
     */
    private class RestMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        /** @description Count of mock invocations across the test's callouts. */
        public Integer callCount = 0;
        /**
         * @description Construct a mock with the response values.
         * @param statusCodeIn HTTP status code to return.
         * @param bodyIn Response body string.
         */
        RestMock(Integer statusCodeIn, String bodyIn) {
            this.statusCode = statusCodeIn;
            this.body = bodyIn;
        }
        /**
         * @description Returns the configured mock response.
         * @param req The outbound HttpRequest (unused).
         * @return The configured HttpResponse.
         */
        public HttpResponse respond(HttpRequest req) {
            this.callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    /**
     * @description HttpCalloutMock that throws CalloutException to simulate
     *              network failure / DNS error / Named-Credential misconfig.
     */
    private class FailingRestMock implements HttpCalloutMock {
        /**
         * @description Always throws CalloutException so the evaluator's
         *              try/catch path is exercised.
         * @param req The outbound HttpRequest (unused).
         * @return Never returns — always throws.
         */
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated network error');
        }
    }

    @IsTest
    static void testEvaluateRestCallPassesOnHttp2xx() {
        Test.setMock(HttpCalloutMock.class, new RestMock(200, '{"ok":true}'));
        Test.startTest();
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateRestCall('https://example.test/api/status');
        Test.stopTest();
        System.assertEquals(true, outcome.passed, 'HTTP 200 must pass');
        System.assertEquals('RestCall', outcome.method);
    }

    @IsTest
    static void testEvaluateRestCallFailsOnHttp4xx() {
        Test.setMock(HttpCalloutMock.class, new RestMock(404, 'not found'));
        Test.startTest();
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateRestCall('https://example.test/api/missing');
        Test.stopTest();
        System.assertEquals(false, outcome.passed, 'HTTP 404 must fail');
        System.assert(outcome.message != null && outcome.message.contains('404'),
            'Failure message should mention the status code: ' + outcome.message);
    }

    @IsTest
    static void testEvaluateRestCallHandlesCalloutException() {
        Test.setMock(HttpCalloutMock.class, new FailingRestMock());
        Test.startTest();
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateRestCall('https://example.test/api/down');
        Test.stopTest();
        System.assertEquals(false, outcome.passed,
            'CalloutException must fail gracefully (no leaked stack)');
        System.assertNotEquals(null, outcome.message,
            'Friendly message must be present');
    }

    @IsTest
    static void testEvaluateRestCallRejectsBlankUrl() {
        DeliveryOnboardingService.EvaluatorOutcome outcomeNull =
            DeliveryOnboardingService.evaluateRestCall(null);
        DeliveryOnboardingService.EvaluatorOutcome outcomeEmpty =
            DeliveryOnboardingService.evaluateRestCall('   ');
        System.assertEquals(false, outcomeNull.passed, 'Null URL must fail');
        System.assertEquals(false, outcomeEmpty.passed, 'Blank URL must fail');
    }

    // ── WebhookReceived evaluator ────────────────────────────────────────

    @IsTest
    static void testEvaluateWebhookReceivedReturnsDocumentedLimitation() {
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateWebhookReceived('any-channel');
        System.assertEquals(false, outcome.passed,
            'WebhookReceived must fail until Phase 3 webhook event log ships');
        System.assertEquals('WebhookReceived', outcome.method);
        System.assert(outcome.message != null && outcome.message.contains('not yet supported'),
            'Message should call out the documented limitation: ' + outcome.message);
    }

    // ── Dispatcher coverage ──────────────────────────────────────────────

    @IsTest
    static void testEvaluateChecklistItemFallsBackToManualWhenCatalogMissing() {
        // Null catalog row → Manual short-circuit → pass.
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateChecklistItem(null);
        System.assertEquals(true, outcome.passed,
            'Missing catalog row must fall back to Manual (LWC-only items keep working)');
        System.assertEquals('Manual', outcome.method);
    }

    @IsTest
    static void testEvaluateChecklistItemUnknownMethodFailsSafe() {
        // Synthesise an mdt row with an unsupported value.
        OnboardingChecklistItem__mdt row = new OnboardingChecklistItem__mdt(
            DeveloperName = 'Test_Item',
            VerificationMethodPk__c = 'Bogus',
            VerificationQueryTxt__c = null
        );
        DeliveryOnboardingService.EvaluatorOutcome outcome =
            DeliveryOnboardingService.evaluateChecklistItem(row);
        System.assertEquals(false, outcome.passed,
            'Unknown method must fail safe, not silently pass');
    }

    @IsTest
    static void testVerifyChecklistItemFallsBackToManualForMissingCatalogRow() {
        // Confirms the dispatcher fall-back via the public verifyChecklistItem
        // surface (not just the evaluator unit-test). Synthetic item name has
        // no OnboardingChecklistItem__mdt row → Manual short-circuit → pass.
        Test.startTest();
        DeliveryOnboardingService.ProgressDTO dto =
            DeliveryOnboardingService.verifyChecklistItem('Some_Track', 'no_such_item_xyz');
        Test.stopTest();
        System.assertNotEquals(null, dto,
            'Missing-catalog dispatch must fall back to Manual + return a DTO');
        System.assert(dto.checklistStateJson != null && dto.checklistStateJson.contains('no_such_item_xyz'),
            'Manual fallback should still write the item to JSON');
        System.assert(dto.checklistStateJson.contains('Manual'),
            'JSON should record method=Manual for the fall-back: ' + dto.checklistStateJson);
    }
}
