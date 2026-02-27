/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliverySLAService — auto-set SLA targets and status counts.
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
     * @description Verifies autoSetSLATarget sets correct dates for each priority.
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
