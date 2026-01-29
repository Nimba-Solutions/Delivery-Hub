/**
 * @description Test class for DeliveryHubBoardController
 */
@isTest
public class DeliveryHubBoardControllerTest {

    @testSetup
    static void setup() {
        TriggerControl.disableAfterLogic();

        List<Ticket__c> tickets = new List<Ticket__c>{
            new Ticket__c(BriefDescriptionTxt__c = 'Stage Test', StageNamePk__c = 'Open', SortOrderNumber__c = 1),
            new Ticket__c(BriefDescriptionTxt__c = 'Sort Test', StageNamePk__c = 'Open', SortOrderNumber__c = 2),
            new Ticket__c(BriefDescriptionTxt__c = 'Blocked Ticket', StageNamePk__c = 'Open', SortOrderNumber__c = 1),
            new Ticket__c(BriefDescriptionTxt__c = 'Blocking Ticket', StageNamePk__c = 'Open', SortOrderNumber__c = 2),
            new Ticket__c(BriefDescriptionTxt__c = 'Search Target', StageNamePk__c = 'In Progress', SortOrderNumber__c = 1)
        };
        insert tickets;
        
        Ticket_Dependency__c dep = new Ticket_Dependency__c(
            Blocked_Ticket__c = tickets[2].Id,
            Blocking_Ticket__c = tickets[3].Id,
            TypePk__c = 'Blocks'
        );
        insert dep;

        TriggerControl.enableAfterLogic();
    }

    @isTest
    static void testUpdateTicketStage() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Stage Test' LIMIT 1];
        
        Test.startTest();
        DeliveryHubBoardController.updateTicketStage(ticket.Id, 'In Progress');
        Test.stopTest();
        
        Ticket__c updated = [SELECT StageNamePk__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('In Progress', updated.StageNamePk__c);
    }
    
    @isTest
    static void testUpdateTicketSortOrder() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Sort Test' LIMIT 1];

        Test.startTest();
        DeliveryHubBoardController.updateTicketSortOrder(ticket.Id, 5);
        Test.stopTest();
        
        Ticket__c updated = [SELECT SortOrderNumber__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(5, updated.SortOrderNumber__c);
    }
    
    @isTest
    static void testCreateDependency() {
        Ticket__c blocked = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Stage Test'];
        Ticket__c blocking = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Sort Test'];
        
        Test.startTest();
        Ticket_Dependency__c dep = DeliveryHubBoardController.createDependency(blocked.Id, blocking.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, dep.Id);
    }
    
    @isTest
    static void testCreateDependencySelfBlock() {
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocked Ticket'];
        
        try {
            Test.startTest();
            DeliveryHubBoardController.createDependency(ticket.Id, ticket.Id);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('block itself'), 'Wrong error message: ' + e.getMessage());
        }
    }
    
    @isTest
    static void testRemoveDependency() {
        Ticket_Dependency__c dep = [SELECT Id FROM Ticket_Dependency__c LIMIT 1];
        
        Test.startTest();
        DeliveryHubBoardController.removeDependency(dep.Id);
        Test.stopTest();
        
        Integer count = [SELECT count() FROM Ticket_Dependency__c WHERE Id = :dep.Id];
        System.assertEquals(0, count);
    }
    
    @isTest
    static void testSearchForPotentialBlockers() {
        Ticket__c currentTicket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Stage Test'];
        
        Test.startTest();
        List<Ticket__c> results = DeliveryHubBoardController.searchForPotentialBlockers(
            'Search Target', 
            currentTicket.Id, 
            new List<Id>()
        );
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals('Search Target', results[0].BriefDescriptionTxt__c);
    }
}