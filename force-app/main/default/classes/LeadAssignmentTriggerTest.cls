@isTest
public class LeadAssignmentTriggerTest {

    @isTest
    static void testLeadAssignmentOnUpdate() {
        
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'User',
            Company = 'Test Company',
            Status = 'New',
            Email = 'testuser@example.com',
            State__c = 'test',
            City__c = 'test'
        );
        insert testLead;

        Id oldOwnerId = testLead.OwnerId;

        testLead.Status = 'Working'; 
        update testLead;
        Lead updatedLead = [SELECT Id, OwnerId FROM Lead WHERE Id = :testLead.Id];

        System.assertNotEquals(null, updatedLead.OwnerId, 'OwnerId should not be null');
        
    }
}