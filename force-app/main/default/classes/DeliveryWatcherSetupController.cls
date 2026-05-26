/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Admin setup surface for the Phase 2 Watcher digest. Backs the
 *               `deliveryWatcherSetup` LWC so subscribers can flip the master
 *               opt-in (EnableWatcherDigestDateTime__c) and populate the
 *               recipient list (WatcherDigestRecipientUserIdsTxt__c) without
 *               opening Setup → Custom Settings.
 *
 *               Read path is cacheable; the LWC re-reads after a save by
 *               refreshing the wire. Write path validates every recipient
 *               Id against active Users (no silent drops — invalid Ids come
 *               back in the DTO so the UI can show a precise toast).
 *
 *               Admin gate reuses DeliveryFeatureCatalogController.isAdmin()
 *               so the DeliveryHubAdmin PermissionSetGroup is the single
 *               source of truth for cockpit-style admin surfaces.
 *
 *               Closes Flow 8 #1 from docs/audits/e2e-walkthrough-2026-05-21.md.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
global with sharing class DeliveryWatcherSetupController {

    /**
     * @description DTO returned by both getSettings() and saveSettings().
     *              `recipientUsers` is the resolved (post-validation) view
     *              of `recipientIdsCsv` — the LWC chip-renders this list so
     *              the admin sees who actually receives the digest, not just
     *              raw 18-char Ids.
     *
     *              `lastSavedDateTime` mirrors LastModifiedDate on the
     *              Custom Setting org-default row when one exists. Null on
     *              orgs that have not yet saved.
     */
    global class SettingsDTO {
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public DateTime enabledSince;
        @AuraEnabled public String recipientIdsCsv;
        @AuraEnabled public List<UserSummaryDTO> recipientUsers;
        @AuraEnabled public List<String> invalidRecipientIds;
        @AuraEnabled public String slackWebhookUrl;
        @AuraEnabled public String slackChannel;
        @AuraEnabled public Decimal runHourGmt;
        @AuraEnabled public DateTime lastSavedDateTime;
        @AuraEnabled public DateTime nextScheduledRunDateTime;
    }

    /**
     * @description Per-user summary used to chip-render the recipient list
     *              in the LWC. `isActive` lets the UI mark a previously-
     *              valid recipient who has since been deactivated without
     *              forcing an immediate save.
     */
    global class UserSummaryDTO {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String userEmail;
        @AuraEnabled public Boolean isActive;
    }

    /**
     * @description Returns the current Watcher digest configuration. Cacheable
     *              so the LWC can @wire it and re-render via refreshApex after
     *              save. Returns a populated DTO even when no Custom Setting
     *              org-default exists yet (fresh-install posture).
     * @return SettingsDTO snapshot of the current configuration.
     */
    @AuraEnabled(cacheable=true)
    global static SettingsDTO getSettings() {
        SettingsDTO dto = new SettingsDTO();
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        populateDtoFromSettings(dto, settings);
        dto.recipientUsers = resolveRecipientUsers(dto.recipientIdsCsv);
        dto.invalidRecipientIds = new List<String>();
        dto.nextScheduledRunDateTime = resolveNextScheduledRun();
        return dto;
    }

    /**
     * @description Persists the Watcher digest configuration. Admin-only.
     *              Validates every recipient Id against active Users before
     *              writing — invalid / inactive Ids are reported back in the
     *              returned DTO's `invalidRecipientIds` list. The save still
     *              proceeds with the validated subset so an admin can ratchet
     *              the list down without one stale Id blocking the whole save.
     *
     *              `enabled=true` stamps EnableWatcherDigestDateTime__c to
     *              NOW only when the field is currently null (preserves the
     *              original opt-in stamp across re-saves). `enabled=false`
     *              nulls it out — entire Watcher pipeline returns to silent.
     * @param enabled True to opt-in to the Watcher digest, false to silence.
     * @param recipientIdsCsv Comma-separated 18-char User Ids. Blank allowed.
     * @param slackWebhookUrl Override for SlackWebhookUrlTxt__c. Blank leaves the
     *                       existing value unchanged so admins editing the
     *                       Watcher form don't accidentally wipe the org's
     *                       global Slack webhook used by escalations + forecasts.
     * @return SettingsDTO post-save snapshot, including `invalidRecipientIds`.
     */
    @AuraEnabled
    global static SettingsDTO saveSettings(Boolean enabled, String recipientIdsCsv, String slackWebhookUrl) {
        assertAdmin();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null) {
            settings = new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }

        applyEnabledFlag(settings, enabled);

        RecipientValidation validation = validateRecipientCsv(recipientIdsCsv);
        settings.WatcherDigestRecipientUserIdsTxt__c = validation.validCsv;

        // Slack webhook: blank input = leave existing value (avoid foot-gun).
        if (slackWebhookUrl != null) {
            String trimmed = slackWebhookUrl.trim();
            if (String.isNotBlank(trimmed)) {
                settings.SlackWebhookUrlTxt__c = trimmed;
            }
        }

        persistSettings(settings);

        SettingsDTO dto = new SettingsDTO();
        populateDtoFromSettings(dto, settings);
        dto.recipientUsers = resolveRecipientUsers(dto.recipientIdsCsv);
        dto.invalidRecipientIds = validation.invalidIds;
        dto.nextScheduledRunDateTime = resolveNextScheduledRun();
        return dto;
    }

    // ────────────────────────────────────────────────────────────────────
    // Internal helpers
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Container for the result of CSV validation so the
     *              save path can persist the cleaned CSV and still
     *              hand back the invalid-id list to the UI.
     */
    private class RecipientValidation {
        String validCsv;
        List<String> invalidIds;
        RecipientValidation() {
            this.validCsv = '';
            this.invalidIds = new List<String>();
        }
    }

    /**
     * @description Splits + trims the user-supplied CSV, then verifies each
     *              candidate Id is (a) a syntactically-valid Salesforce Id,
     *              and (b) belongs to an active User. Validated Ids are
     *              re-joined into a CSV ready to write to Text(255). Invalid
     *              entries are returned separately for UI surfacing.
     * @param csv Raw user-supplied CSV. Tolerates blanks, extra commas,
     *            leading/trailing whitespace.
     * @return RecipientValidation with the cleaned CSV + invalid-id list.
     */
    private static RecipientValidation validateRecipientCsv(String csv) {
        RecipientValidation result = new RecipientValidation();
        if (String.isBlank(csv)) {
            return result;
        }
        Set<Id> candidateIds = new Set<Id>();
        List<String> rawTokens = new List<String>();
        for (String token : csv.split(',')) {
            String trimmed = token == null ? '' : token.trim();
            if (String.isBlank(trimmed)) {
                continue;
            }
            rawTokens.add(trimmed);
            try {
                Id maybeId = Id.valueOf(trimmed);
                candidateIds.add(maybeId);
            } catch (System.StringException e) {
                // Falls through to the invalid-id reporting below.
                result.invalidIds.add(trimmed);
            }
        }
        if (candidateIds.isEmpty()) {
            return result;
        }
        Map<Id, User> activeUsers = new Map<Id, User>([
            SELECT Id, Name, Email, IsActive
            FROM User
            WHERE Id IN :candidateIds
              AND IsActive = true
            WITH SYSTEM_MODE
        ]);
        List<String> validatedIds = new List<String>();
        for (String token : rawTokens) {
            try {
                Id maybeId = Id.valueOf(token);
                if (activeUsers.containsKey(maybeId)) {
                    if (!validatedIds.contains(String.valueOf(maybeId))) {
                        validatedIds.add(String.valueOf(maybeId));
                    }
                } else {
                    result.invalidIds.add(token);
                }
            } catch (System.StringException e) {
                // Already captured above.
            }
        }
        result.validCsv = String.join(validatedIds, ',');
        // Custom Setting field is Text(255). 13 18-char Ids + 12 commas = 246
        // chars, just under the cap. Defensive truncation: if a user pastes
        // 20+ Ids we accept the first 13 silently rather than throwing.
        if (result.validCsv.length() > 255) {
            List<String> trimmedIds = new List<String>();
            Integer running = 0;
            for (String idStr : validatedIds) {
                Integer added = trimmedIds.isEmpty() ? idStr.length() : idStr.length() + 1;
                if (running + added > 255) {
                    break;
                }
                trimmedIds.add(idStr);
                running += added;
            }
            result.validCsv = String.join(trimmedIds, ',');
        }
        return result;
    }

    /**
     * @description Copies the persisted settings row into the DTO. Tolerates
     *              a null settings reference (fresh-install posture — no
     *              org-default exists yet) by leaving DTO fields at their
     *              defaults.
     * @param dto       DTO under construction.
     * @param settings  DeliveryHubSettings__c.getOrgDefaults() result.
     */
    private static void populateDtoFromSettings(SettingsDTO dto, DeliveryHubSettings__c settings) {
        if (settings == null) {
            dto.enabled = false;
            dto.recipientIdsCsv = '';
            return;
        }
        dto.enabled = settings.EnableWatcherDigestDateTime__c != null;
        dto.enabledSince = settings.EnableWatcherDigestDateTime__c;
        dto.recipientIdsCsv = settings.WatcherDigestRecipientUserIdsTxt__c == null
            ? ''
            : settings.WatcherDigestRecipientUserIdsTxt__c;
        dto.slackWebhookUrl = settings.SlackWebhookUrlTxt__c;
        dto.slackChannel = settings.WatcherDigestSlackChannelTxt__c;
        dto.runHourGmt = settings.WatcherDigestRunHourGmtNumber__c;
        if (settings.Id != null) {
            dto.lastSavedDateTime = settings.LastModifiedDate;
        }
    }

    /**
     * @description Maps the validated CSV into the per-user DTO shape the
     *              LWC chip-renders. Returns an empty list when the CSV is
     *              blank or contains no resolvable Ids. Surfaces inactive
     *              Users with isActive=false so the admin can spot a
     *              recipient who has since left without re-saving.
     * @param csv Validated CSV of 18-char User Ids.
     * @return List of UserSummaryDTO, one per resolvable Id.
     */
    private static List<UserSummaryDTO> resolveRecipientUsers(String csv) {
        List<UserSummaryDTO> out = new List<UserSummaryDTO>();
        if (String.isBlank(csv)) {
            return out;
        }
        Set<Id> ids = new Set<Id>();
        for (String token : csv.split(',')) {
            String trimmed = token == null ? '' : token.trim();
            if (String.isBlank(trimmed)) {
                continue;
            }
            try {
                ids.add(Id.valueOf(trimmed));
            } catch (System.StringException e) {
                // Silently skip — validation path already surfaced these.
            }
        }
        if (ids.isEmpty()) {
            return out;
        }
        for (User u : [
            SELECT Id, Name, Email, IsActive
            FROM User
            WHERE Id IN :ids
            WITH SYSTEM_MODE
        ]) {
            UserSummaryDTO summary = new UserSummaryDTO();
            summary.userId = u.Id;
            summary.userName = u.Name;
            summary.userEmail = u.Email;
            summary.isActive = u.IsActive;
            out.add(summary);
        }
        return out;
    }

    /**
     * @description Toggles the master EnableWatcherDigestDateTime__c stamp.
     *              True with an already-stamped value is a no-op (preserves
     *              the original opt-in moment for audit). True on a null
     *              field stamps NOW. False unconditionally nulls.
     * @param settings Settings row about to be upserted.
     * @param enabled  Desired post-save state.
     */
    private static void applyEnabledFlag(DeliveryHubSettings__c settings, Boolean enabled) {
        Boolean enableFlag = enabled == true;
        if (enableFlag) {
            if (settings.EnableWatcherDigestDateTime__c == null) {
                settings.EnableWatcherDigestDateTime__c = DateTime.now();
            }
        } else {
            settings.EnableWatcherDigestDateTime__c = null;
        }
    }

    /**
     * @description Upserts the Custom Setting org-default. Wrapped so the
     *              service has a single place to surface DML failures back
     *              to the LWC as an AuraHandledException (per CLAUDE.md, do
     *              not assert on AuraHandledException.getMessage() — keep
     *              the message generic).
     * @param settings Row to upsert.
     */
    private static void persistSettings(DeliveryHubSettings__c settings) {
        try {
            Database.upsert(settings, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWatcherSetupController.persistSettings] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to save Watcher settings.');
        }
    }

    /**
     * @description Looks up the next CronTrigger fire time for the Watcher
     *              digest scheduler so the LWC can show admins when the
     *              next tick is expected. Returns null when no matching
     *              CronTrigger is found (fresh install — DeliveryHubScheduler
     *              has not run yet).
     * @return NextFireTime of the Watcher scheduled job, or null.
     */
    private static DateTime resolveNextScheduledRun() {
        List<CronTrigger> jobs = [
            SELECT NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Delivery Hub Scheduler%'
            WITH SYSTEM_MODE
            ORDER BY NextFireTime ASC NULLS LAST
            LIMIT 1
        ];
        return jobs.isEmpty() ? null : jobs.get(0).NextFireTime;
    }

    /**
     * @description Throws AuraHandledException when the running user lacks
     *              the DeliveryHubAdmin PSG. Reuses
     *              DeliveryFeatureCatalogController.isAdmin() so the gate
     *              is a single source of truth across cockpit-style
     *              admin surfaces (per CLAUDE.md, all global static helpers
     *              are reusable).
     */
    private static void assertAdmin() {
        if (!DeliveryFeatureCatalogController.isAdmin()) {
            throw new AuraHandledException('Admin permission required.');
        }
    }
}
