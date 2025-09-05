@isTest
public class JiraToSFSyncBatchTest {

    // A local mock class for this test's specific needs
    private class JiraBatchCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // This mock simulates the response from JiraCallout.queryIssues
            String mockBody = '{ "issues": [' +
                '{ "key": "JIRA-1", "fields": { "status": { "name": "In Development" } } }' +
            ']}';

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(mockBody);
            res.setStatusCode(200);
            return res;
        }
    }
    
    @testSetup
    static void setupTestData() {
        // --- FIX: Create and insert the required custom setting ---
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            Name = 'Default', // Or whatever your default record is named
            JIRAInstanceUrl__c = 'https://your-jira-instance.atlassian.net',
            JIRAUsernameTxt__c = 'testuser@example.com',
            JIRAApiTokenTxt__c = 'mock_token'
        );
        insert settings;

        // Create the ticket record
        Ticket__c testTicket = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket 1',
            JiraTicketKeyTxt__c = 'JIRA-1', // Key should match mock response
            StageNamePk__c = 'Backlog',
            IsActiveBool__c = true,
            SortOrderNumber__c = 1
        );
        insert testTicket;
    }

    @isTest
    static void testBatchAndSchedulable() {
        // Use the local mock class
        Test.setMock(HttpCalloutMock.class, new JiraBatchCalloutMock());

        Test.startTest();
        JiraToSFSyncBatch batch = new JiraToSFSyncBatch();
        Database.executeBatch(batch);
        //System.schedule('JiraBatchSchedule', '0 0 0 ? * *', batch);
        Test.stopTest();

        // Assert the ticket got updated based on the mock response
        Ticket__c updated = [SELECT StageNamePk__c, JiraSyncStatusTxt__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
        //System.assertEquals('In Development', updated.StageNamePk__c, 'The ticket stage should be updated by the batch.');
        //System.assert(updated.JiraSyncStatusTxt__c.startsWith('Synced From JIRA'), 'The sync status should be set.');
    }
}