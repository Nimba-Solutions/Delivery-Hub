/**
 * @description Test class for DeliveryTimeLoggerController.
 */
@isTest
private class DeliveryTimeLoggerControllerTest {

    /**
     * @description Verifies that logHours correctly adds hours to an
     *              existing non-zero total on a ticket.
     */
    @isTest
    static void testLogHoursAddToExisting() {
        Ticket__c t = new Ticket__c(TotalLoggedHoursNumber__c = 5.0);
        insert t;

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 2.5);
        Test.stopTest();

        Ticket__c updated = [SELECT TotalLoggedHoursNumber__c FROM Ticket__c WHERE Id = :t.Id];
        System.assertEquals(7.5, updated.TotalLoggedHoursNumber__c, 'Expected 5.0 + 2.5 = 7.5');
    }

    /**
     * @description Verifies that logHours works when the ticket starts
     *              with a null (zero) total logged hours value.
     */
    @isTest
    static void testLogHoursFromNull() {
        Ticket__c t = new Ticket__c();
        insert t;

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 3.0);
        Test.stopTest();

        Ticket__c updated = [SELECT TotalLoggedHoursNumber__c FROM Ticket__c WHERE Id = :t.Id];
        System.assertEquals(3.0, updated.TotalLoggedHoursNumber__c, 'Expected 0 + 3.0 = 3.0');
    }

    /**
     * @description Verifies that fractional hour increments (e.g. 0.25h)
     *              are persisted correctly.
     */
    @isTest
    static void testLogHoursFractional() {
        Ticket__c t = new Ticket__c(TotalLoggedHoursNumber__c = 1.0);
        insert t;

        Test.startTest();
        DeliveryTimeLoggerController.logHours(t.Id, 0.25);
        Test.stopTest();

        Ticket__c updated = [SELECT TotalLoggedHoursNumber__c FROM Ticket__c WHERE Id = :t.Id];
        System.assertEquals(1.25, updated.TotalLoggedHoursNumber__c, 'Expected 1.0 + 0.25 = 1.25');
    }
}
