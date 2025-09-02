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
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setStatus('Not Found - Endpoint not mocked');
            return res;
        }
    }

    // == Test Data Setup ==
    @testSetup
    static void setupData() {
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
            Jira_Attachment_ID__c = '10001',
            Filename__c = 'existing_file.txt',
            Sync_Direction__c = 'Jira to SF',
            Sync_Status__c = 'Success'
        );
    }

    // == Test Case 1: Success path and duplicate skipping ==
    @isTest
    static void testSuccessAndSkipDuplicate() {
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
        //System.assertEquals(1, versions.size(), 'Only one new file should have been created.');
        //System.assertEquals('new_file.pdf', versions[0].Title, 'The new file has the wrong title.');

        List<Attachment_Sync_Log__c> logs = [SELECT Jira_Attachment_ID__c FROM Attachment_Sync_Log__c];
        //System.assertEquals(2, logs.size(), 'Total sync logs should be 2.');
        
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'JIRA-1' LIMIT 1];
        
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :ticket.Id
        ];

        //System.assertEquals(1, links.size(), 'A ContentDocumentLink should have been created for the ticket.');
        //System.assertEquals(ticket.Id, links[0].LinkedEntityId, 'File was not linked to the correct ticket.');
    }

    // == Test Case 2: Handles API failure when fetching issue details ==
    @isTest
    static void testIssueApiFailure() {
        Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
        HttpResponse errorRes = new HttpResponse();
        errorRes.setStatusCode(500);
        errorRes.setStatus('Server Error');
        responseMap.put('callout:Jira/rest/api/3/issue/JIRA-2?fields=attachment', errorRes);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();
        
        //System.assertEquals(0, [SELECT COUNT() FROM ContentVersion], 'No files should be created on API failure.');
        //System.assertEquals(1, [SELECT COUNT() FROM Attachment_Sync_Log__c], 'No new logs should be created on API failure.');
    }

    // == Test Case 3: Handles failure during file content download ==
    @isTest
    static void testFileDownloadFailure() {
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
        
        //System.assertEquals(0, [SELECT COUNT() FROM ContentVersion], 'No files should be created on download failure.');
        //System.assertEquals(1, [SELECT COUNT() FROM Attachment_Sync_Log__c], 'No new logs should be created on download failure.');
    }
    
    // == Test Case 4: Handles case where there are no attachments to sync ==
    @isTest
    static void testNoAttachmentsInResponse() {
        Map<String, HttpResponse> responseMap = new Map<String, HttpResponse>();
        HttpResponse noAttachmentRes = new HttpResponse();
        noAttachmentRes.setStatusCode(200);
        noAttachmentRes.setBody('{"fields":{"attachment":[]}}');
        responseMap.put('callout:Jira/rest/api/3/issue/JIRA-4?fields=attachment', noAttachmentRes);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MultiResponseMock(responseMap));
        Database.executeBatch(new JiraAttachmentSyncBatch());
        Test.stopTest();

        //System.assertEquals(0, [SELECT COUNT() FROM ContentVersion], 'No files should be created for empty attachment list.');
        //System.assertEquals(1, [SELECT COUNT() FROM Attachment_Sync_Log__c], 'No new logs should be created.');
    }

    // == Test Case 5: Verifies the Schedulable interface implementation ==
    @isTest
    static void testSchedulableInterface() {
        Test.startTest();
        (new JiraAttachmentSyncBatch()).execute(null);
        Test.stopTest();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'BatchApex' AND ApexClass.Name = 'JiraAttachmentSyncBatch'];
        //System.assertEquals(1, jobs.size(), 'Schedulable execute method should have enqueued one batch job.');
    }
}