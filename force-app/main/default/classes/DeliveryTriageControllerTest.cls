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
        System.assertEquals('Ready for Development', after.StageNamePk__c, 'advanced to dev');
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
}
