/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryActivityTimelineController.
 * Verifies that the unified timeline correctly queries and merges
 * comments, work logs, and activity logs for a Work Item.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.CyclomaticComplexity')
private class DeliveryActivityTimelineControllerTest {

    /**
     * @description Creates a Work Item with associated comments, work logs,
     *              and activity log records for timeline testing.
     */
    @TestSetup
    static void setup() {
        // Enable activity logging so ActivityLog__c records can be created
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingBool__c = true;
        upsert settings;

        // Network Entity (needed for WorkRequest master-detail chain)
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Timeline Test Vendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        // Work Item
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Timeline Test Work Item',
            StageNamePk__c = 'In Development'
        );
        insert wi;

        // Work Request (master for WorkLog)
        WorkRequest__c wr = new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityId__c = vendor.Id,
            QuotedHoursNumber__c = 20,
            HourlyRateCurrency__c = 150,
            StatusPk__c = 'Accepted'
        );
        insert wr;

        // Comment 1
        WorkItemComment__c comment1 = new WorkItemComment__c(
            WorkItemId__c = wi.Id,
            AuthorTxt__c = 'Jane Developer',
            BodyTxt__c = 'Started working on the implementation.',
            SourcePk__c = 'Salesforce'
        );
        insert comment1;

        // Comment 2
        WorkItemComment__c comment2 = new WorkItemComment__c(
            WorkItemId__c = wi.Id,
            AuthorTxt__c = 'Client User',
            BodyTxt__c = 'Looks good so far, please continue.',
            SourcePk__c = 'Client'
        );
        insert comment2;

        // Work Log
        WorkLog__c wlog = new WorkLog__c(
            RequestId__c = wr.Id,
            WorkItemId__c = wi.Id,
            HoursLoggedNumber__c = 3.5,
            WorkDescriptionTxt__c = 'Completed API integration',
            WorkDateDate__c = Date.today()
        );
        insert wlog;

        // Activity Log — stage change for this work item
        String contextJson = JSON.serialize(new Map<String, Object>{
            'recordId' => wi.Id,
            'oldStage' => 'Backlog',
            'newStage' => 'In Development',
            'objectName' => 'WorkItem__c'
        });
        ActivityLog__c alog = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = contextJson,
            UserIdTxt__c = UserInfo.getUserId(),
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert alog;
    }

    // ── All events ──────────────────────────────────────────────────────

    @IsTest
    static void testGetAllTimelineEvents() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'all', 0);
        Test.stopTest();

        // Should have at least 4 events: 2 comments + 1 work log + 1 stage change
        System.assert(events.size() >= 4,
            'Expected at least 4 timeline events, got ' + events.size());

        // Verify each event has required keys
        for (Map<String, Object> ev : events) {
            System.assertNotEquals(null, ev.get('id'), 'Each event should have an id');
            System.assertNotEquals(null, ev.get('type'), 'Each event should have a type');
            System.assertNotEquals(null, ev.get('timestamp'), 'Each event should have a timestamp');
            System.assertNotEquals(null, ev.get('title'), 'Each event should have a title');
            System.assertNotEquals(null, ev.get('icon'), 'Each event should have an icon');
        }
    }

    // ── Filter: comments only ───────────────────────────────────────────

    @IsTest
    static void testFilterComments() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'comments', 0);
        Test.stopTest();

        System.assertEquals(2, events.size(),
            'Expected exactly 2 comment events');
        for (Map<String, Object> ev : events) {
            System.assertEquals('comment', (String) ev.get('type'),
                'All events should be of type comment');
        }
    }

    // ── Filter: time logs only ──────────────────────────────────────────

    @IsTest
    static void testFilterTimeLogs() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'time_logs', 0);
        Test.stopTest();

        System.assertEquals(1, events.size(),
            'Expected exactly 1 work log event');
        System.assertEquals('worklog', (String) events[0].get('type'),
            'Event type should be worklog');
        System.assert(((String) events[0].get('title')).contains('3.5'),
            'Title should include hours logged');
    }

    // ── Filter: stage changes only ──────────────────────────────────────

    @IsTest
    static void testFilterStageChanges() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        System.assertEquals(1, events.size(),
            'Expected exactly 1 stage change event');
        Map<String, Object> ev = events[0];
        System.assertEquals('stage_change', (String) ev.get('type'),
            'Event type should be stage_change');
        System.assert(((String) ev.get('title')).contains('In Development'),
            'Title should reference the new stage');
        System.assert(((String) ev.get('detail')).contains('Backlog'),
            'Detail should reference the old stage');
    }

    // ── Empty results ───────────────────────────────────────────────────

    @IsTest
    static void testEmptyResultsForNewWorkItem() {
        WorkItem__c emptyWi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Empty Work Item',
            StageNamePk__c = 'Backlog'
        );
        insert emptyWi;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(emptyWi.Id, 'all', 0);
        Test.stopTest();

        System.assertEquals(0, events.size(),
            'Expected 0 events for a work item with no activity');
    }

    // ── Null work item Id ───────────────────────────────────────────────

    @IsTest
    static void testNullWorkItemId() {
        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(null, 'all', 0);
        Test.stopTest();

        System.assertEquals(0, events.size(),
            'Expected 0 events when work item Id is null');
    }

    // ── Pagination ──────────────────────────────────────────────────────

    @IsTest
    static void testPaginationBeyondResults() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        // Request page 100 — well beyond any results
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'all', 100);
        Test.stopTest();

        System.assertEquals(0, events.size(),
            'Expected 0 events when page offset exceeds total');
    }

    // ── Default filter and page values ──────────────────────────────────

    @IsTest
    static void testDefaultParameters() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        // Pass nulls for filterType and pageOffset — should default gracefully
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, null, null);
        Test.stopTest();

        System.assert(events.size() >= 4,
            'Expected at least 4 events with default (all) filter');
    }

    // ── Chronological ordering ──────────────────────────────────────────

    @IsTest
    static void testEventsAreSortedDescending() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'all', 0);
        Test.stopTest();

        // Verify newest-first ordering
        Datetime previous = Datetime.now().addYears(1);
        for (Map<String, Object> ev : events) {
            Datetime ts = (Datetime) ev.get('timestamp');
            System.assert(ts <= previous,
                'Events should be sorted newest first');
            previous = ts;
        }
    }

    // ── Negative page offset sanitized to zero ──────────────────────────

    @IsTest
    static void testNegativePageOffset() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'all', -5);
        Test.stopTest();

        System.assert(events.size() >= 4,
            'Negative page offset should be treated as page 0');
    }

    // ── Comment without AuthorTxt__c falls back to CreatedBy.Name ───────

    @IsTest
    static void testCommentWithoutAuthor() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        // Create a comment without AuthorTxt__c
        WorkItemComment__c noAuthor = new WorkItemComment__c(
            WorkItemId__c = wi.Id,
            BodyTxt__c = 'Comment with no author set.'
        );
        insert noAuthor;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'comments', 0);
        Test.stopTest();

        // Should have 3 comments now (2 from setup + 1 new)
        System.assertEquals(3, events.size(),
            'Expected 3 comment events');

        // Find the one without an explicit author — it should use CreatedBy.Name
        Boolean foundFallback = false;
        String runningUserName = UserInfo.getName();
        for (Map<String, Object> ev : events) {
            String title = (String) ev.get('title');
            if (title.contains(runningUserName) && title.contains('Salesforce')) {
                foundFallback = true;
            }
        }
        System.assert(foundFallback,
            'Comment without AuthorTxt__c should fall back to CreatedBy.Name and default source Salesforce');
    }

    // ── Comment with long HTML body is stripped and truncated ────────────

    @IsTest
    static void testCommentWithLongHtmlBody() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        // Build a body > 300 chars with HTML tags
        String longBody = '<p>' + 'A'.repeat(350) + '</p>';
        WorkItemComment__c longComment = new WorkItemComment__c(
            WorkItemId__c = wi.Id,
            AuthorTxt__c = 'Long Body Author',
            BodyTxt__c = longBody,
            SourcePk__c = 'Salesforce'
        );
        insert longComment;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'comments', 0);
        Test.stopTest();

        // Find the long body comment and verify truncation
        Boolean foundTruncated = false;
        for (Map<String, Object> ev : events) {
            String detail = (String) ev.get('detail');
            if (detail != null && detail.endsWith('...')) {
                System.assert(detail.length() <= 304,
                    'Truncated body should be at most 303 chars + ...');
                foundTruncated = true;
            }
        }
        System.assert(foundTruncated,
            'Should find a truncated comment body');
    }

    // ── Comment with blank body ─────────────────────────────────────────

    @IsTest
    static void testCommentWithBlankBody() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        WorkItemComment__c blankComment = new WorkItemComment__c(
            WorkItemId__c = wi.Id,
            AuthorTxt__c = 'Blank Body Author',
            SourcePk__c = 'GitHub'
        );
        insert blankComment;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'comments', 0);
        Test.stopTest();

        System.assertEquals(3, events.size(),
            'Expected 3 comments (2 from setup + 1 blank body)');
    }

    // ── Work log with null hours and no description or date ──────────────

    @IsTest
    static void testWorkLogMinimalFields() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        WorkRequest__c wr = [SELECT Id FROM WorkRequest__c LIMIT 1];

        WorkLog__c minLog = new WorkLog__c(
            RequestId__c = wr.Id,
            WorkItemId__c = wi.Id
        );
        insert minLog;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'time_logs', 0);
        Test.stopTest();

        System.assertEquals(2, events.size(),
            'Expected 2 work log events (1 from setup + 1 minimal)');

        // Find the minimal log — hours should default to 0
        Boolean foundMinimal = false;
        for (Map<String, Object> ev : events) {
            String title = (String) ev.get('title');
            if (title.contains('0h logged')) {
                foundMinimal = true;
                String detail = (String) ev.get('detail');
                System.assertEquals('', detail,
                    'Detail should be empty when no description or date');
            }
        }
        System.assert(foundMinimal,
            'Should find work log with 0h logged');
    }

    // ── Work log with date but no description ───────────────────────────

    @IsTest
    static void testWorkLogDateOnly() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        WorkRequest__c wr = [SELECT Id FROM WorkRequest__c LIMIT 1];

        WorkLog__c dateOnlyLog = new WorkLog__c(
            RequestId__c = wr.Id,
            WorkItemId__c = wi.Id,
            HoursLoggedNumber__c = 1.0,
            WorkDateDate__c = Date.today()
        );
        insert dateOnlyLog;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'time_logs', 0);
        Test.stopTest();

        // Find the date-only log
        Boolean foundDateOnly = false;
        for (Map<String, Object> ev : events) {
            String detail = (String) ev.get('detail');
            if (detail != null && detail.startsWith('Work date:') && !detail.contains('Completed')) {
                foundDateOnly = true;
            }
        }
        System.assert(foundDateOnly,
            'Should find work log with only date in detail (no description prefix)');
    }

    // ── Stage change with blank ContextDataTxt__c ───────────────────────

    @IsTest
    static void testStageChangeBlankContext() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        // Create an activity log with blank context — contains workItemId in blank = no match
        // So we create one that matches but has empty stage info
        ActivityLog__c blankCtx = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = '{"recordId":"' + wi.Id + '"}',
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert blankCtx;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        // Should have at least 2 stage change events (1 from setup + 1 new)
        System.assert(events.size() >= 2,
            'Expected at least 2 stage change events');

        // The blank-context one should have default title 'Stage changed'
        Boolean foundDefault = false;
        for (Map<String, Object> ev : events) {
            String title = (String) ev.get('title');
            if (title == 'Stage changed') {
                foundDefault = true;
            }
        }
        System.assert(foundDefault,
            'Stage change with no stage data should have default title');
    }

    // ── Stage change with invalid JSON context ──────────────────────────

    @IsTest
    static void testStageChangeInvalidJson() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        // Create activity log with invalid JSON that still contains the work item Id
        ActivityLog__c badJson = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = 'NOT VALID JSON ' + wi.Id,
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert badJson;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        // Should still return events without exception
        System.assert(events.size() >= 2,
            'Expected at least 2 stage change events even with invalid JSON');

        // The bad JSON one should fall back to default title
        Boolean foundDefault = false;
        for (Map<String, Object> ev : events) {
            String title = (String) ev.get('title');
            if (title == 'Stage changed') {
                foundDefault = true;
            }
        }
        System.assert(foundDefault,
            'Invalid JSON context should produce default stage change title');
    }

    // ── Stage change with no UserIdTxt__c (user resolves to System) ─────

    @IsTest
    static void testStageChangeNoUserId() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        String contextJson = JSON.serialize(new Map<String, Object>{
            'recordId' => wi.Id,
            'oldStage' => 'In Development',
            'newStage' => 'Code Review'
        });
        ActivityLog__c noUser = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = contextJson,
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert noUser;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        // Find the event with no user — userName should be 'System'
        Boolean foundSystem = false;
        for (Map<String, Object> ev : events) {
            String title = (String) ev.get('title');
            if (title != null && title.contains('Code Review')) {
                String userName = (String) ev.get('userName');
                System.assertEquals('System', userName,
                    'Missing UserIdTxt__c should resolve to System');
                foundSystem = true;
            }
        }
        System.assert(foundSystem,
            'Should find the stage change event with System user');
    }

    // ── Stage change with invalid UserIdTxt__c (catch block) ────────────

    @IsTest
    static void testStageChangeInvalidUserId() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        String contextJson = JSON.serialize(new Map<String, Object>{
            'recordId' => wi.Id,
            'oldStage' => 'Backlog',
            'newStage' => 'In Development'
        });
        ActivityLog__c invalidUser = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = contextJson,
            UserIdTxt__c = 'NOT_A_VALID_ID',
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert invalidUser;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        // Should handle gracefully without exception
        System.assert(events.size() >= 2,
            'Should return events even with invalid user Id');
    }

    // ── Stage change with only newStage (no oldStage) ───────────────────

    @IsTest
    static void testStageChangeNewStageOnly() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        String contextJson = JSON.serialize(new Map<String, Object>{
            'recordId' => wi.Id,
            'newStage' => 'Deployed'
        });
        ActivityLog__c newOnly = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = contextJson,
            UserIdTxt__c = UserInfo.getUserId(),
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert newOnly;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        // Find the event with only newStage
        Boolean found = false;
        for (Map<String, Object> ev : events) {
            String title = (String) ev.get('title');
            if (title != null && title.contains('Deployed')) {
                found = true;
                // detail should be empty because oldStage is missing
                String detail = (String) ev.get('detail');
                System.assertEquals('', detail,
                    'Detail should be empty when oldStage is missing');
            }
        }
        System.assert(found,
            'Should find stage change event with only newStage');
    }

    // ── Unrecognized filter type returns empty ──────────────────────────

    @IsTest
    static void testUnrecognizedFilterType() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'unknown_type', 0);
        Test.stopTest();

        System.assertEquals(0, events.size(),
            'Unrecognized filter type should yield 0 events');
    }

    // ── Empty string filter defaults to all ─────────────────────────────

    @IsTest
    static void testEmptyStringFilter() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, '', 0);
        Test.stopTest();

        System.assert(events.size() >= 4,
            'Empty string filter should be treated as all');
    }

    // ── Activity log with ContextDataTxt__c not containing workItemId ───

    @IsTest
    static void testStageChangeForDifferentWorkItem() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        // Create a stage change for a DIFFERENT work item
        WorkItem__c otherWi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Other Work Item',
            StageNamePk__c = 'Backlog'
        );
        insert otherWi;

        String contextJson = JSON.serialize(new Map<String, Object>{
            'recordId' => otherWi.Id,
            'oldStage' => 'Backlog',
            'newStage' => 'In Development'
        });
        ActivityLog__c otherLog = new ActivityLog__c(
            ActionTypePk__c = 'Stage_Change',
            ContextDataTxt__c = contextJson,
            UserIdTxt__c = UserInfo.getUserId(),
            ComponentNameTxt__c = 'deliveryHubBoard'
        );
        insert otherLog;

        Test.startTest();
        List<Map<String, Object>> events =
            DeliveryActivityTimelineController.getTimelineEvents(wi.Id, 'stage_changes', 0);
        Test.stopTest();

        // The other work item's stage change should NOT appear
        for (Map<String, Object> ev : events) {
            String detail = (String) ev.get('detail');
            // Should not contain events for the other work item only
            // (the setup event IS for wi, so we just verify count)
        }
        System.assertEquals(1, events.size(),
            'Should only return stage changes for the requested work item');
    }
}

