/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for SyncItem__c. Enforces picklist allowlist integrity
 *               on StatusPk__c and ObjectTypePk__c. Those fields are backed by GVS but
 *               cannot be flipped to restricted=true due to the SF retrofit block on
 *               existing inline-defined picklist fields — so bulk data loaders could
 *               otherwise insert garbage values that break downstream sync processors.
 *               See DeliveryPicklistIntegrityService for the underlying mechanism.
 * @author       Cloud Nimbus LLC
 */
public with sharing class DeliverySyncItemTriggerHandler {

    /**
     * @description Before insert/update picklist allowlist enforcement.
     * @param records The new/updated SyncItem__c records from Trigger.new.
     */
    public static void onBeforeInsertOrUpdate(List<SyncItem__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        for (SyncItem__c rec : records) {
            DeliveryPicklistIntegrityService.validate(rec, 'StatusPk__c', 'DeliverySyncItemStatus');
            DeliveryPicklistIntegrityService.validate(rec, 'ObjectTypePk__c', 'DeliverySyncItemObjectType');
        }
    }
}
