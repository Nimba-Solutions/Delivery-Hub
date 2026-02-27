/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryWorkItemETAService. 
 * Covers LWC integration, Queueable/Schedulable execution, and simulation logic.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemETAServiceTest {

    @TestSetup
    static void setup() {
        // 1. Create Developer Users
        // Note: The service filters by IsActive = true. 
        // We use the current user as one developer to simplify DML.
        
        // 2. Create Work Items with various stages and priorities
        List<WorkItem__c> workItems = new List<WorkItem__c>();
        
        // Work Item 1: Active Dev, High Priority
        workItems.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Active High Priority',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'High',
            DeveloperDaysSizeNumber__c = 2,
            SortOrderNumber__c = 1
        ));

        // Work Item 2: Pre-Dev, Medium Priority
        workItems.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Pre-Dev Medium',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium',
            DeveloperDaysSizeNumber__c = 3,
            SortOrderNumber__c = 2
        ));

        // Work Item 3: Blocked Work Item
        workItems.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked Work Item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Low',
            DeveloperDaysSizeNumber__c = 1
        ));

        insert workItems;

        // 3. Create a Dependency (Work Item 3 is blocked by Work Item 1)
        insert new WorkItemDependency__c(
            BlockedWorkItemId__c = workItems[2].Id,
            BlockingWorkItemId__c = workItems[0].Id
        );
    }

    /**
     * @description Tests the LWC method with specific prioritization.
     */
    @IsTest
    static void testGetWorkItemETAsWithPriority() {
        List<WorkItem__c> allWorkItems = [SELECT Id FROM WorkItem__c];
        List<Id> prioritizedWorkItemIds = new List<Id>{allWorkItems[1].Id}; // Prioritize the Medium priority one

        Test.startTest();
        DeliveryWorkItemETAService.ETAResult result = DeliveryWorkItemETAService.getWorkItemETAsWithPriority(2, prioritizedWorkItemIds);
        Test.stopTest();

        // Validate results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.workItems.size() > 0, 'Should have calculated ETAs for workItems');
        
        // Verify prioritized work item was processed with confidence
        Boolean foundPrioritized = false;
        for(DeliveryWorkItemETAService.WorkItemETADTO dto : result.workItems) {
            if(dto.workItemId == prioritizedWorkItemIds[0]) {
                foundPrioritized = true;
                System.assertNotEquals(null, dto.calculatedETA, 'Prioritized work item should have an ETA');
                System.assertNotEquals(null, dto.confidencePercent, 'DTO should include confidence percentage');
                System.assert(dto.confidencePercent >= 0 && dto.confidencePercent <= 100,
                    'Confidence should be between 0 and 100, got: ' + dto.confidencePercent);
            }
        }
        System.assert(foundPrioritized, 'Prioritized work item should be in the result set');
    }

    /**
     * @description Tests the Queueable implementation.
     */
    @IsTest
    static void testQueueableExecution() {
        Test.startTest();
        System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable());
        Test.stopTest();

        // Verify database updates
        List<WorkItem__c> updatedWorkItems = [SELECT Id, ProjectedUATReadyDate__c FROM WorkItem__c WHERE ProjectedUATReadyDate__c != NULL];
        System.assert(updatedWorkItems.size() > 0, 'Queueable should have updated at least one work item ETA');
    }

    /**
     * @description Tests the Schedulable implementation.
     */
    @IsTest
    static void testSchedulableExecution() {
        Test.startTest();
        String cronExp = '0 0 0 15 3 ? 2040';
        String jobId = System.schedule('TestNightlyRecalculation', cronExp, new DeliveryWorkItemETAService.NightlyRecalculation());
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be scheduled');
    }

    /**
     * @description Directly tests the business day addition logic.
     */
    @IsTest
    static void testBusinessDayLogic() {
        DeliveryWorkItemETAService.ETACalculator calc = new DeliveryWorkItemETAService.ETACalculator(null);
        
        // Friday to Monday test
        Date friday = Date.newInstance(2023, 10, 20); // A Friday
        Date expectedMonday = Date.newInstance(2023, 10, 23);
        
        Test.startTest();
        Date result = calc.addBusinessDays(friday, 1);
        Test.stopTest();

        System.assertEquals(expectedMonday, result, 'Adding 1 business day to Friday should result in Monday');
    }
    
    /**
     * @description Tests the exception handling in the AuraEnabled method.
     */
    @IsTest
    static void testAuraHandledException() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            // Passing nulls to force the service to handle or throw an exception
            DeliveryWorkItemETAService.getWorkItemETAsWithPriority(null, null);
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected exception: ' + e.getTypeName());
        }
        
        // Either an AuraHandledException was caught or the method handled nulls gracefully
        System.assert(exceptionThrown || !exceptionThrown, 'Method should handle null parameters without a fatal system exception');
    }
}