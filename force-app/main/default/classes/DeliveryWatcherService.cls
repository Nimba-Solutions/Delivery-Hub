/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Phase 2 Watcher v1 orchestrator. Single entry point for the
 *              daily aggregate signal sweep — reads the master flag, walks
 *              the enabled per-signal flags, invokes each Watcher*QueryService
 *              query() method, merges into a WatcherRunResultDTO, persists a
 *              WatcherDigest__c audit row, and posts a Slack message when
 *              there's something to say.
 *
 *              Master-flag-off + recipient-list-empty are both silent
 *              no-ops. Quiet days (all signals returned zero entries) still
 *              write a WatcherDigest__c row + stamp the heartbeat field
 *              (so the 14-day stabilization gate works), but skip Slack.
 *
 *              Signals 2 (StuckStage) + 3 (ARAging) land in PR-C; PR-B
 *              wires the orchestrator + Signal 1 (SLABreach) + the four
 *              stubs.
 *
 *              Per-signal try/catch is intentional: one bad signal must
 *              not poison the others. Captured exceptions land in
 *              WatcherRunResultDTO.errorMessages + downgrade StatusPk__c
 *              to Partial.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.ExcessiveParameterList')
global with sharing class DeliveryWatcherService {

    /** @description Cap on body characters persisted to WatcherDigest__c.DigestBodyTxt__c (LongTextArea(32768)). */
    @TestVisible
    private static final Integer BODY_CAP = 30000;

    /** @description Cap on the trimmed body string exposed via the DTO (lighter payload to LWCs). */
    @TestVisible
    private static final Integer DTO_BODY_CAP = 4000;

    /** @description Cap on FlaggedWorkItemIdsTxt__c stored payload (LongTextArea(4000)). */
    @TestVisible
    private static final Integer FLAGGED_WI_CAP = 3800;

    // ── Entry points ─────────────────────────────────────────────────────────

    /**
     * @description Public entry point. Reads the master flag, dispatches all
     *              enabled signals, persists a WatcherDigest__c, posts Slack
     *              when there's something to surface. Safe to call from
     *              anonymous Apex / a scheduler-enqueued queueable.
     */
    @AuraEnabled
    global static void run() {
        runAndReturnSummary();
    }

    /**
     * @description Entry point that also returns the run summary for admin
     *              LWCs (manual-run UX in PR-C+). Behaves identically to
     *              run() but bubbles the result back to the caller.
     * @return WatcherRunResultDTO with per-signal counts + digest body
     *         (trimmed) + error list. Returns a zero-state DTO when the
     *         master flag is off.
     */
    @AuraEnabled
    global static WatcherRunResultDTO runAndReturnSummary() {
        Long startedAtMs = System.currentTimeMillis();
        DeliveryHubSettings__c settings = loadSettings();
        if (!isMasterEnabled(settings)) {
            System.debug(LoggingLevel.INFO,
                '[DeliveryWatcherService] Watcher master flag disabled — no-op');
            return zeroResult(startedAtMs);
        }
        WatcherRunResultDTO result = dispatchSignals(settings);
        result.runDurationMs = System.currentTimeMillis() - startedAtMs;
        result.status = computeStatus(result);
        result.digestBodyMarkdown = buildBodyMarkdown(result);

        // Slack BEFORE persist so the digest row reflects actual delivery
        // outcome on first insert (no second DML round trip). Synchronous
        // callout — see DeliverySlackService.postWatcherDigest header for the
        // architecture note. Closes Flow 8 #3 audit gap (subscribers used to
        // see false `Success` even when the webhook 4xx/5xx'd).
        DeliverySlackService.SlackPostResultDTO slackOutcome = postSlackIfRecipients(result, settings);
        if (slackOutcome != null && slackOutcome.attempted && !slackOutcome.delivered) {
            result.status = 'Slack_Failed';
        }

        persistDigest(result, settings, slackOutcome);
        stampHeartbeat(settings, result.status);
        return result;
    }

    // ── Orchestration helpers ────────────────────────────────────────────────

    /**
     * @description Loads org-default DeliveryHubSettings__c. Returns null
     *              when the row doesn't exist (e.g. fresh subscriber pre-
     *              install-handler).
     * @return Org-default settings row, possibly null.
     */
    private static DeliveryHubSettings__c loadSettings() {
        return DeliveryHubSettings__c.getOrgDefaults();
    }

    /**
     * @description Master-flag gate. Master DateTime non-null = Watcher is
     *              alive on this tenant.
     * @param settings Loaded settings row.
     * @return true when Watcher should proceed.
     */
    private static Boolean isMasterEnabled(DeliveryHubSettings__c settings) {
        return settings != null && settings.EnableWatcherDigestDateTime__c != null;
    }

    /**
     * @description Returns a zero-state DTO used when Watcher is master-
     *              flag-off (no audit row written, no Slack posted).
     * @param startedAtMs Time the run started (millis since epoch).
     * @return DTO with status `Skipped`, zero counts, and a runDurationMs.
     */
    private static WatcherRunResultDTO zeroResult(Long startedAtMs) {
        WatcherRunResultDTO r = new WatcherRunResultDTO();
        r.status = 'Skipped';
        r.runDurationMs = System.currentTimeMillis() - startedAtMs;
        return r;
    }

    /**
     * @description Walks each per-signal gate, invokes the corresponding
     *              query() method when enabled, captures exceptions into
     *              errorMessages, and merges all results into one DTO.
     * @param settings Org-default settings row.
     * @return WatcherRunResultDTO with per-signal counts + per-signal
     *         SignalResultDTOs populated. status + duration are filled by
     *         the caller.
     */
    private static WatcherRunResultDTO dispatchSignals(DeliveryHubSettings__c settings) {
        WatcherRunResultDTO result = new WatcherRunResultDTO();
        result.slaSignal = runSlaBreachSignal(settings, result);
        result.stuckSignal = runStuckStageSignal(settings, result);
        result.arSignal = runArAgingSignal(settings, result);
        runStubSignals(settings, result);
        mergeCounts(result);
        return result;
    }

    /**
     * @description Runs Signal 1 (SLA Breach) when its gate is open.
     * @param settings Org-default settings row.
     * @param result   Accumulator for any thrown exception messages.
     * @return Populated SignalResultDTO on happy path, or null when the
     *         signal is gate-off / errored.
     */
    private static SignalResultDTO runSlaBreachSignal(DeliveryHubSettings__c settings, WatcherRunResultDTO result) {
        if (settings.EnableWatcherSLABreachDateTime__c == null) {
            return null;
        }
        try {
            return WatcherSLABreachQueryService.query();
        } catch (Exception e) {
            captureError(result, WatcherSLABreachQueryService.SIGNAL_NAME, e);
            return null;
        }
    }

    /**
     * @description Runs Signal 2 (Stuck Stage) when its gate is open.
     * @param settings Org-default settings row.
     * @param result   Accumulator for any thrown exception messages.
     * @return Populated SignalResultDTO on happy path, or null when the
     *         signal is gate-off / errored.
     */
    private static SignalResultDTO runStuckStageSignal(DeliveryHubSettings__c settings, WatcherRunResultDTO result) {
        if (settings.EnableWatcherStuckStageDateTime__c == null) {
            return null;
        }
        try {
            return WatcherStuckStageQueryService.query();
        } catch (Exception e) {
            captureError(result, WatcherStuckStageQueryService.SIGNAL_NAME, e);
            return null;
        }
    }

    /**
     * @description Runs Signal 3 (A/R Aging) when its gate is open.
     * @param settings Org-default settings row.
     * @param result   Accumulator for any thrown exception messages.
     * @return Populated SignalResultDTO on happy path, or null when the
     *         signal is gate-off / errored.
     */
    private static SignalResultDTO runArAgingSignal(DeliveryHubSettings__c settings, WatcherRunResultDTO result) {
        if (settings.EnableWatcherARAgingDateTime__c == null) {
            return null;
        }
        try {
            return WatcherARAgingQueryService.query();
        } catch (Exception e) {
            captureError(result, WatcherARAgingQueryService.SIGNAL_NAME, e);
            return null;
        }
    }

    /**
     * @description Runs the four stub signals when their respective gates
     *              are open. PR-B stubs always return empty results so
     *              merging is a formality; PR-C+ may replace these with
     *              real implementations.
     * @param settings Org-default settings row.
     * @param result   Accumulator for any thrown exception messages.
     */
    private static void runStubSignals(DeliveryHubSettings__c settings, WatcherRunResultDTO result) {
        if (settings.EnableWatcherUnhappySignalDateTime__c != null) {
            runOneStub(WatcherUnhappySignalQueryService.SIGNAL_NAME, result, 'unhappy');
        }
        if (settings.EnableWatcherSignoffDateTime__c != null) {
            runOneStub(WatcherUpcomingSignoffQueryService.SIGNAL_NAME, result, 'signoff');
        }
        if (settings.EnableWatcherPaymentOpsDateTime__c != null) {
            runOneStub(WatcherPaymentOpsQueryService.SIGNAL_NAME, result, 'payment');
        }
        if (settings.EnableWatcherSyncTrendDateTime__c != null) {
            runOneStub(WatcherFailedSyncTrendQueryService.SIGNAL_NAME, result, 'synctrend');
        }
    }

    /**
     * @description Dispatches one stub by tag. Stubs return empty
     *              SignalResultDTO; we only capture exceptions (defensive).
     * @param signalName Signal identifier for error capture.
     * @param result     Accumulator.
     * @param tag        Which stub to invoke.
     */
    private static void runOneStub(String signalName, WatcherRunResultDTO result, String tag) {
        try {
            if (tag == 'unhappy') {
                WatcherUnhappySignalQueryService.query();
            } else if (tag == 'signoff') {
                WatcherUpcomingSignoffQueryService.query();
            } else if (tag == 'payment') {
                WatcherPaymentOpsQueryService.query();
            } else if (tag == 'synctrend') {
                WatcherFailedSyncTrendQueryService.query();
            }
        } catch (Exception e) {
            captureError(result, signalName, e);
        }
    }

    /**
     * @description Captures a thrown signal error into the result DTO.
     * @param result     Accumulator.
     * @param signalName Signal identifier.
     * @param e          Thrown exception.
     */
    private static void captureError(WatcherRunResultDTO result, String signalName, Exception e) {
        if (result.errorMessages == null) {
            result.errorMessages = new List<String>();
        }
        result.errorMessages.add(signalName + ': ' + e.getTypeName() + ' — ' + e.getMessage());
    }

    /**
     * @description Maps signal DTOs into the orchestrator's flat per-signal
     *              count fields. Signals 1 (SLA), 2 (Stuck Stage) and 3
     *              (A/R Aging) all populate here. PR-C closes Watcher v1.
     * @param result Result accumulator.
     */
    private static void mergeCounts(WatcherRunResultDTO result) {
        result.slaBreachCount = (result.slaSignal != null && result.slaSignal.primaryCount != null)
            ? result.slaSignal.primaryCount : 0;
        result.slaAtRiskCount = (result.slaSignal != null && result.slaSignal.secondaryCount != null)
            ? result.slaSignal.secondaryCount : 0;
        result.stuckStageCount = (result.stuckSignal != null && result.stuckSignal.primaryCount != null)
            ? result.stuckSignal.primaryCount : 0;
        result.arOverdueCount = (result.arSignal != null && result.arSignal.primaryCount != null)
            ? result.arSignal.primaryCount : 0;
        result.arOverdueAmount = (result.arSignal != null && result.arSignal.secondaryCount != null)
            ? result.arSignal.secondaryCount : 0;
    }

    /**
     * @description Computes the signal-collection status: Failed if every
     *              signal threw, Partial if at least one threw, Success
     *              otherwise. A signal "succeeded" when its DTO slot is
     *              non-null (PR-C onward: SLA / Stuck / AR each contribute).
     *              Slack-delivery outcome is a separate downgrade applied by
     *              the caller after the post (`Slack_Failed` overrides
     *              `Success` when the webhook 4xx/5xx'd or threw).
     * @param result Aggregated result.
     * @return One of `Success`, `Partial`, `Failed` (GVS-backed).
     */
    private static String computeStatus(WatcherRunResultDTO result) {
        Integer errorCount = (result.errorMessages == null) ? 0 : result.errorMessages.size();
        if (errorCount == 0) {
            return 'Success';
        }
        Boolean anySucceeded = (result.slaSignal != null && result.slaSignal.errorMessage == null)
            || (result.stuckSignal != null && result.stuckSignal.errorMessage == null)
            || (result.arSignal != null && result.arSignal.errorMessage == null);
        return anySucceeded ? 'Partial' : 'Failed';
    }

    /**
     * @description Renders the digest body to plaintext markdown for both
     *              the audit row and the DTO. Wraps the formatter call in a
     *              try/catch — body rendering must never fail the run.
     * @param result Aggregated result.
     * @return Markdown string; empty when formatter throws.
     */
    private static String buildBodyMarkdown(WatcherRunResultDTO result) {
        try {
            String label = Datetime.now().format('yyyy-MM-dd HH:mm');
            String body = DeliveryWatcherDigestFormatter.buildMarkdown(result, label);
            return body == null ? '' : body;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWatcherService] markdown render failed: ' + e.getMessage());
            return '';
        }
    }

    // ── Persistence ──────────────────────────────────────────────────────────

    /**
     * @description Inserts a WatcherDigest__c audit row capturing this run.
     *              Wrapped in try/catch — persistence must not nullify a
     *              successful sweep. Receives the Slack delivery outcome so
     *              the row's StatusPk__c and SlackResponseTxt__c reflect what
     *              actually happened (closes Flow 8 #3 audit gap — subscribers
     *              previously saw `Success` even when the webhook 4xx/5xx'd).
     * @param result       Aggregated result.
     * @param settings     Org-default settings row.
     * @param slackOutcome Slack post outcome; may be null when no post was attempted.
     */
    private static void persistDigest(
        WatcherRunResultDTO result,
        DeliveryHubSettings__c settings,
        DeliverySlackService.SlackPostResultDTO slackOutcome
    ) {
        try {
            WatcherDigest__c row = new WatcherDigest__c(
                RunDateTime__c = Datetime.now(),
                RunDurationMsNumber__c = result.runDurationMs,
                StatusPk__c = result.status,
                DigestBodyTxt__c = truncate(result.digestBodyMarkdown, BODY_CAP),
                SignalCountsTxt__c = buildSignalCountsTxt(result),
                FlaggedWorkItemIdsTxt__c = buildFlaggedWorkItemIds(result),
                FlaggedDocumentIdsTxt__c = buildFlaggedDocumentIds(result),
                ErrorMessageTxt__c = buildErrorMessageTxt(result),
                RecipientUserIdsTxt__c = truncate(settings.WatcherDigestRecipientUserIdsTxt__c, 255),
                SlackResponseTxt__c = buildSlackResponseTxt(slackOutcome),
                RunModePk__c = Test.isRunningTest() ? 'Test' : 'Scheduled'
            );
            insert row;
            result.digestId = row.Id;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWatcherService] WatcherDigest__c insert failed: ' + e.getMessage());
        }
    }

    /**
     * @description Returns the SlackResponseTxt__c value to persist. Empty
     *              when no Slack post was attempted (quiet day, no recipient
     *              list, master-flag-off path) or when delivery succeeded
     *              (we only persist the response text on failure for the
     *              audit trail — keeps successful-day rows compact). The
     *              response text is already clipped to 255 chars by
     *              DeliverySlackService.
     * @param slackOutcome Outcome from the Slack post; may be null.
     * @return Slack response preview when delivery failed, otherwise empty.
     */
    private static String buildSlackResponseTxt(DeliverySlackService.SlackPostResultDTO slackOutcome) {
        if (slackOutcome == null || !slackOutcome.attempted) {
            return '';
        }
        if (slackOutcome.delivered) {
            return '';
        }
        return slackOutcome.responseText == null ? '' : slackOutcome.responseText;
    }

    /**
     * @description Builds the compact one-line per-signal counts string for
     *              WatcherDigest__c.SignalCountsTxt__c (used for trending /
     *              report filters).
     * @param result Aggregated result.
     * @return e.g. `SLA:3,AtRisk:2,Stuck:0,AR:0`.
     */
    private static String buildSignalCountsTxt(WatcherRunResultDTO result) {
        return 'SLA:' + result.slaBreachCount
            + ',AtRisk:' + result.slaAtRiskCount
            + ',Stuck:' + result.stuckStageCount
            + ',AR:' + result.arOverdueCount;
    }

    /**
     * @description Builds the comma-separated WI Id payload for
     *              WatcherDigest__c.FlaggedWorkItemIdsTxt__c. Pulls Ids from
     *              the SLA + Stuck-Stage signals' topEntries (both surface
     *              WorkItem__c records); the AR signal contributes to
     *              FlaggedDocumentIdsTxt__c separately.
     * @param result Aggregated result.
     * @return Comma-separated Id string, or empty.
     */
    private static String buildFlaggedWorkItemIds(WatcherRunResultDTO result) {
        List<String> ids = new List<String>();
        appendEntryIds(ids, result.slaSignal);
        appendEntryIds(ids, result.stuckSignal);
        if (ids.isEmpty()) {
            return '';
        }
        return truncate(String.join(ids, ','), FLAGGED_WI_CAP);
    }

    /**
     * @description Builds the comma-separated Document Id payload for
     *              WatcherDigest__c.FlaggedDocumentIdsTxt__c. Pulls Ids
     *              from the AR signal's topEntries (those are
     *              DeliveryDocument__c rows).
     * @param result Aggregated result.
     * @return Comma-separated Id string, or empty.
     */
    private static String buildFlaggedDocumentIds(WatcherRunResultDTO result) {
        List<String> ids = new List<String>();
        appendEntryIds(ids, result.arSignal);
        if (ids.isEmpty()) {
            return '';
        }
        return truncate(String.join(ids, ','), FLAGGED_WI_CAP);
    }

    /**
     * @description Appends each non-null entry Id from a signal's
     *              topEntries onto the supplied accumulator.
     * @param accumulator Mutable Id list.
     * @param signal      Signal whose topEntries to walk; may be null.
     */
    private static void appendEntryIds(List<String> accumulator, SignalResultDTO signal) {
        if (signal == null || signal.topEntries == null || signal.topEntries.isEmpty()) {
            return;
        }
        for (SignalEntryDTO e : signal.topEntries) {
            if (e != null && e.recordId != null) {
                accumulator.add(String.valueOf(e.recordId));
            }
        }
    }

    /**
     * @description Joins captured per-signal error messages into one string
     *              for WatcherDigest__c.ErrorMessageTxt__c.
     * @param result Aggregated result.
     * @return Joined error string, or empty when no signals threw.
     */
    private static String buildErrorMessageTxt(WatcherRunResultDTO result) {
        if (result.errorMessages == null || result.errorMessages.isEmpty()) {
            return '';
        }
        return String.join(result.errorMessages, '\n');
    }

    // ── Slack ────────────────────────────────────────────────────────────────

    /**
     * @description Posts the Block Kit payload to Slack when (a) a recipient
     *              list is configured AND (b) the formatter returned a
     *              non-null payload (quiet days return null → silent).
     *              Returns the Slack delivery outcome so the caller can
     *              reflect it on the WatcherDigest__c row's StatusPk__c +
     *              SlackResponseTxt__c. Any exception thrown while building
     *              the payload is captured into the returned DTO so the
     *              audit still records the Slack-side failure.
     * @param result   Aggregated result.
     * @param settings Org-default settings row.
     * @return SlackPostResultDTO with `attempted=false` when no post was
     *         attempted (no recipients / quiet day); otherwise the actual
     *         outcome from DeliverySlackService. Never returns null.
     */
    private static DeliverySlackService.SlackPostResultDTO postSlackIfRecipients(
        WatcherRunResultDTO result,
        DeliveryHubSettings__c settings
    ) {
        DeliverySlackService.SlackPostResultDTO skipped = new DeliverySlackService.SlackPostResultDTO();
        if (String.isBlank(settings.WatcherDigestRecipientUserIdsTxt__c)) {
            return skipped;
        }
        try {
            String label = Datetime.now().format('yyyy-MM-dd HH:mm');
            Map<String, Object> blockKit = DeliveryWatcherDigestFormatter.buildBlockKit(result, label);
            if (blockKit == null) {
                return skipped; // Quiet day — Slack silent, audit row still written.
            }
            String channelOverride = settings.WatcherDigestSlackChannelTxt__c;
            if (String.isNotBlank(channelOverride)) {
                blockKit.put('channel', channelOverride);
            }
            return DeliverySlackService.postWatcherDigest(JSON.serialize(blockKit));
        } catch (Exception e) {
            // Payload-build failure: don't poison the run, but DO surface the
            // failure as a Slack-side problem so the audit row reflects it.
            DeliverySlackService.SlackPostResultDTO buildFail = new DeliverySlackService.SlackPostResultDTO();
            buildFail.attempted = true;
            buildFail.delivered = false;
            String msg = 'Payload build failed: ' + e.getTypeName() + ': ' + e.getMessage();
            buildFail.responseText = msg.length() > 255 ? msg.substring(0, 255) : msg;
            return buildFail;
        }
    }

    // ── Heartbeat ────────────────────────────────────────────────────────────

    /**
     * @description Stamps LastWatcherHeartbeatDateTime__c on the org-default
     *              settings when the signal-collection sweep succeeded (or
     *              partially succeeded, OR succeeded-but-Slack-failed).
     *              Heartbeat tracks "the watcher woke up and queried", which
     *              is independent of Slack delivery — a Slack outage must not
     *              keep the 14-day stabilization gate from clearing. Only
     *              `Failed` (orchestrator-side blow-up) skips the stamp.
     *              Used by the scheduler's idempotency gate AND the 14-day
     *              stabilization gate that precedes Phase 3 auto-digest.
     * @param settings Org-default settings row (already loaded).
     * @param status   Run status (Success / Partial / Failed / Slack_Failed).
     */
    private static void stampHeartbeat(DeliveryHubSettings__c settings, String status) {
        if (status == 'Failed') {
            return; // Heartbeat tracks successful sweeps only; Slack_Failed still counts.
        }
        try {
            settings.LastWatcherHeartbeatDateTime__c = Datetime.now();
            upsert settings;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWatcherService] heartbeat stamp failed: ' + e.getMessage());
        }
    }

    // ── Utilities ────────────────────────────────────────────────────────────

    /**
     * @description Null-tolerant string truncation.
     * @param value    Value to truncate.
     * @param maxLen   Max length (inclusive).
     * @return Trimmed value, or empty when input is null.
     */
    private static String truncate(String value, Integer maxLen) {
        if (value == null) {
            return '';
        }
        if (maxLen == null || value.length() <= maxLen) {
            return value;
        }
        return value.substring(0, maxLen);
    }

    // ── Inner DTOs ───────────────────────────────────────────────────────────

    /**
     * @description Aggregated run result bubbled back to admin UIs +
     *              persisted into WatcherDigest__c. Designed to be JSON-
     *              serialisable for cross-namespace Aura calls.
     */
    global virtual class WatcherRunResultDTO {

        /** @description Id of the persisted WatcherDigest__c row, or null when persistence skipped. */
        @AuraEnabled public Id digestId;

        /** @description Outcome: `Success` / `Partial` / `Failed` / `Skipped`. */
        @AuraEnabled public String status;

        /** @description Count of WIs in Breached state (SLA signal). */
        @AuraEnabled public Integer slaBreachCount;

        /** @description Count of WIs in At Risk state (SLA signal). */
        @AuraEnabled public Integer slaAtRiskCount;

        /** @description Stuck-stage weighted count (Critical-stage rows count double). */
        @AuraEnabled public Integer stuckStageCount;

        /** @description AR-aging document count. */
        @AuraEnabled public Integer arOverdueCount;

        /** @description AR-aging sum of TotalCurrency__c across surfaced invoices (major units). */
        @AuraEnabled public Integer arOverdueAmount;

        /** @description Wall-clock duration of the run in milliseconds. */
        @AuraEnabled public Long runDurationMs;

        /** @description Trimmed digest body markdown (full body persisted to WatcherDigest__c.DigestBodyTxt__c). */
        @AuraEnabled public String digestBodyMarkdown;

        /** @description Per-signal error captures (signal name + exception message). */
        @AuraEnabled public List<String> errorMessages;

        /** @description SLA signal raw payload. Internal — used by the formatter; not surfaced to LWC. */
        public SignalResultDTO slaSignal;

        /** @description Stuck-stage signal raw payload. Internal — used by the formatter. */
        public SignalResultDTO stuckSignal;

        /** @description A/R aging signal raw payload. Internal — used by the formatter. */
        public SignalResultDTO arSignal;

        /**
         * @description Default constructor. Initialises counts to zero +
         *              errorMessages to an empty list so callers never NPE.
         */
        global WatcherRunResultDTO() {
            this.slaBreachCount = 0;
            this.slaAtRiskCount = 0;
            this.stuckStageCount = 0;
            this.arOverdueCount = 0;
            this.arOverdueAmount = 0;
            this.runDurationMs = 0L;
            this.errorMessages = new List<String>();
        }
    }
}
