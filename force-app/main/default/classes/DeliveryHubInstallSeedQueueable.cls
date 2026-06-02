/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Deferred-seed Queueable for DeliveryHubInstallHandler.
 *
 *              WHY THIS EXISTS: the Feature__c + DatasetTemplate__c seed logic
 *              used to run inline inside InstallHandler.onInstall. It silently
 *              failed on real subscriber installs (verified empirically on
 *              dh-prod + nimba after release/0.252.0.3 — both orgs ended with
 *              0 Feature__c and 0 DatasetTemplate__c rows, yet the same
 *              onInstall successfully scheduled all four sync cron jobs that
 *              run AFTER the seeds). Root cause is almost certainly a
 *              same-transaction interaction with FeatureTrigger /
 *              DeliveryFeatureTriggerHandler, which mirrors Feature__c rows
 *              onto DeliveryHubSettings__c on after-insert — the install
 *              transaction's state at that moment apparently doesn't tolerate
 *              that re-entry, and the inline try/catch swallowed the throw.
 *
 *              The fix: relocate the two seed bodies verbatim into this
 *              Queueable. The InstallHandler enqueues it via
 *              System.enqueueJob, which causes the work to run in a fresh
 *              transaction AFTER postInstall commits — sidestepping the
 *              interaction. Verified locally: running the same seed logic as
 *              anonymous Apex outside the install transaction inserts 6
 *              Feature__c + 1 DatasetTemplate__c cleanly. Idempotent.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryHubInstallSeedQueueable implements System.Queueable {

    /**
     * @description Queueable entry point. Runs the two seed bodies in
     *              independent try/catch blocks so a failure in one does not
     *              block the other.
     * @param context Queueable context (unused).
     */
    public void execute(QueueableContext context) {
        try {
            seedFeatures();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallSeedQueueable] Feature catalog seed failed: '
                + e.getMessage());
        }
        try {
            seedDatasetTemplates();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryHubInstallSeedQueueable] Dataset template seed failed: '
                + e.getMessage());
        }
        // Intentionally swallowed: a missing-OWEA or settings issue must never break
        // install/upgrade. No System.debug here (AvoidDebugStatements is strictly
        // enforced); the only consequence of failure is the admin sets the From
        // address manually, which is the documented fallback. // NOPMD suppresses
        // EmptyCatchBlock on the catch below.
        try {
            seedDocumentFromOwea();
        } catch (Exception e) { // NOPMD — see note above; deliberately empty
        }
    }

    /**
     * @description Seeds one Feature__c per FeatureDefinition__mdt that does not
     *              already have a matching runtime row. Idempotent: re-running
     *              never duplicates existing seeded rows. Defaults the per-tenant
     *              EnabledDateTime__c to the catalog's DefaultEnabledDateTime__c
     *              (currently null for every shipped record — admins activate
     *              features explicitly via the cockpit).
     *
     *              Logic relocated verbatim from
     *              DeliveryHubInstallHandler.seedFeaturesFromDefinitions (pre-fix).
     */
    @TestVisible
    private static void seedFeatures() {
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName, DefaultEnabledDateTime__c
            FROM FeatureDefinition__mdt
            WITH SYSTEM_MODE
        ];
        if (defs.isEmpty()) {
            return;
        }
        Set<String> existingDefNames = new Set<String>();
        for (Feature__c existing : [
            SELECT FeatureDefinitionTxt__c FROM Feature__c
            WHERE FeatureDefinitionTxt__c != null
            WITH SYSTEM_MODE
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
    }

    /**
     * @description Seeds the in-app sample-data DatasetTemplate__c rows that
     *              the cockpit's "Load sample data" / "Remove sample data"
     *              buttons (DeliveryDatasetLoader) drive. Currently ships ONE
     *              template — Invoice Generation — linked to its Feature__c via
     *              FeatureLookup__c so the deliveryDatasetTemplates LWC exposes
     *              the load/remove actions on the feature record page.
     *
     *              Idempotent: keyed by the template Name, so a re-install /
     *              upgrade never duplicates the seeded row.
     *
     *              Adding more datasets later: add a row to templateSeeds and a
     *              matching branch in DeliveryDatasetLoader.resolveDatasetKey.
     *
     *              Logic relocated verbatim from
     *              DeliveryHubInstallHandler.seedDatasetTemplates (pre-fix).
     */
    @TestVisible
    private static void seedDatasetTemplates() {
        // Map of template Name → linked FeatureDefinition DeveloperName.
        Map<String, String> templateSeeds = new Map<String, String>{
            'Invoice Generation Sample Data' => 'Invoice_Generation'
        };

        // Which seed names already exist (idempotency key = Name).
        Set<String> existingNames = new Set<String>();
        for (DatasetTemplate__c existing : [
            SELECT Name FROM DatasetTemplate__c
            WHERE Name IN :templateSeeds.keySet()
            WITH SYSTEM_MODE
        ]) {
            existingNames.add(existing.Name);
        }

        // Resolve the runtime Feature__c rows for the seeds we still need.
        Map<String, Id> featureIdByDefName = new Map<String, Id>();
        for (Feature__c f : [
            SELECT Id, FeatureDefinitionTxt__c FROM Feature__c
            WHERE FeatureDefinitionTxt__c IN :templateSeeds.values()
            WITH SYSTEM_MODE
        ]) {
            featureIdByDefName.put(f.FeatureDefinitionTxt__c, f.Id);
        }

        List<DatasetTemplate__c> toInsert = new List<DatasetTemplate__c>();
        for (String templateName : templateSeeds.keySet()) {
            if (existingNames.contains(templateName)) {
                continue;
            }
            String defName = templateSeeds.get(templateName);
            toInsert.add(new DatasetTemplate__c(
                Name = templateName,
                FeatureLookup__c = featureIdByDefName.get(defName),
                DescriptionTxt__c = 'Loads clearly-marked sample data so you can '
                    + 'see this feature in action. Records are tagged "[DH SAMPLE]" '
                    + 'and can be removed in one click.',
                ApexScriptPathTxt__c = 'scripts/feature-data/invoice_generation.apex',
                RecordCountEstimateNumber__c = 17
            ));
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    /**
     * @description Pre-populates DeliveryHubSettings__c.DocumentFromOrgWideEmailTxt__c
     *              with a sensible default verified Org-Wide Email Address when the
     *              admin has not yet chosen one. This lets outbound document emails
     *              (invoices) send from a stable, verified sender out of the box rather
     *              than the running user.
     *
     *              Selection: prefer an OWEA usable by all profiles
     *              (IsAllowAllProfiles = true); otherwise the most recently created one.
     *
     *              ONLY populates when the setting is blank — never overwrites an
     *              admin's explicit choice. Runs on install AND upgrade (idempotent:
     *              the blank guard makes re-runs a no-op once set). The caller wraps
     *              this in try/catch so a missing-OWEA never breaks install.
     */
    @TestVisible
    private static void seedDocumentFromOwea() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        // Never overwrite an admin's explicit choice.
        if (settings != null && String.isNotBlank(settings.DocumentFromOrgWideEmailTxt__c)) {
            return;
        }

        List<OrgWideEmailAddress> oweas = [
            SELECT Address, IsAllowAllProfiles
            FROM OrgWideEmailAddress
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
        ];
        if (oweas.isEmpty()) {
            // No verified Org-Wide Email Address exists yet — nothing to seed.
            return;
        }

        // Prefer one usable by all profiles; else fall back to the most recently
        // created (the list is already ordered newest-first).
        OrgWideEmailAddress chosen = oweas[0];
        for (OrgWideEmailAddress owea : oweas) {
            if (owea.IsAllowAllProfiles == true) {
                chosen = owea;
                break;
            }
        }
        if (String.isBlank(chosen.Address)) {
            return;
        }

        if (settings == null) {
            settings = new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        settings.DocumentFromOrgWideEmailTxt__c = chosen.Address;
        upsert settings;
    }
}
