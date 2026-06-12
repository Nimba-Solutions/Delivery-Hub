/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the PR1 work-approval queue service:
 *               submit / approve / decline / requestIncrease / queue feed,
 *               plus the discretionary Auto short-circuit (under-threshold
 *               auto-approves; an exhausted monthly cap does not), the
 *               canonical cap landing on ClientPreApprovedHoursNumber__c, and
 *               the budget-increase semantics (approve RAISES the cap by the
 *               delta; decline leaves the in-flight item untouched).
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
     * @param approverId Default approver User ID (null = unassigned requests).
     */
    private static void configureSettings(Decimal threshold, Decimal monthlyCap, Id approverId) {
        configureSettings(threshold, monthlyCap, approverId, null);
    }

    /**
     * @description Writes the discretionary-gate org-default settings
     *              including the optional BACKUP approver.
     * @param threshold Per-request Auto ceiling (null/0 disables Auto).
     * @param monthlyCap Monthly Auto budget (null = uncapped).
     * @param approverId Default approver User ID (null = unassigned requests).
     * @param backupId Backup approver User ID (null = no backup).
     */
    private static void configureSettings(
        Decimal threshold, Decimal monthlyCap, Id approverId, Id backupId
    ) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.DiscretionaryThresholdHoursNumber__c = threshold;
        settings.DiscretionaryMonthlyCapHoursNumber__c = monthlyCap;
        settings.ApproverUserIdTxt__c = approverId == null ? null : String.valueOf(approverId);
        settings.ApproverBackupUserIdTxt__c = backupId == null ? null : String.valueOf(backupId);
        upsert settings;
    }

    /**
     * @description Inserts a second Standard User for caller-guard tests.
     *              runAs isolates the setup-object DML from sObject DML in the
     *              calling test (MIXED_DML_OPERATION guard).
     * @return The inserted user.
     */
    private static User createOtherUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String stamp = String.valueOf(Datetime.now().getTime())
            + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
        User other = new User(
            Alias = 'wapprv', Email = 'wapprv' + stamp + '@example.com',
            EmailEncodingKey = 'UTF-8', LastName = 'Approver',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
            Username = 'wapprv' + stamp + '@example.com.dhtest'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert other;
        }
        return other;
    }

    /**
     * @description Seeds an already-consumed slice of the monthly Auto cap:
     *              one Accepted WorkRequest__c auto-approved this month with
     *              the given quoted hours.
     * @param hours Quoted hours to count against the cap.
     */
    private static void seedConsumedAutoHours(Decimal hours) {
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => hours
        });
        TestDataFactory.createWorkRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => DeliveryWorkApprovalService.REQUEST_ACCEPTED,
            'QuotedHoursNumber__c' => hours,
            'AutoApprovedDateTime__c' => Datetime.now(),
            'DecisionDateTime__c' => Datetime.now()
        });
    }

    // ────────────────────────────────────────────────────────────────────
    // SUBMIT — discretionary Auto path
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Under-threshold + under-cap submit short-circuits to
     *              approved: Accepted request with AutoApprovedDateTime__c,
     *              canonical cap stamped, stage = Ready for Development.
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
            SELECT StatusPk__c, QuotedHoursNumber__c, PreApprovedHoursNumber__c,
                   AutoApprovedDateTime__c, DecisionDateTime__c
            FROM WorkRequest__c
            WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c,
            'auto path lands the request on Accepted');
        System.assertEquals(4, req.QuotedHoursNumber__c,
            'quoted hours copied from EstimatedHoursNumber__c');
        System.assertEquals(4, req.PreApprovedHoursNumber__c,
            'granted hours stamped on the request');
        System.assertNotEquals(null, req.AutoApprovedDateTime__c,
            'auto-approved requests carry the Auto timestamp (consumes the monthly cap)');
        System.assertNotEquals(null, req.DecisionDateTime__c,
            'decision timestamp stamped');

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
     * @description Over-threshold submit sends the offer with the configured
     *              approver and parks the item at Ready for Final Approval —
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
            SELECT StatusPk__c, QuotedHoursNumber__c, ApproverUserLookup__c,
                   AutoApprovedDateTime__c, DecisionDateTime__c
            FROM WorkRequest__c
            WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c, 'offer goes out');
        System.assertEquals(20, req.QuotedHoursNumber__c, 'quoted hours stamped');
        System.assertEquals(UserInfo.getUserId(), req.ApproverUserLookup__c,
            'default approver assigned from settings');
        System.assertEquals(null, req.AutoApprovedDateTime__c, 'not auto-approved');
        System.assertEquals(null, req.DecisionDateTime__c, 'no decision yet');

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
     *              month's auto-approved sum has reached the monthly cap.
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
            SELECT StatusPk__c, AutoApprovedDateTime__c
            FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c,
            'request waits as a sent offer, not Accepted');
        System.assertEquals(null, req.AutoApprovedDateTime__c, 'no Auto stamp');
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
     * @description Submit reuses an existing Draft WorkRequest__c instead of
     *              minting a duplicate request.
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
     * @description Approve accepts the request, stamps the decision fields
     *              (approver/timestamp/note), and lands the approved hours on
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
            SELECT StatusPk__c, ApproverUserLookup__c, DecisionDateTime__c,
                   DecisionNoteTxt__c, PreApprovedHoursNumber__c, AutoApprovedDateTime__c
            FROM WorkRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c, 'request Accepted');
        System.assertEquals(UserInfo.getUserId(), req.ApproverUserLookup__c,
            'approver stamped');
        System.assertNotEquals(null, req.DecisionDateTime__c, 'timestamp stamped');
        System.assertEquals('approved with buffer', req.DecisionNoteTxt__c,
            'note stored');
        System.assertEquals(25, req.PreApprovedHoursNumber__c,
            'granted hours stamped on the request');
        System.assertEquals(null, req.AutoApprovedDateTime__c,
            'human decision — no Auto stamp');

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
     * @description When the request is assigned, only the assigned approver
     *              may decide — the @AuraEnabled surface is reachable outside
     *              the queue LWC (mirrors the FeatureToggle caller guard).
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
    // BACKUP APPROVER (ApproverBackupUserIdTxt__c)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description The configured BACKUP approver may decide a request
     *              assigned to the primary: the approve lands and the
     *              assignment stays with the primary (stampDecision only
     *              stamps previously-unassigned requests).
     */
    @IsTest
    static void testBackupApproverMayDecide() {
        User primary = createOtherUser();
        // Primary = the other user; backup = the running user.
        configureSettings(null, null, primary.Id, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 10
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        DeliveryWorkApprovalService.approve(results[0].workRequestId, 10, 'backup signing off');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, ApproverUserLookup__c, PreApprovedHoursNumber__c
            FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c,
            'the backup approver\'s decision lands');
        System.assertEquals(primary.Id, req.ApproverUserLookup__c,
            'the assignment stays with the primary — the backup decides, not reassigns');
        System.assertEquals(10, req.PreApprovedHoursNumber__c, 'granted hours stamped');

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c, StageNamePk__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(10, after.ClientPreApprovedHoursNumber__c,
            'canonical cap lands exactly as a primary approve would');
        System.assertEquals('Ready for Development', after.StageNamePk__c,
            'approved item is dev-ready');
    }

    /**
     * @description A caller who is NEITHER the assigned approver NOR the
     *              configured backup is still rejected — the backup clause
     *              must not open the decision surface to everyone.
     */
    @IsTest
    static void testStrangerRejectedEvenWithBackupConfigured() {
        User other = createOtherUser();
        // Primary AND backup both point at the other user; the running user
        // is a stranger to the approval chain.
        configureSettings(null, null, other.Id, other.Id);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 10
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryWorkApprovalService.decline(results[0].workRequestId, 'nope');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw,
            'a stranger must be rejected even when a backup approver is configured');
        WorkRequest__c req = [
            SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c,
            'the request stays pending after the rejected attempt');
    }

    /**
     * @description The backup approver's queue feed includes requests
     *              assigned to the PRIMARY approver — primary and backup
     *              share one queue.
     */
    @IsTest
    static void testGetPendingForBackupIncludesPrimaryQueue() {
        User primary = createOtherUser();
        configureSettings(null, null, primary.Id, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });
        DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        List<DeliveryWorkApprovalService.PendingApprovalDTO> queue =
            DeliveryWorkApprovalService.getPendingForApprover(null); // running user = backup
        Test.stopTest();

        System.assertEquals(1, queue.size(),
            'the backup sees the request assigned to the primary');
        System.assertEquals(primary.Id, queue[0].approverUserId,
            'the row is still assigned to the primary');
    }

    // ────────────────────────────────────────────────────────────────────
    // DECLINE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Decline stands the request down (Inactive + reason) and —
     *              because nothing was previously approved — parks the
     *              WorkItem On Hold.
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
            SELECT StatusPk__c, StandDownReasonTxt__c, DecisionDateTime__c,
                   ApproverUserLookup__c
            FROM WorkRequest__c WHERE Id = :requestId
        ];
        System.assertEquals('Inactive', req.StatusPk__c, 'request stood down');
        System.assertEquals('Not in this quarter\'s budget', req.StandDownReasonTxt__c,
            'reason stored on the request');
        System.assertNotEquals(null, req.DecisionDateTime__c, 'decision stamped');
        System.assertEquals(UserInfo.getUserId(), req.ApproverUserLookup__c,
            'deciding user stamped on the previously-unassigned request');

        WorkItem__c after = [
            SELECT ClientIntentionPk__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('On Hold', after.ClientIntentionPk__c,
            'declined item drops out of the committed cohort');
    }

    /**
     * @description Declining a budget INCREASE leaves the in-flight item
     *              alone: original cap intact, no On Hold parking — only the
     *              delta dies.
     */
    @IsTest
    static void testDeclineIncreaseLeavesItemInFlight() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 40,
            'ClientPreApprovedHoursNumber__c' => 40
        });
        Id newRequestId = DeliveryWorkApprovalService.requestIncrease(wi.Id, 10, 'delta ask');

        Test.startTest();
        DeliveryWorkApprovalService.decline(newRequestId, 'Hold the line at 40');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, StandDownReasonTxt__c
            FROM WorkRequest__c WHERE Id = :newRequestId
        ];
        System.assertEquals('Inactive', req.StatusPk__c, 'the increase request stood down');
        System.assertEquals('Hold the line at 40', req.StandDownReasonTxt__c,
            'reason stored');

        WorkItem__c after = [
            SELECT ClientIntentionPk__c, ClientPreApprovedHoursNumber__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(40, after.ClientPreApprovedHoursNumber__c,
            'original cap untouched');
        System.assertNotEquals('On Hold', after.ClientIntentionPk__c,
            'in-flight item must NOT park when only the delta is declined');
    }

    // ────────────────────────────────────────────────────────────────────
    // REQUEST INCREASE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description requestIncrease mints a NEW Offer-Sent request carrying
     *              the delta in RequestedBudgetIncreaseNumber__c — increases
     *              never take the Auto lane, even when the delta is under the
     *              discretionary threshold — and the item keeps its stage and
     *              cap while the delta pends.
     */
    @IsTest
    static void testRequestIncreaseQueuesDelta() {
        configureSettings(20, 100, UserInfo.getUserId()); // delta of 10 WOULD fit
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 40,
            'ClientPreApprovedHoursNumber__c' => 40
        });
        WorkItem__c before = [
            SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :wi.Id
        ];

        Test.startTest();
        Id newRequestId = DeliveryWorkApprovalService.requestIncrease(
            wi.Id, 10, 'Scope grew during dev');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, QuotedHoursNumber__c, RequestedBudgetIncreaseNumber__c,
                   WorkItemId__c, ApproverUserLookup__c, AutoApprovedDateTime__c
            FROM WorkRequest__c WHERE Id = :newRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c, 'increase offer goes out');
        System.assertEquals(10, req.RequestedBudgetIncreaseNumber__c,
            'delta carried on RequestedBudgetIncreaseNumber__c');
        System.assertEquals(wi.Id, req.WorkItemId__c, 'parented to the work item');
        System.assertEquals(UserInfo.getUserId(), req.ApproverUserLookup__c,
            'default approver assigned');
        System.assertEquals(null, req.AutoApprovedDateTime__c,
            'increases ALWAYS queue for a human — no Auto lane');

        WorkItem__c after = [
            SELECT StageNamePk__c, ClientPreApprovedHoursNumber__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(before.StageNamePk__c, after.StageNamePk__c,
            'in-flight item keeps its stage — only the delta pends');
        System.assertEquals(40, after.ClientPreApprovedHoursNumber__c,
            'existing cap untouched until the increase is approved');
    }

    /**
     * @description Approving an increase RAISES the canonical cap by the
     *              approved delta — it never overwrites the cap with the
     *              delta. Null approvedHours falls back to the quoted delta.
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
        DeliveryWorkApprovalService.approve(newRequestId, null, 'granting the delta');
        Test.stopTest();

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c, StageNamePk__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(50, after.ClientPreApprovedHoursNumber__c,
            'cap raised 40 + 10 = 50 — the delta adds, it does not overwrite');
        System.assertEquals('Ready for Development', after.StageNamePk__c,
            'item returns to dev-ready');

        WorkRequest__c req = [
            SELECT PreApprovedHoursNumber__c FROM WorkRequest__c WHERE Id = :newRequestId
        ];
        System.assertEquals(10, req.PreApprovedHoursNumber__c,
            'the request records the granted DELTA, not the new total');
    }

    /**
     * @description Approving an increase with an explicitly reduced delta
     *              raises the cap by the reduced figure ("approve w/ change").
     */
    @IsTest
    static void testApproveIncreaseWithReducedDelta() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 40,
            'ClientPreApprovedHoursNumber__c' => 40
        });
        Id newRequestId = DeliveryWorkApprovalService.requestIncrease(wi.Id, 10, 'delta');

        Test.startTest();
        DeliveryWorkApprovalService.approve(newRequestId, 5, 'half the ask');
        Test.stopTest();

        WorkItem__c after = [
            SELECT ClientPreApprovedHoursNumber__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals(45, after.ClientPreApprovedHoursNumber__c,
            'cap raised 40 + 5 = 45 with the approver\'s reduced delta');
    }

    // ────────────────────────────────────────────────────────────────────
    // QUEUE FEED
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description getPendingForApprover returns assigned + unassigned
     *              Offer-Sent requests with the work-item join populated,
     *              and excludes decided requests.
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
            'only the over-threshold item pends — the auto-Accepted request is excluded');
        DeliveryWorkApprovalService.PendingApprovalDTO dto = queue[0];
        System.assertEquals(pendingWi.Id, dto.workItemId, 'work item joined');
        System.assertEquals(20, dto.quotedHours, 'quoted hours surfaced');
        System.assertEquals('Offer Sent', dto.requestStatus, 'request status surfaced');
        System.assertEquals(UserInfo.getUserId(), dto.approverUserId,
            'assigned approver surfaced');
        System.assertNotEquals(null, dto.submittedAt, 'submitted timestamp surfaced');
    }

    /**
     * @description Unassigned Offer-Sent requests (no default approver
     *              configured) still surface in any approver's queue — the
     *              queue never silently hides work.
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

        System.assertEquals(1, queue.size(), 'unassigned pending request is visible');
        System.assertEquals(null, queue[0].approverUserId, 'request is unassigned');
    }

    // ────────────────────────────────────────────────────────────────────
    // VALIDATION
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Bad inputs throw across the surface: empty submit set,
     *              null/zero increase, approve on a request that is not
     *              awaiting a decision.
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
        System.assert(threw, 'approve on a Draft (not awaiting decision) should throw');
    }

    /**
     * @description The monthly-cap helper sums only THIS_MONTH auto-approved
     *              requests.
     */
    @IsTest
    static void testSumAutoApprovedHoursThisMonth() {
        seedConsumedAutoHours(7.5);
        Decimal total = DeliveryWorkApprovalService.sumAutoApprovedHoursThisMonth();
        System.assertEquals(7.5, total, 'seeded auto-approved hours counted against the cap');
    }

    // ────────────────────────────────────────────────────────────────────
    // NOTIFICATIONS (PR4) — Apex tests cannot assert
    // Messaging.CustomNotification.send() directly (the managed test runner
    // short-circuits delivery — see DeliveryShipVerificationTest /
    // DeliveryNotificationServiceTest). The contract asserted here is the
    // trackable decision state PLUS the notification path completing without
    // exception; Test.stopTest() drains the queueable.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Over-threshold submit runs the approver ping path
     *              (summarized "Approval needed" bell to the configured
     *              approver) without exception — the request still lands as
     *              an assigned Offer-Sent row and the submit DML is never
     *              blocked by the notification fanout.
     */
    @IsTest
    static void testSubmitOverThresholdPingsApproverWithoutException() {
        configureSettings(8, 40, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });

        Test.startTest();
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Test.stopTest();

        // Reaching here = the ping path (and the drained queueable) did not
        // throw. Sanity-check the trackable side effects are intact.
        WorkRequest__c req = [
            SELECT StatusPk__c, ApproverUserLookup__c
            FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c,
            'offer still goes out with the ping path wired in');
        System.assertEquals(UserInfo.getUserId(), req.ApproverUserLookup__c,
            'configured approver assigned — the ping targets this user');
    }

    /**
     * @description Approve fires the decided ping to the work item's
     *              assigned developer without exception; the decision state
     *              and canonical cap land exactly as before.
     */
    @IsTest
    static void testApprovePingsAssignedDev() {
        configureSettings(null, null, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20,
            'DeveloperLookup__c' => UserInfo.getUserId()
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        DeliveryWorkApprovalService.approve(results[0].workRequestId, 25, 'go');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, PreApprovedHoursNumber__c
            FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c,
            'approve decision lands with the dev ping wired in');
        System.assertEquals(25, req.PreApprovedHoursNumber__c,
            'granted hours stamped — the ping body reads this cap');
    }

    /**
     * @description Decline fires the decided ping (with the stand-down
     *              reason in the body) to the assigned developer without
     *              exception; the stand-down state lands exactly as before.
     */
    @IsTest
    static void testDeclinePingsAssignedDevWithReason() {
        configureSettings(null, null, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20,
            'DeveloperLookup__c' => UserInfo.getUserId()
        });
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        DeliveryWorkApprovalService.decline(results[0].workRequestId, 'Budget freeze');
        Test.stopTest();

        WorkRequest__c req = [
            SELECT StatusPk__c, StandDownReasonTxt__c
            FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Inactive', req.StatusPk__c,
            'decline decision lands with the dev ping wired in');
        System.assertEquals('Budget freeze', req.StandDownReasonTxt__c,
            'reason stored — the ping body carries it');
    }

    /**
     * @description No developer assigned on the work item = the decided
     *              ping skips silently: the approve succeeds and no
     *              notification queueable is enqueued.
     */
    @IsTest
    static void testDecidedPingSkipsSilentlyWhenNoDevAssigned() {
        configureSettings(null, null, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        }); // no DeveloperLookup__c
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });

        Test.startTest();
        Integer asyncBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        DeliveryWorkApprovalService.approve(results[0].workRequestId, 20, null);
        Integer asyncAfter = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Test.stopTest();

        System.assertEquals(asyncBefore, asyncAfter,
            'unassigned dev must not enqueue a decided notification');
        WorkRequest__c req = [
            SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Accepted', req.StatusPk__c,
            'the decision itself must never be blocked by the silent skip');
    }

    /**
     * @description Blank approver setting + unassigned request = the submit
     *              ping skips silently: nothing to target, no exception, no
     *              queueable, and the offer still goes out.
     */
    @IsTest
    static void testSubmitPingSkipsSilentlyWhenNoApproverAnywhere() {
        configureSettings(null, null, null); // no default approver, Auto off
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'EstimatedHoursNumber__c' => 20
        });

        Test.startTest();
        Integer asyncBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        List<DeliveryWorkApprovalService.SubmitResultDTO> results =
            DeliveryWorkApprovalService.submitForApproval(new Set<Id>{ wi.Id });
        Integer asyncAfter = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Test.stopTest();

        System.assertEquals(asyncBefore, asyncAfter,
            'no assigned approver and no configured default = no submit ping');
        WorkRequest__c req = [
            SELECT StatusPk__c, ApproverUserLookup__c
            FROM WorkRequest__c WHERE Id = :results[0].workRequestId
        ];
        System.assertEquals('Offer Sent', req.StatusPk__c,
            'the offer itself must never be blocked by the silent skip');
        System.assertEquals(null, req.ApproverUserLookup__c, 'request is unassigned');
    }

    /**
     * @description The two PR4 notification entry points are documented
     *              null-safe no-ops: null / empty inputs and a non-existent
     *              request id must never throw or enqueue.
     */
    @IsTest
    static void testNotificationEntryPointsNullSafety() {
        Test.startTest();
        Integer asyncBefore = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        DeliveryNotificationService.notifyWorkApprovalSubmitted(null);
        DeliveryNotificationService.notifyWorkApprovalSubmitted(new List<Id>());
        DeliveryNotificationService.notifyWorkApprovalDecided(null, true);
        DeliveryNotificationService.notifyWorkApprovalDecided(null, null);
        // Real-shaped but non-existent request id — loader returns no rows.
        DeliveryNotificationService.notifyWorkApprovalDecided(
            WorkRequest__c.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
                .getKeyPrefix() + '000000000000', false);
        Integer asyncAfter = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'];
        Test.stopTest();

        System.assertEquals(asyncBefore, asyncAfter,
            'null, empty, and missing-record inputs must never enqueue or throw');
    }
}
