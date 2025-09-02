/**
 * @description Test class for AttachmentSyncService functionality
 */
@isTest
private class AttachmentSyncServiceTest {

    /**
     * @description Mock implementation of JiraCallout for testing HTTP callouts
     */
    class MockJiraCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('[{"id": "jira-attachment-id-123"}]');
            return res;
        }
        
    }

    /**
     * @description Test method to verify successful file synchronization to Jira
     */
    @isTest
    static void testSyncFilesToJiraSuccess() {
        // Register the mock
        Test.setMock(HttpCalloutMock.class, new MockJiraCallout());

        // Step 1: Create a ticket with Jira key
        Ticket__c ticket = new Ticket__c(
            
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
        AttachmentSyncService.syncFilesToJira(ticket.Id, new List<Id>{insertedCv.ContentDocumentId});
        Test.stopTest();

        // Step 5: Assert a sync log was created
        List<Attachment_Sync_Log__c> logs = [
            SELECT Id, SyncStatusPk__c, JiraAttachmentIdTxt__c
            FROM Attachment_Sync_Log__c
            WHERE Ticket__c = :ticket.Id
        ];
        System.assertEquals(1, logs.size(), 'Expected one sync log to be created');
        System.assertEquals('Success', logs[0].SyncStatusPk__c, 'Expected sync status to be Success');

        //System.assertEquals(1, logs.size(), 'One sync log should be created');
        //System.assertEquals('Success', logs[0].SyncStatusPk__c);
        //System.assertEquals('jira-attachment-id-123', logs[0].JiraAttachmentIdTxt__c);
    }
}