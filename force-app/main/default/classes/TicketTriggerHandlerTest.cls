@isTest
public class TicketTriggerHandlerTest {
    private static Ticket__c t1;
    private static Ticket__c t2;
    private static User dev;

    @testSetup
    static void setup() {
        t1 = new Ticket__c(
            BriefDescriptionTxt__c = 'Desc One',
            StatusPk__c = 'In Progress',
            StageNamePk__c = 'Ready for QA',
            DeveloperDaysSizeNumber__c = 3,
            JiraTicketKeyTxt__c = null,
            IsActiveBool__c = true
        );
        insert t1;
        
        t2 = new Ticket__c(
            BriefDescriptionTxt__c = 'Desc Two',
            StatusPk__c = 'In Progress',
            StageNamePk__c = 'Ready for QA',
            DeveloperDaysSizeNumber__c = 5,
            JiraTicketKeyTxt__c = null,
            IsActiveBool__c = true
        );
        insert t2;
    }
    
     @isTest
    static void testActiveToActiveStageNoBlock() {
        // Retrieve the test ticket
        Ticket__c testTicket = [SELECT Id, BriefDescriptionTxt__c, StatusPk__c, StageNamePk__c, 
                                DeveloperDaysSizeNumber__c, JiraTicketKeyTxt__c, IsActiveBool__c 
                                FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Desc Two' LIMIT 1];
        
        // Change from one active stage to another active stage
        Ticket__c oldTicket = testTicket.clone(false, true, false, false);
        testTicket.StageNamePk__c = 'In Development'; // Assuming this is another active stage
        
        Map<Id, Ticket__c> oldMap = new Map<Id, Ticket__c>{ testTicket.Id => oldTicket };
        List<Ticket__c> newList = new List<Ticket__c>{ testTicket };

        Test.startTest();
        TicketTriggerHandler.handleBeforeUpdate(newList, oldMap);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors());
    }
}