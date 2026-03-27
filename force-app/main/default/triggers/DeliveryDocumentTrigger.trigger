/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for DeliveryDocument__c. Delegates all logic to DeliveryDocumentTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryDocumentTrigger on DeliveryDocument__c (after insert, after update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryDocumentTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryDocumentTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryDocumentTriggerHandler.onBeforeDelete(Trigger.old);
    }
}
