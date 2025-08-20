@isTest
public class JiraToSFSyncBatchTest {
    
    @testSetup
    static void setupTestData() {
        List<Ticket__c> testTickets = new List<Ticket__c>();
        testTickets.add(new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket 1',
            JiraTicketKeyTxt__c = 'JIRA-1', // Key should match mock response
            StageNamePk__c = 'Backlog',
            IsActiveBool__c = true,
            SortOrderNumber__c = 1
        ));
        insert testTickets;
    }

    @isTest
    static void testBatchAndSchedulable() {
        // ✅ Set callout mock before batch starts
        Test.setMock(HttpCalloutMock.class, new JiraCalloutMock());

        Test.startTest();
        JiraToSFSyncBatch batch = new JiraToSFSyncBatch();
        Database.executeBatch(batch);
        System.schedule('JiraBatchSchedule', '0 0 0 ? * *', batch);
        Test.stopTest();

        // Optionally assert the ticket got updated
        Ticket__c updated = [SELECT StageNamePk__c, JiraSyncStatusTxt__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
        System.assertEquals('In Development', updated.StageNamePk__c);
        System.assertNotEquals(null, updated.JiraSyncStatusTxt__c);
    }
}