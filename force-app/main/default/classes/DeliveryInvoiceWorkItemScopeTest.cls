/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests the F13 fix: an Invoice's WORK ITEMS section must display
 *              period-scoped hours (so the line items reconcile to the billed
 *              period total), not each work item's all-time TotalLoggedHoursSum__c.
 *              Work items with no billable hours in the period are omitted entirely.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryInvoiceWorkItemScopeTest {

    @IsTest
    static void testWorkItemsSectionIsPeriodScopedAndReconciles() {
        DeliveryTriggerControl.disableAfterLogic();
        Date pStart = Date.newInstance(2026, 3, 1);
        Date pEnd = Date.newInstance(2026, 3, 31);

        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Scope Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 150
        );
        insert client;

        // WI1: 8h in-period + 4h before the period → all-time 12h, in-period 8h.
        WorkItem__c wi1 = new WorkItem__c(
            BriefDescriptionTxt__c = 'In-period WI',
            StageNamePk__c = 'In Development',
            StatusPk__c = 'Active',
            PriorityPk__c = 'High',
            ActivatedDateTime__c = Datetime.now(),
            ClientNetworkEntityLookup__c = client.Id,
            BillableRateCurrency__c = 150
        );
        // WI2: only out-of-period hours → in-period 0h, must be omitted from the invoice.
        WorkItem__c wi2 = new WorkItem__c(
            BriefDescriptionTxt__c = 'Out-of-period WI',
            StageNamePk__c = 'In Development',
            StatusPk__c = 'Active',
            PriorityPk__c = 'Medium',
            ActivatedDateTime__c = Datetime.now(),
            ClientNetworkEntityLookup__c = client.Id,
            BillableRateCurrency__c = 150
        );
        insert new List<WorkItem__c>{ wi1, wi2 };

        // buildWorkLog auto-mints the required WorkRequest__c master (RequestId__c)
        // per WI and caches it — a raw `new WorkLog__c` omits that master-detail and
        // fails REQUIRED_FIELD_MISSING during package-version test runs.
        insert new List<WorkLog__c>{
            TestDataFactory.buildWorkLog(wi1.Id, 8, Date.newInstance(2026, 3, 10),
                new Map<String, Object>{ 'WorkDescriptionTxt__c' => 'in', 'StatusPk__c' => 'Approved' }),
            TestDataFactory.buildWorkLog(wi1.Id, 4, Date.newInstance(2026, 2, 10),
                new Map<String, Object>{ 'WorkDescriptionTxt__c' => 'before', 'StatusPk__c' => 'Approved' }),
            TestDataFactory.buildWorkLog(wi2.Id, 5, Date.newInstance(2026, 2, 15),
                new Map<String, Object>{ 'WorkDescriptionTxt__c' => 'before', 'StatusPk__c' => 'Approved' })
        };
        DeliveryTriggerControl.enableAfterLogic();

        Test.startTest();
        Map<String, Object> snap = DeliveryDocGenerationService.buildSnapshot(
            client.Id, 'Invoice', pStart, pEnd);
        Test.stopTest();

        List<Object> items = (List<Object>) snap.get('workItems');
        System.assertEquals(1, items.size(),
            'Only the work item with in-period billable hours should appear on the invoice (out-of-period WI omitted)');

        Map<String, Object> shown = (Map<String, Object>) items[0];
        System.assertEquals(wi1.Id, (Id) shown.get('id'),
            'The in-period work item should be the one shown');
        Decimal shownHours = (Decimal) shown.get('totalLoggedHours');
        System.assert(shownHours == 8,
            'WORK ITEMS hours must be period-scoped (8h), not all-time (12h). Got: ' + shownHours);

        // Reconciliation: the line-item hours now tie out to the period total.
        Decimal periodTotal = DeliveryDocGenerationService.calculateTotalHours(snap);
        System.assert(periodTotal == 8,
            'Period total should be the 8 in-period hours. Got: ' + periodTotal);
        System.assert(periodTotal == shownHours,
            'WORK ITEMS line item must reconcile to the period total (' + periodTotal + ' vs ' + shownHours + ')');
    }
}
