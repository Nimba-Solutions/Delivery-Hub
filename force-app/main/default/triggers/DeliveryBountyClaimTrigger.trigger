/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for BountyClaim__c — routes sync items to origin orgs
 *               when claims are created or updated.
 * @author       Cloud Nimbus LLC
 */
trigger DeliveryBountyClaimTrigger on BountyClaim__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryBountyClaimTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryBountyClaimTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
