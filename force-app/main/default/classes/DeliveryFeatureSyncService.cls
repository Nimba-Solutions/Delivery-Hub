/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  PR 2 — Bidirectional sync layer between per-tenant Feature__c
 *               runtime rows and the legacy DeliveryHubSettings__c
 *               Enable*DateTime__c fields. The DH ecosystem already reads
 *               those legacy settings fields from dozens of places
 *               (controllers, services, install handler) — switching them
 *               over to read Feature__c.EnabledDateTime__c directly is a
 *               PR 3+ concern. For now we mirror state on every toggle so
 *               legacy callers see the new value within the same
 *               transaction.
 *
 *               Three entry points:
 *                 - syncFeaturesToSettings(...)  — trigger-driven, runs
 *                   when a Feature__c is toggled in the cockpit.
 *                 - syncSettingsToFeatures()     — install-handler-driven,
 *                   one-shot reconciliation that copies the legacy field
 *                   value back to Feature__c on package install/upgrade.
 *                 - writeAuditRow(...)           — emits one ActivityLog__c
 *                   per toggle (action=Feature_Toggle, RecordIdTxt__c =
 *                   Feature__c.Id, ContextDataTxt__c carries enable/
 *                   previous/user JSON).
 *
 *               Recursion guard `inSyncContext` prevents the
 *               settings-update side effect from re-entering the trigger
 *               handler if a future caller ever wires the inverse flow
 *               (settings → feature) on the same transaction.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
