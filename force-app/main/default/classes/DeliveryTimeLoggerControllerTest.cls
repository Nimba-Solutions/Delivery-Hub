/**
 * @description Test class for DeliveryTimeLoggerController.
 */
@isTest
private class DeliveryTimeLoggerControllerTest {

    /**
     * @description Creates a Ticket and an Accepted Request so the controller
     *              can auto-link WorkLog records.
     */
    @TestSetup
    static void setup() {
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert vendor;

        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Logger Ticket', StageNamePk__c = 'In Development');
        insert t;

        insert new Request__c(
            TicketId__c           = t.Id,
            DeliveryEntityId__c   = vendor.Id,
            QuotedHoursNumber__c  = 10,
            HourlyRateCurrency__c = 100,
            StatusPk__c           = 'Accepted'
        );
    }

    /**
     * @description Verifies that logHours inserts a WorkLog__c record linked
     *              to the accepted Request and the ticket.
     */
    @isTest
    static void testLogHoursCreatesWorkLog() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 2.5, 'Test work notes');
        Test.stopTest();

        List<WorkLog__c> logs = [
            SELECT HoursLoggedNumber__c, TicketId__c, WorkDateDate__c, RequestId__c
            FROM WorkLog__c
            WHERE TicketId__c = :t.Id
        ];
        System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
        System.assertEquals(2.5, logs[0].HoursLoggedNumber__c, 'Expected 2.5 hours');
        System.assertEquals(Date.today(), logs[0].WorkDateDate__c, 'Expected today\'s date');
        System.assertNotEquals(null, logs[0].RequestId__c, 'WorkLog should be linked to the accepted request');
    }

    /**
     * @description Verifies fractional hour increments are stored correctly.
     */
    @isTest
    static void testLogHoursFractional() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 0.25, null);
        Test.stopTest();

        List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE TicketId__c = :t.Id];
        System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
        System.assertEquals(0.25, logs[0].HoursLoggedNumber__c, 'Expected 0.25 hours');
    }

    /**
     * @description Verifies multiple logHours calls each create their own WorkLog__c record.
     */
    @isTest
    static void testLogHoursMultipleEntries() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 1.0, 'Morning session');
        DeliveryTimeLoggerController.logHours(t.Id, 3.0, 'Afternoon session');
        Test.stopTest();

        List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE TicketId__c = :t.Id];
        System.assertEquals(2, logs.size(), 'Expected two WorkLog records');
    }

    /**
     * @description Verifies that logHours throws when no accepted request exists.
     */
    @isTest
    static void testLogHoursNoRequestThrows() {
        Ticket__c noReqTicket = new Ticket__c(BriefDescriptionTxt__c = 'No Request', StageNamePk__c = 'Backlog');
        insert noReqTicket;

        Test.startTest();
        try {
            DeliveryTimeLoggerController.logHours(noReqTicket.Id, 1.0, 'Should fail');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(true, 'Correctly threw when no accepted request exists');
        }
        Test.stopTest();
    }
}
