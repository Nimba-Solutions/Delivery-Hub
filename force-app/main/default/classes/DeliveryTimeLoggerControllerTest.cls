/**
 * @description Test class for DeliveryTimeLoggerController.
 */
@isTest
private class DeliveryTimeLoggerControllerTest {

    /**
     * @description Verifies that logHours inserts a WorkLog__c record with
     *              the correct hours and ticket relationship.
     */
    @isTest
    static void testLogHoursCreatesWorkLog() {
        Ticket__c t = new Ticket__c();
        insert t;

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 2.5, 'Test work notes');
        Test.stopTest();

        List<WorkLog__c> logs = [
            SELECT HoursLoggedNumber__c, TicketId__c, WorkDateDate__c
            FROM WorkLog__c
            WHERE TicketId__c = :t.Id
        ];
        System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
        System.assertEquals(2.5, logs[0].HoursLoggedNumber__c, 'Expected 2.5 hours');
        System.assertEquals(Date.today(), logs[0].WorkDateDate__c, 'Expected today\'s date');
    }

    /**
     * @description Verifies that fractional hour increments are stored
     *              correctly (e.g. 0.25h quarter-hour logging).
     */
    @isTest
    static void testLogHoursFractional() {
        Ticket__c t = new Ticket__c();
        insert t;

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 0.25, null);
        Test.stopTest();

        List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE TicketId__c = :t.Id];
        System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
        System.assertEquals(0.25, logs[0].HoursLoggedNumber__c, 'Expected 0.25 hours');
    }

    /**
     * @description Verifies that multiple logHours calls each create their
     *              own WorkLog__c record (entries are additive, not overwrite).
     */
    @isTest
    static void testLogHoursMultipleEntries() {
        Ticket__c t = new Ticket__c();
        insert t;

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 1.0, 'Morning session');
        DeliveryTimeLoggerController.logHours(t.Id, 3.0, 'Afternoon session');
        Test.stopTest();

        List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE TicketId__c = :t.Id];
        System.assertEquals(2, logs.size(), 'Expected two WorkLog records');
    }
}
