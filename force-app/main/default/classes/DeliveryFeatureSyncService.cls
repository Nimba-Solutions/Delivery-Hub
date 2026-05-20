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
@SuppressWarnings('PMD.ApexCRUDViolation')
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

        // Build a map of FeatureDefinitionTxt__c → EnabledDateTime__c value to apply.
        Map<String, DateTime> defNameToTimestamp = new Map<String, DateTime>();
        for (Feature__c f : changedFeatures) {
            if (String.isBlank(f.FeatureDefinitionTxt__c)) {
                continue;
            }
            defNameToTimestamp.put(f.FeatureDefinitionTxt__c, f.EnabledDateTime__c);
        }
        if (defNameToTimestamp.isEmpty()) {
            return;
        }

        // Resolve the settings-field-API-name mapping from the __mdt catalog.
        Map<String, String> defNameToSettingsField = new Map<String, String>();
        for (FeatureDefinition__mdt fd : [
            SELECT DeveloperName, SettingsFieldApiNameTxt__c
            FROM FeatureDefinition__mdt
            WHERE DeveloperName IN :defNameToTimestamp.keySet()
              AND SettingsFieldApiNameTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            defNameToSettingsField.put(fd.DeveloperName, fd.SettingsFieldApiNameTxt__c);
        }
        if (defNameToSettingsField.isEmpty()) {
            return;
        }

        // Validate target fields exist on DeliveryHubSettings__c — describe is
        // namespace-safe via getLocalName() comparison.
        Map<String, Schema.SObjectField> settingsFields =
            Schema.getGlobalDescribe()
                .get('DeliveryHubSettings__c')
                .getDescribe()
                .fields
                .getMap();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null) {
            settings = new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        } else if (settings.Id == null) {
            settings.SetupOwnerId = UserInfo.getOrganizationId();
        }

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

        if (!anyChanged) {
            return;
        }

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

        Map<String, FeatureDefinition__mdt> defs = new Map<String, FeatureDefinition__mdt>();
        for (FeatureDefinition__mdt fd : [
            SELECT DeveloperName, SettingsFieldApiNameTxt__c
            FROM FeatureDefinition__mdt
            WHERE SettingsFieldApiNameTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            defs.put(fd.DeveloperName, fd);
        }
        if (defs.isEmpty()) {
            return;
        }

        List<Feature__c> features = [
            SELECT Id, FeatureDefinitionTxt__c, EnabledDateTime__c, DisabledDateTime__c
            FROM Feature__c
            WHERE FeatureDefinitionTxt__c IN :defs.keySet()
            WITH SYSTEM_MODE
        ];
        if (features.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> settingsFields =
            Schema.getGlobalDescribe()
                .get('DeliveryHubSettings__c')
                .getDescribe()
                .fields
                .getMap();

        List<Feature__c> toUpdate = new List<Feature__c>();
        for (Feature__c f : features) {
            FeatureDefinition__mdt fd = defs.get(f.FeatureDefinitionTxt__c);
            if (fd == null) {
                continue;
            }
            String key = resolveFieldKey(settingsFields, fd.SettingsFieldApiNameTxt__c);
            if (key == null) {
                continue;
            }
            Object raw = settings.get(key);
            DateTime settingsValue = (raw instanceof DateTime) ? (DateTime) raw : null;

            if (settingsValue == f.EnabledDateTime__c) {
                continue; // idempotent — already in sync
            }
            f.EnabledDateTime__c = settingsValue;
            // Pair the disable side so the formula stays consistent.
            if (settingsValue == null && f.DisabledDateTime__c == null) {
                f.DisabledDateTime__c = DateTime.now();
            } else if (settingsValue != null) {
                f.DisabledDateTime__c = null;
            }
            toUpdate.add(f);
        }

        if (toUpdate.isEmpty()) {
            return;
        }

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
