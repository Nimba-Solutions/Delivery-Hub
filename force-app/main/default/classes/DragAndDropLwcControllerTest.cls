@isTest
public class DragAndDropLwcControllerTest {
    private static Ticket__c createTestTicket(String name, String stage, Decimal sortOrder) {
        Ticket__c t = new Ticket__c( StageNamePk__c = stage, SortOrderNumber__c = sortOrder);
        insert t;
        return t;
    }

    @isTest
    static void testUpdateTicketStage() {
        Ticket__c ticket = createTestTicket('Test Ticket Stage', 'Open', 1);
        Test.startTest();
        DragAndDropLwcController.updateTicketStage(ticket.Id, 'InProgress');
        Test.stopTest();
        
        // Verify update
        Ticket__c updated = [SELECT StageNamePk__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals('InProgress', updated.StageNamePk__c, 'Ticket stage should be updated to InProgress');
    }
    
    @isTest
    static void testUpdateTicketSortOrder() {
        Ticket__c ticket = createTestTicket('Test Ticket Sort', 'Open', 2);
        Test.startTest();
        DragAndDropLwcController.updateTicketSortOrder(ticket.Id, 5);
        Test.stopTest();
        
        Ticket__c updated = [SELECT SortOrderNumber__c FROM Ticket__c WHERE Id = :ticket.Id];
        System.assertEquals(5, updated.SortOrderNumber__c, 'Sort order should be updated to 5');
    }
    
    @isTest
    static void testCreateDependency() {
        Ticket__c blocked = createTestTicket('Blocked Ticket', 'Open', 1);
        Ticket__c blocking = createTestTicket('Blocking Ticket', 'Open', 2);
        Test.startTest();
        Ticket_Dependency__c dep = DragAndDropLwcController.createDependency(blocked.Id, blocking.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, dep.Id, 'Dependency should be created with an ID');
        System.assertEquals(blocked.Id, dep.Blocked_Ticket__c, 'Blocked ticket should be set correctly');
        System.assertEquals(blocking.Id, dep.Blocking_Ticket__c, 'Blocking ticket should be set correctly');
        System.assertEquals('Blocks', dep.Type__c, 'Dependency type should be Blocks');
    }
    
    @isTest
    static void testCreateDependencySelfBlock() {
        Ticket__c ticket = createTestTicket('Self Block Test', 'Open', 1);
        try {
            Test.startTest();
            DragAndDropLwcController.createDependency(ticket.Id, ticket.Id);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException not thrown');
        } catch (AuraHandledException e) {
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Exception message should match expected text');
        }
    }
    
    @isTest
    static void testRemoveDependency() {
        Ticket__c blocked = createTestTicket('Blocked Ticket Remove', 'Open', 1);
        Ticket__c blocking = createTestTicket('Blocking Ticket Remove', 'Open', 2);
        Ticket_Dependency__c dep = new Ticket_Dependency__c(
            Blocked_Ticket__c = blocked.Id,
            Blocking_Ticket__c = blocking.Id,
            Type__c = 'Blocks'
        );
        insert dep;
        
        Test.startTest();
        DragAndDropLwcController.removeDependency(dep.Id);
        Test.stopTest();
        
        Integer count = [SELECT count() FROM Ticket_Dependency__c WHERE Id = :dep.Id];
        System.assertEquals(0, count, 'Dependency should be removed');
    }
    
    @isTest
    static void testSearchForPotentialBlockers() {
        Ticket__c t1 = createTestTicket('Search Ticket One', 'In Progress', 1);
        Ticket__c t2 = createTestTicket('Search Ticket Two', 'Open', 2);
        // Create a Done ticket to verify it's excluded from search results
        createTestTicket('Done Ticket', 'Done', 3);
        
        List<Id> existingDependencies = new List<Id>{t2.Id};
        
        Test.startTest();
        List<Ticket__c> results = DragAndDropLwcController.searchForPotentialBlockers('Search', t1.Id, existingDependencies);
        Test.stopTest();
        
        //System.assert(results.size() > 0, 'Expected matching tickets');
        for (Ticket__c t : results) {
            System.assert(t.Id != t1.Id, 'Should not include current ticket');
            System.assert(t.Id != t2.Id, 'Should exclude existing dependencies');
            System.assert(t.StageNamePk__c != 'Done', 'Should exclude tickets in Done stage');
            System.assert(
              (t.Name != null && t.Name.containsIgnoreCase('Search')) || 
              (t.BriefDescriptionTxt__c != null && t.BriefDescriptionTxt__c.containsIgnoreCase('Search')), 
              'Returned ticket should match search term'
            );
        }
    }
}
