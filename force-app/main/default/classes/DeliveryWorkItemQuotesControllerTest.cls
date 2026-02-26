/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkItemQuotesController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemQuotesControllerTest {

    @TestSetup
    static void setup() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Test Work Item', StageNamePk__c = 'Backlog');
        insert workItem;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert vendor;

        insert new WorkRequest__c(
            WorkItemId__c            = workItem.Id,
            DeliveryEntityId__c    = vendor.Id,
            QuotedHoursNumber__c   = 10,
            HourlyRateCurrency__c  = 150,
            StatusPk__c            = 'Open for Bids'
        );
    }

    @IsTest
    static void testGetQuotes() {
        WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
        List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(workItem.Id);
        System.assertEquals(1, quotes.size(), 'Should return 1 quote');
        System.assertEquals('Test Vendor', quotes[0].vendorName);
        System.assertEquals(10, quotes[0].quotedHours);
    }

    @IsTest
    static void testAcceptQuote() {
        WorkItem__c workItem   = [SELECT Id FROM WorkItem__c LIMIT 1];
        WorkRequest__c request = [SELECT Id FROM WorkRequest__c LIMIT 1];

        DeliveryWorkItemQuotesController.acceptQuote(request.Id, workItem.Id);

        WorkRequest__c updated = [SELECT StatusPk__c FROM WorkRequest__c WHERE Id = :request.Id];
        System.assertEquals('Accepted', updated.StatusPk__c);
    }

    @IsTest
    static void testGetQuotesEmpty() {
        WorkItem__c empty = new WorkItem__c(BriefDescriptionTxt__c = 'No Quotes', StageNamePk__c = 'Backlog');
        insert empty;
        List<DeliveryWorkItemQuotesController.QuoteRow> quotes = DeliveryWorkItemQuotesController.getQuotes(empty.Id);
        System.assertEquals(0, quotes.size());
    }
}
