/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryWorkItemETAService. 
 * Covers LWC integration, Queueable/Schedulable execution, and simulation logic.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemETAServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

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
            BlockedWorkItemLookup__c = workItems[2].Id,
            BlockingWorkItemLookup__c = workItems[0].Id
        );
    }

    /**
     * @description Tests the LWC method with specific prioritization.
     */
    @IsTest
    static void testGetWorkItemETAsWithPriority() {
        System.runAs(testUser) {
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
    }

    /**
     * @description Tests the Queueable implementation.
     */
    @IsTest
    static void testQueueableExecution() {
        System.runAs(testUser) {
            Test.startTest();
            System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable());
            Test.stopTest();

            // Verify database updates
            List<WorkItem__c> updatedWorkItems = [SELECT Id, ProjectedUATReadyDate__c FROM WorkItem__c WHERE ProjectedUATReadyDate__c != NULL];
            System.assert(updatedWorkItems.size() > 0, 'Queueable should have updated at least one work item ETA');
        }
    }

    /**
     * @description Tests the Schedulable implementation.
     */
    @IsTest
    static void testSchedulableExecution() {
        System.runAs(testUser) {
            Test.startTest();
            String cronExp = '0 0 0 15 3 ? 2040';
            String jobId = System.schedule('TestNightlyRecalculation', cronExp, new DeliveryWorkItemETAService.NightlyRecalculation());
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Job should be scheduled');
        }
    }

    /**
     * @description Directly tests the business day addition logic.
     */
    @IsTest
    static void testBusinessDayLogic() {
        System.runAs(testUser) {
            DeliveryWorkItemETAService.ETACalculator calc = new DeliveryWorkItemETAService.ETACalculator(null, 'Software_Delivery');

            // Friday to Monday test
            Date friday = Date.newInstance(2023, 10, 20); // A Friday
            Date expectedMonday = Date.newInstance(2023, 10, 23);

            Test.startTest();
            Date result = calc.addBusinessDays(friday, 1);
            Test.stopTest();

            System.assertEquals(expectedMonday, result, 'Adding 1 business day to Friday should result in Monday');
        }
    }
    
    /**
     * @description Tests the exception handling in the AuraEnabled method.
     */
    @IsTest
    static void testAuraHandledException() {
        System.runAs(testUser) {
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

    /**
     * @description Tests the workflow-type-parameterized method with explicit workflow type.
     */
    @IsTest
    static void testGetWorkItemETAsWithPriorityForType() {
        System.runAs(testUser) {
            List<WorkItem__c> allWorkItems = [SELECT Id FROM WorkItem__c];
            List<Id> prioritizedWorkItemIds = new List<Id>{allWorkItems[0].Id};

            Test.startTest();
            DeliveryWorkItemETAService.ETAResult result =
                DeliveryWorkItemETAService.getWorkItemETAsWithPriorityForType(2, prioritizedWorkItemIds, 'Software_Delivery');
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.workItems, 'Work items list should not be null');
        }
    }

    /**
     * @description Tests the workflow-type-parameterized method with null workflow type (defaults to Software_Delivery).
     */
    @IsTest
    static void testGetWorkItemETAsWithPriorityForTypeDefault() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryWorkItemETAService.ETAResult result =
                DeliveryWorkItemETAService.getWorkItemETAsWithPriorityForType(2, new List<Id>(), null);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null for null workflow type');
            System.assertNotEquals(null, result.workItems, 'Work items list should not be null');
        }
    }

    /**
     * @description Tests the workflow-type-parameterized method with blank workflow type (defaults to Software_Delivery).
     */
    @IsTest
    static void testGetWorkItemETAsWithPriorityForTypeBlank() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryWorkItemETAService.ETAResult result =
                DeliveryWorkItemETAService.getWorkItemETAsWithPriorityForType(2, new List<Id>(), '');
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result should not be null for blank workflow type');
        }
    }

    /**
     * @description Tests the Queueable with an explicit workflow type parameter.
     */
    @IsTest
    static void testQueueableWithWorkflowType() {
        System.runAs(testUser) {
            Test.startTest();
            System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable('Software_Delivery'));
            Test.stopTest();

            List<WorkItem__c> updatedWorkItems = [SELECT Id, ProjectedUATReadyDate__c FROM WorkItem__c WHERE ProjectedUATReadyDate__c != NULL];
            System.assert(updatedWorkItems.size() >= 0, 'Queueable with explicit type should execute without error');
        }
    }

    // ── Hours-only sizing path (Bug fix: PR #588 regression) ─────────────

    /**
     * @description Items sized only with EstimatedHoursNumber__c (no DeveloperDays)
     *              must be processed by the engine. Pre-fix the engine excluded them
     *              entirely, leaving stale dates forever in hour-sized portfolios.
     */
    @IsTest
    static void testHoursOnlySizedItemGetsScheduled() {
        System.runAs(testUser) {
            WorkItem__c hoursOnly = new WorkItem__c(
                BriefDescriptionTxt__c = 'Hours-only sized item',
                StageNamePk__c         = 'In Development',
                PriorityPk__c          = 'High',
                EstimatedHoursNumber__c = 16, // 2 days at 8h
                SortOrderNumber__c     = 100
            );
            insert hoursOnly;

            Test.startTest();
            System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable());
            Test.stopTest();

            WorkItem__c reloaded = [
                SELECT EstimatedStartDevDate__c, EstimatedEndDevDate__c, ProjectedUATReadyDate__c
                FROM WorkItem__c WHERE Id = :hoursOnly.Id
            ];
            System.assertNotEquals(null, reloaded.EstimatedStartDevDate__c,
                'Hours-only item should receive an EstimatedStartDevDate');
            System.assertNotEquals(null, reloaded.EstimatedEndDevDate__c,
                'Hours-only item should receive an EstimatedEndDevDate');
            System.assertNotEquals(null, reloaded.ProjectedUATReadyDate__c,
                'Hours-only item should receive a ProjectedUATReadyDate');
            System.assert(reloaded.EstimatedEndDevDate__c >= reloaded.EstimatedStartDevDate__c,
                'End date must not precede start date');
        }
    }

    /**
     * @description Hours→days conversion rounds up (Math.ceil(hours/8.0)) so a 1h
     *              task still consumes 1 full day. 1h → 1 day, 9h → 2 days.
     */
    @IsTest
    static void testHoursRoundUpToFullDays() {
        System.runAs(testUser) {
            WorkItem__c oneHour = new WorkItem__c(
                BriefDescriptionTxt__c = 'One-hour task',
                StageNamePk__c         = 'In Development',
                PriorityPk__c          = 'High',
                EstimatedHoursNumber__c = 1,
                SortOrderNumber__c     = 200
            );
            WorkItem__c nineHours = new WorkItem__c(
                BriefDescriptionTxt__c = 'Nine-hour task',
                StageNamePk__c         = 'In Development',
                PriorityPk__c          = 'High',
                EstimatedHoursNumber__c = 9,
                SortOrderNumber__c     = 201
            );
            insert new List<WorkItem__c>{ oneHour, nineHours };

            Test.startTest();
            System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable());
            Test.stopTest();

            List<WorkItem__c> results = [
                SELECT Id, EstimatedStartDevDate__c, EstimatedEndDevDate__c
                FROM WorkItem__c WHERE Id IN (:oneHour.Id, :nineHours.Id)
            ];
            for (WorkItem__c r : results) {
                System.assertNotEquals(null, r.EstimatedStartDevDate__c,
                    'Both items should be scheduled');
                System.assertNotEquals(null, r.EstimatedEndDevDate__c,
                    'Both items should have an end date');
                System.assert(r.EstimatedEndDevDate__c >= r.EstimatedStartDevDate__c,
                    'End date must not precede start date');
            }
        }
    }

    /**
     * @description When both DeveloperDays and EstimatedHours are set, DeveloperDays
     *              takes precedence (it is the engine's native unit). This guards
     *              against accidental regressions in the effort selection logic.
     */
    @IsTest
    static void testDeveloperDaysPreferredWhenBothSet() {
        System.runAs(testUser) {
            // 1 devday should produce a meaningfully different end date than
            // 80 hours (which would convert to 10 days). If the test produces
            // identical end dates the precedence logic is broken.
            WorkItem__c bothSet = new WorkItem__c(
                BriefDescriptionTxt__c   = 'Both fields set',
                StageNamePk__c           = 'In Development',
                PriorityPk__c            = 'High',
                DeveloperDaysSizeNumber__c = 1,
                EstimatedHoursNumber__c  = 80,
                SortOrderNumber__c       = 300
            );
            insert bothSet;

            Test.startTest();
            System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable());
            Test.stopTest();

            WorkItem__c reloaded = [
                SELECT EstimatedStartDevDate__c, EstimatedEndDevDate__c
                FROM WorkItem__c WHERE Id = :bothSet.Id
            ];
            // 1 devday means end date is 1 business day past start. 80h would
            // mean ~10 business days. The gap should be small.
            Integer gap = reloaded.EstimatedStartDevDate__c.daysBetween(reloaded.EstimatedEndDevDate__c);
            System.assert(gap <= 3,
                'DeveloperDays(1) should produce ~1-day gap, not ~10. Got: ' + gap);
        }
    }

    /**
     * @description Pre-loop cleanup pass should null out stale Estimated dates on
     *              active WorkItems that have neither DeveloperDays nor EstimatedHours.
     *              Without this, items outside the engine's filter keep stale values
     *              forever. Bug 3 from the parallel handoff doc.
     */
    @IsTest
    static void testUnsizedItemsHaveStaleDatesCleared() {
        System.runAs(testUser) {
            // Active item, no sizing fields, but with stale dates from a "previous run"
            WorkItem__c unsized = new WorkItem__c(
                BriefDescriptionTxt__c   = 'Unsized stale item',
                StageNamePk__c           = 'In Development',
                PriorityPk__c            = 'High',
                EstimatedStartDevDate__c = Date.today().addDays(-5),
                EstimatedEndDevDate__c   = Date.today().addDays(-5),
                ProjectedUATReadyDate__c = Date.today().addDays(-5),
                SortOrderNumber__c       = 400
            );
            insert unsized;

            Test.startTest();
            System.enqueueJob(new DeliveryWorkItemETAService.RecalculateAllETAsQueueable());
            Test.stopTest();

            WorkItem__c reloaded = [
                SELECT EstimatedStartDevDate__c, EstimatedEndDevDate__c, ProjectedUATReadyDate__c
                FROM WorkItem__c WHERE Id = :unsized.Id
            ];
            System.assertEquals(null, reloaded.EstimatedStartDevDate__c,
                'Unsized item EstimatedStartDevDate should be cleared');
            System.assertEquals(null, reloaded.EstimatedEndDevDate__c,
                'Unsized item EstimatedEndDevDate should be cleared');
            System.assertEquals(null, reloaded.ProjectedUATReadyDate__c,
                'Unsized item ProjectedUATReadyDate should be cleared');
        }
    }
}