public with sharing class DeliveryFeatureSyncService {

    /** Static recursion guard. Public-test-visible so tests can assert. */
    @TestVisible
    private static Boolean inSyncContext = false;

    /**
     * @description Returns the current sync-context flag. Trigger handlers
     *              read this to bail out when the sync service is the
     *              originator of an update.
     * @return True when the sync service is currently executing a
     *         settings-mirror write.
     */
    public static Boolean isInSyncContext() {
        return inSyncContext;
    }

    /**
     * @description For each changed Feature__c with a mapped settings
     *              field on its FeatureDefinition__mdt, writes the
     *              Feature's EnabledDateTime__c onto the matching
     *              DeliveryHubSettings__c.Enable*DateTime__c field. One
     *              settings row per org (custom-setting semantics) — fetch
     *              via getInstance(), apply all field updates, upsert
     *              once. Bulk-safe: O(1) DML regardless of input size.
     * @param changedFeatures Feature__c rows whose toggle state has just
     *                        flipped (trigger-supplied subset).
     */
    public static void syncFeaturesToSettings(List<Feature__c> changedFeatures) {
        if (changedFeatures == null || changedFeatures.isEmpty()) {
            return;
        }
        Map<String, DateTime> defNameToTimestamp = buildDefNameToTimestamp(changedFeatures);
        if (defNameToTimestamp.isEmpty()) {
            return;
        }
        Map<String, String> defNameToSettingsField =
            buildDefNameToSettingsField(defNameToTimestamp.keySet());
        if (defNameToSettingsField.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectField> settingsFields = describeSettingsFields();
        DeliveryHubSettings__c settings = loadOrInitSettings();
        Boolean anyChanged = applyTimestampsToSettings(
            settings, settingsFields, defNameToSettingsField, defNameToTimestamp);
        if (!anyChanged) {
            return;
        }
        commitSettingsInSyncContext(settings);
    }

    /**
     * @description Builds the FeatureDefinitionTxt__c → EnabledDateTime__c
     *              map from the changed-features input, skipping rows with
     *              a blank definition name.
     * @param changedFeatures Trigger-supplied subset.
     * @return Map from def-name to the post-toggle timestamp (may be null).
     */
    private static Map<String, DateTime> buildDefNameToTimestamp(
        List<Feature__c> changedFeatures
    ) {
        Map<String, DateTime> out = new Map<String, DateTime>();
        for (Feature__c f : changedFeatures) {
            if (String.isBlank(f.FeatureDefinitionTxt__c)) {
                continue;
            }
            out.put(f.FeatureDefinitionTxt__c, f.EnabledDateTime__c);
        }
        return out;
    }

    /**
     * @description Looks up the SettingsFieldApiNameTxt__c mapping for each
     *              FeatureDefinition__mdt DeveloperName in the set.
     * @param defNames DeveloperNames to resolve.
     * @return Map from DeveloperName to the legacy settings field API name.
     */
    private static Map<String, String> buildDefNameToSettingsField(Set<String> defNames) {
        Map<String, String> out = new Map<String, String>();
        for (FeatureDefinition__mdt fd : [
            SELECT DeveloperName, SettingsFieldApiNameTxt__c
            FROM FeatureDefinition__mdt
            WHERE DeveloperName IN :defNames
              AND SettingsFieldApiNameTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            out.put(fd.DeveloperName, fd.SettingsFieldApiNameTxt__c);
        }
        return out;
    }

    /**
     * @description Returns the field map for DeliveryHubSettings__c.
     *              Namespace-safe via callers using getLocalName().
     * @return Field map keyed by lowercased API name.
     */
    private static Map<String, Schema.SObjectField> describeSettingsFields() {
        return Schema.getGlobalDescribe()
            .get('DeliveryHubSettings__c')
            .getDescribe()
            .fields
            .getMap();
    }

    /**
     * @description Returns the org-default DeliveryHubSettings__c, freshly
     *              initialized if none exists yet, with SetupOwnerId set.
     * @return A row ready to receive field updates and be upserted.
     */
    private static DeliveryHubSettings__c loadOrInitSettings() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null) {
            return new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId());
        }
        if (settings.Id == null) {
            settings.SetupOwnerId = UserInfo.getOrganizationId();
        }
        return settings;
    }

    /**
     * @description Applies the per-def timestamp values onto the matching
     *              settings fields. Logs and skips fields not present on
     *              the describe.
     * @param settings              Target settings row.
     * @param settingsFields        Describe map for DeliveryHubSettings__c.
     * @param defNameToSettingsField Map from def name to the legacy field.
     * @param defNameToTimestamp    Map from def name to the new value.
     * @return True if any field on `settings` was actually changed.
     */
    private static Boolean applyTimestampsToSettings(
        DeliveryHubSettings__c settings,
        Map<String, Schema.SObjectField> settingsFields,
        Map<String, String> defNameToSettingsField,
        Map<String, DateTime> defNameToTimestamp
    ) {
        Boolean anyChanged = false;
        for (String defName : defNameToSettingsField.keySet()) {
            String rawApiName = defNameToSettingsField.get(defName);
            String matchedKey = resolveFieldKey(settingsFields, rawApiName);
            if (matchedKey == null) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryFeatureSyncService] Settings field not found on DeliveryHubSettings__c: '
                    + rawApiName + ' (FeatureDefinition=' + defName + ')');
                continue;
            }
            settings.put(matchedKey, defNameToTimestamp.get(defName));
            anyChanged = true;
        }
        return anyChanged;
    }

    /**
     * @description Upserts the settings row inside the recursion guard so
     *              any downstream sync trigger short-circuits.
     * @param settings The row to upsert.
     */
    private static void commitSettingsInSyncContext(DeliveryHubSettings__c settings) {
        inSyncContext = true;
        try {
            upsert settings;
        } finally {
            inSyncContext = false;
        }
    }

    /**
     * @description Install-handler-driven one-shot reconciliation. For every
     *              Feature__c that maps to a populated legacy settings
     *              field, copies the settings value into
     *              Feature__c.EnabledDateTime__c. Idempotent — only updates
     *              rows whose Feature.EnabledDateTime__c differs from the
     *              settings value. No-ops gracefully if Feature__c is
     *              empty (fresh install before seed) or settings record
     *              missing.
     */
    public static void syncSettingsToFeatures() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            return;
        }
        Map<String, FeatureDefinition__mdt> defs = loadDefinitionsWithSettingsMapping();
        if (defs.isEmpty()) {
            return;
        }
        List<Feature__c> features = loadFeaturesByDefName(defs.keySet());
        if (features.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectField> settingsFields = describeSettingsFields();
        List<Feature__c> toUpdate =
            buildFeatureUpdatesFromSettings(features, defs, settings, settingsFields);
        if (toUpdate.isEmpty()) {
            return;
        }
        commitFeatureUpdatesInSyncContext(toUpdate);
    }

    /**
     * @description Loads every FeatureDefinition__mdt that maps to a
     *              legacy settings field.
     * @return Map keyed by DeveloperName.
     */
    private static Map<String, FeatureDefinition__mdt> loadDefinitionsWithSettingsMapping() {
        Map<String, FeatureDefinition__mdt> out = new Map<String, FeatureDefinition__mdt>();
        for (FeatureDefinition__mdt fd : [
            SELECT DeveloperName, SettingsFieldApiNameTxt__c
            FROM FeatureDefinition__mdt
            WHERE SettingsFieldApiNameTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            out.put(fd.DeveloperName, fd);
        }
        return out;
    }

    /**
     * @description Bulk-loads Feature__c rows whose FeatureDefinitionTxt__c
     *              is in the supplied set.
     * @param defNames Definition names to filter by.
     * @return Matching Feature__c rows.
     */
    private static List<Feature__c> loadFeaturesByDefName(Set<String> defNames) {
        return [
            SELECT Id, FeatureDefinitionTxt__c, EnabledDateTime__c, DisabledDateTime__c
            FROM Feature__c
            WHERE FeatureDefinitionTxt__c IN :defNames
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description For each loaded Feature__c, computes whether the matching
     *              legacy settings field disagrees and returns the subset
     *              that needs updating (with the corrected timestamps
     *              applied in-memory).
     * @param features        Feature__c rows to evaluate.
     * @param defs            Definition map by DeveloperName.
     * @param settings        Org-default settings row.
     * @param settingsFields  Settings describe field map.
     * @return Features whose state needs persisting.
     */
    private static List<Feature__c> buildFeatureUpdatesFromSettings(
        List<Feature__c> features,
        Map<String, FeatureDefinition__mdt> defs,
        DeliveryHubSettings__c settings,
        Map<String, Schema.SObjectField> settingsFields
    ) {
        List<Feature__c> toUpdate = new List<Feature__c>();
        for (Feature__c f : features) {
            if (applySettingsValueToFeature(f, defs, settings, settingsFields)) {
                toUpdate.add(f);
            }
        }
        return toUpdate;
    }

    /**
     * @description Mutates one Feature__c so its DateTime fields agree with
     *              the legacy settings field. Returns true when an actual
     *              change was made.
     * @param f               Feature row to inspect/mutate.
     * @param defs            Definition map.
     * @param settings        Org-default settings row.
     * @param settingsFields  Settings describe field map.
     * @return True when the feature row was updated in-memory.
     */
    private static Boolean applySettingsValueToFeature(
        Feature__c f,
        Map<String, FeatureDefinition__mdt> defs,
        DeliveryHubSettings__c settings,
        Map<String, Schema.SObjectField> settingsFields
    ) {
        FeatureDefinition__mdt fd = defs.get(f.FeatureDefinitionTxt__c);
        if (fd == null) {
            return false;
        }
        String key = resolveFieldKey(settingsFields, fd.SettingsFieldApiNameTxt__c);
        if (key == null) {
            return false;
        }
        Object raw = settings.get(key);
        DateTime settingsValue = (raw instanceof DateTime) ? (DateTime) raw : null;
        if (settingsValue == f.EnabledDateTime__c) {
            return false;
        }
        f.EnabledDateTime__c = settingsValue;
        if (settingsValue == null && f.DisabledDateTime__c == null) {
            f.DisabledDateTime__c = DateTime.now();
        } else if (settingsValue != null) {
            f.DisabledDateTime__c = null;
        }
        return true;
    }

    /**
     * @description Persists feature updates inside the recursion guard.
     * @param toUpdate Features to update.
     */
    private static void commitFeatureUpdatesInSyncContext(List<Feature__c> toUpdate) {
        inSyncContext = true;
        try {
            update toUpdate;
        } finally {
            inSyncContext = false;
        }
    }

    /**
     * @description Emits one ActivityLog__c per toggle. Hash chain + insert
     *              order are handled by the existing
     *              DeliveryActivityLogTrigger →
     *              DeliveryAuditChainService.setHashOnInsert path, so this
     *              method only needs to populate the visible fields.
     *              RecordIdTxt__c carries the Feature__c.Id (the
     *              ActivityLog object is intentionally generic — see plan).
     * @param featureId        Feature__c whose toggle state changed.
     * @param action           Either 'ENABLED' or 'DISABLED'.
     * @param newEnabled       The post-toggle EnabledDateTime__c value.
     * @param previousEnabled  The pre-toggle EnabledDateTime__c value.
     */
    public static void writeAuditRow(
        Id featureId,
        String action,
        DateTime newEnabled,
        DateTime previousEnabled
    ) {
        Map<String, Object> ctx = new Map<String, Object>{
            'action' => action,
            'newEnabled' => newEnabled,
            'previousEnabled' => previousEnabled,
            'userId' => UserInfo.getUserId()
        };
        ActivityLog__c row = new ActivityLog__c(
            ActionTypePk__c = 'Feature_Toggle',
            RecordIdTxt__c = (featureId == null) ? null : String.valueOf(featureId),
            ContextDataTxt__c = JSON.serialize(ctx),
            UserIdTxt__c = UserInfo.getUserId(),
            ComponentNameTxt__c = 'DeliveryFeatureCockpit'
        );
        try {
            insert row;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureSyncService.writeAuditRow] insert failed: ' + e.getMessage());
        }
    }

    /**
     * @description Resolves a bare or namespace-prefixed settings-field API
     *              name to the actual key present on the describe map.
     *              Uses getLocalName() so subscriber-namespace prefixes
     *              (delivery__EnableInvoiceGenerationDateTime__c on
     *              prod, EnableInvoiceGenerationDateTime__c in dev)
     *              both resolve.
     * @param settingsFields  Map from
     *                        DeliveryHubSettings__c.getDescribe().fields.getMap().
     * @param rawApiName      The mdt-declared field name (typically bare).
     * @return The matching key in settingsFields, or null when no field
     *         matches by local-name.
     */
    private static String resolveFieldKey(
        Map<String, Schema.SObjectField> settingsFields,
        String rawApiName
    ) {
        if (String.isBlank(rawApiName) || settingsFields == null) {
            return null;
        }
        String target = rawApiName.toLowerCase();
        // Local name compares are namespace-safe — getLocalName() strips the
        // package prefix on subscriber installs. The mdt typically encodes
        // the bare form so the local-name compare hits first; we also accept
        // the exact key as a fallback (covers an mdt that accidentally
        // stored the prefixed form).
        for (String key : settingsFields.keySet()) {
            Schema.DescribeFieldResult dfr = settingsFields.get(key).getDescribe();
            String local = dfr.getLocalName().toLowerCase();
            if (local == target) {
                return key;
            }
            if (key == target) {
                return key;
            }
        }
        return null;
    }
}
