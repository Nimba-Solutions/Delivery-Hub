/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the PR5 client-approved-cap gate at WorkLog time:
 *               under-cap logging passes untouched; over-cap logging is
 *               hard-blocked when EnforceApprovalCapDateTime__c is set and
 *               allowed-but-flagged (newest Accepted request → Budget Hold)
 *               when it is null (the default); uncapped items are never
 *               evaluated; bulk batches only error the offending rows; and the
 *               shipped requestIncrease → approve flow raises the cap so the
 *               same insert passes afterwards.
 *
 *               Seeds data via TestDataFactory (createWorkItem /
 *               createWorkRequest / createWorkLog) and configures the gate
 *               through DeliveryHubSettings__c org defaults — the same
 *               settings idiom as DeliveryWorkApprovalServiceTest.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkCapEnforcementServiceTest {

    private static final Decimal CAP = 10;

    /**
     * @description Writes the cap-gate org-default settings.
     * @param enforceOn true stamps EnforceApprovalCapDateTime__c (hard-block
     *        mode); false leaves it null (flag mode, the shipping default).
     * @param approverId Default approver User ID (null = no approver target).
     */
    private static void configureSettings(Boolean enforceOn, Id approverId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnforceApprovalCapDateTime__c = enforceOn ? Datetime.now() : null;
        settings.ApproverUserIdTxt__c = approverId == null ? null : String.valueOf(approverId);
        upsert settings;
    }

    /**
     * @description Seeds a WorkItem carrying the standard 10h client-approved cap.
     * @return The inserted capped WorkItem__c.
     */
    private static WorkItem__c cappedItem() {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'ClientPreApprovedHoursNumber__c' => CAP
        });
    }

    // ────────────────────────────────────────────────────────────────────
    // ENFORCE MODE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description An under-cap insert passes untouched even with hard
     *              enforcement on — no error, no Budget Hold side effect.
     */
    @IsTest
    static void testUnderCapInsertPasses() {
        configureSettings(true, null);
        WorkItem__c wi = cappedItem();

        Test.startTest();
        TestDataFactory.createWorkLog(wi.Id, 4, null, null);
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id
        ], 'under-cap log saves normally');
        System.assertEquals(0, [
            SELECT COUNT() FROM WorkRequest__c
            WHERE WorkItemId__c = :wi.Id
            AND StatusPk__c = :DeliveryWorkCapEnforcementService.REQUEST_BUDGET_HOLD
        ], 'no Budget Hold side effect for an under-cap log');
    }

    /**
     * @description With enforcement ON, an insert that pushes the live total
     *              over the cap is blocked with addError — the row never
     *              commits and the message points at the budget-increase path.
     */
    @IsTest
    static void testOverCapInsertBlockedWhenEnforcementOn() {
        configureSettings(true, null);
        WorkItem__c wi = cappedItem();
        TestDataFactory.createWorkLog(wi.Id, 8, null, null); // 8 of 10

        Boolean threw = false;
        String message;
        Test.startTest();
        try {
            TestDataFactory.createWorkLog(wi.Id, 5, null, null); // would be 13 of 10
        } catch (DmlException e) {
            threw = true;
            message = e.getMessage();
        }
        Test.stopTest();

        System.assert(threw, 'over-cap insert must be blocked when enforcement is on');
        System.assert(message.contains('client-approved cap'),
            'error explains the cap: ' + message);
        System.assert(message.contains('budget increase'),
            'error points at the requestIncrease unblock path: ' + message);
        System.assertEquals(1, [
            SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id
        ], 'the blocked row never committed');
    }

    /**
     * @description With enforcement ON, raising an existing log's hours past
     *              the cap is blocked in before update.
     */
    @IsTest
    static void testOverCapUpdateBlockedWhenEnforcementOn() {
        configureSettings(true, null);
        WorkItem__c wi = cappedItem();
        WorkLog__c log = TestDataFactory.createWorkLog(wi.Id, 8, null, null);

        Boolean threw = false;
        Test.startTest();
        try {
            log.HoursLoggedNumber__c = 12;
            update log;
        } catch (DmlException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'raising hours past the cap must be blocked on update');
        System.assertEquals(8, [
            SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE Id = :log.Id
        ].HoursLoggedNumber__c, 'the original hours survive the blocked update');
    }

    /**
     * @description Items with a null cap are uncapped — never evaluated, even
     *              with enforcement on and a huge log.
     */
    @IsTest
    static void testUncappedItemNeverEnforced() {
        configureSettings(true, null);
        WorkItem__c wi = TestDataFactory.createWorkItem(null); // no cap

        Test.startTest();
        TestDataFactory.createWorkLog(wi.Id, 100, null, null);
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id
        ], 'uncapped items take any hours — null cap means unenforced');
    }

    /**
     * @description Bulk partial save: a mixed batch only errors the rows that
     *              push their item over the cap — under-cap rows on the same
     *              item and rows on uncapped items still save. The running
     *              total accumulates WITHIN the batch (6h passes, the second
     *              6h on the same 10h item fails).
     */
    @IsTest
    static void testBulkMixedBatchOnlyErrorsOffendingRows() {
        configureSettings(true, null);
        WorkItem__c capped = cappedItem();
        WorkItem__c uncapped = TestDataFactory.createWorkItem(null);
        List<WorkLog__c> rows = new List<WorkLog__c>{
            TestDataFactory.buildWorkLog(capped.Id, 6, null, null),
            TestDataFactory.buildWorkLog(capped.Id, 6, null, null),  // 12 of 10 → blocked
            TestDataFactory.buildWorkLog(uncapped.Id, 20, null, null)
        };

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(rows, false);
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess(),
            'first 6h on the 10h item fits and saves');
        System.assertEquals(false, results[1].isSuccess(),
            'second 6h on the same item breaches the cap and is blocked');
        System.assert(results[1].getErrors()[0].getMessage().contains('client-approved cap'),
            'the offending row carries the cap error');
        System.assertEquals(true, results[2].isSuccess(),
            'uncapped-item row is untouched by the gate');
        System.assertEquals(1, [
            SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :capped.Id
        ], 'only the fitting row committed on the capped item');
    }

    /**
     * @description The acceptance loop: a blocked insert passes after the
     *              shipped requestIncrease → approve flow raises the cap by
     *              the approved delta (the budget increase re-enters the queue
     *              for the delta only).
     */
    @IsTest
    static void testIncreaseThenApprovePassesAfterCapRaise() {
        configureSettings(true, null);
        WorkItem__c wi = cappedItem();
        TestDataFactory.createWorkLog(wi.Id, 8, null, null); // 8 of 10

        Boolean threwBefore = false;
        try {
            TestDataFactory.createWorkLog(wi.Id, 5, null, null);
        } catch (DmlException e) {
            threwBefore = true;
        }
        System.assert(threwBefore, 'insert is blocked while the cap is 10h');

        Test.startTest();
        Id increaseId = DeliveryWorkApprovalService.requestIncrease(
            wi.Id, 10, 'Cap reached — need the delta to finish');
        DeliveryWorkApprovalService.approve(increaseId, null, 'granting the delta');
        TestDataFactory.createWorkLog(wi.Id, 5, null, null); // 13 of 20 now
        Test.stopTest();

        System.assertEquals(20, [
            SELECT ClientPreApprovedHoursNumber__c FROM WorkItem__c WHERE Id = :wi.Id
        ].ClientPreApprovedHoursNumber__c, 'approve raised the cap 10 + 10 = 20');
        System.assertEquals(2, [
            SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id
        ], 'the same 5h insert passes once the raised cap covers it');
    }

    // ────────────────────────────────────────────────────────────────────
    // FLAG MODE (the default)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description With enforcement OFF (the default), an over-cap insert
     *              SAVES, and the item's newest Accepted request is moved to
     *              Budget Hold while the approver/developer notification is
     *              enqueued — flag, don't block.
     */
    @IsTest
    static void testOverCapFlagModeInsertsAndFlipsBudgetHold() {
        configureSettings(false, UserInfo.getUserId());
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'ClientPreApprovedHoursNumber__c' => CAP,
            'DeveloperLookup__c' => UserInfo.getUserId()
        });
        WorkRequest__c accepted = TestDataFactory.createWorkRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => DeliveryWorkCapEnforcementService.REQUEST_ACCEPTED,
            'QuotedHoursNumber__c' => CAP
        });

        Test.startTest();
        TestDataFactory.createWorkLog(wi.Id, 12, null, null); // 12 of 10 — over
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id
        ], 'flag mode lets the over-cap log save');
        System.assertEquals(
            DeliveryWorkCapEnforcementService.REQUEST_BUDGET_HOLD,
            [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :accepted.Id].StatusPk__c,
            'the Accepted request is parked at Budget Hold for re-entry via requestIncrease');
    }

    /**
     * @description An edit that does not touch hours or the parent item on an
     *              ALREADY over-cap log is never blocked, even after hard
     *              enforcement is switched on — only changes that can move a
     *              total are evaluated.
     */
    @IsTest
    static void testNonHoursUpdateOnOverCapItemNotBlocked() {
        configureSettings(false, null); // flag mode lets the over-cap row in
        WorkItem__c wi = cappedItem();
        WorkLog__c log = TestDataFactory.createWorkLog(wi.Id, 12, null, null);
        configureSettings(true, null); // now hard-block is on

        Test.startTest();
        log.WorkDescriptionTxt__c = 'clarified the work narrative';
        update log;
        Test.stopTest();

        System.assertEquals('clarified the work narrative', [
            SELECT WorkDescriptionTxt__c FROM WorkLog__c WHERE Id = :log.Id
        ].WorkDescriptionTxt__c, 'a non-hours edit on an over-cap item still saves');
    }
}
