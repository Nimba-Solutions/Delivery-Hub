/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger on User. Auto-assigns Delivery Hub PermissionSets per
 *               UserAutoAssignConfig__mdt rules. Delegates all logic to
 *               DeliveryUserTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryUserTrigger on User (after insert, after update) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryUserTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryUserTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
