@isTest
private class JiraAttachmentSyncBatchTest {

    /**
     * @description Custom Mock that handles multiple endpoints based on the FULL URL
     */
    public class MultiResponseMock implements HttpCalloutMock {
        private Map<String, HttpResponse> endpointToResponseMap;

        public MultiResponseMock(Map<String, HttpResponse> responseMap) {
            this.endpointToResponseMap = responseMap;
        }

        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            
            // Check if we have an exact match
            if (endpointToResponseMap.containsKey(endpoint)) {
                return endpointToResponseMap.get(endpoint);
            }
            
            // Fallback: Check if the map has a key that is contained in the endpoint (partial match)
            for(String key : endpointToResponseMap.keySet()) {
                if(endpoint.contains(key)) {
                    return endpointToResponseMap.get(key);
                }
            }

            // Default 404 if not found
            // FIXED: Added LoggingLevel.DEBUG to satisfy PMD rule
            System.debug(LoggingLevel.DEBUG, 'Mock not found for endpoint: ' + endpoint);
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found - Endpoint not mocked');
            res.setBody('{}');
            return res;
        }
    }

    // == Test Data Setup ==
    @testSetup
    static void setupData() {
        // 1. Insert Custom Settings (Non-Setup Object)
        // This triggers the MIXED_DML error if followed immediately by User insertion
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            Name = 'Default',
            JIRAInstanceUrl__c = 'https://mock-jira.test.com',
            JIRAUsernameTxt__c = 'testuser',
            JIRAApiTokenTxt__c = 'token123'
        );
        insert settings;

        // 2. Create User and Permissions (Setup Objects)
        // FIXED: Wrapped in System.runAs to separate it from the Custom Settings DML
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            User testUser = new User(
                Alias = 'testu',
                Email = 'testuser.sync@example.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'test.user.for.attachmentsync@example.com' + System.currentTimeMillis()
            );
            insert testUser;

            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = ps.Id);
        }

        // 3. Create Data (Non-Setup Object)
        // We fetch the user created above to run the ticket creation
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        System.runAs(testUser) {
            List<Ticket__c> tickets = new List<Ticket__c>{
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-1'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-2'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-3')
            };
            insert tickets;

            // Create an existing log to test duplicate skipping
            Ticket__c ticketToLog = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
            insert new Attachment_Sync_Log__c(
                Ticket__c = ticketToLog.Id,
                JiraAttachmentIdTxt__c = '10001',
                FilenameTxt__c = 'existing_file.txt',
                SyncDirectionPk__c = 'Jira to SF',
                SyncStatusPk__c = 'Success'
            );
        }
    }

    // == Test Case 1: Success path and duplicate skipping ==
    @isTest
    static void testSuccessAndSkipDuplicate() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];
        
        System.runAs(testUser) {
            Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
            
            // 1. Issue Response (Contains 1 existing file and 1 new file)
            HttpResponse issueRes = new HttpResponse();
            issueRes.setStatusCode(200);
            issueRes.setHeader('Content-Type', 'application/json');
            // Note the content URL uses the base URL from custom settings
            issueRes.setBody('{"fields":{"attachment":[' +
                '{"id":"10001", "filename":"existing_file.txt", "content":"https://mock-jira.test.com/secure/attachment/10001/existing_file.txt"},' +
                '{"id":"10002", "filename":"new_file.pdf", "content":"https://mock-jira.test.com/secure/attachment/10002/new_file.pdf"}' +
                ']}}');
            
            // Map keys match the URL structure built by JiraCallout + Custom Settings
            responseMap.put('issue/JIRA-1', issueRes);

            // 2. File Download Response
            HttpResponse fileRes = new HttpResponse();
            fileRes.setStatusCode(200);
            fileRes.setHeader('Content-Type', 'application/pdf');
            fileRes.setBodyAsBlob(Blob.valueOf('PDF file content'));
            
            responseMap.put('attachment/10002/new_file.pdf', fileRes);

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
            Database.executeBatch(new JiraAttachmentSyncBatch());
            Test.stopTest();

            // Assertions
            Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
            
            // Verify ContentVersion created
            List<ContentVersion> versions = [SELECT Title FROM ContentVersion WHERE FirstPublishLocationId = :ticket.Id];
            System.assertEquals(1, versions.size(), 'Should have inserted exactly 1 new file (skipping the existing one)');
            System.assertEquals('new_file.pdf', versions[0].Title, 'The new file should be inserted');

            // Verify Log created
            List<Attachment_Sync_Log__c> logs = [SELECT Id FROM Attachment_Sync_Log__c WHERE JiraAttachmentIdTxt__c = '10002'];
            System.assertEquals(1, logs.size(), 'Should create a sync log for the new file');
        }
    }

    // == Test Case 2: Handles API failure (Non-200) ==
    @isTest
    static void testIssueApiFailure() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
            Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
            HttpResponse errorRes = new HttpResponse();
            errorRes.setStatusCode(500);
            errorRes.setStatus('Server Error');
            responseMap.put('issue/JIRA-1', errorRes); // Using partial matching logic
            
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
            Database.executeBatch(new JiraAttachmentSyncBatch());
            Test.stopTest();
            
            // Assert: No files should be created
            List<ContentVersion> versions = [SELECT Id FROM ContentVersion];
            System.assertEquals(0, versions.size(), 'Should not create files on API error');
        }
    }

    // == Test Case 3: Handles File Download Failure ==
    @isTest
    static void testFileDownloadFailure() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
            Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
            
            // Issue response success
            HttpResponse issueRes = new HttpResponse();
            issueRes.setStatusCode(200);
            issueRes.setBody('{"fields":{"attachment":[{"id":"30001", "filename":"bad.zip", "content":"https://mock-jira.test.com/bad/url"}]}}');
            responseMap.put('issue/JIRA-1', issueRes);

            // File response failure
            HttpResponse fileErrorRes = new HttpResponse();
            fileErrorRes.setStatusCode(403);
            responseMap.put('/bad/url', fileErrorRes);

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
            Database.executeBatch(new JiraAttachmentSyncBatch());
            Test.stopTest();
            
            // Assert: Should not insert file if download fails
            List<ContentVersion> versions = [SELECT Id FROM ContentVersion];
            System.assertEquals(0, versions.size(), 'Should not insert file if download fails');
        }
    }

    // == Test Case 4: Schedulable Interface ==
    @isTest
    static void testSchedulable() {
        Test.startTest();
        String cronExp = '0 0 0 3 9 ? 2099';
        String jobId = System.schedule('TestBatchSync', cronExp, new JiraAttachmentSyncBatch());
        Test.stopTest();
        
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
    }
}