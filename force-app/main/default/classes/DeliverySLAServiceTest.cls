/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliverySLAService — CMT-driven SLA targets, warning days,
 *               workflow-specific rules, fallback behavior, and status counts.
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliverySLAServiceTest {

    /**
     * @description Creates baseline data: settings (auto-request OFF to avoid side effects)
     *              and a vendor entity.
     */
    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(AutoCreateWorkRequestBool__c = false);
        insert new NetworkEntity__c(
            Name = 'TestVendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://example.com'
        );
    }

    /**
     * @description Verifies autoSetSLATarget sets correct dates for each priority
     *              using default CMT rules (Critical=3, High=5, Medium=10, Low=20).
     */
    @IsTest
    static void testAutoSetSLATargetSetsDatesBasedOnPriority() {
        Date today = Date.today();

        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(BriefDescriptionTxt__c = 'Critical', PriorityPk__c = 'Critical'),
            new WorkItem__c(BriefDescriptionTxt__c = 'High', PriorityPk__c = 'High'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Medium', PriorityPk__c = 'Medium'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Low', PriorityPk__c = 'Low'),
            new WorkItem__c(BriefDescriptionTxt__c = 'NoPriority')
        };

        Test.startTest();
        List<WorkItem__c> result = DeliverySLAService.autoSetSLATarget(items);
        Test.stopTest();

        System.assertEquals(today.addDays(3), result[0].SLATargetDate__c, 'Critical should be 3 days');
        System.assertEquals(today.addDays(5), result[1].SLATargetDate__c, 'High should be 5 days');
        System.assertEquals(today.addDays(10), result[2].SLATargetDate__c, 'Medium should be 10 days');
        System.assertEquals(today.addDays(20), result[3].SLATargetDate__c, 'Low should be 20 days');
        System.assertEquals(today.addDays(20), result[4].SLATargetDate__c, 'Null priority should default to 20 days');
    }

    /**
     * @description Verifies autoSetSLATarget does not overwrite existing SLA dates.
     */
    @IsTest
    static void testAutoSetSLATargetSkipsExistingDates() {
        Date existingDate = Date.today().addDays(99);
        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Already Set',
                PriorityPk__c = 'High',
                SLATargetDate__c = existingDate
            )
        };

        Test.startTest();
        List<WorkItem__c> result = DeliverySLAService.autoSetSLATarget(items);
        Test.stopTest();

        System.assertEquals(existingDate, result[0].SLATargetDate__c, 'Existing SLA date should not be overwritten');
    }

    /**
     * @description Verifies getDaysForPriority returns correct defaults via the 1-arg signature.
     */
    @IsTest
    static void testGetDaysForPriorityDefaultSignature() {
        Test.startTest();
        Integer criticalDays = DeliverySLAService.getDaysForPriority('Critical');
        Integer highDays = DeliverySLAService.getDaysForPriority('High');
        Integer mediumDays = DeliverySLAService.getDaysForPriority('Medium');
        Integer lowDays = DeliverySLAService.getDaysForPriority('Low');
        Test.stopTest();

        System.assertEquals(3, criticalDays, 'Default Critical should be 3 days');
        System.assertEquals(5, highDays, 'Default High should be 5 days');
        System.assertEquals(10, mediumDays, 'Default Medium should be 10 days');
        System.assertEquals(20, lowDays, 'Default Low should be 20 days');
    }

    /**
     * @description Verifies getDaysForPriority returns workflow-specific values for Software_Delivery.
     */
    @IsTest
    static void testGetDaysForPriorityWithSoftwareDelivery() {
        Test.startTest();
        Integer criticalDays = DeliverySLAService.getDaysForPriority('Software_Delivery', 'Critical');
        Integer highDays = DeliverySLAService.getDaysForPriority('Software_Delivery', 'High');
        Integer mediumDays = DeliverySLAService.getDaysForPriority('Software_Delivery', 'Medium');
        Integer lowDays = DeliverySLAService.getDaysForPriority('Software_Delivery', 'Low');
        Test.stopTest();

        System.assertEquals(3, criticalDays, 'SD Critical should be 3 days');
        System.assertEquals(5, highDays, 'SD High should be 5 days');
        System.assertEquals(10, mediumDays, 'SD Medium should be 10 days');
        System.assertEquals(20, lowDays, 'SD Low should be 20 days');
    }

    /**
     * @description Verifies getDaysForPriority returns tighter SLAs for Loan_Approval.
     */
    @IsTest
    static void testGetDaysForPriorityWithLoanApproval() {
        Test.startTest();
        Integer criticalDays = DeliverySLAService.getDaysForPriority('Loan_Approval', 'Critical');
        Integer highDays = DeliverySLAService.getDaysForPriority('Loan_Approval', 'High');
        Integer mediumDays = DeliverySLAService.getDaysForPriority('Loan_Approval', 'Medium');
        Integer lowDays = DeliverySLAService.getDaysForPriority('Loan_Approval', 'Low');
        Test.stopTest();

        System.assertEquals(1, criticalDays, 'LA Critical should be 1 day');
        System.assertEquals(2, highDays, 'LA High should be 2 days');
        System.assertEquals(5, mediumDays, 'LA Medium should be 5 days');
        System.assertEquals(10, lowDays, 'LA Low should be 10 days');
    }

    /**
     * @description Verifies unknown workflow type falls back to default rules.
     */
    @IsTest
    static void testGetDaysForPriorityFallsBackToDefault() {
        Test.startTest();
        Integer criticalDays = DeliverySLAService.getDaysForPriority('Unknown_Workflow', 'Critical');
        Integer highDays = DeliverySLAService.getDaysForPriority('Unknown_Workflow', 'High');
        Test.stopTest();

        System.assertEquals(3, criticalDays, 'Unknown workflow Critical should fall back to default 3 days');
        System.assertEquals(5, highDays, 'Unknown workflow High should fall back to default 5 days');
    }

    /**
     * @description Verifies getWarningDays returns correct values for default rules.
     */
    @IsTest
    static void testGetWarningDaysDefault() {
        Test.startTest();
        Integer criticalWarning = DeliverySLAService.getWarningDays(null, 'Critical');
        Integer highWarning = DeliverySLAService.getWarningDays(null, 'High');
        Integer mediumWarning = DeliverySLAService.getWarningDays(null, 'Medium');
        Integer lowWarning = DeliverySLAService.getWarningDays(null, 'Low');
        Test.stopTest();

        System.assertEquals(2, criticalWarning, 'Default Critical warning should be 2 days');
        System.assertEquals(3, highWarning, 'Default High warning should be 3 days');
        System.assertEquals(7, mediumWarning, 'Default Medium warning should be 7 days');
        System.assertEquals(15, lowWarning, 'Default Low warning should be 15 days');
    }

    /**
     * @description Verifies getWarningDays returns workflow-specific values for Loan_Approval.
     */
    @IsTest
    static void testGetWarningDaysLoanApproval() {
        Test.startTest();
        Integer criticalWarning = DeliverySLAService.getWarningDays('Loan_Approval', 'Critical');
        Integer highWarning = DeliverySLAService.getWarningDays('Loan_Approval', 'High');
        Integer mediumWarning = DeliverySLAService.getWarningDays('Loan_Approval', 'Medium');
        Integer lowWarning = DeliverySLAService.getWarningDays('Loan_Approval', 'Low');
        Test.stopTest();

        System.assertEquals(0, criticalWarning, 'LA Critical warning should be 0 days');
        System.assertEquals(1, highWarning, 'LA High warning should be 1 day');
        System.assertEquals(3, mediumWarning, 'LA Medium warning should be 3 days');
        System.assertEquals(7, lowWarning, 'LA Low warning should be 7 days');
    }

    /**
     * @description Verifies that the CMT query is cached within a transaction —
     *              multiple calls should not issue additional SOQL.
     */
    @IsTest
    static void testCachingBehavior() {
        Test.startTest();
        // First call loads the cache
        DeliverySLAService.getDaysForPriority('Critical');
        // Verify cachedRules is populated
        System.assertNotEquals(null, DeliverySLAService.cachedRules, 'Cache should be populated after first call');
        Integer initialSize = DeliverySLAService.cachedRules.size();

        // Subsequent calls should reuse the cache (no additional SOQL)
        DeliverySLAService.getDaysForPriority('High');
        DeliverySLAService.getDaysForPriority('Software_Delivery', 'Medium');
        DeliverySLAService.getWarningDays('Loan_Approval', 'Low');
        Test.stopTest();

        System.assertEquals(initialSize, DeliverySLAService.cachedRules.size(),
            'Cache size should not change after subsequent calls');
    }

    /**
     * @description Verifies autoSetSLATarget with workflow type uses correct rules.
     */
    @IsTest
    static void testAutoSetSLATargetWithWorkflowType() {
        Date today = Date.today();

        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(BriefDescriptionTxt__c = 'LA Critical', PriorityPk__c = 'Critical'),
            new WorkItem__c(BriefDescriptionTxt__c = 'LA High', PriorityPk__c = 'High')
        };

        Test.startTest();
        List<WorkItem__c> result = DeliverySLAService.autoSetSLATarget(items, 'Loan_Approval');
        Test.stopTest();

        System.assertEquals(today.addDays(1), result[0].SLATargetDate__c, 'LA Critical should be 1 day');
        System.assertEquals(today.addDays(2), result[1].SLATargetDate__c, 'LA High should be 2 days');
    }

    /**
     * @description Verifies autoSetSLATarget reads WorkflowTypeTxt__c from each record
     *              when no explicit workflow type is passed.
     */
    @IsTest
    static void testAutoSetSLATargetReadsWorkflowTypeFromRecord() {
        Date today = Date.today();

        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'LA item',
                PriorityPk__c = 'Critical',
                WorkflowTypeTxt__c = 'Loan_Approval'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'SD item',
                PriorityPk__c = 'Critical',
                WorkflowTypeTxt__c = 'Software_Delivery'
            )
        };

        Test.startTest();
        List<WorkItem__c> result = DeliverySLAService.autoSetSLATarget(items);
        Test.stopTest();

        System.assertEquals(today.addDays(1), result[0].SLATargetDate__c,
            'LA Critical should use Loan_Approval rule (1 day)');
        System.assertEquals(today.addDays(3), result[1].SLATargetDate__c,
            'SD Critical should use Software_Delivery rule (3 days)');
    }

    /**
     * @description Verifies getSLAStatusCounts returns correct aggregated counts.
     */
    @IsTest
    static void testGetSLAStatusCountsReturnsCorrectCounts() {
        Date today = Date.today();

        List<WorkItem__c> items = new List<WorkItem__c>{
            // On Track: SLA far in the future, not terminal
            new WorkItem__c(
                BriefDescriptionTxt__c = 'On Track Item',
                StageNamePk__c = 'In Development',
                SLATargetDate__c = today.addDays(30),
                WorkflowTypeTxt__c = 'Software_Delivery'
            ),
            // At Risk: SLA within 2 days, not terminal
            new WorkItem__c(
                BriefDescriptionTxt__c = 'At Risk Item',
                StageNamePk__c = 'In Development',
                SLATargetDate__c = today.addDays(1),
                WorkflowTypeTxt__c = 'Software_Delivery'
            ),
            // Breached: SLA in the past, not terminal
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Breached Item',
                StageNamePk__c = 'In Development',
                SLATargetDate__c = today.addDays(-5),
                WorkflowTypeTxt__c = 'Software_Delivery'
            ),
            // Met: terminal stage (Done)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Met Item',
                StageNamePk__c = 'Done',
                SLATargetDate__c = today.addDays(-1),
                WorkflowTypeTxt__c = 'Software_Delivery'
            ),
            // Different workflow — should NOT be counted
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Other Workflow',
                StageNamePk__c = 'In Development',
                SLATargetDate__c = today.addDays(30),
                WorkflowTypeTxt__c = 'Loan_Approval'
            )
        };
        insert items;

        Test.startTest();
        Map<String, Integer> counts = DeliverySLAService.getSLAStatusCounts('Software_Delivery');
        Test.stopTest();

        System.assertEquals(1, counts.get('On Track'), 'Should have 1 On Track');
        System.assertEquals(1, counts.get('At Risk'), 'Should have 1 At Risk');
        System.assertEquals(1, counts.get('Breached'), 'Should have 1 Breached');
        System.assertEquals(1, counts.get('Met'), 'Should have 1 Met');
    }
}
