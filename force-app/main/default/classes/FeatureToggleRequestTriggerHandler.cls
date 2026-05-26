/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Handler for FeatureToggleRequest__c triggers (PR 7 of the
 *               cockpit plan). Delegates to
 *               DeliveryFeatureApprovalService.onRequestAfterChange so the
 *               apply path automatically re-evaluates whenever a request row
 *               transitions into Pending / Granted. Kept thin so the service
 *               class owns all the decision logic and remains the single
 *               surface for PR 8's REST endpoints to call.
 * @author Cloud Nimbus LLC
 */
public with sharing class FeatureToggleRequestTriggerHandler {

    /**
     * @description Trigger entry point. Bails when the apply path is the
     *              originator of the DML (recursion guard inside the
     *              service); otherwise forwards Trigger.new + Trigger.oldMap
     *              to the service for evaluation.
     * @param op Trigger.operationType.
     * @param newRows Trigger.new.
     * @param oldMap Trigger.oldMap (null on insert).
     */
    public static void handle(
        TriggerOperation op,
        List<FeatureToggleRequest__c> newRows,
        Map<Id, FeatureToggleRequest__c> oldMap
    ) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }
        DeliveryFeatureApprovalService.onRequestAfterChange(op, newRows, oldMap);
    }
}
