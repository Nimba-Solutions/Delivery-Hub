@isTest
public class DH_JiraToSFSyncBatchTest {
    
    @testSetup
    static void setupTestData() {
        List<DH_Ticket__c> testTickets = new List<DH_Ticket__c>();
        testTickets.add(new DH_Ticket__c(
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
        DH_JiraToSFSyncBatch batch = new DH_JiraToSFSyncBatch();
        Database.executeBatch(batch);
        System.schedule('JiraBatchSchedule', '0 0 0 ? * *', batch);
        Test.stopTest();

        // Optionally assert the ticket got updated
        DH_Ticket__c updated = [SELECT StageNamePk__c, JiraSyncStatusTxt__c FROM DH_Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
        System.assertEquals('In Development', updated.StageNamePk__c);
        System.assertNotEquals(null, updated.JiraSyncStatusTxt__c);
    }
}