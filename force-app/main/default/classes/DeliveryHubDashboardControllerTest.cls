/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHubDashboardController. Validates budget metrics,
 *               client dashboard data, attention counts, and vendor announcements.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubDashboardControllerTest {
    
    @IsTest
    static void testGetMetrics() {
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
            WorkItemId__c = t.Id
        ));
        
        items.add(new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            StatusPk__c = 'Failed',
            PayloadTxt__c = '{}',
            WorkItemId__c = t.Id
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

    @IsTest
    static void testGetClientDashboard() {
        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(BriefDescriptionTxt__c = 'Backlog Work Item',    StageNamePk__c = 'Backlog'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Dev Work Item',        StageNamePk__c = 'In Development'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Attention Work Item',  StageNamePk__c = 'In Client Approval')
        };
        insert workItems;

        Test.startTest();
        Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard();
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

    @IsTest
    static void testGetAttentionCount() {
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

    @IsTest
    static void testVendorAnnouncementIncludedInDashboard() {
        insert new NetworkEntity__c(
            Name                      = 'Announcing Vendor',
            EntityTypePk__c           = 'Vendor',
            StatusPk__c               = 'Active',
            VendorAnnouncementTxt__c  = 'Scheduled maintenance this weekend.'
        );

        Test.startTest();
        Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard();
        Test.stopTest();

        List<Object> announcements = (List<Object>) result.get('announcements');
        System.assertEquals(1, announcements.size(), 'Should include vendor announcement in dashboard');
        System.assertEquals('Scheduled maintenance this weekend.', (String) announcements[0]);
    }
}