/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the triage controller: the close-out feed (Deployed
 *               to Prod only, oldest-in-stage first, archived/template
 *               excluded, developer + stage-entered surfaced), the intake feed
 *               (un-activated only — the timeline-invisible gap — with
 *               archived/template/terminal excluded and the requestedBy
 *               fallback), and the three bulk mutations (markDone, routeToDev,
 *               dismissIntake) including the partial-failure contract: a real
 *               id succeeds while a not-found id is collected as a failure so
 *               the counts reconcile to the input. Report-id resolution is
 *               shape-only (the report may be absent in a bare scratch org).
 * @author       Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryTriageControllerTest {

    /** A non-resolving but well-formed WorkItem__c id for failure-path tests. */
    private static Id phantomWorkItemId() {
        return Id.valueOf(
            WorkItem__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000'
        );
    }

    private static WorkItem__c seedDeployed(Datetime stageEntered, Id developerId) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Deployed to Prod',
            'StageEnteredDateTime__c' => stageEntered,
            'DeveloperLookup__c' => developerId
        });
    }

    /** An intake item: arrived but never activated onto the timeline. */
    private static WorkItem__c seedIntake(Map<String, Object> extra) {
        Map<String, Object> overrides = new Map<String, Object>{
            'StageNamePk__c' => 'Backlog',
            'StatusPk__c' => 'New',
            'ActivatedDateTime__c' => null
        };
        if (extra != null) {
            overrides.putAll(extra);
        }
        return TestDataFactory.createWorkItem(overrides);
    }

    // ── Close-out feed ───────────────────────────────────────────────

    @IsTest
    static void testCloseOutReturnsDeployedOldestFirst() {
        WorkItem__c newer = seedDeployed(Datetime.now().addDays(-1), UserInfo.getUserId());
        WorkItem__c older = seedDeployed(Datetime.now().addDays(-9), UserInfo.getUserId());
        // Noise that must NOT appear in the feed.
        TestDataFactory.createWorkItem(new Map<String, Object>{ 'StageNamePk__c' => 'In Development' });
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Deployed to Prod',
            'ArchivedDateTime__c' => Datetime.now()
        });
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Deployed to Prod',
            'TemplateMarkedDateTime__c' => Datetime.now()
        });

        Test.startTest();
        List<DeliveryTriageController.CloseOutItemDTO> rows =
            DeliveryTriageController.getCloseOutItems();
        Test.stopTest();

        System.assertEquals(2, rows.size(),
            'only non-archived, non-template Deployed-to-Prod items appear');
        System.assertEquals(older.Id, rows[0].workItemId,
            'oldest-in-stage item leads the queue');
        System.assertEquals(newer.Id, rows[1].workItemId, 'newer item follows');
        System.assertNotEquals(null, rows[0].name, 'auto-number name surfaced');
        System.assertEquals(UserInfo.getUserId(), rows[0].developerId, 'developer id surfaced');
        System.assertNotEquals(null, rows[0].developerName, 'developer name surfaced');
    }

    @IsTest
    static void testCloseOutReportIdShapeOnly() {
        Test.startTest();
        // The report may or may not be deployed in a bare scratch org — the
        // call must simply not throw and return a String or null.
        DeliveryTriageController.getCloseOutReportId();
        Test.stopTest();
        System.assert(true, 'report-id resolution did not throw');
    }

    // ── In-flight feed ───────────────────────────────────────────────

    @IsTest
    static void testInFlightReturnsDevBandInPipelineOrder() {
        WorkItem__c deploying = TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Ready for Deployment',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-1),
            'ClientPreApprovedHoursNumber__c' => 40,
            'DeveloperLookup__c' => UserInfo.getUserId()
        });
        WorkItem__c devOlder = TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'In Development',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-9)
        });
        WorkItem__c devNewer = TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'In Development',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-2)
        });
        WorkItem__c ready = TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Ready for Development',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-30)
        });
        // Noise that must NOT appear: either side of the band, archived, template.
        TestDataFactory.createWorkItem(new Map<String, Object>{ 'StageNamePk__c' => 'Deployed to Prod' });
        TestDataFactory.createWorkItem(new Map<String, Object>{ 'StageNamePk__c' => 'Backlog' });
        TestDataFactory.createWorkItem(new Map<String, Object>{ 'StageNamePk__c' => 'Ready for Final Approval' });
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'In Development',
            'ArchivedDateTime__c' => Datetime.now()
        });
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'In Development',
            'TemplateMarkedDateTime__c' => Datetime.now()
        });

        Test.startTest();
        List<DeliveryTriageController.InFlightItemDTO> rows =
            DeliveryTriageController.getInFlightItems();
        Test.stopTest();

        System.assertEquals(4, rows.size(),
            'only the four in-band, live, non-template items are in flight');
        System.assertEquals(ready.Id, rows[0].workItemId, 'Ready for Development leads the band');
        System.assertEquals(devOlder.Id, rows[1].workItemId, 'older In Development row first');
        System.assertEquals(devNewer.Id, rows[2].workItemId, 'newer In Development row second');
        System.assertEquals(deploying.Id, rows[3].workItemId, 'Ready for Deployment closes the band');
        System.assert(rows[0].stageRank < rows[1].stageRank && rows[1].stageRank < rows[3].stageRank,
            'stageRank follows pipeline order');
        System.assertEquals('Ready for Deployment', rows[3].stage, 'stage surfaced');
        System.assertEquals(40, rows[3].approvedHours, 'approved hours surfaced');
        System.assertEquals(UserInfo.getUserId(), rows[3].developerId, 'developer id surfaced');
        System.assertNotEquals(null, rows[3].developerName, 'developer name surfaced');
        System.assertEquals(null, rows[1].approvedHours, 'no approved hours comes back null, not zero');
    }

    @IsTest
    static void testInFlightBandMatchesApprovalAgenda() {
        Set<String> band = DeliveryWorkflowConfigService.getInFlightStageValues();
        System.assertEquals(DeliveryWorkflowConfigService.IN_FLIGHT_STAGES.size(), band.size(),
            'no duplicate stages in the band');
        System.assert(band.contains('Ready for Development') && band.contains('Deploying'),
            'band spans Ready for Development through Deploying');
        System.assert(!band.contains(DeliveryWorkflowConfigService.STAGE_DEPLOYED_TO_PROD),
            'Deployed to Prod is pending close-out, not in flight');
    }

    @IsTest
    static void testInFlightReportIdShapeOnly() {
        Test.startTest();
        DeliveryTriageController.getInFlightReportId();
        Test.stopTest();
        System.assert(true, 'report-id resolution did not throw');
    }

    // ── Intake feed ──────────────────────────────────────────────────

    @IsTest
    static void testIntakeReturnsUnactivatedOnly() {
        WorkItem__c external = seedIntake(new Map<String, Object>{
            'ExternalRequesterEmail__c' => 'client@example.com'
        });
        seedIntake(null); // requestedBy falls back to CreatedBy.Name
        // Noise that must NOT appear.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Backlog',
            'ActivatedDateTime__c' => Datetime.now()
        }); // activated — visible on the timeline already
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Done',
            'ActivatedDateTime__c' => null
        }); // terminal — excluded
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Backlog',
            'ActivatedDateTime__c' => null,
            'ArchivedDateTime__c' => Datetime.now()
        }); // archived — excluded
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'Backlog',
            'ActivatedDateTime__c' => null,
            'TemplateMarkedDateTime__c' => Datetime.now()
        }); // template — excluded

        Test.startTest();
        List<DeliveryTriageController.IntakeItemDTO> rows =
            DeliveryTriageController.getIntakeItems();
        Test.stopTest();

        System.assertEquals(2, rows.size(),
            'only un-activated, non-terminal, non-archived, non-template items appear');
        Map<Id, DeliveryTriageController.IntakeItemDTO> byId =
            new Map<Id, DeliveryTriageController.IntakeItemDTO>();
        for (DeliveryTriageController.IntakeItemDTO dto : rows) {
            byId.put(dto.workItemId, dto);
        }
        System.assertEquals('client@example.com', byId.get(external.Id).requestedByName,
            'external requester email is used when present');
        System.assertNotEquals(null, byId.get(external.Id).currentStage, 'current stage surfaced');
    }

    // ── markDone ─────────────────────────────────────────────────────

    @IsTest
    static void testMarkDonePartialFailureReconciles() {
        WorkItem__c wi = seedDeployed(Datetime.now().addDays(-2), null);

        // Isolate the controller's stage flip from unrelated WorkItem update-
        // trigger side-effects (the same flag the factory uses); the static
        // persists into the controller's DML.
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        Test.startTest();
        DeliveryTriageController.BulkResultDTO result =
            DeliveryTriageController.markDone(new List<Id>{ wi.Id, phantomWorkItemId() });
        Test.stopTest();

        System.assertEquals(1, result.succeededCount, 'the real item succeeded');
        System.assertEquals(1, result.failedCount, 'the phantom id is a not-found failure');
        System.assertEquals(wi.Id, result.succeededIds[0], 'succeeded id is the real item');
        WorkItem__c after = [SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :wi.Id];
        System.assertEquals('Done', after.StageNamePk__c, 'item moved to the Done terminal stage');
    }

    // ── routeToDev ───────────────────────────────────────────────────

    @IsTest
    static void testRouteToDevAssignsActivatesAndAdvances() {
        WorkItem__c wi = seedIntake(null);
        Id dev = UserInfo.getUserId();

        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        Test.startTest();
        DeliveryTriageController.BulkResultDTO result =
            DeliveryTriageController.routeToDev(new List<Id>{ wi.Id }, dev);
        Test.stopTest();

        System.assertEquals(1, result.succeededCount, 'the item routed');
        WorkItem__c after = [
            SELECT StageNamePk__c, DeveloperLookup__c, ActivatedDateTime__c
            FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('Ready for Sizing', after.StageNamePk__c, 'handed off to the start of the workflow');
        System.assertEquals(dev, after.DeveloperLookup__c, 'developer assigned');
        System.assertNotEquals(null, after.ActivatedDateTime__c,
            'activated so it becomes visible on the timeline');
    }

    // ── dismissIntake ────────────────────────────────────────────────

    @IsTest
    static void testDismissIntakeMovesToTerminalStage() {
        WorkItem__c wi = seedIntake(null);

        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        Test.startTest();
        DeliveryTriageController.BulkResultDTO result =
            DeliveryTriageController.dismissIntake(new List<Id>{ wi.Id });
        Test.stopTest();

        System.assertEquals(1, result.succeededCount, 'the item was dismissed');
        WorkItem__c after = [SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :wi.Id];
        System.assert(
            DeliveryWorkflowConfigService.getAllTerminalStageValues().contains(after.StageNamePk__c),
            'dismissed item lands in a terminal stage'
        );
    }

    // ── Guard ────────────────────────────────────────────────────────

    @IsTest
    static void testEmptySelectionThrows() {
        Test.startTest();
        Boolean threw = false;
        try {
            DeliveryTriageController.markDone(new List<Id>());
        } catch (AuraHandledException e) {
            threw = true; // never assert on the (generic) managed-package message
        }
        Test.stopTest();
        System.assert(threw, 'an empty selection is rejected');
    }

    // ────────────────────────────────────────────────────────────────────
    // Hours without approval
    // ────────────────────────────────────────────────────────────────────

    private static void stampUnapprovedFlag(Datetime cutover) {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.EnableUnapprovedHoursFlagDateTime__c = cutover;
        upsert s;
    }

    private static WorkLog__c logOn(WorkRequest__c req, Decimal hours, String status) {
        WorkLog__c wl = new WorkLog__c(
            WorkItemLookup__c = req.WorkItemId__c,
            RequestId__c = req.Id,
            HoursLoggedNumber__c = hours,
            WorkDateDate__c = Date.today(),
            StatusPk__c = status
        );
        insert wl;
        return wl;
    }

    /**
     * Seeds: Draft request with 2h + 3h after the cutover, plus one pre-cutover
     * log and one Rejected log (both excluded); an Accepted request with 4h
     * (not flagged); an Offer Sent request with 1h (flagged, but refused).
     * Returns [draftReq, acceptedReq, offerReq].
     */
    private static List<WorkRequest__c> seedUnapprovedScenario() {
        stampUnapprovedFlag(Datetime.now().addMinutes(-5));
        WorkItem__c draftItem = TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => 'In Development'
        });
        WorkItem__c acceptedItem = TestDataFactory.createWorkItem(null);
        WorkItem__c offerItem = TestDataFactory.createWorkItem(null);
        WorkRequest__c draftReq = TestDataFactory.createWorkRequest(draftItem.Id,
            new Map<String, Object>{ 'StatusPk__c' => 'Draft' });
        WorkRequest__c acceptedReq = TestDataFactory.createWorkRequest(acceptedItem.Id,
            new Map<String, Object>{ 'StatusPk__c' => 'Accepted' });
        WorkRequest__c offerReq = TestDataFactory.createWorkRequest(offerItem.Id,
            new Map<String, Object>{ 'StatusPk__c' => 'Offer Sent' });

        logOn(draftReq, 2, null);
        logOn(draftReq, 3, 'Approved');
        WorkLog__c old = logOn(draftReq, 40, null);
        Test.setCreatedDate(old.Id, Datetime.now().addDays(-30));
        logOn(draftReq, 7, 'Rejected');
        logOn(acceptedReq, 4, null);
        logOn(offerReq, 1, null);
        return new List<WorkRequest__c>{ draftReq, acceptedReq, offerReq };
    }

    @IsTest
    static void unapprovedHoursDisabledWhileFlagIsNull() {
        Test.startTest();
        DeliveryTriageController.UnapprovedHoursDTO dto = DeliveryTriageController.getUnapprovedHours();
        Test.stopTest();
        System.assertEquals(false, dto.enabled, 'card is off until the flag is stamped');
        System.assertEquals(0, dto.rows.size(), 'no rows while off');
    }

    @IsTest
    static void unapprovedHoursCountsOnlyPostCutoverUnapprovedLogs() {
        List<WorkRequest__c> reqs = seedUnapprovedScenario();
        Test.startTest();
        DeliveryTriageController.UnapprovedHoursDTO dto = DeliveryTriageController.getUnapprovedHours();
        Test.stopTest();

        System.assertEquals(true, dto.enabled, 'flag stamped = card on');
        System.assertEquals(true, dto.canApprove, 'the org admin may approve');
        System.assertEquals(2, dto.rows.size(), 'draft + offer-sent requests are flagged; accepted is not');
        System.assertEquals(6, dto.totalHours, '2h + 3h on the draft + 1h on the offer; pre-cutover and rejected excluded');
        Map<Id, DeliveryTriageController.UnapprovedHoursRowDTO> byReq =
            new Map<Id, DeliveryTriageController.UnapprovedHoursRowDTO>();
        for (DeliveryTriageController.UnapprovedHoursRowDTO row : dto.rows) {
            byReq.put(row.requestId, row);
        }
        System.assertEquals(5, byReq.get(reqs[0].Id).hours, 'draft request carries 5 post-cutover hours');
        System.assertEquals(2, byReq.get(reqs[0].Id).logCount, 'two post-cutover, non-rejected logs');
        System.assertEquals(true, byReq.get(reqs[0].Id).canAcknowledge, 'a Draft can be approved from Home');
        System.assertEquals(false, byReq.get(reqs[2].Id).canAcknowledge, 'Offer Sent is decided in Pending Work Approvals');
        System.assertEquals(reqs[0].Id, dto.rows[0].requestId, 'biggest block of hours first');
    }

    @IsTest
    static void acknowledgeAcceptsRequestWithoutTouchingTheItem() {
        List<WorkRequest__c> reqs = seedUnapprovedScenario();
        WorkItem__c before = [
            SELECT StageNamePk__c, ClientPreApprovedHoursNumber__c FROM WorkItem__c
            WHERE Id = :reqs[0].WorkItemId__c
        ];
        Id phantomRequest = Id.valueOf(
            WorkRequest__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000');

        Test.startTest();
        DeliveryTriageController.BulkResultDTO result = DeliveryTriageController.acknowledgeUnapprovedHours(
            new List<Id>{ reqs[0].Id, reqs[1].Id, reqs[2].Id, phantomRequest });
        Test.stopTest();

        System.assertEquals(2, result.succeededCount, 'draft flipped + already-accepted is an idempotent success');
        System.assertEquals(2, result.failedCount, 'offer-sent refused + phantom not found');
        WorkRequest__c draftAfter = [
            SELECT StatusPk__c, DecisionDateTime__c, ApproverUserLookup__c FROM WorkRequest__c WHERE Id = :reqs[0].Id
        ];
        System.assertEquals('Accepted', draftAfter.StatusPk__c, 'hours approved = request Accepted');
        System.assertNotEquals(null, draftAfter.DecisionDateTime__c, 'decision time stamped');
        System.assertEquals(UserInfo.getUserId(), draftAfter.ApproverUserLookup__c, 'approver stamped');
        System.assertEquals('Offer Sent', [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :reqs[2].Id].StatusPk__c,
            'an Offer Sent request is not pulled out of the approval queue');
        WorkItem__c after = [
            SELECT StageNamePk__c, ClientPreApprovedHoursNumber__c FROM WorkItem__c
            WHERE Id = :reqs[0].WorkItemId__c
        ];
        System.assertEquals(before.StageNamePk__c, after.StageNamePk__c, 'the work item stage must not change');
        System.assertEquals(before.ClientPreApprovedHoursNumber__c, after.ClientPreApprovedHoursNumber__c,
            'the client cap must not change');
        System.assertEquals(1, [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Work_Approval' AND RecordIdTxt__c = :String.valueOf(reqs[0].WorkItemId__c)
        ], 'one Work_Approval audit row for the acknowledged request');

        DeliveryTriageController.UnapprovedHoursDTO dto = DeliveryTriageController.getUnapprovedHours();
        System.assertEquals(1, dto.rows.size(), 'only the Offer Sent request is still flagged');
    }

    @IsTest
    static void acknowledgeRequiresApproverOrAdmin() {
        List<WorkRequest__c> reqs = seedUnapprovedScenario();
        DeliveryAccessService.adminOverride = false;
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryTriageController.acknowledgeUnapprovedHours(new List<Id>{ reqs[0].Id });
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'a non-approver, non-admin caller is refused');
        System.assertEquals('Draft', [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :reqs[0].Id].StatusPk__c,
            'nothing changed');
    }
}
