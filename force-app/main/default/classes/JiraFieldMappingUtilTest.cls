@isTest
private class JiraFieldMappingUtilTest {

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
    }

    /**
     * @description Test the main mapping method with a full, valid Jira payload.
     */
    @isTest
    static void testMapJiraIssueToTicketFullPayload() {
        // 1. Setup
        User dev = [SELECT Id, Email FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        Ticket__c ticket = new Ticket__c();
        Map<String, Object> issue = createMockJiraIssue('TEST-1', 'A full summary', dev.Email, 'Done', 'High');

        // 2. Action
        Test.startTest();
        JiraFieldMappingUtil.mapJiraIssueToTicket(issue, ticket);
        Test.stopTest();

        // 3. Assert
        //System.assertEquals('TEST-1', ticket.JiraTicketKeyTxt__c, 'Jira key should be mapped.');
        System.assertEquals('A full summary', ticket.BriefDescriptionTxt__c, 'Summary should be mapped.');
        System.assertEquals(dev.Id, ticket.Developer__c, 'Assignee should be mapped to the correct user.');
        System.assertEquals('Done', ticket.StatusPk__c, 'Status should be mapped to Done.');
        System.assertEquals('High', ticket.PriorityPk__c, 'Priority should be mapped to High.');
        System.assertNotEquals(null, ticket.LastJiraUpdateDateTime__c, 'Last update date should be set.');
    }

    /**
     * @description Test mapping with a minimal payload to ensure null safety.
     */
    @isTest
    static void testMapJiraIssueToTicket_MinimalPayload() {
        // 1. Setup
        Ticket__c ticket = new Ticket__c();
        Map<String, Object> issue = new Map<String, Object>{
            'key' => 'MIN-1',
            'fields' => new Map<String, Object>{
                'summary' => 'Minimal summary'
            }
        };

        // 2. Action
        Test.startTest();
        JiraFieldMappingUtil.mapJiraIssueToTicket(issue, ticket);
        Test.stopTest();

        // 3. Assert
        //System.assertEquals('MIN-1', ticket.JiraTicketKeyTxt__c, 'Jira key should be mapped.');
        System.assertEquals('Minimal summary', ticket.BriefDescriptionTxt__c, 'Summary should be mapped.');
        System.assertEquals(null, ticket.Developer__c, 'Assignee should be null.');
        System.assertEquals(null, ticket.StatusPk__c, 'Status should be null.');
    }

    /**
     * @description Test the assignee mapping fallback from email to display name.
     */
    @isTest
    static void testAssigneeMapping_ByNameFallback() {
        // 1. Setup
        User userByName = [SELECT Id, Name FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        Ticket__c ticket = new Ticket__c();
        Map<String, Object> fields = new Map<String, Object>{
            'assignee' => new Map<String, Object>{
                'emailAddress' => 'wrong.email@example.com', // Email does not exist
                'displayName' => userByName.Name // Name exists
            }
        };

        // 2. Action
        Test.startTest();
        JiraFieldMappingUtil.mapAssigneeField(fields, ticket);
        Test.stopTest();

        // 3. Assert
        System.assertEquals(userByName.Id, ticket.Developer__c, 'Should find user by display name as a fallback.');
    }

    /**
     * @description Test the conversion of Jira's ADF description format to HTML.
     */
    @isTest
    static void testDescriptionConversion_AdfToHtml() {
        // 1. Setup
        Ticket__c ticket = new Ticket__c();
        Map<String, Object> fields = new Map<String, Object>{
            'description' => createMockAdfDescription()
        };
        
        // 2. Action
        Test.startTest();
        JiraFieldMappingUtil.mapJiraIssueToTicket(new Map<String, Object>{'fields' => fields}, ticket);
        Test.stopTest();

        // 3. Assert
        String expectedHtml = '<h1>Heading 1</h1><p>This is a <strong>bold</strong> and <em>italic</em> paragraph.</p>';
        System.assertEquals(expectedHtml, ticket.DetailsTxt__c, 'ADF description should be converted to correct HTML.');
    }

    /**
     * @description Test date and datetime conversion utilities.
     */
    @isTest
    static void testDateConversion() {
        // Valid timestamp
        Datetime dt = JiraFieldMappingUtil.convertJiraTimestampToDatetime('2023-12-01T10:30:00.000+0000');
        System.assertEquals(2023, dt.year(), 'Year should be parsed correctly.');
        
        // Invalid timestamp
        Datetime dtInvalid = JiraFieldMappingUtil.convertJiraTimestampToDatetime('invalid-date');
        System.assertEquals(null, dtInvalid, 'Invalid timestamp should return null.');

        // Valid date
        Date d = JiraFieldMappingUtil.convertJiraDateToDate('2024-01-15');
        System.assertEquals(15, d.day(), 'Day should be parsed correctly.');

        // Invalid date
        Date dInvalid = JiraFieldMappingUtil.convertJiraDateToDate('not-a-date');
        System.assertEquals(null, dInvalid, 'Invalid date should return null.');
    }

    /**
     * @description Helper to create a mock Jira issue payload.
     */
    private static Map<String, Object> createMockJiraIssue(String key, String summary, String assigneeEmail, String status, String priority) {
        return new Map<String, Object>{
            'id' => '10001',
            'key' => key,
            'fields' => new Map<String, Object>{
                'summary' => summary,
                'issuetype' => new Map<String, Object>{'name' => 'Story'},
                'assignee' => new Map<String, Object>{'emailAddress' => assigneeEmail, 'displayName' => 'Test User'},
                'status' => new Map<String, Object>{'name' => status, 'statusCategory' => new Map<String, Object>{'key' => 'done'}},
                'priority' => new Map<String, Object>{'name' => priority, 'id' => '2'},
                'created' => '2023-12-01T10:00:00.000+0000',
                'updated' => '2023-12-01T11:00:00.000+0000',
                'customfield_10016' => 5.0 // Story Points
            }
        };
    }

    /**
     * @description Helper to create a mock Atlassian Document Format (ADF) payload.
     */
    private static Map<String, Object> createMockAdfDescription() {
        return new Map<String, Object>{
            'type' => 'doc',
            'version' => 1,
            'content' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'heading',
                    'attrs' => new Map<String, Object>{'level' => 1},
                    'content' => new List<Object>{ new Map<String, Object>{'type' => 'text', 'text' => 'Heading 1'} }
                },
                new Map<String, Object>{
                    'type' => 'paragraph',
                    'content' => new List<Object>{
                        new Map<String, Object>{'type' => 'text', 'text' => 'This is a '},
                        new Map<String, Object>{'type' => 'text', 'text' => 'bold', 'marks' => new List<Object>{new Map<String, Object>{'type' => 'strong'}}},
                        new Map<String, Object>{'type' => 'text', 'text' => ' and '},
                        new Map<String, Object>{'type' => 'text', 'text' => 'italic', 'marks' => new List<Object>{new Map<String, Object>{'type' => 'em'}}},
                        new Map<String, Object>{'type' => 'text', 'text' => ' paragraph.'}
                    }
                }
            }
        };
    }
}
