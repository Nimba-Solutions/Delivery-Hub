/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryActivityFeedController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityFeedControllerTest {

    @TestSetup
    static void setup() {
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Feed Test Client', EntityTypePk__c = 'Client', StatusPk__c = 'Active'
        );
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Feed Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ client, vendor };

        WorkItem__c workItem1 = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Feed Test Item 1',
            StageNamePk__c           = 'In Development',
            ClientNetworkEntityId__c = client.Id
        );
        WorkItem__c workItem2 = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Feed Test Item 2',
            StageNamePk__c           = 'In Development',
            ClientNetworkEntityId__c = client.Id
        );
        WorkItem__c unlinkedItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Unlinked Feed Item',
            StageNamePk__c         = 'In Development'
        );
        insert new List<WorkItem__c>{ workItem1, workItem2, unlinkedItem };

        // Work Requests (needed for WorkLog master-detail)
        insert new List<WorkRequest__c>{
            new WorkRequest__c(
                WorkItemId__c         = workItem1.Id,
                DeliveryEntityId__c   = vendor.Id,
                QuotedHoursNumber__c  = 20,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            ),
            new WorkRequest__c(
                WorkItemId__c         = workItem2.Id,
                DeliveryEntityId__c   = vendor.Id,
                QuotedHoursNumber__c  = 10,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            )
        };

        // Comments
        insert new List<WorkItemComment__c>{
            new WorkItemComment__c(
                WorkItemId__c = workItem1.Id,
                BodyTxt__c    = 'First comment on item 1',
                SourcePk__c   = 'Client',
                AuthorTxt__c  = 'Test User'
            ),
            new WorkItemComment__c(
                WorkItemId__c = workItem2.Id,
                BodyTxt__c    = 'Comment on item 2',
                SourcePk__c   = 'Mothership',
                AuthorTxt__c  = 'Vendor User'
            )
        };

        // Work Logs
        WorkRequest__c req1 = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem1.Id LIMIT 1];
        WorkRequest__c req2 = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem2.Id LIMIT 1];

        insert new List<WorkLog__c>{
            new WorkLog__c(
                RequestId__c          = req1.Id,
                WorkItemId__c           = workItem1.Id,
                HoursLoggedNumber__c  = 3.5,
                WorkDateDate__c       = Date.today(),
                WorkDescriptionTxt__c = 'Development work',
                StatusPk__c           = 'Approved'
            ),
            new WorkLog__c(
                RequestId__c          = req2.Id,
                WorkItemId__c           = workItem2.Id,
                HoursLoggedNumber__c  = 1.0,
                WorkDateDate__c       = Date.today(),
                WorkDescriptionTxt__c = 'Draft hours',
                StatusPk__c           = 'Draft'
            )
        };

        // Activity Log (stage change)
        insert new ActivityLog__c(
            ActionTypePk__c    = 'Stage_Change',
            RecordIdTxt__c     = workItem1.Id,
            UserIdTxt__c       = UserInfo.getUserId(),
            ContextDataTxt__c  = '{"oldStage":"Backlog","newStage":"In Development","workItemId":"' + workItem1.Id + '"}'
        );
    }

    // ── getActivityFeed tests ──────────────────────────────────────────

    @IsTest
    static void testGetActivityFeedAll() {
        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'all', 0, null, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assert(events.size() > 0, 'Should return events across all types');
        System.assertNotEquals(null, result.get('totalCount'));
    }

    @IsTest
    static void testGetActivityFeedCommentsOnly() {
        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'comments', 0, null, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assertEquals(2, events.size(), 'Should return 2 comments');
        for (Object ev : events) {
            Map<String, Object> event = (Map<String, Object>) ev;
            System.assertEquals('comment', event.get('type'));
        }
    }

    @IsTest
    static void testGetActivityFeedHoursOnly() {
        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'hours', 0, null, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assertEquals(2, events.size(), 'Should return 2 work logs');
    }

    @IsTest
    static void testGetActivityFeedChangesOnly() {
        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'changes', 0, null, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assert(events.size() >= 1, 'Should return at least 1 stage change');
    }

    @IsTest
    static void testGetActivityFeedByNetworkEntity() {
        NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Feed Test Client' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'all', 0, client.Id, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assert(events.size() > 0, 'Should return events for client-linked items');
    }

    @IsTest
    static void testGetActivityFeedByWorkItem() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Feed Test Item 1' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'all', 0, null, wi.Id, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assert(events.size() > 0, 'Should return events for specific work item');
        // All events should reference this work item
        for (Object ev : events) {
            Map<String, Object> event = (Map<String, Object>) ev;
            System.assertEquals(wi.Id, event.get('workItemId'),
                'All events should be for the filtered work item');
        }
    }

    @IsTest
    static void testGetActivityFeedPagination() {
        Test.startTest();
        // Request page 100 (way beyond data) — should get empty
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'all', 100, null, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        System.assertEquals(0, events.size(), 'Out-of-range page should return empty');
    }

    // ── getConversations tests ─────────────────────────────────────────

    @IsTest
    static void testGetConversations() {
        Test.startTest();
        List<Map<String, Object>> threads = DeliveryActivityFeedController.getConversations(0, null);
        Test.stopTest();

        System.assertEquals(2, threads.size(), 'Should return 2 conversation threads');
        for (Map<String, Object> thread : threads) {
            System.assertNotEquals(null, thread.get('workItemId'));
            System.assertNotEquals(null, thread.get('workItemName'));
            System.assert((Integer) thread.get('commentCount') > 0);
        }
    }

    @IsTest
    static void testGetConversationsByEntity() {
        NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Feed Test Client' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> threads = DeliveryActivityFeedController.getConversations(0, client.Id);
        Test.stopTest();

        System.assertEquals(2, threads.size(), 'Should return 2 threads for client entity');
    }

    // ── getPendingApprovals tests ──────────────────────────────────────

    @IsTest
    static void testGetPendingApprovals() {
        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getPendingApprovals(0, null);
        Test.stopTest();

        List<Object> approvals = (List<Object>) result.get('approvals');
        System.assertEquals(1, approvals.size(), 'Should return 1 draft work log');
        Map<String, Object> approval = (Map<String, Object>) approvals[0];
        System.assertEquals('Draft', approval.get('status'));
    }

    // ── Approval lifecycle tests ───────────────────────────────────────

    @IsTest
    static void testApproveWorkLogs() {
        WorkLog__c draftLog = [SELECT Id FROM WorkLog__c WHERE StatusPk__c = 'Draft' LIMIT 1];

        Test.startTest();
        DeliveryActivityFeedController.approveWorkLogs(new List<Id>{ draftLog.Id });
        Test.stopTest();

        WorkLog__c updated = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :draftLog.Id];
        System.assertEquals('Approved', updated.StatusPk__c, 'Log should be approved');
    }

    @IsTest
    static void testRejectWorkLogs() {
        WorkLog__c draftLog = [SELECT Id FROM WorkLog__c WHERE StatusPk__c = 'Draft' LIMIT 1];

        Test.startTest();
        DeliveryActivityFeedController.rejectWorkLogs(new List<Id>{ draftLog.Id });
        Test.stopTest();

        WorkLog__c updated = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :draftLog.Id];
        System.assertEquals('Rejected', updated.StatusPk__c, 'Log should be rejected');
    }

    // ── postCommentFromFeed tests ──────────────────────────────────────

    @IsTest
    static void testPostCommentFromFeed() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Feed Test Item 1' LIMIT 1];

        Test.startTest();
        DeliveryActivityFeedController.postCommentFromFeed(wi.Id, 'Test reply from feed');
        Test.stopTest();

        List<WorkItemComment__c> comments = [
            SELECT BodyTxt__c, WorkItemId__c, SourcePk__c
            FROM WorkItemComment__c
            WHERE WorkItemId__c = :wi.Id AND SourcePk__c = 'Client'
        ];
        // Filter in Apex since BodyTxt__c is LongTextArea (not filterable in SOQL)
        WorkItemComment__c found = null;
        for (WorkItemComment__c c : comments) {
            if (c.BodyTxt__c == 'Test reply from feed') {
                found = c;
                break;
            }
        }
        System.assertNotEquals(null, found, 'Should create comment with expected body');
    }

    @IsTest
    static void testPostCommentFromFeedValidation() {
        Boolean caughtException = false;
        Test.startTest();
        try {
            DeliveryActivityFeedController.postCommentFromFeed(null, 'body');
        } catch (AuraHandledException e) {
            caughtException = true;
        }
        Test.stopTest();
        System.assert(caughtException, 'Should throw exception for null workItemId');
    }

    // ── Backward compat: no entity filter returns all ──────────────────

    @IsTest
    static void testNoEntityFilterReturnsAll() {
        Test.startTest();
        Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
            'comments', 0, null, null, null, null
        );
        Test.stopTest();

        List<Object> events = (List<Object>) result.get('events');
        // Should include comments from both linked and unlinked items
        System.assert(events.size() >= 2, 'No filter should return all comments');
    }
}
