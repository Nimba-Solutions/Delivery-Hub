/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWorkApprovalService.sendToBacklog, the
 *               approver's "not now": the request stands down like a decline
 *               and the item moves to the Backlog stage, except when the ask
 *               is a budget increase on work already approved (item stays in
 *               flight). Kept apart from DeliveryWorkApprovalServiceTest to
 *               hold that class's size steady.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkApprovalBacklogTest {

    /**
     * @description Clears the discretionary gate so every submit lands in
     *              the approver queue (no Auto short-circuit).
     * @param threshold Per-request Auto ceiling (null/0 disables Auto).
     * @param monthlyCap Monthly Auto budget (null = uncapped).
     * @param approverId Default approver User ID (null = unassigned requests).
     */
    private static void configureSettings(Decimal threshold, Decimal monthlyCap, Id approverId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.DiscretionaryThresholdHoursNumber__c = threshold;
        settings.DiscretionaryMonthlyCapHoursNumber__c = monthlyCap;
        settings.ApproverUserIdTxt__c = approverId == null ? null : String.valueOf(approverId);
        upsert settings;
    }

    /**
     * @description sendToBacklog stands the request down and moves the item
     *              to the Backlog stage (not On Hold), with the default reason.
     */
    @IsTest
    static void testSendToBacklogMovesItemToBacklog() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 30
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Id requestId = results[0].workRequestId;

        Test.startTest();
        DeliveryWorkApprovalService.sendToBacklog(requestId, null);
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, StandDownReasonTxt__c, DecisionDateTime__c
            FROM WorkRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Inactive', req.StatusPk__c, 'request stood down');
        System.assertEquals(DeliveryWorkApprovalService.BACKLOG_REASON, req.StandDownReasonTxt__c,
            'default backlog reason stored');
        System.assertNotEquals(null, req.DecisionDateTime__c, 'decision stamped');

        WorkItem__c after = [
            SELECT StageNamePk__c, ClientIntentionPk__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('Backlog', after.StageNamePk__c, 'item moved to Backlog');
        System.assertNotEquals('On Hold', after.ClientIntentionPk__c,
            'backlog is not a decline; the item is not parked On Hold');
    }

    /**
     * @description A note from the approver rides along on the reason.
     */
    @IsTest
    static void testSendToBacklogKeepsNote() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 30
        });
        Id requestId = DeliveryWorkApprovalService.submitForApproval(
            new Set<Id>{ wi.Id })[0].workRequestId;

        Test.startTest();
        DeliveryWorkApprovalService.sendToBacklog(requestId, 'revisit in Q1');
        Test.stopTest();

        WorkRequest__c req = [SELECT StandDownReasonTxt__c FROM WorkRequest__c WHERE Id = :requestId];
        System.assertEquals(DeliveryWorkApprovalService.BACKLOG_REASON + ': revisit in Q1',
            req.StandDownReasonTxt__c, 'note appended to the reason');
    }

    /**
     * @description Sending a budget INCREASE to Backlog leaves the in-flight
     *              item where it is: original cap and stage untouched.
     */
    @IsTest
    static void testSendToBacklogIncreaseLeavesItemInFlight() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 40,
            'ClientPreApprovedHoursNumber__c' => 40
        });
        String stageBefore = [SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :wi.Id].StageNamePk__c;
        Id newRequestId = DeliveryWorkApprovalService.requestIncrease(wi.Id, 10, 'delta ask');

        Test.startTest();
        DeliveryWorkApprovalService.sendToBacklog(newRequestId, null);
        Test.stopTest();

        WorkRequest__c req = [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :newRequestId];
        System.assertEquals('Inactive', req.StatusPk__c, 'the increase request stood down');

        WorkItem__c after = [
            SELECT StageNamePk__c, ClientPreApprovedHoursNumber__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(40, after.ClientPreApprovedHoursNumber__c, 'original cap untouched');
        System.assertEquals(stageBefore, after.StageNamePk__c,
            'in-flight item must NOT move to Backlog when only the delta is deferred');
    }
}
