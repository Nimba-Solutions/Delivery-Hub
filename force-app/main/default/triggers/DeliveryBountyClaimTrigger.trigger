/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for BountyClaim__c — routes sync items to origin orgs
 *               when claims are created or updated.
 * @author       Cloud Nimbus LLC
 */
trigger DeliveryBountyClaimTrigger on BountyClaim__c (after insert, after update) {
    DeliveryBountyClaimTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}
