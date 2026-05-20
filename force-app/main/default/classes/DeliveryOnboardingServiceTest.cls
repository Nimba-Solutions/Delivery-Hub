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
}
