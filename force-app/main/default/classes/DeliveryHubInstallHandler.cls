/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Runs automatically when the Delivery Hub package is installed or upgraded.
 *              Initialises org-level default settings, schedules the four sync cron jobs,
 *              kicks an initial reconciliation pass, and backfills auto-assigned
 *              PermissionSets to existing active users — so administrators do not need
 *              to trigger the setup wizard before the package is functional.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier')
global class DeliveryHubInstallHandler implements InstallHandler {

    /**
     * @description Entry point called by Salesforce on package install/upgrade.
     * @param context Provides version and install type metadata.
     */
    global void onInstall(InstallContext context) {
        initializeDefaultSettings();
        seedFeaturesFromDefinitions();
        syncLegacySettingsToFeatures();
        scheduleSyncJobs();
        backfillUserPermissionSets();
        backfillWorkItemStatusDefaults();
        enqueueInitialReconciliation();
    }

    /**
     * @description Copies legacy DeliveryHubSettings__c.Enable*DateTime__c
     *              values onto matching Feature__c rows after seeding. So
     *              existing tenants whose admins already toggled features
     *              via Setup → Custom Settings will see the cockpit
     *              reflect that state on first render. Idempotent.
     *              Wrapped in try/catch — install must never fail on
     *              cosmetic mirror.
     */
    private static void syncLegacySettingsToFeatures() {
        try {
            DeliveryFeatureSyncService.syncSettingsToFeatures();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallHandler] Feature settings sync failed: '
                + e.getMessage());
        }
    }

    /**
     * @description Initialises the org-default DeliveryHubSettings__c row on
     *              a fresh tenant install. No-ops when settings already exist,
     *              so a re-install / upgrade never overwrites admin choices
     *              (an existing org such as MF prod is left untouched).
     *
     *              SAFE-BY-DEFAULT / ZERO-NOISE-ON-INSTALL: a brand-new org must
     *              never emit a user-visible side effect — email, in-app bell,
     *              Slack post, AI/OpenAI call, automation, or sync — without an
     *              admin explicitly opting in. So every notification / AI /
     *              automation / Watcher-signal flag is left null (off). The only
     *              flags set on are the two purely-internal, no-external-effect
     *              ones: Activity Logging (the hash-chained audit trail, valuable
     *              from day one) and Board Metrics (display only). Admins enable
     *              everything else through the guided setup flow, after seeing a
     *              preview of what each one does. The Watcher master gate
     *              (EnableWatcherDigestDateTime__c) likewise stays null.
     */
    private static void initializeDefaultSettings() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings.Id != null) {
            return; // Already configured — do not overwrite existing settings
        }
        Datetime now = Datetime.now();
        settings = new DeliveryHubSettings__c(
            SetupOwnerId                     = UserInfo.getOrganizationId(),
            // Zero-noise wins: purely internal, no external side effect.
            EnableActivityLoggingDateTime__c = now,
            EnableBoardMetricsDateTime__c    = now,
            // Operational config (not feature toggles).
            FailedSyncAutoDismissDaysNumber__c = 14,
            StagesToAutoShareWithDevTeamTxt__c = 'All'
            // Everything else — Notifications, Email, AI (suggestions/estimation/
            // auto-descriptions), AutoCreateWorkRequest, AutoSyncNetworkEntity,
            // and every Watcher signal + the digest master gate — is intentionally
            // left null = OFF. Admins opt in via the guided setup flow.
        );
        insert settings;
    }

    /**
     * @description Seeds one Feature__c per FeatureDefinition__mdt that does not
     *              already have a matching runtime row. Idempotent: re-running
     *              the install never duplicates existing seeded rows. Defaults
     *              the per-tenant EnabledDateTime__c to the catalog's
     *              DefaultEnabledDateTime__c (which is currently null for every
     *              shipped record — admins activate features explicitly via the
     *              cockpit). Wrapped in try/catch — install must never fail on
     *              seed (existing handler pattern).
     */
    private static void seedFeaturesFromDefinitions() {
        try {
            List<FeatureDefinition__mdt> defs = [
                SELECT DeveloperName, DefaultEnabledDateTime__c
                FROM FeatureDefinition__mdt
            ];
            if (defs.isEmpty()) {
                return;
            }
            Set<String> existingDefNames = new Set<String>();
            for (Feature__c existing : [
                SELECT FeatureDefinitionTxt__c FROM Feature__c
                WHERE FeatureDefinitionTxt__c != null
            ]) {
                existingDefNames.add(existing.FeatureDefinitionTxt__c);
            }
            List<Feature__c> toInsert = new List<Feature__c>();
            for (FeatureDefinition__mdt fd : defs) {
                if (existingDefNames.contains(fd.DeveloperName)) {
                    continue;
                }
                toInsert.add(new Feature__c(
                    Name = fd.DeveloperName,
                    FeatureDefinitionTxt__c = fd.DeveloperName,
                    EnabledDateTime__c = fd.DefaultEnabledDateTime__c
                ));
            }
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallHandler] Feature catalog seed failed: '
                + e.getMessage());
        }
    }

    /**
     * @description Schedules the four standard 15-min sync cron jobs so a fresh
     *              tenant is fully operational without admin intervention.
     *              scheduleAll() is idempotent — it aborts existing matching
     *              jobs before re-scheduling, so re-running on upgrade is safe.
     *              Wrapped in try/catch because failures here must never block
     *              the install (the setup wizard remains as the manual fallback).
     */
    private static void scheduleSyncJobs() {
        try {
            DeliveryHubScheduler.scheduleAll();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallHandler] scheduleAll failed during install: '
                + e.getMessage());
        }
    }

    /**
     * @description Backfills PermissionSetAssignments for every active internal
     *              user against the current UserAutoAssignConfig__mdt rules.
     *              Catches subscriber tenants whose existing users were created
     *              before the User trigger was deployed. Idempotent.
     */
    private static void backfillUserPermissionSets() {
        try {
            DeliveryUserTriggerHandler.assignAllActiveUsers();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallHandler] PermissionSet backfill failed: '
                + e.getMessage());
        }
    }

    /**
     * @description Flips WorkItems stuck at Status=New (created before the
     *              field-level default was corrected in PR #752) to Active
     *              so they become visible to the gantt's Active filter.
     *              Wrapped in try/catch — install must not fail because of
     *              record-level data issues.
     */
    private static void backfillWorkItemStatusDefaults() {
        try {
            DeliveryWorkItemBackfillService.backfillStatusDefaults();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallHandler] WorkItem Status backfill failed: '
                + e.getMessage());
        }
    }

    /**
     * @description Kicks one reconciliation pass on install so any in-flight
     *              sync drift on the tenant gets healed without waiting for
     *              the next scheduled 6 AM run.
     */
    private static void enqueueInitialReconciliation() {
        if (Test.isRunningTest()) {
            return; // Reconciler enqueues a Queueable that fires real callouts in some scratch orgs.
        }
        try {
            DeliveryHubScheduler.reconcileNow();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallHandler] Initial reconciliation enqueue failed: '
                + e.getMessage());
        }
    }
}
