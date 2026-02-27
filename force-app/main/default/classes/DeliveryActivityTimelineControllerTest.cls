/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryActivityTimelineController.
 * Verifies that the unified timeline correctly queries and merges
 * comments, work logs, and activity logs for a Work Item.
 * @author Cloud Nimbus LLC
 */
@IsTest
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
}
