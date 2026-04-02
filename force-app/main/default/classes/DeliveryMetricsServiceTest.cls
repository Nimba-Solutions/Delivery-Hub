/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryMetricsService. Validates velocity, throughput,
 *               WIP, stage distribution, priority breakdown, aging items, and
 *               completion rate calculations.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryMetricsServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testGetBoardMetricsWithData() {
        System.runAs(testUser) {
            // Create work items across various stages and priorities
            List<WorkItem__c> items = new List<WorkItem__c>{
                new WorkItem__c(
                    BriefDescriptionTxt__c = 'Backlog Item',
                    StageNamePk__c = 'Backlog',
                    PriorityPk__c = 'High'
                ),
                new WorkItem__c(
                    BriefDescriptionTxt__c = 'In Dev Item',
                    StageNamePk__c = 'In Development',
                    PriorityPk__c = 'Medium'
                ),
                new WorkItem__c(
                    BriefDescriptionTxt__c = 'QA Item',
                    StageNamePk__c = 'QA In Progress',
                    PriorityPk__c = 'Low'
                ),
                new WorkItem__c(
                    BriefDescriptionTxt__c = 'Done Item',
                    StageNamePk__c = 'Done'
                ),
                new WorkItem__c(
                    BriefDescriptionTxt__c = 'Cancelled Item',
                    StageNamePk__c = 'Cancelled'
                )
            };
            insert items;

            Test.startTest();
            DeliveryMetricsService.BoardMetrics metrics = DeliveryMetricsService.getBoardMetrics();
            Test.stopTest();

            // Velocity: should have 4 weekly data points
            System.assertEquals(4, metrics.velocity.size(), 'Should return 4 weeks of velocity data');
            for (DeliveryMetricsService.WeeklyVelocity wv : metrics.velocity) {
                System.assertNotEquals(null, wv.weekLabel, 'Week label should not be null');
                System.assert(wv.count >= 0, 'Weekly count should be non-negative');
            }

            // WIP: 3 non-terminal items
            System.assertEquals(3, metrics.wipCount, 'WIP should count non-terminal items');

            // Stage distribution: should have entries for active stages
            System.assert(metrics.stageDistribution.size() > 0, 'Stage distribution should not be empty');
            Integer totalStageItems = 0;
            for (DeliveryMetricsService.StageCount sc : metrics.stageDistribution) {
                System.assertNotEquals(null, sc.stage, 'Stage name should not be null');
                System.assert(sc.count > 0, 'Stage count should be positive');
                totalStageItems += sc.count;
            }
            System.assertEquals(3, totalStageItems, 'Total stage distribution should equal WIP count');

            // Priority breakdown: should have entries for each priority used
            System.assert(metrics.priorityBreakdown.size() > 0, 'Priority breakdown should not be empty');

            // Throughput: should be non-negative
            System.assert(metrics.avgThroughputDays >= 0, 'Average throughput should be non-negative');

            // Completion rate
            System.assert(metrics.completionRate >= 0, 'Completion rate should be non-negative');
            System.assert(metrics.completedLast30 >= 0, 'Completed count should be non-negative');
            System.assert(metrics.totalLast30 >= 0, 'Total count should be non-negative');

            // Aging items: freshly created items should NOT be aging
            System.assert(metrics.agingItemCount >= 0, 'Aging item count should be non-negative');
            System.assertNotEquals(null, metrics.agingItems, 'Aging items list should not be null');
        }
    }

    @IsTest
    static void testGetBoardMetricsEmptyBoard() {
        System.runAs(testUser) {
            // No work items at all — should return safe defaults
            Test.startTest();
            DeliveryMetricsService.BoardMetrics metrics = DeliveryMetricsService.getBoardMetrics();
            Test.stopTest();

            System.assertEquals(4, metrics.velocity.size(), 'Should return 4 weeks even with no data');
            for (DeliveryMetricsService.WeeklyVelocity wv : metrics.velocity) {
                System.assertEquals(0, wv.count, 'Empty board should have zero velocity');
            }

            System.assertEquals(0, metrics.wipCount, 'WIP should be zero on empty board');
            System.assertEquals(0, metrics.stageDistribution.size(), 'No stage distribution on empty board');
            System.assertEquals(0, metrics.priorityBreakdown.size(), 'No priority breakdown on empty board');
            System.assertEquals(0, metrics.agingItemCount, 'No aging items on empty board');
            System.assertEquals(0, metrics.avgThroughputDays, 'Throughput should be zero on empty board');
            System.assertEquals(0, metrics.completionRate, 'Completion rate should be zero on empty board');
        }
    }

    @IsTest
    static void testAllItemsInOneStage() {
        System.runAs(testUser) {
            // Edge case: all items concentrated in a single stage
            List<WorkItem__c> items = new List<WorkItem__c>();
            for (Integer i = 0; i < 5; i++) {
                items.add(new WorkItem__c(
                    BriefDescriptionTxt__c = 'Backlog Item ' + i,
                    StageNamePk__c = 'Backlog',
                    PriorityPk__c = 'High'
                ));
            }
            insert items;

            Test.startTest();
            DeliveryMetricsService.BoardMetrics metrics = DeliveryMetricsService.getBoardMetrics();
            Test.stopTest();

            System.assertEquals(5, metrics.wipCount, 'All 5 items should be WIP');
            System.assertEquals(1, metrics.stageDistribution.size(), 'Should have exactly 1 stage entry');
            System.assertEquals('Backlog', metrics.stageDistribution[0].stage, 'Single stage should be Backlog');
            System.assertEquals(5, metrics.stageDistribution[0].count, 'Should show 5 items in Backlog');

            // Priority: all High
            System.assertEquals(1, metrics.priorityBreakdown.size(), 'Should have exactly 1 priority entry');
            System.assertEquals('High', metrics.priorityBreakdown[0].priority, 'Priority should be High');
            System.assertEquals(5, metrics.priorityBreakdown[0].count, 'All 5 should be High priority');
        }
    }

    @IsTest
    static void testCompletedItemsCountInVelocity() {
        System.runAs(testUser) {
            // Create a completed item — it should appear in velocity for the current week
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Just Completed',
                StageNamePk__c = 'Done'
            );

            Test.startTest();
            DeliveryMetricsService.BoardMetrics metrics = DeliveryMetricsService.getBoardMetrics();
            Test.stopTest();

            // The last entry in velocity (current week) should include the completed item
            DeliveryMetricsService.WeeklyVelocity currentWeek = metrics.velocity[3];
            System.assertEquals(1, currentWeek.count, 'Current week should show 1 completed item');
        }
    }

    @IsTest
    static void testTemplateItemsExcluded() {
        System.runAs(testUser) {
            // Template items should be excluded from all metrics
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Template Item',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'High',
                TemplateMarkedDateTime__c = Datetime.now()
            );

            Test.startTest();
            DeliveryMetricsService.BoardMetrics metrics = DeliveryMetricsService.getBoardMetrics();
            Test.stopTest();

            System.assertEquals(0, metrics.wipCount, 'Template items should not be counted as WIP');
            System.assertEquals(0, metrics.stageDistribution.size(), 'Template items should not appear in stage distribution');
        }
    }

    @IsTest
    static void testPriorityUnsetHandled() {
        System.runAs(testUser) {
            // Items with no priority set should appear as "Unset"
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'No Priority',
                StageNamePk__c = 'Backlog'
            );

            Test.startTest();
            DeliveryMetricsService.BoardMetrics metrics = DeliveryMetricsService.getBoardMetrics();
            Test.stopTest();

            System.assertEquals(1, metrics.priorityBreakdown.size(), 'Should have one priority entry');
            System.assertEquals('Unset', metrics.priorityBreakdown[0].priority, 'Null priority should be labeled Unset');
        }
    }
}
