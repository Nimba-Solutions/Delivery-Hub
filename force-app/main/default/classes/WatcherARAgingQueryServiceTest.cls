/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for WatcherARAgingQueryService. Seeds
 *              DeliveryDocument__c Invoice rows (Master-Detail to
 *              NetworkEntity__c) with explicit Status / DueDate / Total
 *              values and asserts the resulting SignalResultDTO shape.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherARAgingQueryServiceTest {

    /**
     * @description Happy path: 3 overdue invoices spanning aging bands →
     *              primaryCount=3, secondaryCount aggregates the totals,
     *              top entries surface highest-dollar first.
     */
    @IsTest
    static void testHappyPathReturnsCountsAndTopEntries() {
        configureMinDaysOverdue(7);
        NetworkEntity__c client = TestDataFactory.defaultClient();
        // Spread across the aging bands.
        seedInvoice(client.Id, Date.today().addDays(-10), 200, 'Overdue');   // 8-14 band
        seedInvoice(client.Id, Date.today().addDays(-20), 800, 'Overdue');   // 15-30 band
        seedInvoice(client.Id, Date.today().addDays(-45), 1500, 'Overdue');  // 30+ band

        Test.startTest();
        SignalResultDTO result = WatcherARAgingQueryService.query();
        Test.stopTest();

        System.assertEquals('ARAging', result.signalName, 'signalName should be ARAging');
        System.assertEquals(3, result.primaryCount,
            'Three eligible overdue invoices should be counted');
        System.assertEquals(2500, result.secondaryCount,
            'secondaryCount should sum the seeded amounts (200+800+1500=2500)');
        System.assertEquals(3, result.topEntries.size(),
            'topEntries should surface all 3 invoices (under TOP_ENTRY_CAP)');
        SignalEntryDTO first = result.topEntries.get(0);
        System.assertNotEquals(null, first.recordId, 'Entry should carry the invoice Id');
        System.assert(String.isNotBlank(first.detailLine),
            'Entry detail should be populated, got: ' + first.detailLine);
    }

    /**
     * @description Disputed invoices must be excluded by the StatusPk__c='Disputed'
     *              picklist value — Disputed and Overdue are mutually exclusive
     *              status values, so disputed docs never reach this signal. The
     *              prior DisputeReasonTxt__c=NULL belt-and-suspenders predicate
     *              was removed because LongTextArea fields can't be filtered
     *              in SOQL (platform rejection).
     */
    @IsTest
    static void testDisputedInvoicesAreExcluded() {
        configureMinDaysOverdue(7);
        NetworkEntity__c client = TestDataFactory.defaultClient();
        // Eligible.
        seedInvoice(client.Id, Date.today().addDays(-15), 500, 'Overdue');
        // Status=Disputed → excluded by status filter.
        seedInvoice(client.Id, Date.today().addDays(-15), 800, 'Disputed');

        Test.startTest();
        SignalResultDTO result = WatcherARAgingQueryService.query();
        Test.stopTest();

        System.assertEquals(1, result.primaryCount,
            'Only the clean Overdue invoice should surface — got ' + result.primaryCount);
        System.assertEquals(500, result.secondaryCount,
            'Sum should reflect only the clean invoice');
    }

    /**
     * @description Superseded invoices (Status='Superseded') must be
     *              excluded by the status filter — they are not 'Overdue'
     *              so the WHERE clause filters them out automatically.
     */
    @IsTest
    static void testSupersededInvoicesAreExcluded() {
        configureMinDaysOverdue(7);
        NetworkEntity__c client = TestDataFactory.defaultClient();
        seedInvoice(client.Id, Date.today().addDays(-10), 300, 'Overdue');
        seedInvoice(client.Id, Date.today().addDays(-10), 600, 'Superseded');

        Test.startTest();
        SignalResultDTO result = WatcherARAgingQueryService.query();
        Test.stopTest();

        System.assertEquals(1, result.primaryCount,
            'Only the Overdue invoice should surface — Superseded must be filtered');
        System.assertEquals(300, result.secondaryCount,
            'Sum should match the single Overdue row');
    }

    /**
     * @description Invoices below the min-days-overdue threshold must NOT
     *              surface. Default threshold is 7; a 3-days-overdue
     *              invoice should fail the cutoff.
     */
    @IsTest
    static void testBelowThresholdInvoicesAreExcluded() {
        configureMinDaysOverdue(7);
        NetworkEntity__c client = TestDataFactory.defaultClient();
        seedInvoice(client.Id, Date.today().addDays(-3), 100, 'Overdue');  // below 7-day floor
        seedInvoice(client.Id, Date.today().addDays(-15), 400, 'Overdue'); // above threshold

        Test.startTest();
        SignalResultDTO result = WatcherARAgingQueryService.query();
        Test.stopTest();

        System.assertEquals(1, result.primaryCount,
            'Only the 15-day-overdue invoice should surface — 3-day-overdue must be excluded');
        System.assertEquals(400, result.secondaryCount,
            'Sum should reflect only the past-threshold invoice');
    }

    /**
     * @description Empty path: no overdue invoices → zero counts, no entries.
     */
    @IsTest
    static void testEmptyResultZeroCounts() {
        configureMinDaysOverdue(7);
        NetworkEntity__c client = TestDataFactory.defaultClient();
        // Seed a non-overdue invoice to prove the filter excludes it.
        seedInvoice(client.Id, Date.today().addDays(10), 100, 'Sent');

        Test.startTest();
        SignalResultDTO result = WatcherARAgingQueryService.query();
        Test.stopTest();

        System.assertEquals(0, result.primaryCount, 'No overdue invoices → zero primaryCount');
        System.assertEquals(0, result.secondaryCount, 'No overdue invoices → zero secondaryCount');
        System.assertEquals(0, result.topEntries.size(), 'Empty result → empty topEntries');
    }

    /**
     * @description Aging band classification helper should bucket correctly.
     */
    @IsTest
    static void testClassifyAgingBandBuckets() {
        System.assertEquals('1-7', WatcherARAgingQueryService.classifyAgingBand(5),
            '5 days overdue should land in 1-7 band');
        System.assertEquals('8-14', WatcherARAgingQueryService.classifyAgingBand(10),
            '10 days overdue should land in 8-14 band');
        System.assertEquals('15-30', WatcherARAgingQueryService.classifyAgingBand(20),
            '20 days overdue should land in 15-30 band');
        System.assertEquals('30+', WatcherARAgingQueryService.classifyAgingBand(45),
            '45 days overdue should land in 30+ band');
    }

    /**
     * @description Top-entry order: highest TotalCurrency__c should sort first.
     */
    @IsTest
    static void testTopEntriesOrderedByAmountDesc() {
        configureMinDaysOverdue(7);
        NetworkEntity__c client = TestDataFactory.defaultClient();
        seedInvoice(client.Id, Date.today().addDays(-10), 100, 'Overdue');
        seedInvoice(client.Id, Date.today().addDays(-10), 2000, 'Overdue');
        seedInvoice(client.Id, Date.today().addDays(-10), 500, 'Overdue');

        Test.startTest();
        SignalResultDTO result = WatcherARAgingQueryService.query();
        Test.stopTest();

        System.assertEquals(3, result.primaryCount, 'All three invoices should surface');
        System.assertEquals(3, result.topEntries.size(), 'All three should appear in topEntries');
        // Order check: detailLine should embed the highest amount first.
        System.assert(result.topEntries.get(0).detailLine.contains('2,000')
                || result.topEntries.get(0).detailLine.contains('2000'),
            'First topEntries entry should be the $2000 invoice — got: '
                + result.topEntries.get(0).detailLine);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Configures the org-default WatcherARAgingMinDaysOverdueNumber__c
     *              for the test. Inserts the settings row if absent.
     * @param days Threshold value.
     */
    private static void configureMinDaysOverdue(Integer days) {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        if (s == null) {
            s = new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        s.WatcherARAgingMinDaysOverdueNumber__c = days;
        upsert s;
    }

    /**
     * @description Inserts a DeliveryDocument__c Invoice with the supplied
     *              due date / amount / status.
     * @param entityId NetworkEntity__c Master-Detail parent.
     * @param dueDate  DueDateDate__c value.
     * @param amount   TotalCurrency__c value.
     * @param status   StatusPk__c value.
     * @return Inserted DeliveryDocument__c.
     */
    private static DeliveryDocument__c seedInvoice(Id entityId, Date dueDate, Decimal amount, String status) {
        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c = entityId,
            TemplatePk__c = 'Invoice',
            StatusPk__c = status,
            DueDateDate__c = dueDate,
            TotalCurrency__c = amount
        );
        insert doc;
        return doc;
    }

}
