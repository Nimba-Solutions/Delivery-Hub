/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unit tests for DeliveryTimelineController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryTimelineControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Client Corp'
        );
        insert entity;

        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Build login page',
                StageNamePk__c             = 'In Development',
                PriorityPk__c              = 'High',
                ActivatedDateTime__c            = Datetime.now(),
                WorkflowTypeTxt__c         = 'Software_Delivery',
                ClientNetworkEntityLookup__c   = entity.Id,
                EstimatedStartDevDate__c   = Date.today(),
                EstimatedEndDevDate__c     = Date.today().addDays(14)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Fix export bug',
                StageNamePk__c             = 'Ready for QA',
                PriorityPk__c              = 'Medium',
                ActivatedDateTime__c            = Datetime.now(),
                WorkflowTypeTxt__c         = 'Software_Delivery',
                ClientNetworkEntityLookup__c   = entity.Id,
                ProjectedUATReadyDate__c   = Date.today().addDays(7)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Unassigned item',
                StageNamePk__c             = 'Backlog',
                ActivatedDateTime__c            = Datetime.now(),
                WorkflowTypeTxt__c         = 'Software_Delivery'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Inactive item',
                StageNamePk__c             = 'Done',
                ActivatedDateTime__c            = null,
                WorkflowTypeTxt__c         = 'Software_Delivery'
            )
        };
        insert workItems;

        // Deactivate the last item after insert (trigger auto-sets ActivatedDateTime)
        workItems[3].ActivatedDateTime__c = null;
        update workItems[3];
    }

    @IsTest
    static void testGetTimelineDataReturnsActiveItems() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData(null);
            Test.stopTest();

            System.assertEquals(3, rows.size(),
                'Should return 3 active non-template work items.');
        }
    }

    @IsTest
    static void testGetTimelineDataFiltersByWorkflowType() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData('Software_Delivery');
            Test.stopTest();

            System.assertEquals(3, rows.size(),
                'Should return items matching the workflow type filter.');
        }
    }

    @IsTest
    static void testGetTimelineDataFieldsPopulated() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData('Software_Delivery');
            Test.stopTest();

            DeliveryTimelineController.TimelineRow withDates;
            for (DeliveryTimelineController.TimelineRow row : rows) {
                if (row.description == 'Build login page') {
                    withDates = row;
                    break;
                }
            }

            System.assertNotEquals(null, withDates, 'Should find the login page item.');
            System.assertNotEquals(null, withDates.workItemId, 'workItemId should be set.');
            System.assertNotEquals(null, withDates.name, 'name should be set.');
            System.assertNotEquals(null, withDates.startDate, 'startDate should be set.');
            System.assertNotEquals(null, withDates.endDate, 'endDate should be set.');
            System.assertEquals(true, withDates.hasExplicitDates,
                'hasExplicitDates should be true when dates are explicitly set.');
            System.assertEquals('Test Client Corp', withDates.entityName,
                'entityName should match the network entity.');
        }
    }

    @IsTest
    static void testGetTimelineDataUnassignedEntity() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData(null);
            Test.stopTest();

            Boolean foundUnassigned = false;
            for (DeliveryTimelineController.TimelineRow row : rows) {
                if (row.entityName == 'Unassigned') {
                    foundUnassigned = true;
                    break;
                }
            }
            System.assert(foundUnassigned,
                'Should have an item with Unassigned entity name.');
        }
    }

    @IsTest
    static void testGetTimelineDataFallbackDates() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData(null);
            Test.stopTest();

            DeliveryTimelineController.TimelineRow noDateRow;
            for (DeliveryTimelineController.TimelineRow row : rows) {
                if (row.description == 'Unassigned item') {
                    noDateRow = row;
                    break;
                }
            }

            System.assertNotEquals(null, noDateRow, 'Should find the backlog item.');
            System.assertNotEquals(null, noDateRow.startDate,
                'startDate should fallback to CreatedDate.');
            System.assertNotEquals(null, noDateRow.endDate,
                'endDate should fallback to start+14.');
            System.assertEquals(false, noDateRow.hasExplicitDates,
                'hasExplicitDates should be false when no date fields are set.');
        }
    }

    @IsTest
    static void testGetTimelineDataEmptyResult() {
        System.runAs(testUser) {
            delete [SELECT Id FROM WorkItem__c];

            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData('Software_Delivery');
            Test.stopTest();

            System.assertEquals(0, rows.size(),
                'Should return empty list when no active work items exist.');
        }
    }

    @IsTest
    static void testGetTimelineDataPartialDatesHasExplicit() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData(null);
            Test.stopTest();

            DeliveryTimelineController.TimelineRow partialRow;
            for (DeliveryTimelineController.TimelineRow row : rows) {
                if (row.description == 'Fix export bug') {
                    partialRow = row;
                    break;
                }
            }

            System.assertNotEquals(null, partialRow, 'Should find the export bug item.');
            System.assertEquals(true, partialRow.hasExplicitDates,
                'hasExplicitDates should be true when at least one date field is set (ProjectedUATReadyDate).');
        }
    }

    @IsTest
    static void testGetTimelineDataNonMatchingType() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryTimelineController.TimelineRow> rows =
                DeliveryTimelineController.getTimelineData('Non_Existent_Type');
            Test.stopTest();

            System.assertEquals(0, rows.size(),
                'Should return empty list for unmatched workflow type.');
        }
    }
}
