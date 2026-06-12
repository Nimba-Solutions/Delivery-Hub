/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the monthly billing close-out feed (approval-queue
 *               spec §9 — Approved vs Logged vs Billable): the v1 billable
 *               formula billable = MIN(monthLogged, MAX(0, cap −
 *               loggedBefore)) including partial headroom and fully-exhausted
 *               caps, month-window scoping (prior-month logs reduce headroom,
 *               other-month logs never count as month activity), exclusion of
 *               uncapped items and zero-activity rows, totals accumulation,
 *               the blended-rate dollar figure (single active rated entity →
 *               dollars; ambiguous → hours-only), null-param defaulting to
 *               the current month, invalid-month rejection, and empty-org
 *               zero defaults. All month math is anchored on Date.today()
 *               (see feedback_anchor_rolling_window_tests_on_today.md).
 *               Exception assertions are type-only — never on message
 *               (AuraHandledException.getMessage() is generic in a managed
 *               package per CLAUDE.md).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryBillingPreviewControllerTest {

    /**
     * @description Start of the current calendar month — the test anchor.
     * @return First day of the current month.
     */
    private static Date monthStart() {
        return Date.today().toStartOfMonth();
    }

    /**
     * @description A date safely inside the PRIOR calendar month.
     * @return The last day of the previous month.
     */
    private static Date priorMonthDate() {
        return monthStart().addDays(-1);
    }

    /**
     * @description Seeds a WorkItem__c with an optional client-approved cap.
     * @param cap ClientPreApprovedHoursNumber__c value (null = uncapped).
     * @return The inserted item.
     */
    private static WorkItem__c seedItem(Decimal cap) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'ClientPreApprovedHoursNumber__c' => cap
        });
    }

    /**
     * @description Runs getBillingPreview for the current calendar month.
     * @return The controller's BillingPreviewDTO for the current month.
     */
    private static DeliveryBillingPreviewController.BillingPreviewDTO runCurrentMonth() {
        Date anchor = monthStart();
        return DeliveryBillingPreviewController.getBillingPreview(anchor.year(), anchor.month());
    }

    /**
     * @description Prior-month consumption shrinks the cap headroom: cap 10,
     *              4h logged last month, 8h logged this month → only 6h of
     *              this month's work is billable, 2h is over-cap excess.
     */
    @IsTest
    static void testBillableCappedAtRemainingHeadroom() {
        WorkItem__c wi = seedItem(10);
        TestDataFactory.createWorkLog(wi.Id, 4, priorMonthDate(), null);
        TestDataFactory.createWorkLog(wi.Id, 8, Date.today(), null);

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        System.assertEquals(1, dto.rows.size(), 'one capped item logged this month');
        DeliveryBillingPreviewController.BillingRowDTO row = dto.rows[0];
        System.assertEquals(10, row.approvedCap, 'cap carried through');
        System.assertEquals(4, row.loggedBefore, 'prior-month hours consumed headroom');
        System.assertEquals(8, row.monthLogged, 'this month\'s logged hours');
        System.assertEquals(6, row.billable, 'MIN(8, MAX(0, 10-4)) = 6 billable');
        System.assertEquals(2, row.overCap, '8 logged - 6 billable = 2 over-cap');
        System.assertEquals(true, row.isOverCap, 'row flagged over-cap');
    }

    /**
     * @description Under-cap work is fully billable with zero over-cap.
     */
    @IsTest
    static void testFullyBillableWhenUnderCap() {
        WorkItem__c wi = seedItem(20);
        TestDataFactory.createWorkLog(wi.Id, 5, Date.today(), null);

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        System.assertEquals(1, dto.rows.size(), 'one row');
        DeliveryBillingPreviewController.BillingRowDTO row = dto.rows[0];
        System.assertEquals(5, row.billable, 'all 5h fit under the 20h cap');
        System.assertEquals(0, row.overCap, 'no excess');
        System.assertEquals(false, row.isOverCap, 'not flagged');
    }

    /**
     * @description A cap already exhausted before the month starts makes ALL
     *              of this month's hours non-billable (headroom clamps at 0 —
     *              never negative).
     */
    @IsTest
    static void testExhaustedCapMakesMonthNonBillable() {
        WorkItem__c wi = seedItem(5);
        TestDataFactory.createWorkLog(wi.Id, 6, priorMonthDate(), null);
        TestDataFactory.createWorkLog(wi.Id, 3, Date.today(), null);

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        DeliveryBillingPreviewController.BillingRowDTO row = dto.rows[0];
        System.assertEquals(0, row.billable, 'headroom MAX(0, 5-6) = 0 → nothing billable');
        System.assertEquals(3, row.overCap, 'all 3h parked as over-cap');
        System.assertEquals(true, row.isOverCap, 'row flagged over-cap');
    }

    /**
     * @description Uncapped items never appear (even with month activity), and
     *              capped items with logs only OUTSIDE the month produce no row
     *              — but still count in cappedItemCount.
     */
    @IsTest
    static void testScopeExcludesUncappedAndZeroActivityItems() {
        WorkItem__c uncapped = seedItem(null);
        TestDataFactory.createWorkLog(uncapped.Id, 7, Date.today(), null);
        WorkItem__c quietCapped = seedItem(15);
        TestDataFactory.createWorkLog(quietCapped.Id, 2, priorMonthDate(), null);
        WorkItem__c active = seedItem(10);
        TestDataFactory.createWorkLog(active.Id, 1, Date.today(), null);

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        System.assertEquals(2, dto.cappedItemCount, 'both capped items counted in the universe');
        System.assertEquals(1, dto.rows.size(), 'only the capped item with month activity gets a row');
        System.assertEquals(active.Id, dto.rows[0].workItemId, 'the active capped item is the row');
    }

    /**
     * @description Totals sum across rows, and rows order by monthLogged desc.
     */
    @IsTest
    static void testTotalsAggregateAndRowsSortByMonthLoggedDesc() {
        WorkItem__c small = seedItem(10);
        TestDataFactory.createWorkLog(small.Id, 2, Date.today(), null);
        WorkItem__c big = seedItem(4);
        TestDataFactory.createWorkLog(big.Id, 6, Date.today(), null); // 4 billable + 2 over

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        System.assertEquals(2, dto.rows.size(), 'two rows');
        System.assertEquals(big.Id, dto.rows[0].workItemId, 'biggest month-logged row leads');
        System.assertEquals(14, dto.totalApprovedCap, '10 + 4 caps across rows');
        System.assertEquals(8, dto.totalMonthLogged, '2 + 6 logged this month');
        System.assertEquals(6, dto.totalBillable, '2 + MIN(6, 4) billable');
        System.assertEquals(2, dto.totalOverCap, 'the over-cap excess');
    }

    /**
     * @description Exactly one active rated NetworkEntity resolves the blended
     *              rate and prices the billable total; the dollar figure is
     *              totalBillable × rate.
     */
    @IsTest
    static void testSingleRatedEntityResolvesDollars() {
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 90
        });
        WorkItem__c wi = seedItem(10);
        TestDataFactory.createWorkLog(wi.Id, 4, Date.today(), null);

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        System.assertEquals(90, dto.blendedRate, 'the single active rate resolves');
        System.assertEquals(360, dto.totalBillableAmount, '4 billable hours × $90');
    }

    /**
     * @description Two distinct rated entities are ambiguous: no blended rate,
     *              no dollar figure — hours-only display.
     */
    @IsTest
    static void testAmbiguousRatesYieldHoursOnly() {
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 90
        });
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 120
        });
        WorkItem__c wi = seedItem(10);
        TestDataFactory.createWorkLog(wi.Id, 4, Date.today(), null);

        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto = runCurrentMonth();
        Test.stopTest();

        System.assertEquals(null, dto.blendedRate, 'many rates → ambiguous → null');
        System.assertEquals(null, dto.totalBillableAmount, 'no dollar figure without a rate');
    }

    /**
     * @description Null params default to the current calendar month, and an
     *              empty org returns zero totals + an empty row list (never
     *              nulls).
     */
    @IsTest
    static void testNullParamsDefaultToCurrentMonthWithZeroDefaults() {
        Test.startTest();
        DeliveryBillingPreviewController.BillingPreviewDTO dto =
            DeliveryBillingPreviewController.getBillingPreview(null, null);
        Test.stopTest();

        System.assertEquals(Date.today().year(), dto.year, 'defaults to the current year');
        System.assertEquals(Date.today().month(), dto.month, 'defaults to the current month');
        System.assertEquals(0, dto.rows.size(), 'empty org → no rows');
        System.assertEquals(0, dto.cappedItemCount, 'zero default, not null');
        System.assertEquals(0, dto.totalApprovedCap, 'zero default, not null');
        System.assertEquals(0, dto.totalMonthLogged, 'zero default, not null');
        System.assertEquals(0, dto.totalBillable, 'zero default, not null');
        System.assertEquals(0, dto.totalOverCap, 'zero default, not null');
        System.assertNotEquals(null, dto.monthLabel, 'month label always present');
    }

    /**
     * @description An out-of-range month is rejected. Type-only assertion —
     *              the exception message is generic in a managed package.
     */
    @IsTest
    static void testInvalidMonthThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryBillingPreviewController.getBillingPreview(2026, 13);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'month 13 rejected with AuraHandledException');
    }
}
