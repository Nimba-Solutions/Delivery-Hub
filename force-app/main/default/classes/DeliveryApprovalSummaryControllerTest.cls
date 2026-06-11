/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for the approval-summary agenda feed: the
 *               approved-this-month sum (Accepted + DecisionDateTime this
 *               month only), the pending count/quoted-hours pair (Offer Sent
 *               only), the in-flight aggregate (cap &gt; 0 AND stage inside the
 *               dev → deploying band), and the empty-org zero defaults.
 *               Report-id resolution is asserted shape-only — the agenda
 *               reports may not be deployed in a bare scratch context, which
 *               is the documented missing-report tolerance.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryApprovalSummaryControllerTest {

    /**
     * @description Seeds a WorkItem__c at the given stage with an optional
     *              client-approved cap (trigger side effects bypassed).
     * @param stage StageNamePk__c value.
     * @param cap ClientPreApprovedHoursNumber__c value (null = uncapped).
     * @return The inserted item.
     */
    private static WorkItem__c seedItem(String stage, Decimal cap) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'StageNamePk__c' => stage,
            'ClientPreApprovedHoursNumber__c' => cap
        });
    }

    /**
     * @description Seeds a WorkRequest__c on the item with the given
     *              lifecycle/hours overrides.
     * @param workItemId Parent WorkItem__c.
     * @param overrides Field overrides (status / quoted / granted / decided).
     * @return The inserted request.
     */
    private static WorkRequest__c seedRequest(Id workItemId, Map<String, Object> overrides) {
        return TestDataFactory.createWorkRequest(workItemId, overrides);
    }

    /**
     * @description Accepted-this-month requests sum into
     *              hoursApprovedThisMonth; an old decision and a pending
     *              request are both excluded.
     */
    @IsTest
    static void testHoursApprovedThisMonthSumsCurrentMonthOnly() {
        WorkItem__c wi = seedItem('In Development', 10);
        seedRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => 'Accepted',
            'QuotedHoursNumber__c' => 10,
            'PreApprovedHoursNumber__c' => 10,
            'DecisionDateTime__c' => Datetime.now()
        });
        seedRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => 'Accepted',
            'QuotedHoursNumber__c' => 6,
            'PreApprovedHoursNumber__c' => 6,
            'DecisionDateTime__c' => Datetime.now().addMonths(-2)
        });
        seedRequest(wi.Id, new Map<String, Object>{
            'StatusPk__c' => 'Offer Sent',
            'QuotedHoursNumber__c' => 4
        });

        Test.startTest();
        DeliveryApprovalSummaryController.ApprovalSummaryDTO dto =
            DeliveryApprovalSummaryController.getApprovalSummary();
        Test.stopTest();

        System.assertEquals(10, dto.hoursApprovedThisMonth,
            'only this month\'s Accepted decision counts toward the period sum');
    }

    /**
     * @description Offer-Sent requests drive pendingCount and the quoted-hours
     *              sum; decided requests are excluded.
     */
    @IsTest
    static void testPendingAggregatesCountOfferSentOnly() {
        WorkItem__c wi1 = seedItem('Ready for Final Approval', null);
        WorkItem__c wi2 = seedItem('Ready for Final Approval', null);
        seedRequest(wi1.Id, new Map<String, Object>{
            'StatusPk__c' => 'Offer Sent',
            'QuotedHoursNumber__c' => 12
        });
        seedRequest(wi2.Id, new Map<String, Object>{
            'StatusPk__c' => 'Offer Sent',
            'QuotedHoursNumber__c' => 4
        });
        seedRequest(wi2.Id, new Map<String, Object>{
            'StatusPk__c' => 'Inactive',
            'QuotedHoursNumber__c' => 99,
            'DecisionDateTime__c' => Datetime.now()
        });

        Test.startTest();
        DeliveryApprovalSummaryController.ApprovalSummaryDTO dto =
            DeliveryApprovalSummaryController.getApprovalSummary();
        Test.stopTest();

        System.assertEquals(2, dto.pendingCount, 'two Offer-Sent requests pending');
        System.assertEquals(16, dto.pendingQuotedHours, '12 + 4 quoted hours pending');
    }

    /**
     * @description In-flight aggregate requires BOTH a positive client cap
     *              AND a stage inside the dev → deploying band: a capped
     *              Backlog item and an uncapped In-Development item are
     *              excluded.
     */
    @IsTest
    static void testInProgressRequiresCapAndInFlightStage() {
        seedItem('In Development', 8);
        seedItem('QA In Progress', 4);
        seedItem('Backlog', 20);          // capped but not in flight
        seedItem('In Development', null); // in flight but no cap
        seedItem('Deployed to Prod', 6);  // past the in-flight band

        Test.startTest();
        DeliveryApprovalSummaryController.ApprovalSummaryDTO dto =
            DeliveryApprovalSummaryController.getApprovalSummary();
        Test.stopTest();

        System.assertEquals(2, dto.inProgressCount,
            'only capped items inside the dev → deploying band count');
        System.assertEquals(12, dto.inProgressApprovedHours,
            '8 + 4 approved hours in flight');
    }

    /**
     * @description Empty org returns zero defaults (never null numbers) and a
     *              non-null report-id map. Report rows may or may not exist in
     *              the test org — shape-only assertion, mirroring
     *              DeliveryHubDashboardControllerTest.testGetReportIds.
     */
    @IsTest
    static void testEmptyOrgReturnsZeroDefaults() {
        Test.startTest();
        DeliveryApprovalSummaryController.ApprovalSummaryDTO dto =
            DeliveryApprovalSummaryController.getApprovalSummary();
        Test.stopTest();

        System.assertEquals(0, dto.hoursApprovedThisMonth, 'zero default, not null');
        System.assertEquals(0, dto.pendingCount, 'zero default, not null');
        System.assertEquals(0, dto.pendingQuotedHours, 'zero default, not null');
        System.assertEquals(0, dto.inProgressCount, 'zero default, not null');
        System.assertEquals(0, dto.inProgressApprovedHours, 'zero default, not null');
        System.assertNotEquals(null, dto.reportIdsByDeveloperName,
            'report-id map is always present (possibly empty)');
    }
}
