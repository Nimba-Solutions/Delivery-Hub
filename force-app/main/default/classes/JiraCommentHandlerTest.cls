/**
 * @description Test class for JiraCommentHandler
 * Tests comment synchronization functionality including creation, updates, deletion,
 * field mapping, validation, and error handling scenarios.
 */
@isTest
private class JiraCommentHandlerTest {
    
    // Test data constants
    private static final String TEST_JIRA_KEY = 'TEST-123';
    private static final String TEST_COMMENT_ID = 'comment-456';
    private static final String TEST_AUTHOR_NAME = 'John Doe';
    private static final String TEST_AUTHOR_EMAIL = 'john.doe@example.com';
    private static final String TEST_COMMENT_BODY = '<p>This is a <b>test</b> comment with <i>formatting</i>.</p>';
    private static final String TEST_PLAIN_BODY = 'This is a test comment with formatting.';
    
    /**
     * @description Test setup method to create test data
     */
    @testSetup
    static void setupTestData() {
        // Create a test ticket
        Ticket__c testTicket = new Ticket__c(
            JiraTicketKeyTxt__c = TEST_JIRA_KEY,
            BriefDescriptionTxt__c = 'Test ticket for comment sync'
        );
        insert testTicket;
    }
    
    /**
     * @description Test successful comment creation from Jira webhook
     */
    @isTest
    static void testHandleCommentCreated_Success() {
        // Prepare test payload
        Map<String, Object> payload = createTestCommentPayload(TEST_COMMENT_ID, TEST_JIRA_KEY, TEST_COMMENT_BODY);
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentCreated(payload);
        Test.stopTest();
        
        // Verify success
        System.assert(result, 'Comment creation should succeed');
        
        // Verify comment was created
        List<Ticket_Comment__c> comments = [
            SELECT Id, JiraCommentIdTxt__c, AuthorTxt__c, BodyTxt__c, SourcePk__c, TicketId__c
            FROM Ticket_Comment__c
            WHERE JiraCommentIdTxt__c = :TEST_COMMENT_ID
        ];
        
        System.assertEquals(1, comments.size(), 'Should create one comment');
        
        Ticket_Comment__c comment = comments[0];
        System.assertEquals(TEST_COMMENT_ID, comment.JiraCommentIdTxt__c, 'Should set Jira comment ID');
        System.assertEquals(TEST_AUTHOR_NAME, comment.AuthorTxt__c, 'Should set author name');
        System.assertEquals('Jira', comment.SourcePk__c, 'Should set source as Jira');
        System.assert(comment.BodyTxt__c.contains('test comment'), 'Should contain comment text');
    }
    
