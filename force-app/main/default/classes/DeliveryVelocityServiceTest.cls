/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryVelocityService. Covers team velocity, developer velocity,
 *               projected completion, capacity utilization, and the combined dashboard.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryVelocityServiceTest {

    @testSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        List<WorkItem__c> items = new List<WorkItem__c>{
            // Active items (non-terminal)
            new WorkItem__c(BriefDescriptionTxt__c = 'Active 1', StageNamePk__c = 'In Development',
                            PriorityPk__c = 'High', SortOrderNumber__c = 1, ActivatedDateTime__c = Datetime.now(),
                            WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Active 2', StageNamePk__c = 'QA In Progress',
                            PriorityPk__c = 'Medium', SortOrderNumber__c = 2, ActivatedDateTime__c = Datetime.now(),
                            WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Active 3', StageNamePk__c = 'Backlog',
                            PriorityPk__c = 'Low', SortOrderNumber__c = 3, ActivatedDateTime__c = Datetime.now(),
                            WorkflowTypeTxt__c = 'Software_Delivery'),
            // Completed items
            new WorkItem__c(BriefDescriptionTxt__c = 'Done 1', StageNamePk__c = 'Done',
                            PriorityPk__c = 'Medium', SortOrderNumber__c = 4, ActivatedDateTime__c = Datetime.now(),
                            WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Done 2', StageNamePk__c = 'Done',
                            PriorityPk__c = 'Low', SortOrderNumber__c = 5, ActivatedDateTime__c = Datetime.now(),
                            WorkflowTypeTxt__c = 'Software_Delivery'),
            // Template (should be excluded)
            new WorkItem__c(BriefDescriptionTxt__c = 'Template 1', StageNamePk__c = 'Done',
                            PriorityPk__c = 'Low', SortOrderNumber__c = 6, ActivatedDateTime__c = Datetime.now(),
                            TemplateMarkedDateTime__c = Datetime.now(), WorkflowTypeTxt__c = 'Software_Delivery')
        };
        insert items;

        DeliveryTriggerControl.enableAfterLogic();
    }

    @isTest
    static void testGetTeamVelocityDefault() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getTeamVelocity('Software_Delivery', null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        System.assert(result.size() > 0, 'Should have at least one week bucket');

        for (DeliveryVelocityService.WeeklyVelocity wv : result) {
            System.assertNotEquals(null, wv.weekLabel, 'Week label must be set');
            System.assert(wv.completedCount >= 0, 'Completed count must be non-negative');
            System.assertNotEquals(null, wv.weekStart, 'Week start must be set');
        }
    }

    @isTest
    static void testGetTeamVelocityCustomWeeks() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getTeamVelocity('Software_Delivery', 4);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
    }

    @isTest
    static void testGetTeamVelocityBlankWorkflow() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getTeamVelocity('', 8);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Blank workflow should default and return data');
    }

    @isTest
    static void testGetTeamVelocityZeroWeeks() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getTeamVelocity('Software_Delivery', 0);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Zero weeks should default to 8');
    }

    @isTest
    static void testGetDeveloperVelocity() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getDeveloperVelocity(UserInfo.getUserId(), 8);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Developer velocity must not be null');
    }

    @isTest
    static void testGetDeveloperVelocityBlankId() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getDeveloperVelocity('', 8);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Blank developer ID should return empty list');
    }

    @isTest
    static void testGetDeveloperVelocityNullWeeks() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.getDeveloperVelocity(UserInfo.getUserId(), null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Null weeks should default to 8');
    }

    @isTest
    static void testGetProjectedCompletion() {
        Test.startTest();
        DeliveryVelocityService.ProjectionResult result =
            DeliveryVelocityService.getProjectedCompletion('Software_Delivery');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Projection result must not be null');
        System.assert(result.remainingItems >= 0, 'Remaining items must be non-negative');
        System.assert(result.averageVelocity >= 0, 'Average velocity must be non-negative');
    }

    @isTest
    static void testGetProjectedCompletionBlankWorkflow() {
        Test.startTest();
        DeliveryVelocityService.ProjectionResult result =
            DeliveryVelocityService.getProjectedCompletion('');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Blank workflow should default and return data');
    }

    @isTest
    static void testGetCapacityUtilization() {
        Test.startTest();
        DeliveryVelocityService.CapacityResult result =
            DeliveryVelocityService.getCapacityUtilization('Software_Delivery');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Capacity result must not be null');
        System.assertNotEquals(null, result.developers, 'Developers list must not be null');
        System.assert(result.totalCapacityHours >= 0, 'Total capacity must be non-negative');
        System.assert(result.utilizationPercent >= 0, 'Utilization percent must be non-negative');
    }

    @isTest
    static void testGetCapacityUtilizationBlankWorkflow() {
        Test.startTest();
        DeliveryVelocityService.CapacityResult result =
            DeliveryVelocityService.getCapacityUtilization('');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Blank workflow should default and return data');
    }

    @isTest
    static void testGetVelocityDashboard() {
        Test.startTest();
        DeliveryVelocityService.VelocityDashboard result =
            DeliveryVelocityService.getVelocityDashboard('Software_Delivery');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Dashboard must not be null');
        System.assertNotEquals(null, result.weeklyVelocity, 'Weekly velocity must not be null');
        System.assertNotEquals(null, result.projection, 'Projection must not be null');
        System.assertNotEquals(null, result.capacity, 'Capacity must not be null');
    }

    @isTest
    static void testGetVelocityDashboardBlankWorkflow() {
        Test.startTest();
        DeliveryVelocityService.VelocityDashboard result =
            DeliveryVelocityService.getVelocityDashboard('');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Blank workflow should default');
    }

    @isTest
    static void testBuildWeeklyBucketsEmpty() {
        Test.startTest();
        List<DeliveryVelocityService.WeeklyVelocity> result =
            DeliveryVelocityService.buildWeeklyBuckets(new List<WorkItem__c>(), 4);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Empty items should still return week buckets');
        for (DeliveryVelocityService.WeeklyVelocity wv : result) {
            System.assertEquals(0, wv.completedCount, 'Empty input should have 0 completed per week');
        }
    }

    @isTest
    static void testCalculateAverageVelocityEmpty() {
        Test.startTest();
        Decimal result = DeliveryVelocityService.calculateAverageVelocity(new List<DeliveryVelocityService.WeeklyVelocity>());
        Test.stopTest();

        System.assertEquals(0, result, 'Empty list should return 0');
    }

    @isTest
    static void testCalculateAverageVelocityNull() {
        Test.startTest();
        Decimal result = DeliveryVelocityService.calculateAverageVelocity(null);
        Test.stopTest();

        System.assertEquals(0, result, 'Null list should return 0');
    }

    @isTest
    static void testCalculateAverageVelocityWithData() {
        List<DeliveryVelocityService.WeeklyVelocity> data = new List<DeliveryVelocityService.WeeklyVelocity>();

        DeliveryVelocityService.WeeklyVelocity wv1 = new DeliveryVelocityService.WeeklyVelocity();
        wv1.completedCount = 3;
        wv1.weekLabel = '3/1';
        wv1.weekStart = Date.newInstance(2026, 3, 1);
        data.add(wv1);

        DeliveryVelocityService.WeeklyVelocity wv2 = new DeliveryVelocityService.WeeklyVelocity();
        wv2.completedCount = 5;
        wv2.weekLabel = '3/8';
        wv2.weekStart = Date.newInstance(2026, 3, 8);
        data.add(wv2);

        Test.startTest();
        Decimal result = DeliveryVelocityService.calculateAverageVelocity(data);
        Test.stopTest();

        System.assertEquals(4.0, result, 'Average of 3 and 5 should be 4.0');
    }

    @isTest
    static void testWrapperClasses() {
        // Verify all wrapper fields are accessible
        DeliveryVelocityService.WeeklyVelocity wv = new DeliveryVelocityService.WeeklyVelocity();
        wv.weekLabel = 'Test';
        wv.completedCount = 5;
        wv.weekStart = Date.today();
        System.assertEquals('Test', wv.weekLabel);

        DeliveryVelocityService.DeveloperUtilization du = new DeliveryVelocityService.DeveloperUtilization();
        du.developerName = 'Dev 1';
        du.developerId = 'abc123';
        du.weeklyCapacityHours = 40;
        du.allocationPercent = 80;
        du.allocatedHours = 32;
        du.activeItemCount = 3;
        System.assertEquals('Dev 1', du.developerName);

        DeliveryVelocityService.ProjectionResult pr = new DeliveryVelocityService.ProjectionResult();
        pr.remainingItems = 10;
        pr.averageVelocity = 2.5;
        pr.estimatedWeeks = 4;
        pr.projectedCompletionDate = Date.today().addDays(28);
        System.assertEquals(10, pr.remainingItems);

        DeliveryVelocityService.CapacityResult cr = new DeliveryVelocityService.CapacityResult();
        cr.totalCapacityHours = 160;
        cr.allocatedHours = 120;
        cr.utilizationPercent = 75;
        cr.developerCount = 4;
        cr.developers = new List<DeliveryVelocityService.DeveloperUtilization>();
        System.assertEquals(160, cr.totalCapacityHours);

        DeliveryVelocityService.VelocityDashboard vd = new DeliveryVelocityService.VelocityDashboard();
        vd.weeklyVelocity = new List<DeliveryVelocityService.WeeklyVelocity>();
        vd.projection = pr;
        vd.capacity = cr;
        System.assertNotEquals(null, vd.weeklyVelocity);
    }
}
