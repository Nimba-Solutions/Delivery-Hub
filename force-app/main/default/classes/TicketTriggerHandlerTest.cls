@isTest
public class TicketTriggerHandlerTest {
    private static Ticket__c t1;
    private static Ticket__c t2;
    private static User dev;

    @testSetup
    static void setup() {
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Desc Two',
            StatusPk__c = 'In Progress',
            StageNamePk__c = 'Ready for QA',
            DeveloperDaysSizeNumber__c = 3,
            JiraTicketKeyTxt__c = null,
            IsActiveBool__c = true
        );
        insert t;
    }
    
     @isTest
    static void testActiveToActiveStageNoBlock() {
        // Change t2 from one active stage to another active stage
        t2.StageNamePk__c = 'In Development'; // Assuming this is another active stage
        Map<Id, Ticket__c> oldMap = new Map<Id, Ticket__c>{ t2.Id => t2.clone(false, true, false, false) };
        List<Ticket__c> newList = new List<Ticket__c>{ t2 };

        Test.startTest();
        TicketTriggerHandler.handleBeforeUpdate(newList, oldMap);
        Test.stopTest();

        System.assertEquals(false, newList[0].hasErrors());
    }
}