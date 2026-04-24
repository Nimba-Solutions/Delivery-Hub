/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for NotificationPreference__c — enforces picklist allowlist
 *               integrity on EventTypePk__c via DeliveryPicklistIntegrityService.
 * @author       Cloud Nimbus LLC
 */
trigger DeliveryNotificationPreferenceTrigger on NotificationPreference__c (before insert, before update) { //NOPMD - AvoidLogicInTrigger: single-line delegation only
    DeliveryNotifPrefTriggerHandler.onBeforeInsertOrUpdate(Trigger.new);
}
