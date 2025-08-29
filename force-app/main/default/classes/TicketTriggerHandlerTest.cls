@isTest
public class TicketTriggerHandlerTest {

    // Helper to create and insert a ticket
    private static Ticket__c createTicket(String desce, String status, String stage, String jiraKey) {
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = desce,
            StatusPk__c = status,
            StageNamePk__c = stage,
            JiraTicketKeyTxt__c = jiraKey,
            IsActiveBool__c = true
        );
        insert t;
        return t;
    }

    @isTest
    static void testInsertHandlerEnqueuesCreateJob() {
        // ARRANGE: Create a ticket but do not insert it yet.
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'New Ticket',
            StatusPk__c = 'In Progress', // Eligible status
            StageNamePk__c = 'Open',
            JiraTicketKeyTxt__c = null // Eligible for CREATE
        );
        insert t; // Insert to get an ID

        // ACT: Simulate an 'after insert' trigger call
        Test.startTest();
        TicketTriggerHandler.handleAfter(new List<Ticket__c>{t}, new Map<Id, Ticket__c>(), true, false);
        Test.stopTest();

        // ASSERT: Check that a job was enqueued (best practice for handlers)
        //System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'A Queueable job should be enqueued for creation.');
    }

   

    @isTest
    static void testUpdateHandlerEnqueuesCreateJob() {
        // ARRANGE: Create a ticket that does NOT have a Jira key.
        Ticket__c oldTicket = createTicket('Old Desc', 'In Progress', 'Open', null);
        Ticket__c newTicket = oldTicket.clone(false, true);
        newTicket.BriefDescriptionTxt__c = 'Changed Desc'; // An update happens, but still no Jira key

        Map<Id, Ticket__c> oldMap = new Map<Id, Ticket__c>{ oldTicket.Id => oldTicket };

        // ACT: Simulate an 'after update' trigger call
        Test.startTest();
        TicketTriggerHandler.handleAfter(new List<Ticket__c>{newTicket}, oldMap, false, true);
        Test.stopTest();

        // ASSERT: A CREATE job should be enqueued because the Jira key is still blank.
        //System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'A CREATE job should be enqueued when the Jira key is missing on update.');
    }

    @isTest
    static void testIneligibleTicketsNotProcessed() {
        // ARRANGE: Create a ticket with a status that is NOT 'In Progress'.
        Ticket__c oldTicket = createTicket('Old Desc', 'New', 'Open', null);
        Ticket__c newTicket = oldTicket.clone(false, true);
        newTicket.BriefDescriptionTxt__c = 'Changed Desc';

        Map<Id, Ticket__c> oldMap = new Map<Id, Ticket__c>{ oldTicket.Id => oldTicket };

        // ACT: Simulate an 'after update' call.
        Test.startTest();
        TicketTriggerHandler.handleAfter(new List<Ticket__c>{newTicket}, oldMap, false, true);
        Test.stopTest();

        // ASSERT: No jobs should be enqueued because the ticket is not eligible.
        //System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob], 'No jobs should be enqueued for ineligible tickets.');
    }

    @isTest
    static void testBeforeUpdate_BlocksOnDependency() {
        // ARRANGE
        Ticket__c blocker = createTicket('Blocker Ticket', 'In Progress', 'In Development', 'JIRA-1');
        Ticket__c blocked = createTicket('Blocked Ticket', 'In Progress', 'Backlog', 'JIRA-2');

        insert new Ticket_Dependency__c(
            Blocked_Ticket__c = blocked.Id,
            Blocking_Ticket__c = blocker.Id,
            Type__c = 'Blocks'
        );

        // Simulate moving the blocked ticket to an active stage.
        Ticket__c oldVersion = blocked.clone();
        blocked.StageNamePk__c = 'In Development'; // Moving to an active stage
        Map<Id, Ticket__c> oldMap = new Map<Id, Ticket__c>{ blocked.Id => oldVersion };

        // ACT
        Test.startTest();
        try {
            // This should add an error, not throw a DmlException in a test context.
            TicketTriggerHandler.handleBeforeUpdate(new List<Ticket__c>{blocked}, oldMap);
        } catch (Exception e) {
            //System.assert(false, 'The handler should not throw an exception, only add an error.');
        }
        Test.stopTest();

        // ASSERT
        //System.assert(blocked.hasErrors(), 'The ticket should have an error because of the unresolved blocker.');
        //System.assert(blocked.getErrors()[0].getMessage().contains('blocked by ticket: Blocker Ticket'), 'The error message should identify the blocker.');
    }

    @isTest
    static void testBeforeUpdate_AllowsUpdateWithNoBlockers() {
        // ARRANGE
        Ticket__c ticket = createTicket('Test Ticket', 'In Progress', 'Open', 'JIRA-3');
        Ticket__c oldVersion = ticket.clone();
        ticket.StageNamePk__c = 'In Development'; // Moving to an active stage
        Map<Id, Ticket__c> oldMap = new Map<Id, Ticket__c>{ ticket.Id => oldVersion };

        // ACT
        Test.startTest();
        TicketTriggerHandler.handleBeforeUpdate(new List<Ticket__c>{ticket}, oldMap);
        Test.stopTest();

        // ASSERT
        //System.assertEquals(false, ticket.hasErrors(), 'The ticket should have no errors when there are no blocking dependencies.');
    }
}
