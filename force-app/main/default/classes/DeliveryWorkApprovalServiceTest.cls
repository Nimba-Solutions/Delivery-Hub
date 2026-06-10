/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the PR1 work-approval queue service:
 *               submit / approve / decline / requestIncrease / queue feed,
 *               plus the discretionary Auto short-circuit (under-threshold
 *               auto-approves; an exhausted monthly cap does not) and the
 *               canonical cap landing on ClientPreApprovedHoursNumber__c.
 *
 *               Each test seeds WorkItem__c rows via TestDataFactory (trigger
 *               side-effects bypassed) and configures the discretionary gate
 *               through DeliveryHubSettings__c org defaults — the same
 *               per-org settings pattern the analytics tests use.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkApprovalServiceTest {

    /**
     * @description Writes the discretionary-gate org-default settings.
     * @param threshold Per-request Auto ceiling (null/0 disables Auto).
     * @param monthlyCap Monthly Auto budget (null = uncapped).
     * @param approverId Default approver User ID (null = unassigned rows).
     */
    private static void configureSettings(Decimal threshold, Decimal monthlyCap, Id approverId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.DiscretionaryThresholdHoursNumber__c = threshold;
        settings.DiscretionaryMonthlyCapHoursNumber__c = monthlyCap;
        settings.ApproverUserIdTxt__c = approverId == null ? null : String.valueOf(approverId);
        upsert settings;
    }

    /**
     * @description Seeds an already-consumed slice of the monthly Auto cap:
     *              one Accepted WorkRequest__c with the given quoted hours
     *              plus an Auto approval row decided this month.
     * @param hours Quoted hours to count against the cap.
     */
    private static void seedConsumedAutoHours(Decimal hours) {
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => hours
        });
        WorkRequest__c wr = TestDataFactory.createWorkRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => DeliveryWorkApprovalService.REQUEST_ACCEPTED,
            'QuotedHoursNumber__c' => hours
        });
        insert new WorkItemApproval__c(
            RequestLookup__c = wr.Id,
            StepNumber__c = 1,
            StatusPk__c = DeliveryWorkApprovalService.APPROVAL_AUTO,
            DecisionDateTime__c = Datetime.now()
        );
    }

    // ────────────────────────────────────────────────────────────────────
    // SUBMIT — discretionary Auto path
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Under-threshold + under-cap submit short-circuits to
     *              approved: Auto approval row, Accepted request, canonical
     *              cap stamped, stage = Ready for Development.
     */
    @IsTest
    static void testSubmitUnderThresholdAutoApproves() {
        configureSettings(8, 40, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 4
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'one result per submitted item');
        System.assertEquals(true, results[0].autoApproved,
            'under-threshold submit should auto-approve');

        WorkRequest__c req = [
            SELECT StatusPk__c, QuotedHoursNumber__c FROM WorkRequest__c
            WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c,
            'auto path lands the request on Accepted');
        System.assertEquals(4, req.QuotedHoursNumber__c,
            'quoted hours copied from EstimatedHoursNumber__c');

        WorkItemApproval__c row = [
            SELECT StatusPk__c, StepNumber__c, DecisionDateTime__c
            FROM WorkItemApproval__c WHERE RequestLookup__c = :req.Id
        ];
        System.assertEquals('Auto', row.StatusPk__c, 'approval row marked Auto');
        System.assertEquals(1, row.StepNumber__c, 'single-step row');
        System.assertNotEquals(null, row.DecisionDateTime__c,
            'Auto rows carry a decision timestamp (consumes the monthly cap)');

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c, StageNamePk__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(4, after.ClientPreApprovedHoursNumber__c,
            'canonical cap lands on ClientPreApprovedHoursNumber__c');
        System.assertEquals('Ready for Development', after.StageNamePk__c,
            'auto-approved item is dev-ready');
    }

    /**
     * @description Over-threshold submit creates a Pending row, sends the
     *              offer, and parks the item at Ready for Final Approval —
     *              no cap is stamped until a human approves.
     */
    @IsTest
    static void testSubmitOverThresholdQueuesPending() {
        configureSettings(8, 40, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Test.stopTest();

        System.assertEquals(false, results[0].autoApproved,
            'over-threshold submit must NOT auto-approve');

        WorkRequest__c req = [
            SELECT StatusPk__c, QuotedHoursNumber__c FROM WorkRequest__c
            WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c, 'offer goes out');
        System.assertEquals(20, req.QuotedHoursNumber__c, 'quoted hours stamped');

        WorkItemApproval__c row = [
            SELECT StatusPk__c, ApproverUserLookup__c, DecisionDateTime__c
            FROM WorkItemApproval__c WHERE RequestLookup__c = :req.Id
        ];
        System.assertEquals('Pending', row.StatusPk__c, 'row awaits the approver');
        System.assertEquals(UserInfo.getUserId(), row.ApproverUserLookup__c,
            'default approver assigned from settings');
        System.assertEquals(null, row.DecisionDateTime__c, 'no decision yet');

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c, StageNamePk__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(null, after.ClientPreApprovedHoursNumber__c,
            'no cap until a human approves');
        System.assertEquals('Ready for Final Approval', after.StageNamePk__c,
            'item parks at the approval gate');
    }

    /**
     * @description Under-threshold submit does NOT auto-approve once the
     *              month's Auto-approved sum has reached the monthly cap.
     */
    @IsTest
    static void testSubmitOverMonthlyCapDoesNotAutoApprove() {
        configureSettings(8, 40, null);
        seedConsumedAutoHours(40); // cap fully consumed this month
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 4
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Test.stopTest();

        System.assertEquals(false, results[0].autoApproved,
            'exhausted monthly cap must force the human queue');
        WorkRequest__c req = [
            SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c,
            'request waits as a sent offer, not Accepted');
        WorkItem__c after = [
            SELECT StageNamePk__c, ClientPreApprovedHoursNumber__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('Ready for Final Approval', after.StageNamePk__c,
            'item queues for the approver');
        System.assertEquals(null, after.ClientPreApprovedHoursNumber__c,
            'no auto cap stamped');
    }

    /**
     * @description The running Auto sum is tracked WITHIN one submit call:
     *              with 38 of 40 cap hours consumed, the first under-threshold
     *              item still fits (38 < 40) but the second sees the updated
     *              sum and falls back to Pending.
     */
    @IsTest
    static void testMonthlyCapCountsWithinSingleSubmit() {
        configureSettings(8, 40, null);
        seedConsumedAutoHours(38);
        WorkItem__c first = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 4
        });
        WorkItem__c second = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 4
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(
                new Set<Id>{ first.Id, second.Id });
        Test.stopTest();

        Integer autoCount = 0;
        for (DeliveryWorkApprovalService.SubmitResultDTO dto : results) {
            if (dto.autoApproved) {
                autoCount++;
            }
        }
        System.assertEquals(1, autoCount,
            'only the first item fits under the remaining monthly cap');
    }

    /**
     * @description An explicit per-item quoted value overrides the WorkItem
     *              estimate on the request.
     */
    @IsTest
    static void testSubmitUsesExplicitQuotedHours() {
        configureSettings(8, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 50
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(
                new Set<Id>{ wi.Id },
                new Map<Id, Decimal>{ wi.Id => 2 });
        Test.stopTest();

        System.assertEquals(true, results[0].autoApproved,
            'explicit 2h quote is under the 8h threshold even though the estimate is 50h');
        WorkRequest__c req = [
            SELECT QuotedHoursNumber__c FROM WorkRequest__c
            WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals(2, req.QuotedHoursNumber__c,
            'explicit value wins over EstimatedHoursNumber__c');
    }

    /**
     * @description Submit reuses an existing Draft WorkRequest__c (the
     *              auto-create trigger seeds Drafts) instead of minting a
     *              duplicate request.
     */
    @IsTest
    static void testSubmitReusesDraftRequest() {
        configureSettings(null, null, null); // Auto disabled — plain queue path
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 10
        });
        WorkRequest__c draft = TestDataFactory.createWorkRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => DeliveryWorkApprovalService.REQUEST_DRAFT
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Test.stopTest();

        System.assertEquals(draft.Id, results[0].workRequestId,
            'the existing Draft request is promoted, not duplicated');
        Integer requestCount = [
            SELECT COUNT() FROM WorkRequest__c WHERE WorkItemId__c = :wi.Id
        ];
        System.assertEquals(1, requestCount, 'no duplicate request minted');
        WorkRequest__c after = [
            SELECT StatusPk__c, QuotedHoursNumber__c FROM WorkRequest__c WHERE Id = :draft.Id
        ];
        System.assertEquals('Offer Sent', after.StatusPk__c, 'Draft -> Offer Sent');
        System.assertEquals(10, after.QuotedHoursNumber__c, 'quote stamped on the Draft');
    }

    /**
     * @description A blank/zero threshold disables the Auto path entirely —
     *              even a tiny estimate queues for a human.
     */
    @IsTest
    static void testBlankThresholdDisablesAutoPath() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 0.5
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Test.stopTest();

        System.assertEquals(false, results[0].autoApproved,
            'no threshold configured = no discretionary lane');
    }

    // ────────────────────────────────────────────────────────────────────
    // APPROVE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approve accepts the request, stamps the row with the
     *              approver/timestamp/note, and lands the approved hours on
     *              ClientPreApprovedHoursNumber__c — THE canonical cap.
     */
    @IsTest
    static void testApproveLandsCanonicalCap() {
        configureSettings(null, null, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Id requestId = results[0].workRequestId;

        Test.startTest();
        DeliveryWorkApprovalService.approve(requestId, 25, 'approved with buffer');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c, 'request Accepted');

        WorkItemApproval__c row = [
            SELECT StatusPk__c, ApproverUserLookup__c, DecisionDateTime__c, DecisionNoteTxt__c
            FROM WorkItemApproval__c WHERE RequestLookup__c = :requestId
        ];
        System.assertEquals('Approved', row.StatusPk__c, 'row Approved');
        System.assertEquals(UserInfo.getUserId(), row.ApproverUserLookup__c,
            'approver stamped');
        System.assertNotEquals(null, row.DecisionDateTime__c, 'timestamp stamped');
        System.assertEquals('approved with buffer', row.DecisionNoteTxt__c,
            'note stored');

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c, StageNamePk__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(25, after.ClientPreApprovedHoursNumber__c,
            'approvedHours (not the 20h quote) is the canonical cap');
        System.assertEquals('Ready for Development', after.StageNamePk__c,
            'approved item is dev-ready');
    }

    /**
     * @description Approve with null approvedHours falls back to the
     *              request's quoted hours for the cap.
     */
    @IsTest
    static void testApproveDefaultsToQuotedHours() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 12
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        DeliveryWorkApprovalService.approve(results[0].workRequestId, null, null);
        Test.stopTest();

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(12, after.ClientPreApprovedHoursNumber__c,
            'cap defaults to the quoted hours');
    }

    /**
     * @description When the row is assigned, only the assigned approver may
     *              decide — the @AuraEnabled surface is reachable outside the
     *              queue LWC (mirrors the FeatureToggle caller guard).
     */
    @IsTest
    static void testApproveRejectsWrongCaller() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String stamp = String.valueOf(Datetime.now().getTime());
        User other = new User(
            Alias = 'wapprv', Email = 'wapprv' + stamp + '@example.com',
            EmailEncodingKey = 'UTF-8', LastName = 'Approver',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
            Username = 'wapprv' + stamp + '@example.com.dhtest'
        );
        // runAs isolates the setup-object DML from the sObject DML below
        // (MIXED_DML_OPERATION guard).
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert other;
        }
        configureSettings(null, null, other.Id);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 10
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryWorkApprovalService.approve(results[0].workRequestId, 10, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'a caller other than the assigned approver must be rejected');
    }

    // ────────────────────────────────────────────────────────────────────
    // DECLINE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Decline stands the request down (Inactive + reason),
     *              rejects the pending row, and parks the WorkItem On Hold.
     */
    @IsTest
    static void testDeclineStandsDownAndParksItem() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 30
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Id requestId = results[0].workRequestId;

        Test.startTest();
        DeliveryWorkApprovalService.decline(requestId, 'Not in this quarter\'s budget');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, StandDownReasonTxt__c FROM WorkRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Inactive', req.StatusPk__c, 'request stood down');
        System.assertEquals('Not in this quarter\'s budget', req.StandDownReasonTxt__c,
            'reason stored on the request');

        WorkItemApproval__c row = [
            SELECT StatusPk__c, DecisionDateTime__c
            FROM WorkItemApproval__c WHERE RequestLookup__c = :requestId
        ];
        System.assertEquals('Rejected', row.StatusPk__c, 'pending row rejected');
        System.assertNotEquals(null, row.DecisionDateTime__c, 'decision stamped');

        WorkItem__c after = [
            SELECT ClientIntentionPk__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('On Hold', after.ClientIntentionPk__c,
            'declined item drops out of the committed cohort');
    }

    // ────────────────────────────────────────────────────────────────────
    // REQUEST INCREASE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description requestIncrease mints a NEW request carrying the delta in
     *              RequestedBudgetIncreaseNumber__c with a Pending approval
     *              row — increases never take the Auto lane, even when the
     *              delta is under the discretionary threshold.
     */
    @IsTest
    static void testRequestIncreaseQueuesDelta() {
        configureSettings(20, 100, UserInfo.getUserId()); // delta of 10 WOULD fit
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 40,
            'ClientPreApprovedHoursNumber__c' => 40
        });

        Test.startTest();
        Id newRequestId = DeliveryWorkApprovalService.requestIncrease(
            wi.Id, 10, 'Scope grew during dev');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, QuotedHoursNumber__c, RequestedBudgetIncreaseNumber__c,
                   WorkItemId__c
            FROM WorkRequest__c WHERE Id = :newRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c, 'increase offer goes out');
        System.assertEquals(10, req.RequestedBudgetIncreaseNumber__c,
            'delta carried on RequestedBudgetIncreaseNumber__c');
        System.assertEquals(wi.Id, req.WorkItemId__c, 'parented to the work item');

        WorkItemApproval__c row = [
            SELECT StatusPk__c, ApproverUserLookup__c
            FROM WorkItemApproval__c WHERE RequestLookup__c = :newRequestId
        ];
        System.assertEquals('Pending', row.StatusPk__c,
            'increases ALWAYS queue for a human — no Auto lane');
        System.assertEquals(UserInfo.getUserId(), row.ApproverUserLookup__c,
            'default approver assigned');

        WorkItem__c after = [
            SELECT StageNamePk__c, ClientPreApprovedHoursNumber__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('Ready for Final Approval', after.StageNamePk__c,
            'item returns to the approval gate while the delta pends');
        System.assertEquals(40, after.ClientPreApprovedHoursNumber__c,
            'existing cap untouched until the increase is approved');
    }

    /**
     * @description Approving an increase request raises the canonical cap to
     *              the approved figure.
     */
    @IsTest
    static void testApproveIncreaseRaisesCap() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 40,
            'ClientPreApprovedHoursNumber__c' => 40
        });
        Id newRequestId = DeliveryWorkApprovalService.requestIncrease(wi.Id, 10, 'delta');

        Test.startTest();
        DeliveryWorkApprovalService.approve(newRequestId, 50, 'cap raised to 50');
        Test.stopTest();

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c, StageNamePk__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(50, after.ClientPreApprovedHoursNumber__c,
            'approved increase lands the new canonical cap');
        System.assertEquals('Ready for Development', after.StageNamePk__c,
            'item returns to dev-ready');
    }

    // ────────────────────────────────────────────────────────────────────
    // QUEUE FEED
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description getPendingForApprover returns assigned + unassigned
     *              Pending rows with the request/work-item join populated,
     *              and excludes decided rows.
     */
    @IsTest
    static void testGetPendingForApproverReturnsQueue() {
        configureSettings(8, 40, UserInfo.getUserId());
        WorkItem__c pendingWi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });
        WorkItem__c autoWi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 4
        });
        DeliveryWorkApprovalService.submitForApproval(
            new Set<Id>{ pendingWi.Id, autoWi.Id });

        Test.startTest();
        List<DeliveryWorkApprovalService.PendingApprovalDTO> queue =
            DeliveryWorkApprovalService.getPendingForApprover(null);
        Test.stopTest();

        System.assertEquals(1, queue.size(),
            'only the over-threshold item pends — the Auto row is excluded');
        DeliveryWorkApprovalService.PendingApprovalDTO dto = queue[0];
        System.assertEquals(pendingWi.Id, dto.workItemId, 'work item joined');
        System.assertEquals(20, dto.quotedHours, 'quoted hours surfaced');
        System.assertEquals('Pending', dto.status, 'status surfaced');
        System.assertEquals('Offer Sent', dto.requestStatus, 'request status surfaced');
        System.assertEquals(UserInfo.getUserId(), dto.approverUserId,
            'assigned approver surfaced');
        System.assertNotEquals(null, dto.submittedAt, 'submitted timestamp surfaced');
    }

    /**
     * @description Unassigned Pending rows (no default approver configured)
     *              still surface in any approver's queue — the queue never
     *              silently hides work.
     */
    @IsTest
    static void testGetPendingIncludesUnassignedRows() {
        configureSettings(null, null, null); // no default approver
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });
        DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        List<DeliveryWorkApprovalService.PendingApprovalDTO> queue =
            DeliveryWorkApprovalService.getPendingForApprover(UserInfo.getUserId());
        Test.stopTest();

        System.assertEquals(1, queue.size(), 'unassigned pending row is visible');
        System.assertEquals(null, queue[0].approverUserId, 'row is unassigned');
    }

    // ────────────────────────────────────────────────────────────────────
    // VALIDATION
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Bad inputs throw across the surface: empty submit set,
     *              null/zero increase, approve without a pending row.
     */
    @IsTest
    static void testValidationErrors() {
        Boolean threw = false;
        try {
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>());
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'empty workItemIds should throw');

        WorkItem__c wi = TestDataFactory.createWorkItem(null);
        threw = false;
        try {
            DeliveryWorkApprovalService.requestIncrease(wi.Id, 0, 'none');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'zero extraHours should throw');

        threw = false;
        try {
            DeliveryWorkApprovalService.requestIncrease(null, 5, 'none');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'null workItemId should throw');

        WorkRequest__c bare = TestDataFactory.createWorkRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => DeliveryWorkApprovalService.REQUEST_DRAFT
        });
        threw = false;
        try {
            DeliveryWorkApprovalService.approve(bare.Id, 5, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'approve without a pending approval row should throw');
    }

    /**
     * @description The monthly-cap helper sums only THIS_MONTH Auto rows.
     */
    @IsTest
    static void testSumAutoApprovedHoursThisMonth() {
        seedConsumedAutoHours(7.5);
        Decimal total = DeliveryWorkApprovalService.sumAutoApprovedHoursThisMonth();
        System.assertEquals(7.5, total, 'seeded Auto hours counted against the cap');
    }
}
