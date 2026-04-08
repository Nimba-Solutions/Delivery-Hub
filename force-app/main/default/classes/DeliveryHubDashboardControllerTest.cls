/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHubDashboardController. Validates budget metrics,
 *               client dashboard data, attention counts, and vendor announcements.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubDashboardControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    
    @IsTest
    static void testGetMetrics() {
        System.runAs(testUser) {
            // 1. Create Active Work Item
            // We do not set LoggedHoursNum__c here as the field does not exist yet
            WorkItem__c t = new WorkItem__c(
                BriefDescriptionTxt__c = 'Test Work Item',
                StageNamePk__c = 'In Progress'
            );
            insert t;

            // 2. Create Sync Items (1 Success, 1 Failure)
            List<SyncItem__c> items = new List<SyncItem__c>();

            items.add(new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                StatusPk__c = 'Synced',
                PayloadTxt__c = '{}',
                WorkItemLookup__c = t.Id
            ));

            items.add(new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                StatusPk__c = 'Failed',
                PayloadTxt__c = '{}',
                WorkItemLookup__c = t.Id
            ));

            insert items;

            Test.startTest();
            // Return type is now Map<String, Object> to support the String date
            Map<String, Object> metrics = DeliveryHubDashboardController.getBudgetMetrics();
            Test.stopTest();

            // 3. Assertions
            // We cast the Decimal values because the map values are generic Objects
            System.assertEquals(1, (Decimal)metrics.get('activeRequests'), 'Should count 1 active work item');
            System.assertEquals(1, (Decimal)metrics.get('succeededSyncs'), 'Should count 1 success');
            System.assertEquals(1, (Decimal)metrics.get('failedSyncs'), 'Should count 1 failure');

            // 4. Verify Last Entry
            System.assert(metrics.containsKey('lastEntry'), 'Should return lastEntry key');
            String lastEntry = (String)metrics.get('lastEntry');

            System.assertNotEquals(null, lastEntry, 'Last Entry should not be null');
            System.assertNotEquals('--', lastEntry, 'Last Entry should have a formatted date value');
        }
    }

    /**
     * @description Bug A regression guard: System Pulse "Hours This Month" should
     *              still count WorkLog records that have NULL WorkDateDate__c by
     *              falling back to CreatedDate. Pre-fix the query filtered exclusively
     *              on WorkDateDate__c, so legacy logs created before PR #613's trigger
     *              default landed (and any integration-inserted logs that don't set
     *              the field) silently dropped out of the System Pulse total.
     */
    @IsTest
    static void testHoursThisMonthIncludesLogsWithNullWorkDate() {
        System.runAs(testUser) {
            WorkItem__c wi = new WorkItem__c(
                BriefDescriptionTxt__c = 'Hours fallback test',
                StageNamePk__c = 'In Development'
            );
            insert wi;

            // Master-detail to WorkRequest__c per the WorkLog__c trigger contract
            NetworkEntity__c vendor = new NetworkEntity__c(
                Name = 'Hours Test Vendor',
                EntityTypePk__c = 'Vendor',
                StatusPk__c = 'Active'
            );
            insert vendor;
            WorkRequest__c req = new WorkRequest__c(
                WorkItemId__c = wi.Id,
                DeliveryEntityLookup__c = vendor.Id,
                StatusPk__c = 'Active'
            );
            insert req;

            // Insert a WorkLog with WorkDateDate__c explicitly set (this month)
            WorkLog__c logWithDate = new WorkLog__c(
                RequestId__c = req.Id,
                WorkItemLookup__c = wi.Id,
                HoursLoggedNumber__c = 4.0,
                WorkDateDate__c = Date.today(),
                WorkDescriptionTxt__c = 'Has WorkDateDate'
            );
            insert logWithDate;

            // Insert a second WorkLog and clear WorkDateDate__c afterwards
            // (simulates the legacy / integration case where the field is null)
            WorkLog__c logWithoutDate = new WorkLog__c(
                RequestId__c = req.Id,
                WorkItemLookup__c = wi.Id,
                HoursLoggedNumber__c = 3.0,
                WorkDateDate__c = Date.today(),
                WorkDescriptionTxt__c = 'No WorkDateDate'
            );
            insert logWithoutDate;
            logWithoutDate.WorkDateDate__c = null;
            update logWithoutDate;

            Test.startTest();
            Map<String, Object> metrics = DeliveryHubDashboardController.getBudgetMetrics();
            Test.stopTest();

            Decimal hoursThisMonth = (Decimal) metrics.get('hoursThisMonth');
            System.assertEquals(7.0, hoursThisMonth,
                'Should count BOTH the dated log (4h) and the null-dated log (3h via CreatedDate fallback). Got: ' + hoursThisMonth);
        }
    }

    /**
     * @description Bug A real-fix regression guard: hoursLoggedThisMonth surfaces
     *              the entry-time view of hours, separate from hoursThisMonth which
     *              honors WorkDate. The two diverge whenever entries are backdated.
     *              Showing both makes the divergence self-documenting on the System
     *              Pulse widget — no need for a human to explain why "this month = 0
     *              but I worked 35 hours yesterday".
     */
    @IsTest
    static void testHoursLoggedThisMonthIncludesBackdatedEntries() {
        System.runAs(testUser) {
            WorkItem__c wi = new WorkItem__c(
                BriefDescriptionTxt__c = 'Logged-vs-worked test',
                StageNamePk__c = 'In Development'
            );
            insert wi;

            NetworkEntity__c vendor = new NetworkEntity__c(
                Name = 'Logged Test Vendor',
                EntityTypePk__c = 'Vendor',
                StatusPk__c = 'Active'
            );
            insert vendor;
            WorkRequest__c req = new WorkRequest__c(
                WorkItemId__c = wi.Id,
                DeliveryEntityLookup__c = vendor.Id,
                StatusPk__c = 'Active'
            );
            insert req;

            // Insert a log with a CURRENT-month WorkDate — counts in BOTH metrics
            WorkLog__c currentLog = new WorkLog__c(
                RequestId__c = req.Id,
                WorkItemLookup__c = wi.Id,
                HoursLoggedNumber__c = 4.0,
                WorkDateDate__c = Date.today(),
                WorkDescriptionTxt__c = 'Current month work'
            );
            insert currentLog;

            // Insert a log BACKDATED to the previous month (CreatedDate is now,
            // WorkDate is in the past). Should count in hoursLoggedThisMonth only,
            // NOT in hoursThisMonth (which honors WorkDate).
            WorkLog__c backdatedLog = new WorkLog__c(
                RequestId__c = req.Id,
                WorkItemLookup__c = wi.Id,
                HoursLoggedNumber__c = 6.0,
                WorkDateDate__c = Date.today().toStartOfMonth().addDays(-5),
                WorkDescriptionTxt__c = 'Backdated work for last month'
            );
            insert backdatedLog;

            Test.startTest();
            Map<String, Object> metrics = DeliveryHubDashboardController.getBudgetMetrics();
            Test.stopTest();

            Decimal hoursWorked = (Decimal) metrics.get('hoursThisMonth');
            Decimal hoursLogged = (Decimal) metrics.get('hoursLoggedThisMonth');

            System.assertEquals(4.0, hoursWorked,
                'hoursThisMonth (WorkDate-based) should count only the current-month log (4h)');
            System.assertEquals(10.0, hoursLogged,
                'hoursLoggedThisMonth (CreatedDate-based) should count BOTH logs (4h + 6h backdated)');
            System.assertNotEquals(hoursWorked, hoursLogged,
                'When entries are backdated, the two metrics MUST diverge — that is the whole point of surfacing both');
        }
    }

    /**
     * @description Bug C real-fix regression guard: the per-phase tile counts on
     *              the "What's In Flight" widget should only include items that
     *              are active (ActivatedDateTime__c not null), non-template, and
     *              non-archived. Pre-fix the SOQL only excluded terminal stages,
     *              so unactivated backlog items, recurring-item templates, and
     *              archived items inflated the per-phase counts and caused the
     *              tiles to disagree with every other "active items" metric.
     */
    @IsTest
    static void testInFlightPhaseListExcludesUnactivatedAndTemplateAndArchived() {
        System.runAs(testUser) {
            // 1) Active item — should be counted
            WorkItem__c active = new WorkItem__c(
                BriefDescriptionTxt__c = 'Active in dev',
                StageNamePk__c = 'In Development',
                ActivatedDateTime__c = Datetime.now()
            );
            insert active;

            // 2) Unactivated backlog item — should NOT be counted (no ActivatedDateTime)
            // Bypass the auto-stamp trigger so it lands genuinely unactivated.
            DeliveryWorkItemTriggerHandler.triggerDisabled = true;
            try {
                insert new WorkItem__c(
                    BriefDescriptionTxt__c = 'Backlog unactivated',
                    StageNamePk__c = 'Backlog'
                );
            } finally {
                DeliveryWorkItemTriggerHandler.triggerDisabled = false;
            }

            // 3) Template item — should NOT be counted
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Recurring template',
                StageNamePk__c = 'In Development',
                ActivatedDateTime__c = Datetime.now(),
                TemplateMarkedDateTime__c = Datetime.now()
            );

            // 4) Archived item — should NOT be counted
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Archived',
                StageNamePk__c = 'In Development',
                ActivatedDateTime__c = Datetime.now(),
                ArchivedDateTime__c = Datetime.now()
            );

            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard('thisWeek', 'Software_Delivery');
            Test.stopTest();

            // Sum the per-phase counts. Only the 1 active record should appear.
            // The phases list contains typed PhaseItem instances when called from
            // Apex (not Map<String, Object> — that's only how it's serialized for
            // @AuraEnabled JSON delivery to the LWC). Cast accordingly.
            List<DeliveryHubDashboardController.PhaseItem> phases =
                (List<DeliveryHubDashboardController.PhaseItem>) result.get('phases');
            Integer totalAcrossPhases = 0;
            for (DeliveryHubDashboardController.PhaseItem p : phases) {
                totalAcrossPhases += (p.count != null ? p.count : 0);
            }
            System.assertEquals(1, totalAcrossPhases,
                'Per-phase total should equal the 1 active non-template non-archived item, not 4. Got: ' + totalAcrossPhases);
        }
    }

    @IsTest
    static void testGetClientDashboard() {
        System.runAs(testUser) {
            List<WorkItem__c> workItems = new List<WorkItem__c>{
                new WorkItem__c(BriefDescriptionTxt__c = 'Backlog Work Item',    StageNamePk__c = 'Backlog'),
                new WorkItem__c(BriefDescriptionTxt__c = 'Dev Work Item',        StageNamePk__c = 'In Development'),
                new WorkItem__c(BriefDescriptionTxt__c = 'Attention Work Item',  StageNamePk__c = 'In Client Approval')
            };
            insert workItems;

            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard('thisWeek', 'Software_Delivery');
            Test.stopTest();

            System.assert(result.containsKey('attentionWorkItems'), 'Should return attentionWorkItems key');
            System.assert(result.containsKey('phases'), 'Should return phases key');
            System.assert(result.containsKey('recentWorkItems'), 'Should return recentWorkItems key');
            System.assert(result.containsKey('thisWeek'), 'Should return thisWeek key');

            Map<String, Object> thisWeek = (Map<String, Object>)result.get('thisWeek');
            System.assert(thisWeek.containsKey('completed'), 'thisWeek should contain completed metric');
            System.assert(thisWeek.containsKey('moved'), 'thisWeek should contain moved metric');
            System.assert(thisWeek.containsKey('hoursLogged'), 'thisWeek should contain hoursLogged metric');
            System.assert(thisWeek.containsKey('blocked'), 'thisWeek should contain blocked metric');

            List<DeliveryHubDashboardController.WorkItemSummary> attention =
                (List<DeliveryHubDashboardController.WorkItemSummary>)result.get('attentionWorkItems');
            System.assertEquals(1, attention.size(), 'Should return 1 attention work item');
            System.assertEquals('In Client Approval', attention[0].stage, 'Attention work item stage should match');

            List<DeliveryHubDashboardController.PhaseItem> phases =
                (List<DeliveryHubDashboardController.PhaseItem>)result.get('phases');
            System.assertEquals(6, phases.size(), 'Should return all 6 phase buckets');

            List<DeliveryHubDashboardController.WorkItemSummary> recent =
                (List<DeliveryHubDashboardController.WorkItemSummary>)result.get('recentWorkItems');
            System.assert(recent.size() > 0, 'Should return at least one recent work item');
        }
    }

    @IsTest
    static void testGetAttentionCount() {
        System.runAs(testUser) {
            insert new List<WorkItem__c>{
                new WorkItem__c(BriefDescriptionTxt__c = 'UAT Work Item',      StageNamePk__c = 'In Client UAT'),
                new WorkItem__c(BriefDescriptionTxt__c = 'Approval Work Item', StageNamePk__c = 'Ready for Client Approval'),
                new WorkItem__c(BriefDescriptionTxt__c = 'Dev Work Item',      StageNamePk__c = 'In Development')
            };

            Test.startTest();
            Integer count = DeliveryHubDashboardController.getAttentionCount();
            Test.stopTest();

            System.assertEquals(2, count, 'Should count workItems in client-facing stages only');
        }
    }

    @IsTest
    static void testVendorAnnouncementIncludedInDashboard() {
        System.runAs(testUser) {
            insert new NetworkEntity__c(
                Name                      = 'Announcing Vendor',
                EntityTypePk__c           = 'Vendor',
                StatusPk__c               = 'Active',
                VendorAnnouncementTxt__c  = 'Scheduled maintenance this weekend.'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard('thisWeek', 'Software_Delivery');
            Test.stopTest();

            List<Object> announcements = (List<Object>) result.get('announcements');
            System.assertEquals(1, announcements.size(), 'Should include vendor announcement in dashboard');
            System.assertEquals('Scheduled maintenance this weekend.', (String) announcements[0]);
        }
    }

    @IsTest
    static void testGetClientDashboardThisMonth() {
        System.runAs(testUser) {
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Monthly Work Item',
                StageNamePk__c = 'In Progress'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard('thisMonth', 'Software_Delivery');
            Test.stopTest();

            System.assert(result.containsKey('thisWeek'), 'thisMonth range should still return thisWeek key');
            Map<String, Object> metrics = (Map<String, Object>)result.get('thisWeek');
            System.assert(metrics.containsKey('completed'), 'thisMonth metrics should contain completed');
            System.assert(metrics.containsKey('moved'), 'thisMonth metrics should contain moved');
            System.assert(metrics.containsKey('hoursLogged'), 'thisMonth metrics should contain hoursLogged');
            System.assert(metrics.containsKey('blocked'), 'thisMonth metrics should contain blocked');
        }
    }

    @IsTest
    static void testGetReportIds() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, String> result = DeliveryHubDashboardController.getReportIds(
                new List<String>{ 'Recently_Completed', 'Nonexistent_Report' }
            );
            Test.stopTest();

            // Reports may or may not exist in scratch org; just verify no exception and correct type
            System.assertNotEquals(null, result, 'getReportIds should return a non-null map');
            System.assert(!result.containsKey('Nonexistent_Report'), 'Should not contain nonexistent report');
        }
    }

    @IsTest
    static void testIsAdminUser() {
        System.runAs(testUser) {
            Test.startTest();
            Boolean result = DeliveryHubDashboardController.isAdminUser();
            Test.stopTest();

            // Running user may or may not have admin PSG; just verify no exception and returns Boolean
            System.assertNotEquals(null, result, 'isAdminUser should return a non-null Boolean');
        }
    }

    @IsTest
    static void testGetClientDashboardLastWeek() {
        System.runAs(testUser) {
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Last Week Item',
                StageNamePk__c = 'In Progress'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard('lastWeek', 'Software_Delivery');
            Test.stopTest();

            System.assert(result.containsKey('thisWeek'), 'lastWeek range should still use thisWeek key');
            Map<String, Object> metrics = (Map<String, Object>)result.get('thisWeek');
            System.assert(metrics.containsKey('completed'), 'lastWeek metrics should contain completed');
            System.assert(metrics.containsKey('blocked'), 'lastWeek metrics should contain blocked');
        }
    }

    @IsTest
    static void testGetClientDashboardDefaultParams() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard(null, null);
            Test.stopTest();

            System.assert(result.containsKey('attentionWorkItems'), 'Should return attentionWorkItems with null params');
            System.assert(result.containsKey('phases'), 'Should return phases with null params');
            System.assert(result.containsKey('recentWorkItems'), 'Should return recentWorkItems with null params');
        }
    }

    @IsTest
    static void testGetBudgetMetricsNoWorkItems() {
        System.runAs(testUser) {
            // No data — should return zeros and dashes without errors
            Test.startTest();
            Map<String, Object> metrics = DeliveryHubDashboardController.getBudgetMetrics();
            Test.stopTest();

            System.assertEquals(0, (Decimal)metrics.get('activeRequests'), 'Should be 0 with no work items');
            System.assertEquals('--', (String)metrics.get('lastEntry'), 'Should be -- with no recent activity');
        }
    }

    @IsTest
    static void testGetClientDashboardWithComments() {
        System.runAs(testUser) {
            WorkItem__c item = new WorkItem__c(
                BriefDescriptionTxt__c = 'Comment Test Item',
                StageNamePk__c = 'In Development'
            );
            insert item;

            insert new WorkItemComment__c(
                WorkItemId__c = item.Id,
                BodyTxt__c = 'Test comment for coverage',
                AuthorTxt__c = 'Test Author',
                SourcePk__c = 'Internal'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard('thisWeek', 'Software_Delivery');
            Test.stopTest();

            List<DeliveryHubDashboardController.WorkItemSummary> recent =
                (List<DeliveryHubDashboardController.WorkItemSummary>)result.get('recentWorkItems');
            System.assert(recent.size() > 0, 'Should include items and/or comments in recent list');
        }
    }

    @IsTest
    static void testGetReportIdsEmptyList() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, String> result = DeliveryHubDashboardController.getReportIds(
                new List<String>()
            );
            Test.stopTest();

            System.assertEquals(0, result.size(), 'Should return empty map for empty input list');
        }
    }
}