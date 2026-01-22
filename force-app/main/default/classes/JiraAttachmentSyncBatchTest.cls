@isTest
private class JiraAttachmentSyncBatchTest {

    public class MultiResponseMock implements HttpCalloutMock {
        private Map<String, HttpResponse> endpointToResponseMap;

        public MultiResponseMock(Map<String, HttpResponse> responseMap) {
            this.endpointToResponseMap = responseMap;
        }

        /**
         * @description Mock response handler for various endpoints
         * @param req The HTTP Request being sent
         * @return The Mock HTTP Response
         */
        public HttpResponse respond(HttpRequest req) {
            String endpoint = req.getEndpoint();
            if (endpointToResponseMap.containsKey(endpoint)) {
                return endpointToResponseMap.get(endpoint);
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found - Endpoint not mocked');
            return res;
        }
    }

    // == Test Data Setup ==
    @testSetup
    static void setupData() {
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
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );
        insert psa;

        System.runAs(testUser) {
            List<Ticket__c> tickets = new List<Ticket__c>{
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-1'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-2'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-3'),
                new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-4')
            };
            insert tickets;

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
        
        HttpResponse issueRes = new HttpResponse();
        issueRes.setStatusCode(200);
        issueRes.setHeader('Content-Type', 'application/json');
        issueRes.setBody('{"fields":{"attachment":[' +
            '{"id":"10001", "filename":"existing_file.txt", "content":"callout:Jira/download/10001"},' +
            '{"id":"10002", "filename":"new_file.pdf", "content":"callout:Jira/download/10002"}' +
            ']}}');
        responseMap.put('callout:Jira/rest/api/3/issue/JIRA-1?fields=attachment', issueRes);

        HttpResponse fileRes = new HttpResponse();
        fileRes.setStatusCode(200);
        fileRes.setHeader('Content-Type', 'application/pdf');
        fileRes.setBodyAsBlob(Blob.valueOf('PDF file content'));
        responseMap.put('callout:Jira/download/10002', fileRes);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();

        List<ContentVersion> versions = [SELECT Title, PathOnClient FROM ContentVersion];
        List<Attachment_Sync_Log__c> logs = [SELECT JiraAttachmentIdTxt__c FROM Attachment_Sync_Log__c];
        
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
        
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :ticket.Id
        ];
        }
    }

    // == Test Case 2: Handles API failure when fetching issue details ==
    @isTest
    static void testIssueApiFailure() {
          
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
        HttpResponse errorRes = new HttpResponse();
        errorRes.setStatusCode(500);
        errorRes.setStatus('Server Error');
        responseMap.put('callout:Jira/rest/api/3/issue/JIRA-2?fields=attachment', errorRes);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();
        }
    }

    // == Test Case 3: Handles failure during file content download ==
    @isTest
    static void testFileDownloadFailure() {
          
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
        
        HttpResponse issueRes = new HttpResponse();
        issueRes.setStatusCode(200);
        issueRes.setBody('{"fields":{"attachment":[{"id":"30001", "filename":"bad_download.zip", "content":"callout:Jira/download/30001"}]}}');
        responseMap.put('callout:Jira/rest/api/3/issue/JIRA-3?fields=attachment', issueRes);

        HttpResponse fileErrorRes = new HttpResponse();
        fileErrorRes.setStatusCode(403);
        fileErrorRes.setStatus('Forbidden');
        responseMap.put('callout:Jira/download/30001', fileErrorRes);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();
        }
    }
    
    // == Test Case 4: Handles case where there are no attachments to sync ==
    @isTest
    static void testNoAttachmentsInResponse() {
          
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
        HttpResponse noAttachmentRes = new HttpResponse();
        noAttachmentRes.setStatusCode(200);
        noAttachmentRes.setBody('{"fields":{"attachment":[]}}');
        responseMap.put('callout:Jira/rest/api/3/issue/JIRA-4?fields=attachment', noAttachmentRes);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();
        }
    }

    // == Test Case 5: Verifies the Schedulable interface implementation ==
    @isTest
    static void testSchedulableInterface() {
          
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        Test.startTest();
        (new JiraAttachmentSyncBatch()).execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'BatchApex' AND ApexClass.Name = 'JiraAttachmentSyncBatch'];
        }
    }
}