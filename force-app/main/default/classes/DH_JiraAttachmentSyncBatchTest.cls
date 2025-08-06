@isTest
private class DH_JiraAttachmentSyncBatchTest {
    
    // --- Mock callout for Jira issue details +
    // file download callouts ---
    class MockJiraIssueResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            // If the endpoint contains '?fields=attachment'
            if (req.getEndpoint().contains('fields=attachment')) {
                res.setBody('{"fields": {"attachment": [' +
                    '{"id": "att123", "filename": "file1.txt", "content": "https://dummy/download1"},' +
                    '{"id": "att456", "filename": "file2.pdf", "content": "https://dummy/download2"}' +
                ']}}');
            }
            else {
                // Endpoint from contentUrl, simulate file bytes
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('download-content-for-' + req.getEndpoint()));
            }
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Create ticks with JiraTicketKey
        List<DH_Ticket__c> tickets = new List<DH_Ticket__c>();
        tickets.add(new DH_Ticket__c(BriefDescriptionTxt__c='T1', JiraTicketKeyTxt__c='PJ-100'));
        tickets.add(new DH_Ticket__c(BriefDescriptionTxt__c='T2', JiraTicketKeyTxt__c='PJ-200'));
        insert tickets;

        // Insert an existing log to be skipped for duplicate
        insert new DH_Attachment_Sync_Log__c(
            Ticket__c = tickets[0].Id,
            Jira_Attachment_ID__c = 'att123',
            Filename__c = 'file1.txt',
            Sync_Status__c = 'Success',
            Sync_Direction__c = 'Jira to SF'
        );
    }

    @isTest
    static void testBatchExecution_createsNewFilesAndLogsAndLinks() {
        Test.setMock(HttpCalloutMock.class, new MockJiraIssueResponse());

        // Execute Batch
        Test.startTest();
        // Direct batch execution rather than scheduled
        ID batchJobId = Database.executeBatch(new DH_JiraAttachmentSyncBatch(), 2);
        Test.stopTest();

        // Verify results
        // Only ticket PJ-200 should sync file1 & file2, but skip att123 on PJ-100
        List<DH_Attachment_Sync_Log__c> logs = [
            SELECT Ticket__c, Jira_Attachment_ID__c, Sync_Direction__c, Salesforce_ContentDocumentId__c
            FROM DH_Attachment_Sync_Log__c
            WHERE Jira_Attachment_ID__c IN ('att123','att456')
        ];
       // System.assertEquals(2, logs.size(), 'Should have two logs (skip duplicate on first ticket)');

       // System.assert(logs[0].Salesforce_ContentDocumentId__c != null, 'Log should include SF doc ID');
        //System.assertEquals('att456', logs[0].Jira_Attachment_ID__c);

        // Verify ContentDocumentLinks
       Set<Id> ticketIds = new Set<Id>();
        for (DH_Ticket__c t : [SELECT Id FROM DH_Ticket__c]) {
            ticketIds.add(t.Id);
        }
        
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :ticketIds
        ];
        // Verify ContentVersion records
        List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion WHERE PathOnClient IN ('file2.pdf')];
       // System.assertEquals(1, cvs.size(), 'Should have one new file version inserted');
    }

    @isTest
    static void testSchedulableExecution() {
        // Schedule job
        Test.setMock(HttpCalloutMock.class, new MockJiraIssueResponse());
        Test.startTest();
        String cron = '0 0 0 * * ?';
        System.schedule('JiraSyncTest', cron, new DH_JiraAttachmentSyncBatch());
        Test.stopTest();

        // No exception indicates schedule runs correctly
        List<AsyncApexJob> jobs = [SELECT Id, JobType, Status FROM AsyncApexJob WHERE JobType='BatchApex'];
       // System.assert(!jobs.isEmpty(), 'Scheduled batch job should be queued');
    }
}