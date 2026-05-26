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
 *               verification methods with real evaluators. SoqlQuery and RestCall
 *               are fully wired (closes Flow 3 #3 audit gap); WebhookReceived
 *               surfaces a documented limitation until a generic inbound-event
 *               log ships (DeliveryWebhookReceiverApi today writes business
 *               records via per-provider handlers — no generic event audit
 *               table to query).
 *
 *               Global by intent: PR 8 may expose this surface via REST so the
 *               external onboarding portal can drive the same flow. All inner
 *               classes used in the return signature are global per CLAUDE.md
 *               ("When making Apex classes global, ALL inner classes used as
 *               return/param types must also be global").
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.ExcessivePublicCount,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.ApexSuggestUsingNamedCred')
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
     *              Dispatches on the catalog row's VerificationMethodPk__c:
     *              <ul>
     *                <li><b>Manual</b> — operator self-attests (LWC button click is the proof).</li>
     *                <li><b>SoqlQuery</b> — runs VerificationQueryTxt__c via
     *                    Database.queryWithBinds with whitelisted bind vars
     *                    <code>:currentUserId</code> + <code>:currentUserName</code>
     *                    and the literal tokens <code>{currentUserId}</code> +
     *                    <code>{currentUserName}</code> pre-substituted in.
     *                    Passes when result.size() &gt; 0.</li>
     *                <li><b>RestCall</b> — HTTP GET VerificationQueryTxt__c
     *                    (Named-Credential <code>callout:</code> URLs supported)
     *                    with a 10s timeout. Passes on HTTP 2xx.</li>
     *                <li><b>WebhookReceived</b> — not yet supported. DH has no
     *                    persistent webhook-event log (DeliveryWebhookReceiverApi
     *                    dispatches to handlers that write business records).
     *                    Throws an AuraHandledException directing admins to a
     *                    Manual fallback until a generic inbound-event log is
     *                    shipped.</li>
     *              </ul>
     *              When no OnboardingChecklistItem__mdt row matches itemDeveloperName
     *              the method falls back to Manual so LWC-only checklist items
     *              (catalog-less) continue to work end-to-end.
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
            OnboardingChecklistItem__mdt catalogRow = loadChecklistItemMdt(itemDeveloperName);
            EvaluatorOutcome outcome = evaluateChecklistItem(catalogRow);
            if (!outcome.passed) {
                throw new AuraHandledException(outcome.message);
            }
            OnboardingProgress__c row = upsertProgress(trackDeveloperName);
            Map<String, Object> state = parseChecklistState(row.ChecklistStateJsonTxt__c);
            Map<String, Object> entry = new Map<String, Object>{
                'completed' => true,
                'verifiedAt' => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
                'method' => outcome.method
            };
            state.put(itemDeveloperName, entry);
            row.ChecklistStateJsonTxt__c = JSON.serialize(state);
            updateAndCheckComplete(row);
            return toProgressDTO(row);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            // Evaluators surface friendly messages via EvaluatorOutcome —
            // anything reaching here is unexpected. Convert to a generic
            // AuraHandledException without leaking the underlying error.
            throw new AuraHandledException('Unable to verify checklist item.');
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // PR 4 — external verification evaluators (SoqlQuery / RestCall /
    // WebhookReceived). Each evaluator returns an EvaluatorOutcome rather
    // than throwing so the dispatcher can report a friendly message via
    // AuraHandledException without leaking stack traces to the LWC.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Internal evaluator result. passed=true means the catalog
     *              gate is satisfied; passed=false means verifyChecklistItem
     *              should throw AuraHandledException(message). method is the
     *              VerificationMethodPk__c value the evaluator ran so the
     *              ChecklistState JSON can record which gate fired.
     *              Package-private (no global modifier) so it remains an
     *              internal contract — not exposed via REST or LWC.
     */
    public class EvaluatorOutcome {
        /** @description True when the evaluator's gate is satisfied. */
        public Boolean passed;
        /** @description VerificationMethodPk__c value the evaluator ran. */
        public String method;
        /** @description Friendly message surfaced via AuraHandledException on failure. */
        public String message;
        /**
         * @description Construct a populated EvaluatorOutcome.
         * @param passedIn Whether the gate is satisfied.
         * @param methodIn The VerificationMethodPk__c value that ran.
         * @param messageIn The user-facing failure message (null on pass).
         */
        public EvaluatorOutcome(Boolean passedIn, String methodIn, String messageIn) {
            this.passed = passedIn;
            this.method = methodIn;
            this.message = messageIn;
        }
    }

    /**
     * @description Look up the OnboardingChecklistItem__mdt catalog row by
     *              DeveloperName. Returns null when no row exists so the
     *              dispatcher can fall back to Manual for catalog-less items.
     * @param itemDeveloperName DeveloperName to look up.
     * @return Catalog row, or null when not found.
     */
    @TestVisible
    private static OnboardingChecklistItem__mdt loadChecklistItemMdt(String itemDeveloperName) {
        List<OnboardingChecklistItem__mdt> rows = [
            SELECT DeveloperName, VerificationMethodPk__c, VerificationQueryTxt__c
            FROM OnboardingChecklistItem__mdt
            WHERE DeveloperName = :itemDeveloperName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * @description Dispatch on VerificationMethodPk__c. Null catalog row or
     *              Manual method always passes (manual attest). The other
     *              three branches delegate to a per-method evaluator.
     * @param catalogRow OnboardingChecklistItem__mdt row, or null.
     * @return EvaluatorOutcome with passed + method + message populated.
     */
    @TestVisible
    private static EvaluatorOutcome evaluateChecklistItem(OnboardingChecklistItem__mdt catalogRow) {
        String method = (catalogRow == null || String.isBlank(catalogRow.VerificationMethodPk__c))
            ? 'Manual' : catalogRow.VerificationMethodPk__c;
        if (method == 'Manual') {
            return new EvaluatorOutcome(true, 'Manual', null);
        }
        String query = catalogRow == null ? null : catalogRow.VerificationQueryTxt__c;
        if (method == 'SoqlQuery') {
            return evaluateSoqlQuery(query);
        }
        if (method == 'RestCall') {
            return evaluateRestCall(query);
        }
        if (method == 'WebhookReceived') {
            return evaluateWebhookReceived(query);
        }
        // Unknown method — fail safe: do not silently pass.
        return new EvaluatorOutcome(false, method,
            'Unknown verification method "' + method + '". Configure the catalog row to a supported value.');
    }

    /**
     * @description SoqlQuery evaluator. Pre-substitutes the whitelisted
     *              tokens {currentUserId} and {currentUserName} into the
     *              query string, then runs it via Database.queryWithBinds
     *              in SYSTEM_MODE with the same two values bound for native
     *              :currentUserId / :currentUserName bind syntax. Passes
     *              when the result set is non-empty. QueryException is
     *              treated as a fail (surfaced with a generic message —
     *              no SOQL fragment leaked to the LWC).
     * @param queryTemplate VerificationQueryTxt__c from the catalog row.
     * @return EvaluatorOutcome.passed=true when the query returns &ge;1 row.
     */
    @TestVisible
    private static EvaluatorOutcome evaluateSoqlQuery(String queryTemplate) {
        if (String.isBlank(queryTemplate)) {
            return new EvaluatorOutcome(false, 'SoqlQuery',
                'Verification query is empty. Populate VerificationQueryTxt__c on the catalog row.');
        }
        Id currentUserId = UserInfo.getUserId();
        // Escape single quotes in the display name so admins who use the
        // {currentUserName} literal-substitution path can't accidentally
        // (or deliberately) break out of a quoted SOQL literal.
        String safeUserName = UserInfo.getName() == null
            ? '' : UserInfo.getName().replace('\'', '\\\'');
        String finalQuery = queryTemplate
            .replace('{currentUserId}', String.valueOf(currentUserId))
            .replace('{currentUserName}', safeUserName);
        try {
            List<SObject> results = Database.queryWithBinds(
                finalQuery,
                new Map<String, Object>{
                    'currentUserId' => currentUserId,
                    'currentUserName' => UserInfo.getName()
                },
                AccessLevel.SYSTEM_MODE
            );
            if (results != null && !results.isEmpty()) {
                return new EvaluatorOutcome(true, 'SoqlQuery', null);
            }
            return new EvaluatorOutcome(false, 'SoqlQuery',
                'Verification query returned no rows. Complete the required action first, then retry.');
        } catch (QueryException qe) {
            return new EvaluatorOutcome(false, 'SoqlQuery',
                'Verification failed: query error. Check the catalog row\'s SOQL syntax.');
        } catch (System.SObjectException soe) {
            // Misconfigured bind var or unknown field — same surface as QueryException.
            return new EvaluatorOutcome(false, 'SoqlQuery',
                'Verification failed: query error. Check the catalog row\'s SOQL syntax.');
        }
    }

    /**
     * @description RestCall evaluator. HTTP GET the URL in VerificationQueryTxt__c
     *              with a 10s timeout. URLs beginning with <code>callout:</code>
     *              resolve through a Named Credential. Passes on HTTP 2xx;
     *              CalloutException is treated as a fail and surfaced with a
     *              generic message.
     * @param restUrl VerificationQueryTxt__c interpreted as a URL.
     * @return EvaluatorOutcome.passed=true when the GET returns HTTP 2xx.
     */
    @TestVisible
    private static EvaluatorOutcome evaluateRestCall(String restUrl) {
        if (String.isBlank(restUrl)) {
            return new EvaluatorOutcome(false, 'RestCall',
                'Verification URL is empty. Populate VerificationQueryTxt__c on the catalog row.');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(restUrl);
        req.setMethod('GET');
        req.setTimeout(10000);
        try {
            HttpResponse res = new Http().send(req);
            Integer status = res == null ? 0 : res.getStatusCode();
            if (status >= 200 && status < 300) {
                return new EvaluatorOutcome(true, 'RestCall', null);
            }
            return new EvaluatorOutcome(false, 'RestCall',
                'Verification URL returned HTTP ' + status + '. Complete the required action first, then retry.');
        } catch (CalloutException ce) {
            return new EvaluatorOutcome(false, 'RestCall',
                'Verification failed: callout error. Confirm the URL or Named Credential is reachable.');
        }
    }

    /**
     * @description WebhookReceived evaluator. DH does not yet persist a
     *              generic inbound-webhook event log — DeliveryWebhookReceiverApi
     *              dispatches each event to a typed handler that writes a
     *              business record (e.g. DeliveryTransaction__c for Stripe).
     *              Until a generic event log ships, this method always returns
     *              a documented limitation. Switch the catalog row's
     *              VerificationMethodPk__c to Manual or RestCall (polling
     *              an endpoint the webhook handler updates) as a workaround.
     * @param channelKey VerificationQueryTxt__c interpreted as the channel
     *                   key the future webhook log would filter on.
     * @return EvaluatorOutcome.passed=false with a documented message.
     */
    @TestVisible
    private static EvaluatorOutcome evaluateWebhookReceived(String channelKey) {
        return new EvaluatorOutcome(false, 'WebhookReceived',
            'WebhookReceived verification is not yet supported in this release. '
            + 'Install the Phase 3 webhook-event log first, or switch the catalog '
            + 'row to Manual or RestCall (poll an endpoint the webhook handler updates).');
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
        if (row.CompletedDateTime__c == null && isTrackComplete(row)) {
            row.CompletedDateTime__c = Datetime.now();
        }
        update row;
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
