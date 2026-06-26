/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests the missing-billable detector
 *              (DeliveryHubHealthService.StaleInvoiceCheck). An invoice freezes a
 *              tamper-evident snapshot at generation; if an in-period billable
 *              WorkLog lands afterward, nothing tells the biller to regenerate and
 *              the client is silently under-billed. The check rebuilds each
 *              invoice's period snapshot with the generator's own scoping and warns
 *              when current period hours exceed the frozen TotalHoursNumber__c.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryStaleInvoiceCheckTest {

    private static final String CHECK_KEY = 'staleInvoices';
    private static final String CHECK_LABEL = 'Invoices Pending Re-bill';

    /**
     * @description Builds a Client entity + one WorkItem with the supplied approved
     *              in-period billable logs. Mirrors DeliveryDocGenerationServiceTest's
     *              proven setup so the generator scopes the data correctly.
     * @param hours Hours for each approved WorkLog to create.
     * @param pStart Period start the logs are dated within.
     * @return The inserted Client NetworkEntity__c.
     */
    private static NetworkEntity__c seedClientWithLogs(List<Decimal> hours, Date pStart) {
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Stale Invoice Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 150
        );
        insert client;

        WorkItem__c item = new WorkItem__c(
            BriefDescriptionTxt__c = 'Billable WI',
            StageNamePk__c = 'In Development',
            StatusPk__c = 'Active',
            PriorityPk__c = 'High',
            ActivatedDateTime__c = Datetime.now(),
            ClientNetworkEntityLookup__c = client.Id
        );
        insert item;

        // buildWorkLog auto-mints+caches the required WorkRequest__c master
        // (RequestId__c) for the WI; a raw `new WorkLog__c` omits it and fails
        // REQUIRED_FIELD_MISSING during package-version test runs.
        List<WorkLog__c> logs = new List<WorkLog__c>();
        Integer i = 0;
        for (Decimal h : hours) {
            logs.add(TestDataFactory.buildWorkLog(
                item.Id, h, pStart.addDays(5 + i),
                new Map<String, Object>{
                    'WorkDescriptionTxt__c' => 'work',
                    'StatusPk__c' => 'Approved'
                }
            ));
            i++;
        }
        insert logs;
        return client;
    }

    @IsTest
    static void testWarnsWhenBillableLogsAfterGeneration() {
        DeliveryTriggerControl.disableAfterLogic();
        Date pStart = Date.newInstance(2026, 1, 1);
        Date pEnd = Date.newInstance(2026, 1, 31);
        NetworkEntity__c client = seedClientWithLogs(new List<Decimal>{ 5 }, pStart);
        DeliveryTriggerControl.enableAfterLogic();

        Test.startTest();
        // Freeze the invoice at the current 5h.
        DeliveryDocGenerationService.generateDocument(client.Id, 'Invoice', pStart, pEnd, null);

        // A late billable lands in-period AFTER the invoice froze.
        DeliveryTriggerControl.disableAfterLogic();
        WorkItem__c wi = [SELECT Id FROM WorkItem__c WHERE ClientNetworkEntityLookup__c = :client.Id LIMIT 1];
        insert TestDataFactory.buildWorkLog(
            wi.Id, 3, pStart.addDays(20),
            new Map<String, Object>{
                'WorkDescriptionTxt__c' => 'late entry',
                'StatusPk__c' => 'Approved'
            }
        );
        DeliveryTriggerControl.enableAfterLogic();

        DeliveryHubHealthCheckResult r = new DeliveryHubHealthService.StaleInvoiceCheck()
            .run(CHECK_KEY, CHECK_LABEL);
        Test.stopTest();

        System.assertEquals('warn', r.statusPk,
            'An invoice with 3h logged after generation should warn. Detail: ' + r.detail);
        System.assert(r.detail.containsIgnoreCase('unbilled'),
            'Detail should flag unbilled hours. Was: ' + r.detail);
    }

    @IsTest
    static void testPassesWhenInvoiceFullyBilled() {
        DeliveryTriggerControl.disableAfterLogic();
        Date pStart = Date.newInstance(2026, 1, 1);
        Date pEnd = Date.newInstance(2026, 1, 31);
        NetworkEntity__c client = seedClientWithLogs(new List<Decimal>{ 8 }, pStart);
        DeliveryTriggerControl.enableAfterLogic();

        Test.startTest();
        // Freeze at 8h with no later billables — fully reconciled.
        DeliveryDocGenerationService.generateDocument(client.Id, 'Invoice', pStart, pEnd, null);
        DeliveryHubHealthCheckResult r = new DeliveryHubHealthService.StaleInvoiceCheck()
            .run(CHECK_KEY, CHECK_LABEL);
        Test.stopTest();

        System.assertEquals('pass', r.statusPk,
            'A fully-billed invoice should pass. Detail: ' + r.detail);
    }

    @IsTest
    static void testNoInvoicesPasses() {
        Test.startTest();
        DeliveryHubHealthCheckResult r = new DeliveryHubHealthService.StaleInvoiceCheck()
            .run(CHECK_KEY, CHECK_LABEL);
        Test.stopTest();

        System.assertEquals('pass', r.statusPk,
            'With no invoices present the check should pass. Detail: ' + r.detail);
    }
}