    /**
     * @description Test comment creation with duplicate prevention
     */
    @isTest
    static void testHandleCommentCreated_DuplicatePrevention() {
        // Create existing comment
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = :TEST_JIRA_KEY LIMIT 1];
        Ticket_Comment__c existingComment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            JiraCommentIdTxt__c = TEST_COMMENT_ID,
            AuthorTxt__c = 'Existing Author',
            BodyTxt__c = 'Existing comment',
            SourcePk__c = 'Jira'
        );
        insert existingComment;
        
        // Prepare test payload with same comment ID
        Map<String, Object> payload = createTestCommentPayload(TEST_COMMENT_ID, TEST_JIRA_KEY, TEST_COMMENT_BODY);
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentCreated(payload);
        Test.stopTest();
        
        // Verify success (duplicate handling)
        System.assert(result, 'Should handle duplicate gracefully');
        
        // Verify only one comment exists
        List<Ticket_Comment__c> comments = [
            SELECT Id FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = :TEST_COMMENT_ID
        ];
        System.assertEquals(1, comments.size(), 'Should not create duplicate comment');
    }
    
    /**
     * @description Test comment creation with missing ticket
     */
    @isTest
    static void testHandleCommentCreated_MissingTicket() {
        String nonExistentKey = 'MISSING-999';
        Map<String, Object> payload = createTestCommentPayload(TEST_COMMENT_ID, nonExistentKey, TEST_COMMENT_BODY);
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentCreated(payload);
        Test.stopTest();
        
        // Verify failure
        System.assert(!result, 'Should fail when ticket not found');
        
        // Verify no comment was created
        List<Ticket_Comment__c> comments = [
            SELECT Id FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = :TEST_COMMENT_ID
        ];
        System.assertEquals(0, comments.size(), 'Should not create comment without ticket');
    }
    
    /**
     * @description Test successful comment update from Jira webhook
     */
    @isTest
    static void testHandleCommentUpdated_Success() {
        // Create existing comment
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = :TEST_JIRA_KEY LIMIT 1];
        Ticket_Comment__c existingComment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            JiraCommentIdTxt__c = TEST_COMMENT_ID,
            AuthorTxt__c = 'Original Author',
            BodyTxt__c = 'Original comment text',
            SourcePk__c = 'Jira'
        );
        insert existingComment;
        
        // Prepare update payload
        String updatedBody = '<p>Updated comment with <b>new</b> content.</p>';
        Map<String, Object> payload = createTestCommentPayload(TEST_COMMENT_ID, TEST_JIRA_KEY, updatedBody);
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentUpdated(payload);
        Test.stopTest();
        
        // Verify success
        System.assert(result, 'Comment update should succeed');
        
        // Verify comment was updated
        Ticket_Comment__c updatedComment = [
            SELECT Id, AuthorTxt__c, BodyTxt__c, SyncedDateTime__c
            FROM Ticket_Comment__c
            WHERE JiraCommentIdTxt__c = :TEST_COMMENT_ID
            LIMIT 1
        ];
        
        System.assertEquals(TEST_AUTHOR_NAME, updatedComment.AuthorTxt__c, 'Should update author');
        System.assert(updatedComment.BodyTxt__c.contains('Updated comment'), 'Should update body text');
        System.assert(updatedComment.SyncedDateTime__c != null, 'Should update sync timestamp');
    }
    
    /**
     * @description Test comment update when comment doesn't exist (should create)
     */
    @isTest
    static void testHandleCommentUpdated_CreateIfMissing() {
        Map<String, Object> payload = createTestCommentPayload(TEST_COMMENT_ID, TEST_JIRA_KEY, TEST_COMMENT_BODY);
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentUpdated(payload);
        Test.stopTest();
        
        // Verify success
        System.assert(result, 'Should create comment if not found during update');
        
        // Verify comment was created
        List<Ticket_Comment__c> comments = [
            SELECT Id FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = :TEST_COMMENT_ID
        ];
        System.assertEquals(1, comments.size(), 'Should create comment when updating non-existent comment');
    }
    
    /**
     * @description Test successful comment deletion from Jira webhook
     */
    @isTest
    static void testHandleCommentDeleted_Success() {
        // Create existing comment
        Ticket__c ticket = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = :TEST_JIRA_KEY LIMIT 1];
        Ticket_Comment__c existingComment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            JiraCommentIdTxt__c = TEST_COMMENT_ID,
            AuthorTxt__c = TEST_AUTHOR_NAME,
            BodyTxt__c = 'Comment to be deleted',
            SourcePk__c = 'Jira'
        );
        insert existingComment;
        
        // Prepare deletion payload
        Map<String, Object> payload = new Map<String, Object>{
            'comment' => new Map<String, Object>{
                'id' => TEST_COMMENT_ID
            }
        };
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentDeleted(payload);
        Test.stopTest();
        
        // Verify success
        System.assert(result, 'Comment deletion should succeed');
        
        // Verify comment was marked as deleted
        Ticket_Comment__c deletedComment = [
            SELECT Id, BodyTxt__c, SyncedDateTime__c
            FROM Ticket_Comment__c
            WHERE JiraCommentIdTxt__c = :TEST_COMMENT_ID
            LIMIT 1
        ];
        
        System.assertEquals('[Comment deleted in Jira]', deletedComment.BodyTxt__c, 'Should mark as deleted');
        System.assert(deletedComment.SyncedDateTime__c != null, 'Should update sync timestamp');
    }
    
    /**
     * @description Test comment deletion when comment doesn't exist
     */
    @isTest
    static void testHandleCommentDeleted_NotFound() {
        Map<String, Object> payload = new Map<String, Object>{
            'comment' => new Map<String, Object>{
                'id' => 'non-existent-comment'
            }
        };
        
        Test.startTest();
        Boolean result = JiraCommentHandler.handleCommentDeleted(payload);
        Test.stopTest();
        
        // Verify success (graceful handling)
        System.assert(result, 'Should handle missing comment gracefully during deletion');
    }
    
    /**
     * @description Test enhanced author information extraction
     */
    @isTest
    static void testExtractAuthorInformationFromPayload() {
        Map<String, Object> commentData = new Map<String, Object>{
            'author' => new Map<String, Object>{
                'displayName' => TEST_AUTHOR_NAME,
                'emailAddress' => TEST_AUTHOR_EMAIL,
                'accountId' => 'account-123',
                'name' => 'jdoe'
            }
        };
        
        Test.startTest();
        Map<String, String> authorInfo = JiraCommentHandler.extractAuthorInformationFromPayload(commentData);
        Test.stopTest();
        
        System.assertEquals(TEST_AUTHOR_NAME, authorInfo.get('displayName'), 'Should extract display name');
        System.assertEquals(TEST_AUTHOR_EMAIL, authorInfo.get('emailAddress'), 'Should extract email');
        System.assertEquals('account-123', authorInfo.get('accountId'), 'Should extract account ID');
        System.assertEquals('jdoe', authorInfo.get('name'), 'Should extract name');
    }
    
    /**
     * @description Test author extraction with fallback scenarios
     */
    @isTest
    static void testExtractAuthorInformationFromPayload_Fallbacks() {
        // Test with updateAuthor fallback
        Map<String, Object> commentData = new Map<String, Object>{
            'updateAuthor' => new Map<String, Object>{
                'displayName' => 'Update Author',
                'emailAddress' => 'update@example.com'
            }
        };
        
        Test.startTest();
        Map<String, String> authorInfo = JiraCommentHandler.extractAuthorInformationFromPayload(commentData);
        Test.stopTest();
        
        System.assertEquals('Update Author', authorInfo.get('displayName'), 'Should use updateAuthor as fallback');
    }
    
    /**
     * @description Test enhanced comment body validation
     */
    @isTest
    static void testValidateCommentBodyEnhanced() {
        Test.startTest();
        
        // Test valid comment
        Map<String, Object> validResult = JiraCommentHandler.validateCommentBodyEnhanced('Valid comment text', null);
        System.assert((Boolean)validResult.get('isValid'), 'Valid comment should pass validation');
        
        // Test empty comment
        Map<String, Object> emptyResult = JiraCommentHandler.validateCommentBodyEnhanced('', null);
        System.assert(!(Boolean)emptyResult.get('isValid'), 'Empty comment should fail validation');
        
        // Test too long comment
        String longComment = 'x'.repeat(200000); // Exceeds max length
        Map<String, Object> longResult = JiraCommentHandler.validateCommentBodyEnhanced(longComment, null);
        System.assert(!(Boolean)longResult.get('isValid'), 'Too long comment should fail validation');
        
        Test.stopTest();
    }
    
    /**
     * @description Test enhanced ticket linking functionality
     */
    @isTest
    static void testLinkCommentToTicketEnhanced() {
        Test.startTest();
        
        // Test existing ticket
        Map<String, Object> linkResult = JiraCommentHandler.linkCommentToTicketEnhanced(TEST_JIRA_KEY, false);
        System.assert((Boolean)linkResult.get('success'), 'Should successfully link to existing ticket');
        System.assert((Boolean)linkResult.get('ticketExists'), 'Should indicate ticket exists');
        System.assert(!(Boolean)linkResult.get('ticketCreated'), 'Should not indicate ticket was created');
        
        // Test non-existent ticket without creation
        Map<String, Object> missingResult = JiraCommentHandler.linkCommentToTicketEnhanced('MISSING-999', false);
        System.assert(!(Boolean)missingResult.get('success'), 'Should fail for non-existent ticket');
        
        Test.stopTest();
    }
    
    /**
     * @description Test payload structure validation
     */
    @isTest
    static void testValidateCommentPayloadStructure() {
        Test.startTest();
        
        // Test valid payload
        Map<String, Object> validPayload = createTestCommentPayload(TEST_COMMENT_ID, TEST_JIRA_KEY, TEST_COMMENT_BODY);
        Map<String, Object> validResult = JiraCommentHandler.validateCommentPayloadStructure(validPayload);
        System.assert((Boolean)validResult.get('isValid'), 'Valid payload should pass validation');
        
        // Test null payload
        Map<String, Object> nullResult = JiraCommentHandler.validateCommentPayloadStructure(null);
        System.assert(!(Boolean)nullResult.get('isValid'), 'Null payload should fail validation');
        
        // Test missing comment field
        Map<String, Object> missingCommentPayload = new Map<String, Object>{
            'issue' => new Map<String, Object>{'key' => TEST_JIRA_KEY}
        };
        Map<String, Object> missingCommentResult = JiraCommentHandler.validateCommentPayloadStructure(missingCommentPayload);
        System.assert(!(Boolean)missingCommentResult.get('isValid'), 'Missing comment field should fail validation');
        
        Test.stopTest();
    }
    
    /**
     * @description Test HTML to plain text conversion
     */
    @isTest
    static void testConvertHtmlToPlainText() {
        Test.startTest();
        
        String htmlContent = '<p>This is <b>bold</b> and <i>italic</i> text.</p>';
        String plainText = JiraCommentHandler.convertHtmlToPlainText(htmlContent);
        
        System.assert(plainText.contains('This is bold and italic text'), 'Should convert HTML to plain text');
        System.assert(!plainText.contains('<'), 'Should remove HTML tags');
        
        // Test empty content
        String emptyResult = JiraCommentHandler.convertHtmlToPlainText('');
        System.assertEquals('', emptyResult, 'Should handle empty content');
        
        // Test null content
        String nullResult = JiraCommentHandler.convertHtmlToPlainText(null);
        System.assertEquals('', nullResult, 'Should handle null content');
        
        Test.stopTest();
    }
    
    /**
     * @description Test Jira timestamp conversion
     */
    @isTest
    static void testConvertJiraTimestamp() {
        Test.startTest();
        
        // Test valid ISO timestamp
        String isoTimestamp = '2023-12-01T10:30:00.000+0000';
        DateTime result = JiraCommentHandler.convertJiraTimestamp(isoTimestamp);
        System.assert(result != null, 'Should parse valid timestamp');
        
        // Test invalid timestamp (should return current time)
        DateTime invalidResult = JiraCommentHandler.convertJiraTimestamp('invalid-timestamp');
        System.assert(invalidResult != null, 'Should return current time for invalid timestamp');
        
        // Test null timestamp
        DateTime nullResult = JiraCommentHandler.convertJiraTimestamp(null);
        System.assert(nullResult != null, 'Should return current time for null timestamp');
        
        Test.stopTest();
    }
    
    /**
     * @description Test invalid payload handling
     */
    @isTest
    static void testInvalidPayloadHandling() {
        Test.startTest();
        
        // Test with invalid payload structure
        Map<String, Object> invalidPayload = new Map<String, Object>{
            'invalid' => 'data'
        };
        
        Boolean createResult = JiraCommentHandler.handleCommentCreated(invalidPayload);
        Boolean updateResult = JiraCommentHandler.handleCommentUpdated(invalidPayload);
        Boolean deleteResult = JiraCommentHandler.handleCommentDeleted(invalidPayload);
        
        System.assert(!createResult, 'Should fail with invalid payload for creation');
        System.assert(!updateResult, 'Should fail with invalid payload for update');
        System.assert(!deleteResult, 'Should fail with invalid payload for deletion');
        
        Test.stopTest();
    }
    
    // ========== HELPER METHODS ==========
    
    /**
     * @description Creates a test comment payload for webhook simulation
     */
    private static Map<String, Object> createTestCommentPayload(String commentId, String issueKey, String body) {
        return new Map<String, Object>{
            'comment' => new Map<String, Object>{
                'id' => commentId,
                'body' => body,
                'author' => new Map<String, Object>{
                    'displayName' => TEST_AUTHOR_NAME,
                    'emailAddress' => TEST_AUTHOR_EMAIL,
                    'accountId' => 'test-account-123',
                    'name' => 'jdoe'
                },
                'created' => '2023-12-01T10:30:00.000+0000',
                'updated' => '2023-12-01T10:35:00.000+0000'
            },
            'issue' => new Map<String, Object>{
                'key' => issueKey,
                'id' => '12345'
            }
        };
    }
}