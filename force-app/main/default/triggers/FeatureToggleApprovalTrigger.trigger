/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger on FeatureToggleApproval__c. Delegates all logic to
 *               FToggleApprovalTriggerHandler. Before-insert so the handler
 *               can stamp ApproverUserLookup__c from ApprovalRouting__mdt
 *               BEFORE the row is persisted (no extra DML, no race with
 *               downstream code that reads ApproverUserLookup__c on insert).
 *               Closes Flow 4 #2 (auto-assignment gap) from
 *               docs/audits/e2e-walkthrough-2026-05-21.md.
 * @author Cloud Nimbus LLC
 */
trigger FeatureToggleApprovalTrigger on FeatureToggleApproval__c (before insert) { //NOPMD - AvoidLogicInTrigger: trivial handler delegation only
    new FToggleApprovalTriggerHandler().onBeforeInsert(Trigger.new);
}
