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
        assignApproverToRunningUser(new List<Id>{ approval.Id });

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
        assignApproverToRunningUser(new List<Id>{ first.Id });

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
        assignApproverToRunningUser(new List<Id>{ approval.Id });

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
        assignApproverToRunningUser(new List<Id>{ approval.Id });

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
        assignApproverToRunningUser(new List<Id>{ approval.Id });
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
        assignApproverToRunningUser(new List<Id>{ approval.Id });

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

    // ────────────────────────────────────────────────────────────────────
    // PR 8 — multi-step cascade chain tests
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Submit on a feature with a 2-level Hard cascade (A -> B -> C
     *              via BlockingFeatureLookup__c, walked on Enable) produces
     *              exactly one root approval (Step=0) plus one approval per
     *              cascade layer. With A as the requested feature and B, C as
     *              blockers, the BFS surfaces B at depth 1 and C at depth 2,
     *              for a total of 3 approval rows.
     */
    @IsTest
    static void testSubmitGeneratesMultiStepChainForCascade() {
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Feature__c featC = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        // A depends on B (A blocked by B); B depends on C (B blocked by C).
        TestDataFactory.createFeatureDependency(featB.Id, featA.Id, new Map<String, Object>{
            'TypePk__c' => 'Hard',
            'CascadeDirectionPk__c' => 'Both'
        });
        TestDataFactory.createFeatureDependency(featC.Id, featB.Id, new Map<String, Object>{
            'TypePk__c' => 'Hard',
            'CascadeDirectionPk__c' => 'Both'
        });

        Test.startTest();
        Id requestId = DeliveryFeatureApprovalService.submit(featA.Id, 'Enable', 'cascade test');
        Test.stopTest();

        List<FeatureToggleApproval__c> approvals = [
            SELECT Id, StepNumber__c, FeatureLookup__c, RequiredDateTime__c
            FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId
            ORDER BY StepNumber__c ASC
        ];
        System.assertEquals(3, approvals.size(),
            'expected root + 2 cascade approvals for A -> B -> C chain');
        System.assertEquals(0, approvals[0].StepNumber__c.intValue(),
            'root sign-off row is StepNumber=0');
        System.assertEquals(featA.Id, approvals[0].FeatureLookup__c,
            'root row references the requested feature');
        // Hard edges => RequiredDateTime__c populated.
        for (FeatureToggleApproval__c a : approvals) {
            System.assertNotEquals(null, a.RequiredDateTime__c,
                'Hard cascade edges must be Required');
        }
    }

    /**
     * @description When a chain has 3 required approvals, granting only 2
     *              must NOT apply. Granting the 3rd flips Apply.
     */
    @IsTest
    static void testApplyIfFullyGrantedRequiresAllRequiredApprovals() {
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        TestDataFactory.createFeatureDependency(featB.Id, featA.Id, new Map<String, Object>{
            'TypePk__c' => 'Hard',
            'CascadeDirectionPk__c' => 'Both'
        });

        Id requestId = DeliveryFeatureApprovalService.submit(featA.Id, 'Enable', null);
        List<FeatureToggleApproval__c> approvals = [
            SELECT Id, StepNumber__c
            FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId
            ORDER BY StepNumber__c ASC
        ];
        System.assertEquals(2, approvals.size(),
            'expected root + 1 cascade approval for A -> B chain');
        assignApproverToRunningUser(new List<Id>{ approvals[0].Id, approvals[1].Id });

        Test.startTest();
        // Grant only the cascade-leaf approval first. The root remains pending.
        DeliveryFeatureApprovalService.grant(approvals[1].Id, 'leaf ok');

        FeatureToggleRequest__c reqMid = [
            SELECT StatusPk__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Pending', reqMid.StatusPk__c,
            'only one required grant should not flip the request');

        // Now grant the root.
        DeliveryFeatureApprovalService.grant(approvals[0].Id, 'final sign-off');
        Test.stopTest();

        FeatureToggleRequest__c reqFinal = [
            SELECT StatusPk__c, AppliedDateTime__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Applied', reqFinal.StatusPk__c,
            'all required grants should flip to Applied');
        System.assertNotEquals(null, reqFinal.AppliedDateTime__c,
            'AppliedDateTime stamped on apply');
    }

    /**
     * @description Soft (non-required) dependencies are auto-marked
     *              Status='Auto' when all required rows resolve. Soft rows
     *              do not block apply.
     */
    @IsTest
    static void testSoftDependenciesAreAutoApproved() {
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Feature__c featSoft = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        TestDataFactory.createFeatureDependency(featSoft.Id, featA.Id, new Map<String, Object>{
            'TypePk__c' => 'Soft',
            'CascadeDirectionPk__c' => 'Both'
        });

        Id requestId = DeliveryFeatureApprovalService.submit(featA.Id, 'Enable', null);
        List<FeatureToggleApproval__c> approvals = [
            SELECT Id, StepNumber__c, RequiredDateTime__c, StatusPk__c
            FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId
            ORDER BY StepNumber__c ASC
        ];
        System.assertEquals(2, approvals.size(),
            'soft dependencies still produce an approval row');

        // The Soft row (depth 1) should NOT be Required.
        FeatureToggleApproval__c softRow;
        FeatureToggleApproval__c rootRow;
        for (FeatureToggleApproval__c a : approvals) {
            if (a.StepNumber__c == 0) { rootRow = a; }
            else { softRow = a; }
        }
        System.assertNotEquals(null, rootRow, 'root row created');
        System.assertNotEquals(null, softRow, 'soft row created');
        System.assertNotEquals(null, rootRow.RequiredDateTime__c, 'root row is required');
        System.assertEquals(null, softRow.RequiredDateTime__c,
            'Soft dependency row must have RequiredDateTime__c=null');
        assignApproverToRunningUser(new List<Id>{ rootRow.Id });

        Test.startTest();
        // Grant only the root — soft should be auto-marked on apply.
        DeliveryFeatureApprovalService.grant(rootRow.Id, null);
        Test.stopTest();

        FeatureToggleApproval__c softAfter = [
            SELECT StatusPk__c, DecisionDateTime__c FROM FeatureToggleApproval__c
            WHERE Id = :softRow.Id
        ];
        System.assertEquals('Auto', softAfter.StatusPk__c,
            'Soft row should be auto-marked at apply');
        System.assertNotEquals(null, softAfter.DecisionDateTime__c,
            'Auto row gets a DecisionDateTime stamp');
        FeatureToggleRequest__c reqFinal = [
            SELECT StatusPk__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Applied', reqFinal.StatusPk__c, 'request applied');
    }

    /**
     * @description getApprovalChain returns one DTO per approval row, ordered
     *              by StepNumber. Required/Optional flag derived from
     *              RequiredDateTime__c presence.
     */
    @IsTest
    static void testGetApprovalChainReturnsOrderedDtos() {
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        TestDataFactory.createFeatureDependency(featB.Id, featA.Id, new Map<String, Object>{
            'TypePk__c' => 'Hard',
            'CascadeDirectionPk__c' => 'Both'
        });
        Id requestId = DeliveryFeatureApprovalService.submit(featA.Id, 'Enable', null);

        Test.startTest();
        List<DeliveryFeatureApprovalService.ApprovalChainNodeDTO> chain =
            DeliveryFeatureApprovalService.getApprovalChain(requestId);
        Test.stopTest();

        System.assertEquals(2, chain.size(), 'expected 2 chain entries');
        System.assertEquals(0, chain.get(0).stepNumber,
            'first entry is root (Step 0)');
        System.assertEquals(true, chain.get(0).requiredBoolean,
            'root row is required');
        System.assertEquals(featA.Id, chain.get(0).featureId,
            'root references the requested feature');
        System.assertEquals(1, chain.get(1).stepNumber,
            'second entry is the cascade row at depth 1');
        System.assertEquals(featB.Id, chain.get(1).featureId,
            'cascade row references the blocker feature');
        // Both rows still pending; status DTO carries that through.
        System.assertEquals('Pending', chain.get(0).status, 'pending status');
    }

    // ────────────────────────────────────────────────────────────────────
    // Caller-is-approver guard (security-review-2026-05-21 §7)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Callers other than the assigned approver must be rejected
     *              by grant(). Closes medium-severity finding in
     *              docs/audits/security-review-2026-05-21.md §7 — without
     *              this guard any authenticated DH user could call grant()
     *              on any approval id.
     */
    @IsTest
    static void testGrantRejectsNonApproverCaller() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];
        // Pin approver to a fabricated user id (not the running user) so the
        // guard fires on the null-vs-mismatch second branch. User is a setup
        // object — isolate its DML in System.runAs() to avoid MIXED_DML.
        User other = buildOtherStandardUser();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert other;
        }
        approval.ApproverUserLookup__c = other.Id;
        update approval;

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureApprovalService.grant(approval.Id, 'sneaky');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw,
            'grant() must throw when caller is not the assigned approver');
        FeatureToggleApproval__c after = [
            SELECT StatusPk__c FROM FeatureToggleApproval__c WHERE Id = :approval.Id
        ];
        System.assertEquals('Pending', after.StatusPk__c,
            'approval row must remain Pending after a blocked grant');
    }

    /**
     * @description When ApproverUserLookup__c is null, grant() must refuse —
     *              an unassigned approval row is otherwise reachable by any
     *              authenticated user.
     */
    @IsTest
    static void testGrantRejectsNullApprover() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id, ApproverUserLookup__c FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId LIMIT 1
        ];
        System.assertEquals(null, approval.ApproverUserLookup__c,
            'precondition: submit() leaves approver null until admin assignment');

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureApprovalService.grant(approval.Id, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw,
            'grant() must throw when ApproverUserLookup__c is null');
    }

    /**
     * @description When ApproverUserLookup__c matches the running user, the
     *              guard lets grant() through. (Happy path also exercised
     *              by testGrantAppliesWhenLastApprovalGranted; this asserts
     *              the guard specifically does not regress that path.)
     */
    @IsTest
    static void testGrantSucceedsWhenCallerIsApprover() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];
        assignApproverToRunningUser(new List<Id>{ approval.Id });

        Test.startTest();
        DeliveryFeatureApprovalService.grant(approval.Id, 'ok');
        Test.stopTest();

        FeatureToggleRequest__c req = [
            SELECT StatusPk__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Applied', req.StatusPk__c,
            'request should apply when running user is the assigned approver');
    }

    /**
     * @description reject() must also enforce the caller-is-approver guard.
     */
    @IsTest
    static void testRejectRejectsNonApproverCaller() {
        Feature__c feat = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Id requestId = DeliveryFeatureApprovalService.submit(feat.Id, 'Enable', null);
        FeatureToggleApproval__c approval = [
            SELECT Id FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId LIMIT 1
        ];
        User other = buildOtherStandardUser();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert other;
        }
        approval.ApproverUserLookup__c = other.Id;
        update approval;

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureApprovalService.reject(approval.Id, 'no');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw,
            'reject() must throw when caller is not the assigned approver');
        FeatureToggleRequest__c req = [
            SELECT StatusPk__c FROM FeatureToggleRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Pending', req.StatusPk__c,
            'request must remain Pending after a blocked reject');
    }

    /**
     * @description Test helper — assigns ApproverUserLookup__c=UserInfo.getUserId()
     *              on the given approval rows so existing happy-path tests still
     *              pass through the new caller-is-approver guard.
     */
    private static void assignApproverToRunningUser(List<Id> approvalIds) {
        if (approvalIds == null || approvalIds.isEmpty()) {
            return;
        }
        List<FeatureToggleApproval__c> rows = new List<FeatureToggleApproval__c>();
        Id me = UserInfo.getUserId();
        for (Id a : approvalIds) {
            rows.add(new FeatureToggleApproval__c(
                Id = a,
                ApproverUserLookup__c = me
            ));
        }
        update rows;
    }

    /**
     * @description Test helper — builds (but does not insert) a Standard User
     *              with a unique username, for negative-path tests that need
     *              an approver id different from UserInfo.getUserId().
     */
    private static User buildOtherStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(DateTime.now().getTime());
        return new User(
            FirstName = 'Other',
            LastName = 'Approver',
            Email = 'other.approver+' + uniq + '@example.invalid',
            Username = 'other.approver+' + uniq + '@example.invalid.test',
            Alias = 'oappr',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    /**
     * @description Optional cascade edges must NOT produce an approval row.
     */
    @IsTest
    static void testOptionalDependenciesProduceNoApprovalRow() {
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        Feature__c featOpt = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => Datetime.now()
        });
        TestDataFactory.createFeatureDependency(featOpt.Id, featA.Id, new Map<String, Object>{
            'TypePk__c' => 'Optional',
            'CascadeDirectionPk__c' => 'Both'
        });

        Test.startTest();
        Id requestId = DeliveryFeatureApprovalService.submit(featA.Id, 'Enable', null);
        Test.stopTest();

        Integer approvalCount = [
            SELECT COUNT() FROM FeatureToggleApproval__c WHERE RequestLookup__c = :requestId
        ];
        System.assertEquals(1, approvalCount,
            'Optional edges should be skipped — only the root row exists');
    }
}
