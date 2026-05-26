/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for Feature__c. Delegates all logic to
 *               DeliveryFeatureTriggerHandler. Fires after insert/update so
 *               the sync layer always sees the post-DML record state.
 * @author Cloud Nimbus LLC
 */
trigger FeatureTrigger on Feature__c (after insert, after update) { //NOPMD - AvoidLogicInTrigger: trivial handler delegation only
    DeliveryFeatureTriggerHandler.handle(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
