/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for SyncItem__c. Picklist-allowlist enforcement was
 *               deprecated 2026-04-26 because the GVS seed data wasn't reliably
 *               present across orgs; handler is intentionally a no-op. Trigger
 *               declaration kept stable as the future callback target.
 * @author       Cloud Nimbus LLC
 */
trigger DeliverySyncItemTrigger on SyncItem__c (before insert, before update) { //NOPMD - AvoidLogicInTrigger: single-line delegation only
    DeliverySyncItemTriggerHandler.onBeforeInsertOrUpdate(Trigger.new);
}
