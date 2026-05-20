/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for FeatureToggleRequest__c. Delegates all logic to
 *               FeatureToggleRequestTriggerHandler. After-insert / after-update
 *               so the handler always sees the post-DML row state and can
 *               re-evaluate applyIfFullyGranted safely.
 * @author Cloud Nimbus LLC
 */
trigger FeatureToggleRequestTrigger on FeatureToggleRequest__c (after insert, after update) { //NOPMD - AvoidLogicInTrigger: trivial handler delegation only
    FeatureToggleRequestTriggerHandler.handle(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
