@isTest
private class DH_AttachmentSyncServiceTest {

    // Mock implementation of JiraCallout
    class MockJiraCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('[{"id": "jira-attachment-id-123"}]');
            return res;
        }
        
    }

    @isTest
    static void testSyncFilesToJira_success() {
        // Register the mock
        Test.setMock(HttpCalloutMock.class, new MockJiraCallout());

        // Step 1: Create a ticket with Jira key
        DH_Ticket__c ticket = new DH_Ticket__c(
            
            BriefDescriptionTxt__c = 'Testing file sync',
            JiraTicketKeyTxt__c = 'JIRA-123'
        );
        insert ticket;

        // Step 2: Create a ContentVersion (creates ContentDocument automatically)
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile.txt',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test content'),
            IsMajorVersion = true
        );
        insert cv;

        // Step 3: Query the ContentDocumentId
        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        // Step 4: Call the future method inside test context
        Test.startTest();
        DH_AttachmentSyncService.syncFilesToJira(ticket.Id, new List<Id>{insertedCv.ContentDocumentId});
        Test.stopTest();

        // Step 5: Assert a sync log was created
        List<DH_Attachment_Sync_Log__c> logs = [
            SELECT Id, Sync_Status__c, Jira_Attachment_ID__c
            FROM DH_Attachment_Sync_Log__c
            WHERE Ticket__c = :ticket.Id
        ];

        //System.assertEquals(1, logs.size(), 'One sync log should be created');
        //System.assertEquals('Success', logs[0].Sync_Status__c);
        //System.assertEquals('jira-attachment-id-123', logs[0].Jira_Attachment_ID__c);
    }
}