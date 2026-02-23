/**
 * @description Test class for AttachmentSyncService functionality
 */
@isTest
private class AttachmentSyncServiceTest {
    
    @testSetup
    static void setup() {
        // 1. Create a standard user for testing
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
            UserName = 'test.user.for.attachmentsync@test.com' + System.currentTimeMillis()
        );
        insert testUser;

        // 2. Find the specified permission set by its API Name
        //PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin' LIMIT 1];
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App' LIMIT 1];
        // 3. Assign the permission set to the test user
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );
        insert psa;
    }

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
        
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        // Use System.runAs() to ensure the entire operation runs as the test user
        System.runAs(testUser) {
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
}
