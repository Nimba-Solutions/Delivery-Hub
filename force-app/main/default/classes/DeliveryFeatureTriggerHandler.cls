/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Handler for Feature__c triggers (PR 2 of the cockpit plan).
 *               On after-insert / after-update, filters for rows whose
 *               EnabledDateTime__c OR DisabledDateTime__c just changed,
 *               then:
 *                 1. Mirrors the new state onto the legacy
 *                    DeliveryHubSettings__c.Enable*DateTime__c field via
 *                    DeliveryFeatureSyncService.syncFeaturesToSettings()
 *                 2. Emits one ActivityLog__c audit row per toggle.
 *
 *               Recursion guard: bails immediately when
 *               DeliveryFeatureSyncService.isInSyncContext() returns true
 *               (so any future inverse sync settings → Feature__c won't
 *               trigger a feedback loop).
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryFeatureTriggerHandler {

    /**
     * @description Trigger entry point. Filters to genuinely-toggled rows
     *              and delegates to the sync service.
     * @param op       Trigger.operationType.
     * @param newRows  Trigger.new.
     * @param oldMap   Trigger.oldMap (null on insert).
     */
    public static void handle(
        TriggerOperation op,
        List<Feature__c> newRows,
        Map<Id, Feature__c> oldMap
    ) {
        if (DeliveryFeatureSyncService.isInSyncContext()) {
            return;
        }
        if (newRows == null || newRows.isEmpty()) {
            return;
        }
        List<Feature__c> toggled = collectToggledAndEmitAudit(newRows, oldMap);
        if (toggled.isEmpty()) {
            return;
        }
        DeliveryFeatureSyncService.syncFeaturesToSettings(toggled);
    }

    /**
     * @description Walks the new-rows list, filters to rows that actually
     *              flipped (Enabled or Disabled DateTime changed) and emits
     *              an audit row per change. Returns the filtered list for
     *              the caller to forward to the sync service.
     * @param newRows Trigger.new.
     * @param oldMap  Trigger.oldMap (null on insert).
     * @return Rows that actually toggled.
     */
    private static List<Feature__c> collectToggledAndEmitAudit(
        List<Feature__c> newRows,
        Map<Id, Feature__c> oldMap
    ) {
        List<Feature__c> toggled = new List<Feature__c>();
        for (Feature__c f : newRows) {
            Feature__c prev = (oldMap == null) ? null : oldMap.get(f.Id);
            if (!didToggle(f, prev)) {
                continue;
            }
            toggled.add(f);
            emitAuditFor(f, prev);
        }
        return toggled;
    }

    /**
     * @description Whether either DateTime stamp on the feature changed
     *              between the prior and current row state.
     * @param f    Current row.
     * @param prev Prior row (null on insert).
     * @return True when EnabledDateTime__c or DisabledDateTime__c differs.
     */
    private static Boolean didToggle(Feature__c f, Feature__c prev) {
        DateTime priorEnabled = (prev == null) ? null : prev.EnabledDateTime__c;
        DateTime priorDisabled = (prev == null) ? null : prev.DisabledDateTime__c;
        return priorEnabled != f.EnabledDateTime__c
            || priorDisabled != f.DisabledDateTime__c;
    }

    /**
     * @description Emits one ActivityLog__c audit row per toggle via the
     *              sync service. Action is derived from the post-toggle
     *              state (enabled when EnabledDateTime is populated AND
     *              Disabled is null; otherwise disabled).
     * @param f    Current (post-toggle) row.
     * @param prev Prior row (null on insert).
     */
    private static void emitAuditFor(Feature__c f, Feature__c prev) {
        DateTime priorEnabled = (prev == null) ? null : prev.EnabledDateTime__c;
        Boolean nowEnabled = (f.EnabledDateTime__c != null && f.DisabledDateTime__c == null);
        String action = nowEnabled ? 'ENABLED' : 'DISABLED';
        DeliveryFeatureSyncService.writeAuditRow(
            f.Id, action, f.EnabledDateTime__c, priorEnabled);
    }
}
