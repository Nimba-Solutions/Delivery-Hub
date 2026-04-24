/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for SyncItem__c — enforces picklist allowlist integrity on
 *               StatusPk__c and ObjectTypePk__c via DeliveryPicklistIntegrityService.
 * @author       Cloud Nimbus LLC
 */
trigger DeliverySyncItemTrigger on SyncItem__c (before insert, before update) { //NOPMD - AvoidLogicInTrigger: single-line delegation only
    DeliverySyncItemTriggerHandler.onBeforeInsertOrUpdate(Trigger.new);
}
