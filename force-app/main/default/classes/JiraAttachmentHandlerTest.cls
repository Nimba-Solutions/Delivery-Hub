/**
 * @description Test class for JiraAttachmentHandler
 * Tests attachment synchronization functionality including download, creation,
 * removal, and comprehensive error handling scenarios.
 */
@isTest
public class JiraAttachmentHandlerTest {
    
    /**
     * @description Test setup method to create test data
     */
    @testSetup
    static void setupTestData() {
        // Create test ticket
        DH_Ticket__c testTicket = new DH_Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket for Attachment Sync',
            JiraTicketKeyTxt__c = 'TEST-123',
            StatusPk__c = 'Open'
        );
        insert testTicket;
    }
    
    /**
     * @description Test successful attachment addition from Jira webhook
     */
    @isTest
    static void testHandleAttachmentAdded_Success() {
        // Setup test data
        DH_Ticket__c testTicket = [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c LIMIT 1];
        
        // Create mock attachment payload
        Map<String, Object> payload = createMockAttachmentPayload('12345', 'test-file.pdf', 'TEST-123', 1024, 
                                                                 'https://jira.example.com/rest/api/2/attachment/content/12345');
        
        // Set up mock HTTP response
        Test.setMock(HttpCalloutMock.class, new JiraAttachmentHandlerMock(200, 'Mock file content'));
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentAdded(payload);
        Test.stopTest();
        
        // Verify success
        System.assert(result, 'handleAttachmentAdded should return true for successful processing');
        
        // Verify ContentVersion was created
        List<ContentVersion> contentVersions = [SELECT Id, Title, Description FROM ContentVersion WHERE Title = 'test-file.pdf'];
        System.assertEquals(1, contentVersions.size(), 'One ContentVersion should be created');
        System.assert(contentVersions[0].Description.contains('12345'), 'Description should contain Jira attachment ID');
        
        // Verify ContentDocumentLink was created
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testTicket.Id];
        System.assertEquals(1, links.size(), 'One ContentDocumentLink should be created');
        
        // Verify sync log was created
        List<DH_Attachment_Sync_Log__c> logs = [SELECT Id, Sync_Status__c, Jira_Attachment_ID__c, Filename__c 
                                               FROM DH_Attachment_Sync_Log__c WHERE Ticket__c = :testTicket.Id];
        System.assertEquals(1, logs.size(), 'One sync log should be created');
        System.assertEquals('Success', logs[0].Sync_Status__c, 'Sync status should be Success');
        System.assertEquals('12345', logs[0].Jira_Attachment_ID__c, 'Jira attachment ID should match');
        System.assertEquals('test-file.pdf', logs[0].Filename__c, 'Filename should match');
    }
    
    /**
     * @description Test attachment addition when ticket is not found
     */
    @isTest
    static void testHandleAttachmentAdded_TicketNotFound() {
        // Create mock attachment payload with non-existent issue key
        Map<String, Object> payload = createMockAttachmentPayload('12345', 'test-file.pdf', 'NONEXISTENT-123', 1024, 
                                                                 'https://jira.example.com/rest/api/2/attachment/content/12345');
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentAdded(payload);
        Test.stopTest();
        
        // Verify failure
        System.assert(!result, 'handleAttachmentAdded should return false when ticket not found');
        
        // Verify no ContentVersion was created
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = 'test-file.pdf'];
        System.assertEquals(0, contentVersions.size(), 'No ContentVersion should be created');
        
        // Verify no sync log was created (cannot create without ticket ID due to Master-Detail relationship)
        List<DH_Attachment_Sync_Log__c> logs = [SELECT Id FROM DH_Attachment_Sync_Log__c WHERE Jira_Attachment_ID__c = '12345'];
        System.assertEquals(0, logs.size(), 'No sync log should be created when ticket is not found');
    }
    
    /**
     * @description Test attachment addition with file size too large
     */
    @isTest
    static void testHandleAttachmentAdded_FileSizeTooLarge() {
        // Setup test data
        DH_Ticket__c testTicket = [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c LIMIT 1];
        
        // Create mock attachment payload with large file size (30MB)
        Integer largeFileSize = 30 * 1024 * 1024;
        Map<String, Object> payload = createMockAttachmentPayload('12345', 'large-file.pdf', 'TEST-123', largeFileSize, 
                                                                 'https://jira.example.com/rest/api/2/attachment/content/12345');
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentAdded(payload);
        Test.stopTest();
        
        // Verify failure
        System.assert(!result, 'handleAttachmentAdded should return false for oversized files');
        
        // Verify no ContentVersion was created
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = 'large-file.pdf'];
        System.assertEquals(0, contentVersions.size(), 'No ContentVersion should be created for oversized files');
        
        // Verify error sync log was created
        List<DH_Attachment_Sync_Log__c> logs = [SELECT Id, Sync_Status__c, Error_Details__c 
                                               FROM DH_Attachment_Sync_Log__c WHERE Ticket__c = :testTicket.Id];
        System.assertEquals(1, logs.size(), 'One error sync log should be created');
        System.assertEquals('Failed', logs[0].Sync_Status__c, 'Sync status should be Failed');
        System.assert(logs[0].Error_Details__c.contains('exceeds Salesforce limit'), 'Error should mention size limit');
    }
    
    /**
     * @description Test attachment addition with HTTP callout failure
     */
    @isTest
    static void testHandleAttachmentAdded_DownloadFailure() {
        // Setup test data
        DH_Ticket__c testTicket = [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c LIMIT 1];
        
        // Create mock attachment payload
        Map<String, Object> payload = createMockAttachmentPayload('12345', 'test-file.pdf', 'TEST-123', 1024, 
                                                                 'https://jira.example.com/rest/api/2/attachment/content/12345');
        
        // Set up mock HTTP response with error
        Test.setMock(HttpCalloutMock.class, new JiraAttachmentHandlerMock(404, 'Attachment not found'));
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentAdded(payload);
        Test.stopTest();
        
        // Verify failure
        System.assert(!result, 'handleAttachmentAdded should return false for download failures');
        
        // Verify no ContentVersion was created
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = 'test-file.pdf'];
        System.assertEquals(0, contentVersions.size(), 'No ContentVersion should be created for failed downloads');
        
        // Verify error sync log was created
        List<DH_Attachment_Sync_Log__c> logs = [SELECT Id, Sync_Status__c, Error_Details__c 
                                               FROM DH_Attachment_Sync_Log__c WHERE Ticket__c = :testTicket.Id];
        System.assertEquals(1, logs.size(), 'One error sync log should be created');
        System.assertEquals('Failed', logs[0].Sync_Status__c, 'Sync status should be Failed');
        System.assert(logs[0].Error_Details__c.contains('Failed to download attachment'), 'Error should mention download failure');
    }
    
    /**
     * @description Test successful attachment removal from Jira webhook
     */
    @isTest
    static void testHandleAttachmentRemoved_Success() {
        // Setup test data
        DH_Ticket__c testTicket = [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c LIMIT 1];
        
        // Create ContentVersion and ContentDocumentLink
        ContentVersion cv = new ContentVersion(
            Title = 'test-file.pdf',
            PathOnClient = 'test-file.pdf',
            VersionData = Blob.valueOf('Test content'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = testTicket.Id,
            ShareType = 'V'
        );
        insert cdl;
        
        // Create existing sync log
        DH_Attachment_Sync_Log__c existingLog = new DH_Attachment_Sync_Log__c(
            Ticket__c = testTicket.Id,
            Jira_Attachment_ID__c = '12345',
            Filename__c = 'test-file.pdf',
            Sync_Direction__c = 'Jira to SF',
            Sync_Status__c = 'Success',
            Salesforce_ContentDocumentId__c = insertedCv.ContentDocumentId
        );
        insert existingLog;
        
        // Create mock attachment removal payload
        Map<String, Object> payload = createMockAttachmentRemovalPayload('12345', 'test-file.pdf', 'TEST-123');
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentRemoved(payload);
        Test.stopTest();
        
        // Verify success
        System.assert(result, 'handleAttachmentRemoved should return true for successful processing');
        
        // Verify ContentDocumentLink was removed
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testTicket.Id];
        System.assertEquals(0, links.size(), 'ContentDocumentLink should be removed');
        
        // Verify removal sync log was created
        List<DH_Attachment_Sync_Log__c> logs = [SELECT Id, Sync_Status__c, Error_Details__c 
                                               FROM DH_Attachment_Sync_Log__c 
                                               WHERE Ticket__c = :testTicket.Id 
                                               AND Jira_Attachment_ID__c = '12345'
                                               ORDER BY CreatedDate DESC];
        System.assertEquals(2, logs.size(), 'Two sync logs should exist (original + removal)');
        System.assertEquals('Success', logs[0].Sync_Status__c, 'Latest sync status should be Success');
        System.assert(logs[0].Error_Details__c.contains('removed successfully'), 'Success message should mention removal');
    }
    
    /**
     * @description Test attachment removal when no existing sync log found
     */
    @isTest
    static void testHandleAttachmentRemoved_NoExistingLog() {
        // Setup test data
        DH_Ticket__c testTicket = [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c LIMIT 1];
        
        // Create mock attachment removal payload
        Map<String, Object> payload = createMockAttachmentRemovalPayload('12345', 'test-file.pdf', 'TEST-123');
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentRemoved(payload);
        Test.stopTest();
        
        // Verify failure
        System.assert(!result, 'handleAttachmentRemoved should return false when no existing log found');
        
        // Verify error sync log was created
        List<DH_Attachment_Sync_Log__c> logs = [SELECT Id, Sync_Status__c, Error_Details__c 
                                               FROM DH_Attachment_Sync_Log__c WHERE Ticket__c = :testTicket.Id];
        System.assertEquals(1, logs.size(), 'One error sync log should be created');
        System.assertEquals('Failed', logs[0].Sync_Status__c, 'Sync status should be Failed');
        System.assert(logs[0].Error_Details__c.contains('No existing ContentDocument found'), 'Error should mention missing ContentDocument');
    }
    
    /**
     * @description Test attachment handling with invalid payload
     */
    @isTest
    static void testHandleAttachmentAdded_InvalidPayload() {
        // Create invalid payload (missing attachment data)
        Map<String, Object> payload = new Map<String, Object>{
            'issue' => new Map<String, Object>{
                'key' => 'TEST-123'
            }
        };
        
        Test.startTest();
        Boolean result = JiraAttachmentHandler.handleAttachmentAdded(payload);
        Test.stopTest();
        
        // Verify failure
        System.assert(!result, 'handleAttachmentAdded should return false for invalid payload');
    }
    
    /**
     * @description Helper method to create mock attachment payload
     */
    private static Map<String, Object> createMockAttachmentPayload(String attachmentId, String filename, 
                                                                  String issueKey, Integer fileSize, String contentUrl) {
        return new Map<String, Object>{
            'attachment' => new Map<String, Object>{
                'id' => attachmentId,
                'filename' => filename,
                'size' => fileSize,
                'content' => contentUrl
            },
            'issue' => new Map<String, Object>{
                'key' => issueKey
            }
        };
    }
    
    /**
     * @description Helper method to create mock attachment removal payload
     */
    private static Map<String, Object> createMockAttachmentRemovalPayload(String attachmentId, String filename, String issueKey) {
        return new Map<String, Object>{
            'attachment' => new Map<String, Object>{
                'id' => attachmentId,
                'filename' => filename
            },
            'issue' => new Map<String, Object>{
                'key' => issueKey
            }
        };
    }
    
    /**
     * @description Mock HTTP callout class for testing Jira attachment downloads
     */
    public class JiraAttachmentHandlerMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public JiraAttachmentHandlerMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            
            if (statusCode == 200) {
                res.setHeader('Content-Type', 'application/octet-stream');
            }
            
            return res;
        }
    }
}