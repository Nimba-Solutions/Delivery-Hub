/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the PR 7 single-step approval framework:
 *               submit / grant / reject / apply / rollback / audit.
 *
 *               Each test starts with a Feature__c seeded via TestDataFactory.
 *               The default Feature__c has EnabledDateTime__c=now() so we
 *               explicitly toggle starting state per scenario.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFeatureApprovalServiceTest {

    /**
     * @description Submit creates a Pending request + ONE Pending approval row.
     */
    @IsTest
    static void testSubmitCreatesRequestAndApproval() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });

        Test.startTest();
        Id requestId = DeliveryFeatureApprovalService.submit(
            feat.Id, 'Enable', 'Need this on for client demo');
        Test.stopTest();

        System.assertNotEquals(null, requestId, 'submit should return a request id');
        FeatureToggleRequest__c req = [
            SELECT Id, StatusPk__c, ActionPk__c, FeatureLookup__c,
                   CascadeSnapshotJsonTxt__c, RequestedByUserLookup__c
            FROM FeatureToggleRequest__c
            WHERE Id = :requestId
        ];
        System.assertEquals('Pending', req.StatusPk__c, 'request should be Pending');
        System.assertEquals('Enable', req.ActionPk__c, 'action propagates');
        System.assertEquals(feat.Id, req.FeatureLookup__c, 'feature linked');
        System.assertEquals(UserInfo.getUserId(), req.RequestedByUserLookup__c,
            'requester stamped');

        Integer approvalCount = [
            SELECT COUNT() FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId
        ];
        System.assertEquals(1, approvalCount,
            'single-step: exactly one approval row');
    }

    /**
     * @description Grant on the last (only) approval flips the request to
     *              Applied and toggles the underlying Feature__c.
     */
    @IsTest
    static void testGrantAppliesWhenLastApprovalGranted() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];

        Test.startTest();
        DeliveryFeatureApprovalService.grant(approval.Id, 'looks good');
        Test.stopTest();

        FeatureToggleRequest__c req = [
            SELECT StatusPk__c, AppliedDateTime__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Applied', req.StatusPk__c, 'request should be Applied');
        System.assertNotEquals(null, req.AppliedDateTime__c, 'AppliedDateTime stamped');

        Feature__c after = [
            SELECT EnabledDateTime__c, DisabledDateTime__c, LastToggledByUserLookup__c
            FROM Feature__c WHERE Id = :feat.Id
        ];
        System.assertNotEquals(null, after.EnabledDateTime__c,
            'feature should now have EnabledDateTime');
        System.assertEquals(null, after.DisabledDateTime__c,
            'Disable stamp cleared on enable');
    }

    /**
     * @description Single-step shape: when there is more than one approval row
     *              on a request and only one is granted, apply does NOT fire.
     *              PR 7 always inserts one row; this test stubs the multi-row
     *              shape PR 8 will introduce to lock the gating contract.
     */
    @IsTest
    static void testGrantPendingWhenOtherApprovalsPending() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        // Inject a second pending approval row directly (PR 8 shape stub).
        TestDataFactory.newFeatureToggleApproval(requestId, feat.Id);

        FeatureToggleApproval__c first = [
            SELECT Id FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId
            ORDER BY CreatedDate ASC LIMIT 1
        ];

        Test.startTest();
        DeliveryFeatureApprovalService.grant(first.Id, null);
        Test.stopTest();

        FeatureToggleRequest__c req = [
            SELECT StatusPk__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Pending', req.StatusPk__c,
            'one row granted while another still pending should NOT apply');
    }

    /**
     * @description Reject on any single approval propagates Status=Rejected
     *              to the parent request and does NOT apply.
     */
    @IsTest
    static void testRejectFailsTheRequest() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];

        Test.startTest();
        DeliveryFeatureApprovalService.reject(approval.Id, 'risky');
        Test.stopTest();

        FeatureToggleRequest__c req = [
            SELECT StatusPk__c, AppliedDateTime__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Rejected', req.StatusPk__c,
            'request should be Rejected after a reject');
        System.assertEquals(null, req.AppliedDateTime__c,
            'AppliedDateTime should remain null');

        Feature__c after = [
            SELECT EnabledDateTime__c, DisabledDateTime__c FROM Feature__c WHERE Id = :feat.Id
        ];
        System.assertEquals(null, after.EnabledDateTime__c,
            'feature should NOT have been enabled');
    }

    /**
     * @description Apply path on Disable flips DisabledDateTime__c, leaving
     *              EnabledDateTime__c null (or unchanged).
     */
    @IsTest
    static void testApplyFlipsFeatureDateTime() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => Datetime.now().addDays(-1),
            'DisabledDateTime__c' => null
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Disable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];

        Test.startTest();
        DeliveryFeatureApprovalService.grant(approval.Id, null);
        Test.stopTest();

        Feature__c after = [
            SELECT EnabledDateTime__c, DisabledDateTime__c FROM Feature__c WHERE Id = :feat.Id
        ];
        System.assertNotEquals(null, after.DisabledDateTime__c,
            'feature should now have DisabledDateTime');
    }

    /**
     * @description Rollback on an Applied request reverses the flip. After
     *              an Enable+Apply, rollback should leave the feature disabled
     *              (DisabledDateTime populated, EnabledDateTime cleared).
     */
    @IsTest
    static void testRollbackReversesFeatureState() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];
        DeliveryFeatureApprovalService.grant(approval.Id, null);

        Test.startTest();
        DeliveryFeatureApprovalService.rollback(requestId, 'undo it');
        Test.stopTest();

        FeatureToggleRequest__c req = [
            SELECT StatusPk__c, AppliedDateTime__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('RolledBack', req.StatusPk__c, 'status should be RolledBack');
        System.assertEquals(null, req.AppliedDateTime__c, 'AppliedDateTime cleared');

        Feature__c after = [
            SELECT EnabledDateTime__c, DisabledDateTime__c FROM Feature__c WHERE Id = :feat.Id
        ];
        System.assertNotEquals(null, after.DisabledDateTime__c,
            'feature should be disabled after rollback');
    }

    /**
     * @description Each Apply emits an ActivityLog__c with
     *              ActionTypePk__c='Feature_Toggle' and RecordIdTxt__c set
     *              to the feature id.
     */
    @IsTest
    static void testAuditRowWrittenPerApply() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];

        Test.startTest();
        DeliveryFeatureApprovalService.grant(approval.Id, null);
        Test.stopTest();

        String featureIdStr = String.valueOf(feat.Id);
        Integer auditCount = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :featureIdStr
        ];
        System.assert(auditCount >= 1,
            'at least one ActivityLog row should reference the feature toggle');
    }

    /**
     * @description Inbox returns rows assigned to the running user.
     */
    @IsTest
    static void testGetInboxReturnsAssignedRows() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', 'demo');
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];
        approval.ApproverUserLookup__c = UserInfo.getUserId();
        update approval;

        Test.startTest();
        List<DeliveryFeatureApprovalService.ApprovalInboxDTO> inbox =
            DeliveryFeatureApprovalService.getInbox();
        Test.stopTest();

        System.assertEquals(1, inbox.size(), 'should return the one assigned row');
        DeliveryFeatureApprovalService.ApprovalInboxDTO row = inbox.get(0);
        System.assertEquals(approval.Id, row.approvalId, 'approval id propagates');
        System.assertEquals(feat.Id, row.featureId, 'feature id propagates');
        System.assertEquals('Enable', row.action, 'action propagates');
    }

    /**
     * @description Submit rejects bad input.
     */
    @IsTest
    static void testSubmitValidatesInputs() {
        Feature__c feat = TestDataFactory.createFeature(null);
        Boolean threw = false;
        try {
            DeliveryFeatureApprovalService.submit(null, 'Enable', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'null featureId should throw');

        threw = false;
        try {
            DeliveryFeatureApprovalService.submit(feat.Id, 'Bogus', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'invalid action should throw');
    }

    /**
     * @description Rollback is only valid from Applied. Calling it on a
     *              Pending or RolledBack request must throw.
     */
    @IsTest
    static void testRollbackOnlyFromApplied() {
        Feature__c feat = TestDataFactory.createFeature(null);
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);

        Boolean threw = false;
        try {
            DeliveryFeatureApprovalService.rollback(requestId, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'rollback of a Pending request should throw');
    }
}
