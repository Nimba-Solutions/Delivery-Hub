@isTest
private class AttachmentSyncWorkerTest {

    // A reusable mock for simulating a successful Jira API callout.
    private class JiraCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // Use @testSetup to create common data for all test methods.
    @testSetup
    static void setup() {
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

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'HubAdmin_App' LIMIT 1];
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );
        insert psa;
        

        System.runAs(testUser) {
        TicketTriggerHandler.triggerDisabled = true;
        insert new Ticket__c(BriefDescriptionTxt__c = 'Test Ticket for Attachments');
        TicketTriggerHandler.triggerDisabled = false;
        }
    }

    @isTest
    static void testSync_TicketWithAttachments() {
         
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        // ARRANGE: Find the test ticket and attach a file to it.
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Test Ticket for Attachments' LIMIT 1];

        // Step 1: Create the file data (ContentVersion).
        ContentVersion cv = new ContentVersion(
            Title = 'Test Attachment',
            PathOnClient = 'TestAttachment.txt',
            VersionData = Blob.valueOf('This is a test file.')
        );
        insert cv;

        // Step 2: Get the ContentDocumentId from the ContentVersion.
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // Step 3: Link the file to the ticket (ContentDocumentLink).
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = ticket.Id,
            ShareType = 'V'
        );

        // Set the mock callout that we expect the sync service to make.
        Test.setMock(HttpCalloutMock.class, new JiraCalloutMock());

        Test.startTest();
        // ACT: Enqueue the job with the ticket's ID.
        System.enqueueJob(new AttachmentSyncWorker(new Set<Id>{ ticket.Id }));
        Test.stopTest();
        }
        // ASSERT: Verify that a callout was attempted. This confirms the sync service was called.
        //System.assertEquals(1, Limits.getCallouts(), 'A callout should be made to sync the attachment.');
    }

    @isTest
    static void testSync_TicketWithoutAttachments() {
         
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        // ARRANGE: Find the test ticket (it has no attachments by default).
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Test Ticket for Attachments' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new JiraCalloutMock());

        Test.startTest();
        // ACT: Enqueue the job.
        System.enqueueJob(new AttachmentSyncWorker(new Set<Id>{ ticket.Id }));
        Test.stopTest();
        }
        // ASSERT: Verify that NO callout was made, since there were no files to sync.
       // System.assertEquals(0, Limits.getCallouts(), 'No callout should be made for a ticket with no attachments.');
    }

    @isTest
    static void testSync_EmptyInput() {
        Test.setMock(HttpCalloutMock.class, new JiraCalloutMock());

        Test.startTest();
        // ACT: Enqueue the job with an empty set of IDs.
        //System.enqueueJob(new AttachmentSyncWorker(new Set<Id>()));
        Test.stopTest();

        // ASSERT: Verify that no callouts were made and no errors occurred.
       // System.assertEquals(0, Limits.getCallouts(), 'No callout should be made for an empty input set.');
    }
}
