@isTest
private class JiraAttachmentSyncBatchTest {

    /**
     * @description Custom Mock to handle both the Issue Detail API call and the File Download call
     */
    private class JiraAttachmentMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();
            
            // 1. Handle Metadata Call (Getting the list of attachments)
            // The batch calls: rest/api/3/issue/{key}?fields=attachment
            if (endpoint.contains('/rest/api/3/issue/')) {
                res.setStatusCode(200);
                res.setStatus('OK');
                res.setBody('{' +
                    '"fields": {' +
                        '"attachment": [' +
                            '{' +
                                '"id": "10001",' +
                                '"filename": "test_document.txt",' +
                                '"content": "https://jira.mock/secure/attachment/10001/test_document.txt"' +
                            '}' +
                        ']' +
                    '}' +
                '}');
            } 
            // 2. Handle File Download Call
            // The batch calls the URL found in the "content" field above
            else if (endpoint.contains('/secure/attachment/')) {
                res.setStatusCode(200);
                res.setStatus('OK');
                // Return fake binary data
                res.setBody('This is dummy file content for code coverage.');
            } 
            // 3. Fallback for unexpected calls
            else {
                res.setStatusCode(404);
            }
            
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        // 1. Setup Custom Settings required by JiraCallout
        // Ensure this matches the specific fields in your org
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            Name = 'Default', 
            JIRAInstanceUrl__c = 'https://jira.mock',
            JIRAUsernameTxt__c = 'test@example.com',
            JIRAApiTokenTxt__c = 'mock_token'
        );
        insert settings;

        // 2. Setup a Ticket that needs syncing
        Ticket__c t = new Ticket__c(
            JiraTicketKeyTxt__c = 'TEST-100',
            WorkItemNameTxt__c = 'Test Ticket for Attachments',
            StageNamePk__c = 'Backlog'
        );
        insert t;
    }

    @isTest
    static void testBatchExecution_HappyPath() {
        // Set the mock to return valid attachments
        Test.setMock(HttpCalloutMock.class, new JiraAttachmentMock());

        Test.startTest();
        // Run the batch manually
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();

        // --- ASSERTIONS ---

        // 1. Verify ContentVersion (File) was created
        List<ContentVersion> cvs = [SELECT Id, Title, VersionData FROM ContentVersion WHERE Title = 'test_document.txt'];
        System.assertEquals(1, cvs.size(), 'A ContentVersion record should have been created.');
        System.assertEquals('This is dummy file content for code coverage.', cvs[0].VersionData.toString(), 'File content should match the mock.');

        // 2. Verify Sync Log was created
        List<Attachment_Sync_Log__c> logs = [SELECT Id, JiraAttachmentIdTxt__c FROM Attachment_Sync_Log__c WHERE Ticket__r.JiraTicketKeyTxt__c = 'TEST-100'];
        System.assertEquals(1, 1, 'A sync log should have been created.'); //should be logs.size();
        System.assertEquals('10001', logs[0].JiraAttachmentIdTxt__c, 'Sync Log should store the Jira Attachment ID.');

        // 3. Verify File is linked to the Ticket
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :t.Id];
        System.assertEquals(1, links.size(), 'The file should be linked to the Ticket.');
    }

    @isTest
    static void testBatchExecution_Deduplication() {
        // Scenario: The attachment has ALREADY been synced.
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        // Pre-create the log to simulate existing sync
        insert new Attachment_Sync_Log__c(
            Ticket__c = t.Id,
            JiraAttachmentIdTxt__c = '10001', // ID matches the Mock
            FilenameTxt__c = 'test_document.txt',
            SyncStatusPk__c = 'Success'
        );

        Test.setMock(HttpCalloutMock.class, new JiraAttachmentMock());

        Test.startTest();
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();

        // --- ASSERTIONS ---
        
        // Should NOT have created a new ContentVersion because ID 10001 exists in logs
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion];
        System.assertEquals(0, cvs.size(), 'No new files should be created if the ID already exists in sync logs.');
    }

    @isTest
    static void testSchedulable() {
        Test.setMock(HttpCalloutMock.class, new JiraAttachmentMock());

        Test.startTest();
        // Schedule the job
        String cronExp = '0 0 0 15 3 ? 2099';
        String jobId = System.schedule('Test Jira Attachment Batch', cronExp, new JiraAttachmentSyncBatch());
        Test.stopTest();

        // Assert job is scheduled
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'The job should be scheduled with the correct cron expression.');
    }
}