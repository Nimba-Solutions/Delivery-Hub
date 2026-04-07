/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkItemQuotesController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemQuotesControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Test Work Item', StageNamePk__c = 'Backlog');
        insert workItem;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert vendor;

        insert new WorkRequest__c(
            WorkItemLookup__c            = workItem.Id,
            DeliveryEntityLookup__c    = vendor.Id,
            QuotedHoursNumber__c   = 10,
            HourlyRateCurrency__c  = 150,
            StatusPk__c            = 'Open for Bids'
        );
    }

    @IsTest
    static void testGetQuotes() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(workItem.Id);
            System.assertEquals(1, quotes.size(), 'Should return 1 quote');
            System.assertEquals('Test Vendor', quotes[0].vendorName);
            System.assertEquals(10, quotes[0].quotedHours);
        }
    }

    @IsTest
    static void testAcceptQuote() {
        System.runAs(testUser) {
            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c LIMIT 1];

            DeliveryWorkItemQuotesController.acceptQuote(request.Id, workItem.Id);

            WorkRequest__c updated = [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :request.Id];
            System.assertEquals('Accepted', updated.StatusPk__c);
        }
    }

    @IsTest
    static void testGetQuotesEmpty() {
        System.runAs(testUser) {
            WorkItem__c empty = new WorkItem__c(BriefDescriptionTxt__c = 'No Quotes', StageNamePk__c = 'Backlog');
            insert empty;
            List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(empty.Id);
            System.assertEquals(0, quotes.size());
        }
    }

    /**
     * @description Verifies all QuoteRow fields are populated correctly from the WorkRequest.
     */
    @IsTest
    static void testGetQuotesFullFieldVerification() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];

            List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(workItem.Id);
            System.assertEquals(1, quotes.size(), 'Should return 1 quote');

            DeliveryWorkItemQuotesController.QuoteRow row = quotes[0];
            System.assertNotEquals(null, row.id, 'id should be populated');
            System.assertEquals('Test Vendor', row.vendorName, 'vendorName should match');
            System.assertNotEquals(null, row.vendorId, 'vendorId should be populated');
            System.assertEquals(10, row.quotedHours, 'quotedHours should be 10');
            System.assertEquals(150, row.hourlyRate, 'hourlyRate should be 150');
            System.assertEquals('Open for Bids', row.status, 'status should be Open for Bids');
            System.assertEquals(false, row.isAccepted, 'isAccepted should be false for Open for Bids');
        }
    }

    /**
     * @description Verifies acceptQuote sets isAccepted flag and deactivates other bids.
     */
    @IsTest
    static void testAcceptQuoteSetsIsAccepted() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            NetworkEntity__c vendor2 = new NetworkEntity__c(
                Name = 'Second Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
            );
            insert vendor2;

            WorkRequest__c secondReq = new WorkRequest__c(
                WorkItemLookup__c = workItem.Id,
                DeliveryEntityLookup__c = vendor2.Id,
                QuotedHoursNumber__c = 20,
                HourlyRateCurrency__c = 120,
                StatusPk__c = 'Open for Bids'
            );
            insert secondReq;

            WorkRequest__c firstReq = [SELECT Id FROM WorkRequest__c WHERE DeliveryEntityLookup__r.Name = 'Test Vendor' LIMIT 1];

            Test.startTest();
            DeliveryWorkItemQuotesController.acceptQuote(firstReq.Id, workItem.Id);
            Test.stopTest();

            // Verify accepted quote
            List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(workItem.Id);
            Boolean foundAccepted = false;
            Boolean foundInactive = false;
            for (DeliveryWorkItemQuotesController.QuoteRow q : quotes) {
                if (q.id == firstReq.Id) {
                    System.assertEquals(true, q.isAccepted, 'Accepted quote should have isAccepted = true');
                    System.assertEquals('Accepted', q.status, 'Accepted quote status should be Accepted');
                    foundAccepted = true;
                }
                if (q.id == secondReq.Id) {
                    System.assertEquals(false, q.isAccepted, 'Other quote should not be accepted');
                    System.assertEquals('Inactive', q.status, 'Other quote should be Inactive');
                    foundInactive = true;
                }
            }
            System.assert(foundAccepted, 'Should have found the accepted quote');
            System.assert(foundInactive, 'Should have found the inactive quote');
        }
    }

    /**
     * @description Verifies acceptQuote is a no-op when the quote is already accepted.
     */
    @IsTest
    static void testAcceptQuoteAlreadyAcceptedNoOp() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c LIMIT 1];

            // Accept once
            DeliveryWorkItemQuotesController.acceptQuote(request.Id, workItem.Id);

            WorkRequest__c afterFirst = [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :request.Id];
            System.assertEquals('Accepted', afterFirst.StatusPk__c, 'Should be Accepted after first call');

            Test.startTest();
            // Accept again — should be no-op (already has correct status, no DML)
            DeliveryWorkItemQuotesController.acceptQuote(request.Id, workItem.Id);
            Test.stopTest();

            WorkRequest__c afterSecond = [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :request.Id];
            System.assertEquals('Accepted', afterSecond.StatusPk__c, 'Should still be Accepted after second call');
        }
    }

    /**
     * @description Verifies isAccepted is true for In Progress and Completed statuses.
     */
    @IsTest
    static void testIsAcceptedForInProgressAndCompleted() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c LIMIT 1];

            // Set to In Progress
            request.StatusPk__c = 'In Progress';
            update request;

            List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(workItem.Id);
            System.assertEquals(true, quotes[0].isAccepted, 'isAccepted should be true for In Progress');

            // Set to Completed
            request.StatusPk__c = 'Completed';
            update request;

            quotes = DeliveryWorkItemQuotesController.getQuotes(workItem.Id);
            System.assertEquals(true, quotes[0].isAccepted, 'isAccepted should be true for Completed');
        }
    }
}
