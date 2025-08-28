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