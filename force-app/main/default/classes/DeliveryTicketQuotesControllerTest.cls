/**
 * @description Tests for DeliveryTicketQuotesController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryTicketQuotesControllerTest {

    @TestSetup
    static void setup() {
        Ticket__c ticket = new Ticket__c(BriefDescriptionTxt__c = 'Test Ticket', StageNamePk__c = 'Backlog');
        insert ticket;

        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert vendor;

        insert new Request__c(
            TicketId__c            = ticket.Id,
            DeliveryEntityId__c    = vendor.Id,
            QuotedHoursNumber__c   = 10,
            HourlyRateCurrency__c  = 150,
            StatusPk__c            = 'Open for Bids'
        );
    }

    @IsTest
    static void testGetQuotes() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c LIMIT 1];
        List<DeliveryTicketQuotesController.QuoteRow> quotes = DeliveryTicketQuotesController.getQuotes(ticket.Id);
        System.assertEquals(1, quotes.size(), 'Should return 1 quote');
        System.assertEquals('Test Vendor', quotes[0].vendorName);
        System.assertEquals(10, quotes[0].quotedHours);
    }

    @IsTest
    static void testAcceptQuote() {
        Ticket__c ticket   = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c request = [SELECT Id FROM Request__c LIMIT 1];

        DeliveryTicketQuotesController.acceptQuote(request.Id, ticket.Id);

        Request__c updated = [SELECT StatusPk__c FROM Request__c WHERE Id = :request.Id];
        System.assertEquals('Accepted', updated.StatusPk__c);
    }

    @IsTest
    static void testGetQuotesEmpty() {
        Ticket__c empty = new Ticket__c(BriefDescriptionTxt__c = 'No Quotes', StageNamePk__c = 'Backlog');
        insert empty;
        List<DeliveryTicketQuotesController.QuoteRow> quotes = DeliveryTicketQuotesController.getQuotes(empty.Id);
        System.assertEquals(0, quotes.size());
    }
}
