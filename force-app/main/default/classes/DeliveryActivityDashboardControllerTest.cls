/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryActivityDashboardController. Validates activity summary
 *               aggregates: totals, top users, top components, daily counts, and top pages.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityDashboardControllerTest {

    @IsTest
    static void testGetActivitySummaryWithData() {
        // Create test activity logs
        List<ActivityLog__c> logs = new List<ActivityLog__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new ActivityLog__c(
                UserIdTxt__c = UserInfo.getUserId(),
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                PageUrlTxt__c = '/lightning/page/home'
            ));
        }
        for (Integer i = 0; i < 3; i++) {
            logs.add(new ActivityLog__c(
                UserIdTxt__c = 'test-user-beta',
                ActionTypePk__c = 'Button_Click',
                ComponentNameTxt__c = 'deliveryGhostRecorder',
                PageUrlTxt__c = '/lightning/r/WorkItem__c/record/view'
            ));
        }
        insert logs;

        Test.startTest();
        Map<String, Object> result = DeliveryActivityDashboardController.getActivitySummary();
        Test.stopTest();

        // Validate totals
        System.assert(result.containsKey('totalThisWeek'), 'Should contain totalThisWeek key');
        System.assert(result.containsKey('totalThisMonth'), 'Should contain totalThisMonth key');
        Integer totalMonth = (Integer) result.get('totalThisMonth');
        System.assertEquals(8, totalMonth, 'Should count all 8 activity logs this month');

        // Validate top users
        System.assert(result.containsKey('topUsers'), 'Should contain topUsers key');
        List<DeliveryActivityDashboardController.RankedItem> topUsers =
            (List<DeliveryActivityDashboardController.RankedItem>) result.get('topUsers');
        System.assert(topUsers.size() >= 1, 'Should have at least one top user');
        System.assertEquals(UserInfo.getName(), topUsers[0].label, 'Top user should show name, not ID');
        System.assertEquals(5, topUsers[0].count, 'Top user should have 5 activities');

        // Validate top components
        System.assert(result.containsKey('topComponents'), 'Should contain topComponents key');
        List<DeliveryActivityDashboardController.RankedItem> topComponents =
            (List<DeliveryActivityDashboardController.RankedItem>) result.get('topComponents');
        System.assert(topComponents.size() >= 1, 'Should have at least one top component');

        // Validate daily counts
        System.assert(result.containsKey('dailyCounts'), 'Should contain dailyCounts key');
        List<DeliveryActivityDashboardController.DailyCount> dailyCounts =
            (List<DeliveryActivityDashboardController.DailyCount>) result.get('dailyCounts');
        System.assertEquals(7, dailyCounts.size(), 'Should have 7 daily count entries');

        // Validate top pages
        System.assert(result.containsKey('topPages'), 'Should contain topPages key');
        List<DeliveryActivityDashboardController.RankedItem> topPages =
            (List<DeliveryActivityDashboardController.RankedItem>) result.get('topPages');
        System.assert(topPages.size() >= 1, 'Should have at least one top page');
    }

    @IsTest
    static void testGetActivitySummaryEmpty() {
        // No data — should return zeros and empty lists without errors
        Test.startTest();
        Map<String, Object> result = DeliveryActivityDashboardController.getActivitySummary();
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('totalThisWeek'), 'Week total should be 0 with no data');
        System.assertEquals(0, (Integer) result.get('totalThisMonth'), 'Month total should be 0 with no data');

        List<DeliveryActivityDashboardController.RankedItem> topUsers =
            (List<DeliveryActivityDashboardController.RankedItem>) result.get('topUsers');
        System.assertEquals(0, topUsers.size(), 'Top users should be empty with no data');

        List<DeliveryActivityDashboardController.RankedItem> topComponents =
            (List<DeliveryActivityDashboardController.RankedItem>) result.get('topComponents');
        System.assertEquals(0, topComponents.size(), 'Top components should be empty with no data');

        List<DeliveryActivityDashboardController.DailyCount> dailyCounts =
            (List<DeliveryActivityDashboardController.DailyCount>) result.get('dailyCounts');
        System.assertEquals(7, dailyCounts.size(), 'Should still have 7 daily count entries even with no data');
        for (DeliveryActivityDashboardController.DailyCount dc : dailyCounts) {
            System.assertEquals(0, dc.count, 'Each daily count should be 0 with no data');
        }
    }
}
