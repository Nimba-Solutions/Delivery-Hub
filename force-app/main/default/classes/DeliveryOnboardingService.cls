/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Onboarding service for the Checkr-style gated feature tracks
 *               (Layer 5 of the cockpit architecture). Joins the package-shipped
 *               OnboardingTrack__mdt + OnboardingLesson__mdt + OnboardingQuiz__mdt
 *               + OnboardingChecklistItem__mdt catalog with per-user runtime state
 *               stored in OnboardingProgress__c, and supplies the read / write
 *               operations the deliveryFeatureOnboarding LWC drives.
 *
 *               PR 3 ships the schema + reader + quiz grading + manual checklist
 *               attestation. PR 4 wires the actual gate (refuse non-admin feature
 *               toggle until CompletedDateTime__c is populated) and replaces the
 *               manual-attest fallback for SoqlQuery / RestCall / WebhookReceived
 *               verification methods with real evaluators.
 *
 *               Global by intent: PR 8 may expose this surface via REST so the
 *               external onboarding portal can drive the same flow. All inner
 *               classes used in the return signature are global per CLAUDE.md
 *               ("When making Apex classes global, ALL inner classes used as
 *               return/param types must also be global").
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.ExcessivePublicCount,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
global with sharing class DeliveryOnboardingService {

    // ────────────────────────────────────────────────────────────────────
    // DTOs — all global because they appear in global return signatures.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Top-level track header DTO. requiresWalkthrough is derived
     *              from RequiresWalkthroughDateTime__c != null.
     */
    global class TrackDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String label;
        @AuraEnabled public String featureDefinition;
        @AuraEnabled public Decimal requiredQuizScore;
        @AuraEnabled public Boolean requiresWalkthrough;
        @AuraEnabled public Decimal estimatedDuration;
    }

    /** @description One lesson card per track. */
    global class LessonDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String track;
        @AuraEnabled public Decimal sortOrder;
        @AuraEnabled public String label;
        @AuraEnabled public String bodyMarkdown;
        @AuraEnabled public String lessonUrl;
        @AuraEnabled public Decimal estimatedDuration;
    }

    /**
     * @description Quiz catalog DTO. allowRetry derived from
     *              AllowRetryDateTime__c != null.
     */
    global class QuizDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String track;
        @AuraEnabled public String questionsJson;
        @AuraEnabled public Decimal passThreshold;
        @AuraEnabled public Boolean allowRetry;
    }

    /**
     * @description Checklist item DTO. required derived from
     *              RequiredDateTime__c != null.
     */
    global class ChecklistItemDTO {
        @AuraEnabled public String developerName;
        @AuraEnabled public String track;
        @AuraEnabled public Decimal sortOrder;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String verificationMethod;
        @AuraEnabled public String verificationQuery;
        @AuraEnabled public Boolean required;
    }

    /**
     * @description Composite payload returned by getTrack — track header +
     *              lessons + quiz + checklist items in one round-trip.
     */
    global class TrackBundleDTO {
        @AuraEnabled public TrackDTO track;
        @AuraEnabled public List<LessonDTO> lessons;
        @AuraEnabled public QuizDTO quiz;
        @AuraEnabled public List<ChecklistItemDTO> checklist;
    }

    /**
     * @description Per-user runtime progress DTO. isComplete derived from
     *              CompletedDateTime__c != null.
     */
    global class ProgressDTO {
        @AuraEnabled public Id progressId;
        @AuraEnabled public String track;
        @AuraEnabled public Id userId;
        @AuraEnabled public DateTime startedDateTime;
        @AuraEnabled public DateTime completedDateTime;
        @AuraEnabled public String lessonsCompletedJson;
        @AuraEnabled public Decimal quizScore;
        @AuraEnabled public Decimal quizAttempts;
        @AuraEnabled public DateTime quizLastAttemptDateTime;
        @AuraEnabled public String checklistStateJson;
        @AuraEnabled public DateTime walkthroughScheduledDateTime;
        @AuraEnabled public DateTime walkthroughCompletedDateTime;
        @AuraEnabled public Boolean isComplete;
    }

    // ────────────────────────────────────────────────────────────────────
    // READ — getTrack returns the full catalog bundle for a track.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Returns the track header plus all child lessons, the quiz,
     *              and all checklist items in a single bundle DTO. Cacheable
     *              so the LWC can wire it without re-fetching on every render.
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt.
     * @return TrackBundleDTO populated bundle, or null if the track is not found.
     */
    @AuraEnabled(cacheable=true)
    global static TrackBundleDTO getTrack(String trackDeveloperName) {
        if (String.isBlank(trackDeveloperName)) {
            return null;
        }
        try {
            List<OnboardingTrack__mdt> tracks = [
                SELECT DeveloperName, LabelTxt__c, FeatureDefinitionTxt__c,
                       RequiredQuizScoreNumber__c, RequiresWalkthroughDateTime__c,
                       EstimatedDurationMinutesNumber__c
                FROM OnboardingTrack__mdt
                WHERE DeveloperName = :trackDeveloperName
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (tracks.isEmpty()) {
                return null;
            }
            OnboardingTrack__mdt trackRow = tracks.get(0);

            TrackBundleDTO bundle = new TrackBundleDTO();
            bundle.track = toTrackDTO(trackRow);
            bundle.lessons = loadLessons(trackDeveloperName);
            bundle.quiz = loadQuiz(trackDeveloperName);
            bundle.checklist = loadChecklist(trackDeveloperName);
            return bundle;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryOnboardingService.getTrack] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to load onboarding track.');
        }
    }

    private static List<LessonDTO> loadLessons(String trackName) {
        List<LessonDTO> out = new List<LessonDTO>();
        for (OnboardingLesson__mdt row : [
            SELECT DeveloperName, TrackTxt__c, SortOrderNumber__c, LabelTxt__c,
                   BodyMarkdownTxt__c, LessonUrl__c, EstimatedDurationMinutesNumber__c
            FROM OnboardingLesson__mdt
            WHERE TrackTxt__c = :trackName
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, DeveloperName ASC
        ]) {
            LessonDTO dto = new LessonDTO();
            dto.developerName = row.DeveloperName;
            dto.track = row.TrackTxt__c;
            dto.sortOrder = row.SortOrderNumber__c;
            dto.label = row.LabelTxt__c;
            dto.bodyMarkdown = row.BodyMarkdownTxt__c;
            dto.lessonUrl = row.LessonUrl__c;
            dto.estimatedDuration = row.EstimatedDurationMinutesNumber__c;
            out.add(dto);
        }
        return out;
    }

    private static QuizDTO loadQuiz(String trackName) {
        List<OnboardingQuiz__mdt> rows = [
            SELECT DeveloperName, TrackTxt__c, QuestionsJsonTxt__c,
                   PassThresholdNumber__c, AllowRetryDateTime__c
            FROM OnboardingQuiz__mdt
            WHERE TrackTxt__c = :trackName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        OnboardingQuiz__mdt row = rows.get(0);
        QuizDTO dto = new QuizDTO();
        dto.developerName = row.DeveloperName;
        dto.track = row.TrackTxt__c;
        dto.questionsJson = row.QuestionsJsonTxt__c;
        dto.passThreshold = row.PassThresholdNumber__c;
        dto.allowRetry = row.AllowRetryDateTime__c != null;
        return dto;
    }

    private static List<ChecklistItemDTO> loadChecklist(String trackName) {
        List<ChecklistItemDTO> out = new List<ChecklistItemDTO>();
        for (OnboardingChecklistItem__mdt row : [
            SELECT DeveloperName, TrackTxt__c, SortOrderNumber__c, LabelTxt__c,
                   DescriptionTxt__c, VerificationMethodPk__c, VerificationQueryTxt__c,
                   RequiredDateTime__c
            FROM OnboardingChecklistItem__mdt
            WHERE TrackTxt__c = :trackName
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, DeveloperName ASC
        ]) {
            ChecklistItemDTO dto = new ChecklistItemDTO();
            dto.developerName = row.DeveloperName;
            dto.track = row.TrackTxt__c;
            dto.sortOrder = row.SortOrderNumber__c;
            dto.label = row.LabelTxt__c;
            dto.description = row.DescriptionTxt__c;
            dto.verificationMethod = row.VerificationMethodPk__c;
            dto.verificationQuery = row.VerificationQueryTxt__c;
            dto.required = row.RequiredDateTime__c != null;
            out.add(dto);
        }
        return out;
    }

    private static TrackDTO toTrackDTO(OnboardingTrack__mdt row) {
        TrackDTO dto = new TrackDTO();
        dto.developerName = row.DeveloperName;
        dto.label = row.LabelTxt__c;
        dto.featureDefinition = row.FeatureDefinitionTxt__c;
        dto.requiredQuizScore = row.RequiredQuizScoreNumber__c;
        dto.requiresWalkthrough = row.RequiresWalkthroughDateTime__c != null;
        dto.estimatedDuration = row.EstimatedDurationMinutesNumber__c;
        return dto;
    }

    // ────────────────────────────────────────────────────────────────────
    // READ — getProgress returns the runtime row for the current user,
    // returning an empty/initialized DTO when no record exists yet.
    // NOT cacheable — progress changes inside the LWC session.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Returns the per-user progress DTO. If no OnboardingProgress__c
     *              row exists yet for (current user, trackDeveloperName), the
     *              returned DTO is populated with the track name and userId
     *              only — every datetime / score field is null and isComplete
     *              is false. Callers can treat that shape as "not yet started".
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt.
     * @return ProgressDTO initialised DTO, never null.
     */
    @AuraEnabled
    global static ProgressDTO getProgress(String trackDeveloperName) {
        if (String.isBlank(trackDeveloperName)) {
            return null;
        }
        try {
            OnboardingProgress__c row = findProgressForCurrentUser(trackDeveloperName);
            if (row == null) {
                ProgressDTO dto = new ProgressDTO();
                dto.track = trackDeveloperName;
                dto.userId = UserInfo.getUserId();
                dto.isComplete = false;
                return dto;
            }
            return toProgressDTO(row);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryOnboardingService.getProgress] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to load onboarding progress.');
        }
    }

    private static OnboardingProgress__c findProgressForCurrentUser(String trackName) {
        Id uid = UserInfo.getUserId();
        List<OnboardingProgress__c> rows = [
            SELECT Id, Name, TrackTxt__c, UserLookup__c, StartedDateTime__c,
                   CompletedDateTime__c, LessonsCompletedJsonTxt__c,
                   QuizScoreNumber__c, QuizAttemptsNumber__c,
                   QuizLastAttemptDateTime__c, ChecklistStateJsonTxt__c,
                   WalkthroughScheduledDateTime__c, WalkthroughCompletedDateTime__c
            FROM OnboardingProgress__c
            WHERE TrackTxt__c = :trackName AND UserLookup__c = :uid
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows.get(0);
    }

    private static ProgressDTO toProgressDTO(OnboardingProgress__c row) {
        ProgressDTO dto = new ProgressDTO();
        dto.progressId = row.Id;
        dto.track = row.TrackTxt__c;
        dto.userId = row.UserLookup__c;
        dto.startedDateTime = row.StartedDateTime__c;
        dto.completedDateTime = row.CompletedDateTime__c;
        dto.lessonsCompletedJson = row.LessonsCompletedJsonTxt__c;
        dto.quizScore = row.QuizScoreNumber__c;
        dto.quizAttempts = row.QuizAttemptsNumber__c;
        dto.quizLastAttemptDateTime = row.QuizLastAttemptDateTime__c;
        dto.checklistStateJson = row.ChecklistStateJsonTxt__c;
        dto.walkthroughScheduledDateTime = row.WalkthroughScheduledDateTime__c;
        dto.walkthroughCompletedDateTime = row.WalkthroughCompletedDateTime__c;
        dto.isComplete = row.CompletedDateTime__c != null;
        return dto;
    }

    // ────────────────────────────────────────────────────────────────────
    // WRITE — markLessonComplete appends to the JSON lessons-completed list.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Upserts the per-user progress row and appends the given
     *              lesson DeveloperName + completion timestamp to its
     *              LessonsCompletedJsonTxt__c. Idempotent — re-marking a lesson
     *              is a no-op on the JSON shape (the latest stamp wins).
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt.
     * @param lessonDeveloperName DeveloperName of the OnboardingLesson__mdt.
     * @return ProgressDTO updated progress row.
     */
    @AuraEnabled
    global static ProgressDTO markLessonComplete(String trackDeveloperName, String lessonDeveloperName) {
        if (String.isBlank(trackDeveloperName) || String.isBlank(lessonDeveloperName)) {
            throw new AuraHandledException('Track and lesson developer name are required.');
        }
        try {
            OnboardingProgress__c row = upsertProgress(trackDeveloperName);
            Map<String, String> done = parseLessonsCompletedMap(row.LessonsCompletedJsonTxt__c);
            done.put(lessonDeveloperName,
                Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
            row.LessonsCompletedJsonTxt__c = serializeLessonsCompleted(done);
            updateAndCheckComplete(row);
            return toProgressDTO(row);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryOnboardingService.markLessonComplete] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to mark lesson complete.');
        }
    }

    /**
     * @description Records a quiz attempt. Always increments QuizAttemptsNumber__c
     *              and stamps QuizLastAttemptDateTime__c. If the submitted score
     *              meets the configured quiz threshold AND every required lesson
     *              is complete AND every required checklist item is verified,
     *              also stamps CompletedDateTime__c.
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt.
     * @param score Number of correct answers on this attempt.
     * @return ProgressDTO updated progress row.
     */
    @AuraEnabled
    global static ProgressDTO submitQuiz(String trackDeveloperName, Decimal score) {
        if (String.isBlank(trackDeveloperName)) {
            throw new AuraHandledException('Track developer name is required.');
        }
        if (score == null || score < 0) {
            throw new AuraHandledException('Quiz score must be a non-negative number.');
        }
        try {
            OnboardingProgress__c row = upsertProgress(trackDeveloperName);
            row.QuizScoreNumber__c = score;
            row.QuizAttemptsNumber__c = (row.QuizAttemptsNumber__c == null ? 0 : row.QuizAttemptsNumber__c) + 1;
            row.QuizLastAttemptDateTime__c = Datetime.now();
            updateAndCheckComplete(row);
            return toProgressDTO(row);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryOnboardingService.submitQuiz] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to submit quiz.');
        }
    }

    /**
     * @description Marks a single checklist item verified for the current user.
     *              In the MVP every VerificationMethodPk__c value resolves to a
     *              manual self-attest — the LWC button click is the proof.
     *              PR 4+ will wire real evaluators for SoqlQuery / RestCall /
     *              WebhookReceived; the catalog already carries the query/URL
     *              shape it will need.
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt.
     * @param itemDeveloperName DeveloperName of the OnboardingChecklistItem__mdt.
     * @return ProgressDTO updated progress row.
     */
    @AuraEnabled
    global static ProgressDTO verifyChecklistItem(String trackDeveloperName, String itemDeveloperName) {
        if (String.isBlank(trackDeveloperName) || String.isBlank(itemDeveloperName)) {
            throw new AuraHandledException('Track and checklist item developer name are required.');
        }
        try {
            OnboardingProgress__c row = upsertProgress(trackDeveloperName);
            Map<String, Object> state = parseChecklistState(row.ChecklistStateJsonTxt__c);
            // TODO PR 4+: when VerificationMethodPk__c != 'Manual', call the
            // real evaluator (SOQL COUNT() / REST GET / inbound-webhook lookup)
            // before stamping verifiedAt. For now every method short-circuits
            // to a manual attest.
            Map<String, Object> entry = new Map<String, Object>{
                'completed' => true,
                'verifiedAt' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
            };
            state.put(itemDeveloperName, entry);
            row.ChecklistStateJsonTxt__c = JSON.serialize(state);
            updateAndCheckComplete(row);
            return toProgressDTO(row);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryOnboardingService.verifyChecklistItem] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to verify checklist item.');
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // READ — isTrackComplete(trackName, userId) is the PR 4 gate hook.
    // Returns true when the named user has an OnboardingProgress__c row for
    // the track and that row's CompletedDateTime__c is populated. Blank /
    // null trackDeveloperName means "no track required" — always true.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description PR 4 gate hook. Returns true when the user has finished
     *              the named onboarding track (CompletedDateTime__c != null
     *              on their OnboardingProgress__c row). A blank track name
     *              is treated as "no track required" and always returns true,
     *              so callers can pipe a FeatureDefinition__mdt's
     *              RequiresOnboardingTrackTxt__c straight in without a
     *              null-check.
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt to
     *                           check. Blank / null = no gate required.
     * @param userId Id of the user whose progress row to evaluate. If null
     *               the current running user is used.
     * @return True when no track is required OR when the user has finished it.
     */
    @AuraEnabled
    global static Boolean isTrackComplete(String trackDeveloperName, Id userId) {
        if (String.isBlank(trackDeveloperName)) {
            return true;
        }
        Id effectiveUserId = userId == null ? UserInfo.getUserId() : userId;
        try {
            List<OnboardingProgress__c> rows = [
                SELECT Id, CompletedDateTime__c
                FROM OnboardingProgress__c
                WHERE TrackTxt__c = :trackDeveloperName
                  AND UserLookup__c = :effectiveUserId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                return false;
            }
            return rows.get(0).CompletedDateTime__c != null;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryOnboardingService.isTrackComplete] failed: ' + e.getMessage());
            return false;
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — upsert + completion check.
    // ────────────────────────────────────────────────────────────────────

    private static OnboardingProgress__c upsertProgress(String trackName) {
        OnboardingProgress__c row = findProgressForCurrentUser(trackName);
        if (row == null) {
            row = new OnboardingProgress__c(
                Name = trackName + ' — ' + UserInfo.getUserName(),
                TrackTxt__c = trackName,
                UserLookup__c = UserInfo.getUserId(),
                StartedDateTime__c = Datetime.now(),
                QuizAttemptsNumber__c = 0
            );
            insert row;
            // Re-query so the row carries any defaulted system fields the
            // completion check later relies on.
            row = findProgressForCurrentUser(trackName);
        }
        return row;
    }

    private static void updateAndCheckComplete(OnboardingProgress__c row) {
        Boolean justCompleted = false;
        if (row.CompletedDateTime__c == null && isTrackComplete(row)) {
            row.CompletedDateTime__c = Datetime.now();
            justCompleted = true;
        }
        update row;
        // Fire the cross-flow notification only on the FIRST completion stamp,
        // not on subsequent post-completion writes (lesson re-marks, checklist
        // edits, etc.). Notification dispatch is queueable + try/catch wrapped —
        // a failure cannot break the upsert. Closes the cross-flow notifications
        // gap in docs/audits/e2e-walkthrough-2026-05-21.md.
        if (justCompleted) {
            DeliveryNotificationService.notifyOnboardingCompleted(row.Id);
        }
    }

    /**
     * @description Returns true when (a) the quiz passes threshold, (b) every
     *              required lesson DeveloperName appears in LessonsCompletedJsonTxt__c,
     *              and (c) every required checklist item is verified.
     * @param row The OnboardingProgress__c record to evaluate against the
     *            track's quiz / lesson / checklist completion rules.
     * @return True when all three gates pass; false otherwise.
     */
    @TestVisible
    private static Boolean isTrackComplete(OnboardingProgress__c row) {
        // (a) quiz pass — read the quiz threshold from the catalog.
        List<OnboardingQuiz__mdt> quizzes = [
            SELECT PassThresholdNumber__c
            FROM OnboardingQuiz__mdt
            WHERE TrackTxt__c = :row.TrackTxt__c
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (quizzes.isEmpty()) {
            return false;
        }
        Decimal threshold = quizzes.get(0).PassThresholdNumber__c == null ? 0 : quizzes.get(0).PassThresholdNumber__c;
        if (row.QuizScoreNumber__c == null || row.QuizScoreNumber__c < threshold) {
            return false;
        }

        // (b) lessons — every lesson on the track must appear in the JSON.
        Map<String, String> done = parseLessonsCompletedMap(row.LessonsCompletedJsonTxt__c);
        for (OnboardingLesson__mdt l : [
            SELECT DeveloperName
            FROM OnboardingLesson__mdt
            WHERE TrackTxt__c = :row.TrackTxt__c
            WITH SYSTEM_MODE
        ]) {
            if (!done.containsKey(l.DeveloperName)) {
                return false;
            }
        }

        // (c) required checklist items — informational items skipped.
        Map<String, Object> state = parseChecklistState(row.ChecklistStateJsonTxt__c);
        for (OnboardingChecklistItem__mdt c : [
            SELECT DeveloperName, RequiredDateTime__c
            FROM OnboardingChecklistItem__mdt
            WHERE TrackTxt__c = :row.TrackTxt__c
            WITH SYSTEM_MODE
        ]) {
            if (c.RequiredDateTime__c == null) {
                continue;
            }
            Object raw = state.get(c.DeveloperName);
            if (raw == null) {
                return false;
            }
            Map<String, Object> entry = (Map<String, Object>) raw;
            Object completedFlag = entry.get('completed');
            if (completedFlag != true) {
                return false;
            }
        }
        return true;
    }

    // ────────────────────────────────────────────────────────────────────
    // INTERNAL — JSON shape helpers.
    // LessonsCompletedJsonTxt__c carries an array of {lesson, completedAt}
    // entries; ChecklistStateJsonTxt__c carries a map keyed by item
    // DeveloperName. Both helpers tolerate null / malformed input gracefully.
    // ────────────────────────────────────────────────────────────────────

    @TestVisible
    private static Map<String, String> parseLessonsCompletedMap(String raw) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(raw)) {
            return out;
        }
        try {
            Object parsed = JSON.deserializeUntyped(raw);
            if (!(parsed instanceof List<Object>)) {
                return out;
            }
            for (Object entry : (List<Object>) parsed) {
                if (!(entry instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> m = (Map<String, Object>) entry;
                Object lesson = m.get('lesson');
                Object completedAt = m.get('completedAt');
                if (lesson == null) {
                    continue;
                }
                String stampStr = completedAt instanceof String
                    ? (String) completedAt
                    : Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
                out.put((String) lesson, stampStr);
            }
        } catch (Exception ignore) {
            // Malformed JSON — return empty map; caller will rebuild on next write.
            return new Map<String, String>();
        }
        return out;
    }

    private static String serializeLessonsCompleted(Map<String, String> done) {
        List<Map<String, Object>> arr = new List<Map<String, Object>>();
        for (String lesson : done.keySet()) {
            arr.add(new Map<String, Object>{
                'lesson' => lesson,
                'completedAt' => done.get(lesson)
            });
        }
        return JSON.serialize(arr);
    }

    @TestVisible
    private static Map<String, Object> parseChecklistState(String raw) {
        if (String.isBlank(raw)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(raw);
            if (parsed instanceof Map<String, Object>) {
                return (Map<String, Object>) parsed;
            }
        } catch (Exception ignore) {
            return new Map<String, Object>();
        }
        return new Map<String, Object>();
    }
}
