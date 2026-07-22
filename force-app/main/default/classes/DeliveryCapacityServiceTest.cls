/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryCapacityService (DECISION-G3, Wave 5). Covers the
 *               explicit no-CMT fallback (3 × 160 = 480 h/mo — never near-zero),
 *               team-pool and per-developer row aggregation, monthly-first row
 *               resolution, allocation scaling, and the workflow-type filter.
 *               DeveloperCapacity__mdt rows cannot be inserted via DML (and packaged
 *               seed rows ARE visible to tests), so every test injects rows through
 *               the capacityRowsOverride seam for determinism.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryCapacityServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    private static DeveloperCapacity__mdt teamRow(Decimal monthlyHours, String workflowType) {
        return new DeveloperCapacity__mdt(
            Label = 'Delivery Team',
            DeveloperName = 'Delivery_Team',
            MonthlyCapacityHoursNumber__c = monthlyHours,
            AllocationPercentNumber__c = 100,
            WorkflowTypeNameTxt__c = workflowType
        );
    }

    private static DeveloperCapacity__mdt devRow(String name, String userId, Decimal weeklyHours, Decimal allocPct) {
        return new DeveloperCapacity__mdt(
            Label = name,
            DeveloperName = name.replace(' ', '_'),
            DeveloperUserIdTxt__c = userId,
            WeeklyCapacityHoursNumber__c = weeklyHours,
            AllocationPercentNumber__c = allocPct,
            WorkflowTypeNameTxt__c = 'Software_Delivery'
        );
    }

    @IsTest
    static void testFallbackWhenNoRowsIsExplicitAndNotNearZero() {
        System.runAs(testUser) {
            DeliveryCapacityService.capacityRowsOverride = new List<DeveloperCapacity__mdt>();

            Test.startTest();
            DeliveryCapacityService.TeamCapacity cap = DeliveryCapacityService.getTeamCapacity(null);
            Test.stopTest();

            System.assertEquals(false, cap.isConfigured,
                'No CMT rows → the documented fallback, flagged unconfigured');
            System.assertEquals(480, cap.monthlyCapacityHours,
                'Fallback = 3 developer-equivalents × 160 h/mo — the historical slider model');
            System.assertEquals(3, cap.developerEquivalents, 'Fallback dev-equivalents = 3');
            System.assertEquals(160, cap.perDeveloperMonthlyHours, 'Fallback per-dev = 160 h/mo');
            System.assert(cap.weeklyCapacityHours > 100,
                'Fallback weekly hours derive from 480/mo — NEVER a silent near-zero');
            System.assert(cap.sourceLabel.containsIgnoreCase('default'),
                'Fallback source label declares itself a default');
        }
    }

    @IsTest
    static void testTeamPoolRowSeedShape() {
        System.runAs(testUser) {
            // The packaged MF-Prod seed: one team-pool row, 1000 h/mo (from the
            // TeamPool convention "Delivery Team|Development|1000").
            DeliveryCapacityService.capacityRowsOverride =
                new List<DeveloperCapacity__mdt>{ teamRow(1000, 'Software_Delivery') };

            Test.startTest();
            DeliveryCapacityService.TeamCapacity cap =
                DeliveryCapacityService.getTeamCapacity('Software_Delivery');
            Test.stopTest();

            System.assertEquals(true, cap.isConfigured, 'CMT rows present → configured');
            System.assertEquals(1000, cap.monthlyCapacityHours, 'Monthly = the seeded 1000');
            System.assertEquals(6, cap.developerEquivalents,
                'Team-pool row → round(1000 / 160) = 6 dev-equivalents');
            System.assertEquals(166.67, cap.perDeveloperMonthlyHours,
                '1000 / 6 dev-equivalents = 166.67 h/mo per step');
            System.assertEquals(230.77, cap.weeklyCapacityHours,
                'Weekly = monthly × 12 / 52 = 230.77');
        }
    }

    @IsTest
    static void testPerDeveloperRowsCountOneEach() {
        System.runAs(testUser) {
            DeliveryCapacityService.capacityRowsOverride = new List<DeveloperCapacity__mdt>{
                devRow('Dev One', '005000000000001AAA', 40, 100),
                devRow('Dev Two', '005000000000002AAA', 40, 100)
            };

            Test.startTest();
            DeliveryCapacityService.TeamCapacity cap =
                DeliveryCapacityService.getTeamCapacity('Software_Delivery');
            Test.stopTest();

            System.assertEquals(2, cap.developerEquivalents,
                'Per-developer rows count 1 each regardless of hours');
            // 40 h/wk × 52/12 = 173.33 monthly each → 346.67 team.
            System.assertEquals(346.67, cap.monthlyCapacityHours.setScale(2),
                'Legacy weekly rows convert at 52/12 weeks per month');
        }
    }

    @IsTest
    static void testAllocationPercentScalesCapacity() {
        System.runAs(testUser) {
            DeliveryCapacityService.capacityRowsOverride = new List<DeveloperCapacity__mdt>{
                devRow('Half Timer', '005000000000003AAA', 40, 50)
            };

            Test.startTest();
            DeliveryCapacityService.TeamCapacity cap =
                DeliveryCapacityService.getTeamCapacity('Software_Delivery');
            Test.stopTest();

            // 40 × 52/12 = 173.33 × 50% = 86.67.
            System.assertEquals(86.67, cap.monthlyCapacityHours.setScale(2),
                'AllocationPercentNumber__c scales effective monthly capacity');
        }
    }

    @IsTest
    static void testWorkflowTypeFilterAndBlankMeansAll() {
        System.runAs(testUser) {
            DeliveryCapacityService.capacityRowsOverride = new List<DeveloperCapacity__mdt>{
                teamRow(1000, 'Software_Delivery'),
                teamRow(500, 'Other_Workflow')
            };

            Test.startTest();
            DeliveryCapacityService.TeamCapacity swOnly =
                DeliveryCapacityService.getTeamCapacity('Software_Delivery');
            DeliveryCapacityService.TeamCapacity all =
                DeliveryCapacityService.getTeamCapacity(null);
            Test.stopTest();

            System.assertEquals(1000, swOnly.monthlyCapacityHours,
                'Workflow filter keeps only matching rows');
            System.assertEquals(1500, all.monthlyCapacityHours,
                'Blank workflowType = whole-org capacity (the buyer slider scope)');
        }
    }

    @IsTest
    static void testRowResolutionMonthlyFirstThenWeeklyThenDefault() {
        System.runAs(testUser) {
            DeveloperCapacity__mdt monthlyRow = teamRow(1000, 'Software_Delivery');
            DeveloperCapacity__mdt weeklyRow = devRow('Weekly Dev', '005000000000004AAA', 40, 100);
            DeveloperCapacity__mdt emptyRow = new DeveloperCapacity__mdt(
                Label = 'Empty Row',
                DeveloperName = 'Empty_Row',
                WorkflowTypeNameTxt__c = 'Software_Delivery'
            );

            Test.startTest();
            Decimal fromMonthly = DeliveryCapacityService.weeklyHoursForRow(monthlyRow);
            Decimal fromWeekly = DeliveryCapacityService.weeklyHoursForRow(weeklyRow);
            Decimal fromDefault = DeliveryCapacityService.weeklyHoursForRow(emptyRow);
            Test.stopTest();

            System.assertEquals(230.77, fromMonthly,
                'Monthly wins when set: 1000 × 12 / 52 = 230.77 weekly');
            System.assertEquals(40, fromWeekly, 'Weekly used when monthly is absent');
            System.assertEquals(40, fromDefault, 'Neither set → legacy 40 h/wk default');
        }
    }

    @IsTest
    static void testQueryRowsOverrideFiltersByWorkflow() {
        System.runAs(testUser) {
            DeliveryCapacityService.capacityRowsOverride = new List<DeveloperCapacity__mdt>{
                teamRow(1000, 'Software_Delivery'),
                teamRow(500, 'Other_Workflow')
            };

            Test.startTest();
            List<DeveloperCapacity__mdt> sw = DeliveryCapacityService.queryRows('Software_Delivery');
            List<DeveloperCapacity__mdt> all = DeliveryCapacityService.queryRows('');
            Test.stopTest();

            System.assertEquals(1, sw.size(), 'Override rows honor the workflow filter');
            System.assertEquals(2, all.size(), 'Blank filter returns every override row');
        }
    }
}
