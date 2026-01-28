/**
 * @description Test class for DeliveryHubBoardController
 */
@isTest
public class DeliveryHubBoardControllerTest {

    @testSetup
    static void setup() {
        // 1. Create a standard user for testing
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testu',
            Email = 'testuser.board@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'test.user.board' + System.currentTimeMillis() + '@example.com'
        );
        insert testUser;

        // 2. Assign Permission Set
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App' LIMIT 1];
        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );
        
        System.runAs(testUser) {
            // Disable trigger logic to speed up setup
            TriggerControl.disableAfterLogic();

            List<Ticket__c> tickets = new List<Ticket__c>{
                new Ticket__c(BriefDescriptionTxt__c = 'Stage Test', StageNamePk__c = 'Open', SortOrderNumber__c = 1),
                new Ticket__c(BriefDescriptionTxt__c = 'Sort Test', StageNamePk__c = 'Open', SortOrderNumber__c = 2),
                new Ticket__c(BriefDescriptionTxt__c = 'Blocked Ticket', StageNamePk__c = 'Open', SortOrderNumber__c = 1),
                new Ticket__c(BriefDescriptionTxt__c = 'Blocking Ticket', StageNamePk__c = 'Open', SortOrderNumber__c = 2),
                new Ticket__c(BriefDescriptionTxt__c = 'Search Target', StageNamePk__c = 'In Progress', SortOrderNumber__c = 1)
            };
            insert tickets;
            
            // Create a dependency to test removal
            Ticket__c t1 = tickets[2]; // Blocked
            Ticket__c t2 = tickets[3]; // Blocking
            insert new Ticket_Dependency__c(
                Blocked_Ticket__c = t1.Id,
                Blocking_Ticket__c = t2.Id,
                TypePk__c = 'Blocks'
            );

            TriggerControl.enableAfterLogic();
        }
    }

    @isTest
    static void testUpdateTicketStage() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Stage Test' LIMIT 1];
            
            Test.startTest();
            DeliveryHubBoardController.updateTicketStage(ticket.Id, 'In Progress');
            Test.stopTest();
            
            Ticket__c updated = [SELECT StageNamePk__c FROM Ticket__c WHERE Id = :ticket.Id];
            System.assertEquals('In Progress', updated.StageNamePk__c, 'Stage should be updated');
        }
    }
    
    @isTest
    static void testUpdateTicketSortOrder() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Sort Test' LIMIT 1];

            Test.startTest();
            DeliveryHubBoardController.updateTicketSortOrder(ticket.Id, 5);
            Test.stopTest();
            
            Ticket__c updated = [SELECT SortOrderNumber__c FROM Ticket__c WHERE Id = :ticket.Id];
            System.assertEquals(5, updated.SortOrderNumber__c, 'Sort order should be updated');
        }
    }
    
    @isTest
    static void testCreateDependency() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            // Use the first two tickets which don't have a dependency yet
            Ticket__c blocked = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Stage Test'];
            Ticket__c blocking = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Sort Test'];
            
            Test.startTest();
            Ticket_Dependency__c dep = DeliveryHubBoardController.createDependency(blocked.Id, blocking.Id);
            Test.stopTest();
            
            System.assertNotEquals(null, dep.Id, 'Dependency should be created');
            System.assertEquals(blocked.Id, dep.Blocked_Ticket__c);
            System.assertEquals(blocking.Id, dep.Blocking_Ticket__c);
        }
    }
    
    @isTest
    static void testCreateDependencySelfBlock() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Blocked Ticket'];
            
            try {
                Test.startTest();
                DeliveryHubBoardController.createDependency(ticket.Id, ticket.Id);
                Test.stopTest();
                System.assert(false, 'Expected AuraHandledException not thrown');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('cannot block itself'), 'Wrong error message: ' + e.getMessage());
            }
        }
    }
    
    @isTest
    static void testRemoveDependency() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            Ticket_Dependency__c dep = [SELECT Id FROM Ticket_Dependency__c LIMIT 1];
            
            Test.startTest();
            DeliveryHubBoardController.removeDependency(dep.Id);
            Test.stopTest();
            
            Integer count = [SELECT count() FROM Ticket_Dependency__c WHERE Id = :dep.Id];
            System.assertEquals(0, count, 'Dependency should be deleted');
        }
    }
    
    @isTest
    static void testSearchForPotentialBlockers() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            Ticket__c currentTicket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Stage Test'];
            
            Test.startTest();
            List<Ticket__c> results = DeliveryHubBoardController.searchForPotentialBlockers(
                'Search Target', 
                currentTicket.Id, 
                new List<Id>() // No existing dependencies to exclude
            );
            Test.stopTest();
            
            System.assertEquals(1, results.size(), 'Search should return exactly one result');
            System.assertEquals('Search Target', results[0].BriefDescriptionTxt__c);
        }
    }
}