/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for NotificationPreference__c. Enforces picklist
 *               allowlist integrity on EventTypePk__c. That field is backed by GVS
 *               but cannot be flipped to restricted=true due to the SF retrofit
 *               block, so bulk data loaders could otherwise insert garbage values.
 *               See DeliveryPicklistIntegrityService.
 * @author       Cloud Nimbus LLC
 */
public with sharing class DeliveryNotificationPreferenceTriggerHandler {

    /**
     * @description Before insert/update picklist allowlist enforcement.
     * @param records The new/updated NotificationPreference__c records from Trigger.new.
     */
    public static void onBeforeInsertOrUpdate(List<NotificationPreference__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        for (NotificationPreference__c rec : records) {
            DeliveryPicklistIntegrityService.validate(rec, 'EventTypePk__c', 'DeliveryNotificationEventType');
        }
    }
}
