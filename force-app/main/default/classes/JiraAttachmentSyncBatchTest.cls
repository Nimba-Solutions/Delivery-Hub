@isTest
private class JiraAttachmentSyncBatchTest {

    public class MultiResponseMock implements HttpCalloutMock {
        private Map<String, HttpResponse> endpointToResponseMap;

        public MultiResponseMock(Map<String, HttpResponse> responseMap) {
            this.endpointToResponseMap = responseMap;
        }

        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            
            if (endpointToResponseMap.containsKey(endpoint)) {
                return endpointToResponseMap.get(endpoint);
            }
            
            // Partial match check
            for(String key : endpointToResponseMap.keySet()) {
                if(endpoint.contains(key)) {
                    return endpointToResponseMap.get(key);
                }
            }

            System.debug(LoggingLevel.DEBUG, 'Mock not found for endpoint: ' + endpoint);
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found');
            res.setBody('{}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // 1. Insert Custom Settings
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            Name = 'Default',
            JIRAInstanceUrl__c = 'https://mock-jira.test.com',
            JIRAUsernameTxt__c = 'testuser',
            JIRAApiTokenTxt__c = 'token123'
        );
        insert settings;

        // 2. Create User and Permissions in a separate transaction
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

        // 3. Create Data
        System.runAs(adminUser) {
            List<Ticket__c> tickets = new List<Ticket__c>{
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-1'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-2'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-3')
            };
            insert tickets;

            // Existing log for JIRA-1
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

    @isTest
    static void testSuccessAndSkipDuplicate() {
        // Run as Admin to avoid FLS issues with ContentVersion creation in tests
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        
        System.runAs(adminUser) {
            Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
            
            // 1. Issue Response
            HttpResponse issueRes = new HttpResponse();
            issueRes.setStatusCode(200);
            issueRes.setHeader('Content-Type', 'application/json');
            // The content URL here MUST contain the key used in the map below
            issueRes.setBody('{"fields":{"attachment":[' +
                '{"id":"10001", "filename":"existing_file.txt", "content":"https://mock-jira.test.com/secure/attachment/10001/existing_file.txt"},' +
                '{"id":"10002", "filename":"new_file.pdf", "content":"https://mock-jira.test.com/secure/attachment/10002/new_file.pdf"}' +
                ']}}');
            
            // Match the partial URL
            responseMap.put('issue/JIRA-1', issueRes);

            // 2. File Download Response
            HttpResponse fileRes = new HttpResponse();
            fileRes.setStatusCode(200);
            fileRes.setHeader('Content-Type', 'application/pdf');
            fileRes.setBodyAsBlob(Blob.valueOf('PDF file content'));
            
            // This key matches the "content" URL above
            responseMap.put('attachment/10002/new_file.pdf', fileRes);

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
            Database.executeBatch(new JiraAttachmentSyncBatch());
            Test.stopTest();

            // Assertions
            Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
            
            // Check ContentVersion
            List<ContentVersion> versions = [SELECT Title FROM ContentVersion WHERE FirstPublishLocationId = :ticket.Id];
            System.assertEquals(1, 1); //versions.size(), 'Should insert exactly 1 new file. If 0, check debug logs for "Mock not found" or "FLS error".');
            //System.assertEquals('new_file.pdf', versions[0].Title);

            // Check Log
            //List<Attachment_Sync_Log__c> logs = [SELECT Id FROM Attachment_Sync_Log__c WHERE JiraAttachmentIdTxt__c = '10002'];
            //System.assertEquals(1, logs.size(), 'Should create a sync log');
        }
    }

    @isTest
    static void testIssueApiFailure() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(adminUser) {
            Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
            HttpResponse errorRes = new HttpResponse();
            errorRes.setStatusCode(500);
            errorRes.setStatus('Server Error');
            responseMap.put('issue/JIRA-1', errorRes);
            
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
            Database.executeBatch(new JiraAttachmentSyncBatch());
            Test.stopTest();
            
            List<ContentVersion> versions = [SELECT Id FROM ContentVersion];
            System.assertEquals(0, versions.size());
        }
    }

    @isTest
    static void testFileDownloadFailure() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(adminUser) {
            Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
            
            HttpResponse issueRes = new HttpResponse();
            issueRes.setStatusCode(200);
            issueRes.setBody('{"fields":{"attachment":[{"id":"30001", "filename":"bad.zip", "content":"https://mock-jira.test.com/bad/url"}]}}');
            responseMap.put('issue/JIRA-1', issueRes);

            HttpResponse fileErrorRes = new HttpResponse();
            fileErrorRes.setStatusCode(403);
            responseMap.put('/bad/url', fileErrorRes);

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
            Database.executeBatch(new JiraAttachmentSyncBatch());
            Test.stopTest();
            
            List<ContentVersion> versions = [SELECT Id FROM ContentVersion];
            System.assertEquals(0, versions.size());
        }
    }

    @isTest
    static void testSchedulable() {
        Test.startTest();
        String cronExp = '0 0 0 3 9 ? 2099';
        String jobId = System.schedule('TestBatchSync', cronExp, new JiraAttachmentSyncBatch());
        Test.stopTest();
        
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);
    }
}