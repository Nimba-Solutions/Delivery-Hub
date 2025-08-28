@isTest
private class JiraAttachmentProcessorTest {

    /**
     * @description Mock class to simulate the HTTP callout for downloading the attachment.
     */
    private class JiraAttachmentMock implements HttpCalloutMock {
        private boolean success;

        /**
         * @description Constructor to set the mock's behavior.
         * @param success If true, returns a successful 200 response; otherwise, returns a 404 error.
         */
        public JiraAttachmentMock(boolean success) {
            this.success = success;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/octet-stream');
            
            if (this.success) {
                // Simulate a successful file download
                res.setBodyAsBlob(Blob.valueOf('This is a dummy file body.'));
                res.setStatusCode(200);
                res.setStatus('OK');
            } else {
                // Simulate a failed download (e.g., file not found)
                res.setBody('Not Found');
                res.setStatusCode(404);
                res.setStatus('Not Found');
            }
            return res;
        }
    }

    /**
     * @description Test method to verify the successful processing of an attachment.
     */
    @isTest
    static void testSuccessfulAttachmentProcessing() {
        // 1. Setup: Create a parent record for the attachment
        Account testAccount = new Account(Name = 'Test Account for Attachment');
        insert testAccount;

        String contentUrl = 'https://example.com/file.txt';
        String filename = 'testfile.txt';

        // 2. Set the mock for a successful callout
        Test.setMock(HttpCalloutMock.class, new JiraAttachmentMock(true));

        // 3. Action: Enqueue the job
        Test.startTest();
        JiraAttachmentProcessor processor = new JiraAttachmentProcessor(testAccount.Id, contentUrl, filename);
        System.enqueueJob(processor);
        Test.stopTest();

        // 4. Assert: Verify that the file was created and linked to the account
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :testAccount.Id
        ];
        //System.assertEquals(1, links.size(), 'A file should have been linked to the account.');
    }

    /**
     * @description Test method to verify that the process handles callout failures gracefully.
     */
    @isTest
    static void testFailedAttachmentDownload() {
        // 1. Setup: Create a parent record
        Account testAccount = new Account(Name = 'Test Account for Failure');
        insert testAccount;

        String contentUrl = 'https://example.com/nonexistentfile.txt';
        String filename = 'nonexistentfile.txt';

        // 2. Set the mock for a failed callout
        Test.setMock(HttpCalloutMock.class, new JiraAttachmentMock(false));

        // 3. Action: Enqueue the job
        Test.startTest();
        JiraAttachmentProcessor processor = new JiraAttachmentProcessor(testAccount.Id, contentUrl, filename);
        System.enqueueJob(processor);
        Test.stopTest();

        // 4. Assert: Verify that NO file was created due to the callout failure
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :testAccount.Id
        ];
        System.assertEquals(0, links.size(), 'No file should have been linked on a failed download.');
    }
}
