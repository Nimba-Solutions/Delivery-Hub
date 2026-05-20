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

        List<Feature__c> toggled = new List<Feature__c>();
        for (Feature__c f : newRows) {
            Feature__c prev = (oldMap == null) ? null : oldMap.get(f.Id);
            DateTime priorEnabled = (prev == null) ? null : prev.EnabledDateTime__c;
            DateTime priorDisabled = (prev == null) ? null : prev.DisabledDateTime__c;

            Boolean enabledChanged = (priorEnabled != f.EnabledDateTime__c);
            Boolean disabledChanged = (priorDisabled != f.DisabledDateTime__c);

            if (!enabledChanged && !disabledChanged) {
                continue;
            }
            toggled.add(f);

            // Audit one row per toggle. Action is derived from the new state.
            String action = (f.EnabledDateTime__c != null
                                && f.DisabledDateTime__c == null) ? 'ENABLED' : 'DISABLED';
            DeliveryFeatureSyncService.writeAuditRow(
                f.Id, action, f.EnabledDateTime__c, priorEnabled);
        }

        if (toggled.isEmpty()) {
            return;
        }

        DeliveryFeatureSyncService.syncFeaturesToSettings(toggled);
    }
}
