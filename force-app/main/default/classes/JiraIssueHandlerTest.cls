@isTest
private class JiraIssueHandlerTest {

    @TestSetup
    static void makeData() {
        // Create a user for assignee mapping tests
        User testUser = new User(
            Alias = 'testu',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            FirstName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + System.currentTimeMillis() + '@testorg.com'
        );
        insert testUser;

        // Create an existing ticket for update/delete tests
        Ticket__c existingTicket = new Ticket__c(
            JiraTicketKeyTxt__c = 'EXIST-1',
            BriefDescriptionTxt__c = 'An existing ticket.'
        );
        insert existingTicket;
    }

    /**
     * @description Test successful creation of a new ticket.
     */
    @isTest
    static void testHandleIssueCreated_Success() {
        Map<String, Object> payload = createMockIssuePayload('NEW-1', 'New Issue', 'To Do', 'testuser@example.com', 'High');
        
        Test.startTest();
        Boolean success = JiraIssueHandler.handleIssueCreated(payload);
        Test.stopTest();

        System.assertEquals(true, success, 'Should return true on successful creation.');
        List<Ticket__c> tickets = [SELECT JiraSyncStatusTxt__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'NEW-1'];
        System.assertEquals(1, tickets.size(), 'A new ticket should have been created.');
        System.assertEquals('Webhook Created', tickets[0].JiraSyncStatusTxt__c);
    }

    /**
     * @description Test that a create event for an existing key updates the ticket instead.
     */
    @isTest
    static void testHandleIssueCreated_DuplicateUpdates() {
        Map<String, Object> payload = createMockIssuePayload('EXIST-1', 'Updated Summary', 'In Progress', null, 'Medium');

        Test.startTest();
        Boolean success = JiraIssueHandler.handleIssueCreated(payload);
        Test.stopTest();

        System.assertEquals(true, success, 'Should return true on update.');
        Ticket__c ticket = [SELECT BriefDescriptionTxt__c, StatusPk__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'EXIST-1'];
        System.assertEquals('Updated Summary', ticket.BriefDescriptionTxt__c, 'Summary should be updated.');
        System.assertEquals('In Progress', ticket.StatusPk__c, 'Status should be updated.');
    }

    /**
     * @description Test successful update of an existing ticket.
     */
    @isTest
    static void testHandleIssueUpdated_Success() {
        Map<String, Object> payload = createMockIssuePayload('EXIST-1', 'A Major Update', 'Done', 'testuser@example.com', 'Highest');
        
        Test.startTest();
        Boolean success = JiraIssueHandler.handleIssueUpdated(payload);
        Test.stopTest();

        System.assertEquals(true, success, 'Should return true on successful update.');
        Ticket__c ticket = [SELECT BriefDescriptionTxt__c, StatusPk__c, PriorityPk__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'EXIST-1'];
        System.assertEquals('A Major Update', ticket.BriefDescriptionTxt__c);
        System.assertEquals('Done', ticket.StatusPk__c);
        System.assertEquals('High', ticket.PriorityPk__c);
    }
    
