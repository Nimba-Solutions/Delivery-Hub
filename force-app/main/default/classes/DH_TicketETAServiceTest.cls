@isTest
public class TicketETAServiceTest {
    @testSetup
    static void setup() {
        // Insert a developer User, Kanban_Configuration__mdt, and needed tickets
    }

    @isTest
    static void testGetTicketETAsWithPriority() {
        List<Id> ticketIds = new List<Id>(); // Add ticket Ids if needed
        Test.startTest();
        TicketETAService.ETAResult res = TicketETAService.getTicketETAsWithPriority(1, ticketIds);
        Test.stopTest();
        System.assertNotEquals(null, res);
        // Further asserts on res.tickets, etc.
    }

    
    @isTest
    static void testAsyncJobs() {
        Test.startTest();
        System.enqueueJob(new TicketETAService.RecalculateAllETAsQueueable());
        String sched = '0 0 0 ? * MON';
        System.schedule('NightlyRecalculation', sched, new TicketETAService.NightlyRecalculation());
        Test.stopTest();
    }
}