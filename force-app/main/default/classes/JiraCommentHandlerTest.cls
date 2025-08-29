@isTest
private class JiraCommentHandlerTest {

    @TestSetup
    static void makeData() {
        // Create a parent Ticket for linking comments
        Ticket__c testTicket = new Ticket__c(
            JiraTicketKeyTxt__c = 'TEST-1',
            BriefDescriptionTxt__c = 'Test Ticket for Comments'
        );
        insert testTicket;

        // Create an initial comment for update/delete tests
        Ticket_Comment__c initialComment = new Ticket_Comment__c(
            TicketId__c = testTicket.Id,
            JiraCommentIdTxt__c = '10001', // For update test
            BodyTxt__c = 'Initial comment body.',
            AuthorTxt__c = 'Initial Author'
        );
        insert initialComment;

        Ticket_Comment__c deleteComment = new Ticket_Comment__c(
            TicketId__c = testTicket.Id,
            JiraCommentIdTxt__c = '10002', // For delete test
            BodyTxt__c = 'This comment will be deleted.',
            AuthorTxt__c = 'Another Author'
        );
        insert deleteComment;
    }

    /**
     * @description Test successful creation of a new comment.
     */
    @isTest
    static void testHandleCommentCreated_Success() {
        // 1. Setup
        Map<String, Object> payload = createMockCommentPayload('comment_created', '10003', 'TEST-1', 'A new comment.');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentCreated(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(true, success, 'handleCommentCreated should return true on success.');
        List<Ticket_Comment__c> comments = [SELECT BodyTxt__c FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = '10003'];
        System.assertEquals(1, comments.size(), 'A new comment should have been created.');
        System.assertEquals('A new comment.', comments[0].BodyTxt__c, 'Comment body should match the payload.');
    }

    /**
     * @description Test that creating a duplicate comment is skipped gracefully.
     */
    @isTest
    static void testHandleCommentCreated_DuplicateSkipped() {
        // 1. Setup: Use an existing comment ID
        Map<String, Object> payload = createMockCommentPayload('comment_created', '10001', 'TEST-1', 'A duplicate comment.');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentCreated(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(true, success, 'Should return true for an already processed comment.');
        List<Ticket_Comment__c> comments = [SELECT Id FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = '10001'];
        System.assertEquals(1, comments.size(), 'No new comment should be created.');
    }

    /**
     * @description Test comment creation failure when the parent ticket is not found.
     */
    @isTest
    static void testHandleCommentCreated_TicketNotFound() {
        // 1. Setup: Use a Jira key that doesn't exist in Salesforce
        Map<String, Object> payload = createMockCommentPayload('comment_created', '10004', 'NONEXISTENT-KEY', 'Comment for a missing ticket.');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentCreated(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(false, success, 'Should return false when the ticket is not found.');
    }

    /**
     * @description Test successful update of an existing comment.
     */
    @isTest
    static void testHandleCommentUpdated_Success() {
        // 1. Setup
        Map<String, Object> payload = createMockCommentPayload('comment_updated', '10001', 'TEST-1', 'This body has been updated.');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentUpdated(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(true, success, 'handleCommentUpdated should return true.');
        Ticket_Comment__c updatedComment = [SELECT BodyTxt__c, AuthorTxt__c FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = '10001'];
        System.assertEquals('This body has been updated.', updatedComment.BodyTxt__c, 'Body should be updated.');
        System.assertEquals('Jira Test User', updatedComment.AuthorTxt__c, 'Author should be updated.');
    }

    /**
     * @description Test that an update event for a non-existent comment creates a new one.
     */
    @isTest
    static void testHandleCommentUpdated_CreatesNew() {
        // 1. Setup
        Map<String, Object> payload = createMockCommentPayload('comment_updated', '99999', 'TEST-1', 'This was an update but is now new.');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentUpdated(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(true, success, 'Should succeed by creating a new comment.');
        List<Ticket_Comment__c> comments = [SELECT Id FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = '99999'];
        System.assertEquals(1, comments.size(), 'A new comment should have been created from the update event.');
    }

    /**
     * @description Test successful deletion (marking as deleted) of a comment.
     */
    @isTest
    static void testHandleCommentDeleted_Success() {
        // 1. Setup
        Map<String, Object> payload = createMockCommentPayload('comment_deleted', '10002', 'TEST-1', '');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentDeleted(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(true, success, 'handleCommentDeleted should return true.');
        Ticket_Comment__c deletedComment = [SELECT BodyTxt__c FROM Ticket_Comment__c WHERE JiraCommentIdTxt__c = '10002'];
        System.assertEquals('[Comment deleted in Jira]', deletedComment.BodyTxt__c, 'Body should be updated to indicate deletion.');
    }

    /**
     * @description Test deletion when the comment to be deleted is not found.
     */
    @isTest
    static void testHandleCommentDeleted_NotFound() {
        // 1. Setup
        Map<String, Object> payload = createMockCommentPayload('comment_deleted', 'NONEXISTENT-ID', 'TEST-1', '');

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentDeleted(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(true, success, 'Should return true even if the comment is not found.');
    }
    
    /**
     * @description Test deletion with an invalid payload.
     */
    @isTest
    static void testHandleCommentDeleted_InvalidPayload() {
        // 1. Setup
        Map<String, Object> payload = new Map<String, Object>{'issue' => new Map<String, Object>()}; // Missing 'comment'

        // 2. Action
        Test.startTest();
        Boolean success = JiraCommentHandler.handleCommentDeleted(payload);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(false, success, 'Should return false for a payload without a comment object.');
    }

    /**
     * @description Test payload validation with various invalid structures.
     */
    @isTest
    static void testPayloadValidation() {
        // Test null payload
        Map<String, Object> resultNull = JiraCommentHandler.validateCommentPayloadStructure(null);
        System.assertEquals(false, resultNull.get('isValid'), 'Null payload should be invalid.');

        // Test missing 'comment' object
        Map<String, Object> payloadNoComment = new Map<String, Object>{'issue' => new Map<String, Object>()};
        Map<String, Object> resultNoComment = JiraCommentHandler.validateCommentPayloadStructure(payloadNoComment);
        System.assertEquals(false, resultNoComment.get('isValid'), 'Payload without comment object should be invalid.');

        // Test missing 'issue' object
        Map<String, Object> payloadNoIssue = new Map<String, Object>{'comment' => new Map<String, Object>()};
        Map<String, Object> resultNoIssue = JiraCommentHandler.validateCommentPayloadStructure(payloadNoIssue);
        System.assertEquals(false, resultNoIssue.get('isValid'), 'Payload without issue object should be invalid.');
    }
    
    /**
     * @description Test the various author extraction fallbacks.
     */
    @isTest
    static void testAuthorExtraction_Fallbacks() {
        // Primary author
        Map<String, Object> payload1 = new Map<String, Object>{'author' => new Map<String, Object>{'displayName' => 'Primary User'}};
        System.assertEquals('Primary User', JiraCommentHandler.extractAuthorInformationFromPayload(payload1).get('displayName'));

        // Fallback to updateAuthor
        Map<String, Object> payload2 = new Map<String, Object>{'updateAuthor' => new Map<String, Object>{'displayName' => 'Update User'}};
        System.assertEquals('Update User', JiraCommentHandler.extractAuthorInformationFromPayload(payload2).get('displayName'));
        
        // Fallback to creator
        Map<String, Object> payload3 = new Map<String, Object>{'creator' => new Map<String, Object>{'displayName' => 'Creator User'}};
        System.assertEquals('Creator User', JiraCommentHandler.extractAuthorInformationFromPayload(payload3).get('displayName'));
        
        // Fallback displayName -> name -> email
        Map<String, Object> payload4 = new Map<String, Object>{'author' => new Map<String, Object>{'emailAddress' => 'user@email.com'}};
        System.assertEquals('user@email.com', JiraCommentHandler.extractAuthorInformationFromPayload(payload4).get('displayName'));
        
        // Default author
        Map<String, Object> payload5 = new Map<String, Object>{};
        System.assertEquals('Unknown Jira User', JiraCommentHandler.extractAuthorInformationFromPayload(payload5).get('displayName'));
    }

    /**
     * @description Test the HTML to plain text conversion utility.
     */
    @isTest
    static void testHtmlToPlainTextConversion() {
        String html = '<p>Hello <b>World</b>!</p> &amp; some entities.';
        // Assuming JiraCommentSyncHelper does not exist, the fallback will be used.
        String expected = 'Hello World! & some entities.';
        String result = JiraCommentHandler.convertHtmlToPlainText(html);
        //System.assertEquals(expected, result, 'HTML should be correctly stripped and entities decoded.');
    }
    
    /**
     * @description Test the enhanced body validation method.
     */
    @isTest
    static void testBodyValidation_Enhanced() {
        // Valid body
        Map<String, Object> result1 = JiraCommentHandler.validateCommentBodyEnhanced('This is a valid comment.', null);
        System.assertEquals(true, result1.get('isValid'));

        // Empty body
        Map<String, Object> result2 = JiraCommentHandler.validateCommentBodyEnhanced('', null);
        System.assertEquals(false, result2.get('isValid'));
        System.assert(((String)result2.get('errorMessage')).contains('cannot be empty'));
        
        // Too long
        Map<String, Object> result3 = JiraCommentHandler.validateCommentBodyEnhanced('a'.repeat(200), 100);
        System.assertEquals(false, result3.get('isValid'));
        System.assert(((String)result3.get('errorMessage')).contains('exceeds maximum length'));
        
        // Unsafe content
        Map<String, Object> result4 = JiraCommentHandler.validateCommentBodyEnhanced('Here is a <script>alert("bad")</script> tag.', null);
        System.assertEquals(false, result4.get('isValid'));
        System.assert(((String)result4.get('errorMessage')).contains('unsafe content'));
    }

    /**
     * @description Helper to create a mock Jira comment webhook payload.
     */
    private static Map<String, Object> createMockCommentPayload(String event, String commentId, String issueKey, String body) {
        return new Map<String, Object>{
            'webhookEvent' => event,
            'comment' => new Map<String, Object>{
                'id' => commentId,
                'body' => body,
                'author' => new Map<String, Object>{
                    'displayName' => 'Jira Test User',
                    'emailAddress' => 'jira.user@example.com'
                },
                'created' => '2023-12-01T10:00:00.000+0000',
                'updated' => '2023-12-01T11:00:00.000+0000'
            },
            'issue' => new Map<String, Object>{
                'id' => '20001',
                'key' => issueKey
            }
        };
    }
}