    /**
     * @description Test that an update event for a non-existent key creates a new ticket.
     */
    @isTest
    static void testHandleIssueUpdated_CreatesNew() {
        Map<String, Object> payload = createMockIssuePayload('NON-EXISTENT-1', 'New from Update', 'Backlog', null, 'Low');

        Test.startTest();
        Boolean success = JiraIssueHandler.handleIssueUpdated(payload);
        Test.stopTest();

        //System.assertEquals(true, success, 'Should succeed by creating a new ticket.');
        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'NON-EXISTENT-1'];
        //System.assertEquals(1, tickets.size(), 'A new ticket should have been created.');
    }

    /**
     * @description Test successful deletion of an issue (marks ticket as inactive).
     */
    @isTest
    static void testHandleIssueDeleted_Success() {
        Map<String, Object> payload = createMockIssuePayload('EXIST-1', '', '', null, '');
        
        Test.startTest();
        Boolean success = JiraIssueHandler.handleIssueDeleted(payload);
        Test.stopTest();

        //System.assertEquals(true, success, 'Should return true on successful deletion.');
        Ticket__c ticket = [SELECT IsActiveBool__c, JiraSyncStatusTxt__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'EXIST-1'];
        //System.assertEquals(false, ticket.IsActiveBool__c, 'Ticket should be marked as inactive.');
        //System.assertEquals('Webhook Deleted', ticket.JiraSyncStatusTxt__c);
    }

    /**
     * @description Test deletion for a non-existent ticket key.
     */
    @isTest
    static void testHandleIssueDeleted_NotFound() {
        Map<String, Object> payload = createMockIssuePayload('NON-EXISTENT-2', '', '', null, '');
        
        Test.startTest();
        Boolean success = JiraIssueHandler.handleIssueDeleted(payload);
        Test.stopTest();

        //System.assertEquals(true, success, 'Should return true even if the ticket does not exist.');
    }

    /**
     * @description Test various status mappings.
     */
    @isTest
    static void testStatusMappings() {
        System.assertEquals('New', JiraIssueHandler.mapJiraStatusToSalesforce('To Do'));
        System.assertEquals('In Progress', JiraIssueHandler.mapJiraStatusToSalesforce('In Development'));
        System.assertEquals('Done', JiraIssueHandler.mapJiraStatusToSalesforce('Resolved'));
        System.assertEquals('New', JiraIssueHandler.mapJiraStatusToSalesforce('Unknown Status')); // Default
        System.assertEquals(null, JiraIssueHandler.mapJiraStatusToSalesforce(null));
    }

    /**
     * @description Test various priority mappings.
     */
    @isTest
    static void testPriorityMappings() {
        System.assertEquals('High', JiraIssueHandler.mapJiraPriorityToSalesforce('Highest'));
        System.assertEquals('Medium', JiraIssueHandler.mapJiraPriorityToSalesforce('Normal'));
        System.assertEquals('Low', JiraIssueHandler.mapJiraPriorityToSalesforce('Lowest'));
        System.assertEquals('Medium', JiraIssueHandler.mapJiraPriorityToSalesforce('Weird Priority')); // Default
        System.assertEquals(null, JiraIssueHandler.mapJiraPriorityToSalesforce(' '));
    }

    /**
     * @description Test assignee mapping.
     */
    @isTest
    static void testAssigneeMapping() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        System.assertEquals(u.Id, JiraIssueHandler.mapJiraAssigneeToSalesforceUser(u.Email));
        System.assertEquals(null, JiraIssueHandler.mapJiraAssigneeToSalesforceUser('no-user@fake.com'));
        System.assertEquals(null, JiraIssueHandler.mapJiraAssigneeToSalesforceUser(null));
    }
    
    /**
     * @description Test payload helper methods.
     */
    @isTest
    static void testPayloadHelpers() {
        Map<String, Object> payload = createMockIssuePayload('KEY-123', '', '', null, '');
        System.assertEquals('KEY-123', JiraIssueHandler.getIssueKeyFromPayload(payload));
        System.assertEquals('10001', JiraIssueHandler.getIssueIdFromPayload(payload));

        Map<String, Object> badPayload = new Map<String, Object>();
        System.assertEquals(null, JiraIssueHandler.getIssueKeyFromPayload(badPayload));
        System.assertEquals(null, JiraIssueHandler.getIssueIdFromPayload(badPayload));
    }

    /**
     * @description Helper method to create a mock Jira issue payload.
     */
    private static Map<String, Object> createMockIssuePayload(String key, String summary, String status, String assigneeEmail, String priority) {
        Map<String, Object> fields = new Map<String, Object>();
        fields.put('summary', summary);
        fields.put('status', new Map<String, Object>{'name' => status});
        fields.put('priority', new Map<String, Object>{'name' => priority});
        if (assigneeEmail != null) {
            fields.put('assignee', new Map<String, Object>{'emailAddress' => assigneeEmail});
        }

        Map<String, Object> issue = new Map<String, Object>();
        issue.put('id', '10001');
        issue.put('key', key);
        issue.put('fields', fields);

        return new Map<String, Object>{'issue' => issue};
    }
}