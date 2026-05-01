/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryActivityFeedController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityFeedControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

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
            ClientNetworkEntityLookup__c = client.Id
        );
        WorkItem__c workItem2 = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Feed Test Item 2',
            StageNamePk__c           = 'In Development',
            ClientNetworkEntityLookup__c = client.Id
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
                DeliveryEntityLookup__c   = vendor.Id,
                QuotedHoursNumber__c  = 20,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            ),
            new WorkRequest__c(
                WorkItemId__c         = workItem2.Id,
                DeliveryEntityLookup__c   = vendor.Id,
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
                WorkItemLookup__c           = workItem1.Id,
                HoursLoggedNumber__c  = 3.5,
                WorkDateDate__c       = Date.today(),
                WorkDescriptionTxt__c = 'Development work',
                StatusPk__c           = 'Approved'
            ),
            new WorkLog__c(
                RequestId__c          = req2.Id,
                WorkItemLookup__c           = workItem2.Id,
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
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'all', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            System.assert(events.size() > 0, 'Should return events across all types');
            System.assertNotEquals(null, result.get('totalCount'));
        }
    }

    @IsTest
    static void testGetActivityFeedCommentsOnly() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetActivityFeedHoursOnly() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'hours', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            System.assertEquals(2, events.size(), 'Should return 2 work logs');
        }
    }

    @IsTest
    static void testGetActivityFeedChangesOnly() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            System.assert(events.size() >= 1, 'Should return at least 1 stage change');
        }
    }

    @IsTest
    static void testGetActivityFeedByNetworkEntity() {
        System.runAs(testUser) {
            NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Feed Test Client' LIMIT 1];

            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'all', 0, client.Id, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            System.assert(events.size() > 0, 'Should return events for client-linked items');
        }
    }

    @IsTest
    static void testGetActivityFeedByWorkItem() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetActivityFeedPagination() {
        System.runAs(testUser) {
            Test.startTest();
            // Request page 100 (way beyond data) — should get empty
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'all', 100, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            System.assertEquals(0, events.size(), 'Out-of-range page should return empty');
        }
    }

    // ── Field-change suppression tests ─────────────────────────────────

    @IsTest
    static void testFieldChangeSuppressDescriptionOnly() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Feed Test Item 1' LIMIT 1];
        insert new ActivityLog__c(
            ActionTypePk__c   = 'Field_Change',
            RecordIdTxt__c    = wi.Id,
            UserIdTxt__c      = UserInfo.getUserId(),
            ContextDataTxt__c = JSON.serialize(new Map<String, Object>{
                'fieldName'  => 'WorkDescriptionTxt__c',
                'fieldLabel' => 'Description',
                'oldValue'   => 'Old text',
                'newValue'   => 'New text'
            })
        );

        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            for (Object ev : events) {
                Map<String, Object> event = (Map<String, Object>) ev;
                System.assertNotEquals('field_change', event.get('type'),
                    'Description-only field change should be suppressed');
            }
        }
    }

    @IsTest
    static void testFieldChangeSuppressNoOp() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Feed Test Item 1' LIMIT 1];
        insert new ActivityLog__c(
            ActionTypePk__c   = 'Field_Change',
            RecordIdTxt__c    = wi.Id,
            UserIdTxt__c      = UserInfo.getUserId(),
            ContextDataTxt__c = JSON.serialize(new Map<String, Object>{
                'fieldName'  => 'StatusPk__c',
                'fieldLabel' => 'Status',
                'oldValue'   => 'Approved',
                'newValue'   => 'Approved'
            })
        );

        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            for (Object ev : events) {
                Map<String, Object> event = (Map<String, Object>) ev;
                System.assertNotEquals('field_change', event.get('type'),
                    'No-op (old==new) field change should be suppressed');
            }
        }
    }

    @IsTest
    static void testFieldChangeKeepsRealChange() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Feed Test Item 1' LIMIT 1];
        insert new ActivityLog__c(
            ActionTypePk__c   = 'Field_Change',
            RecordIdTxt__c    = wi.Id,
            UserIdTxt__c      = UserInfo.getUserId(),
            ContextDataTxt__c = JSON.serialize(new Map<String, Object>{
                'fieldName'  => 'HoursLoggedNumber__c',
                'fieldLabel' => 'Hours Logged',
                'oldValue'   => '1.5',
                'newValue'   => '2.0'
            })
        );

        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            Boolean foundRealChange = false;
            for (Object ev : events) {
                Map<String, Object> event = (Map<String, Object>) ev;
                if (event.get('type') == 'field_change') {
                    String detail = (String) event.get('detail');
                    if (detail != null && detail.contains('1.5') && detail.contains('2.0')) {
                        foundRealChange = true;
                    }
                }
            }
            System.assert(foundRealChange,
                'Real Hours Logged change should surface with FROM → TO detail');
        }
    }

    // ── getConversations tests ─────────────────────────────────────────

    @IsTest
    static void testGetConversations() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetConversationsByEntity() {
        System.runAs(testUser) {
            NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Feed Test Client' LIMIT 1];

            Test.startTest();
            List<Map<String, Object>> threads = DeliveryActivityFeedController.getConversations(0, client.Id);
            Test.stopTest();

            System.assertEquals(2, threads.size(), 'Should return 2 threads for client entity');
        }
    }

    // ── getPendingApprovals tests ──────────────────────────────────────

    @IsTest
    static void testGetPendingApprovals() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getPendingApprovals(0, null);
            Test.stopTest();

            List<Object> approvals = (List<Object>) result.get('approvals');
            System.assertEquals(1, approvals.size(), 'Should return 1 draft work log');
            Map<String, Object> approval = (Map<String, Object>) approvals[0];
            System.assertEquals('Draft', approval.get('status'));
        }
    }

    // ── Approval lifecycle tests ───────────────────────────────────────

    @IsTest
    static void testApproveWorkLogs() {
        System.runAs(testUser) {
            WorkLog__c draftLog = [SELECT Id FROM WorkLog__c WHERE StatusPk__c = 'Draft' LIMIT 1];

            Test.startTest();
            DeliveryActivityFeedController.approveWorkLogs(new List<Id>{ draftLog.Id });
            Test.stopTest();

            WorkLog__c updated = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :draftLog.Id];
            System.assertEquals('Approved', updated.StatusPk__c, 'Log should be approved');
        }
    }

    @IsTest
    static void testRejectWorkLogs() {
        System.runAs(testUser) {
            WorkLog__c draftLog = [SELECT Id FROM WorkLog__c WHERE StatusPk__c = 'Draft' LIMIT 1];

            Test.startTest();
            DeliveryActivityFeedController.rejectWorkLogs(new List<Id>{ draftLog.Id });
            Test.stopTest();

            WorkLog__c updated = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :draftLog.Id];
            System.assertEquals('Rejected', updated.StatusPk__c, 'Log should be rejected');
        }
    }

    // ── postCommentFromFeed tests ──────────────────────────────────────

    @IsTest
    static void testPostCommentFromFeed() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testPostCommentFromFeedValidation() {
        System.runAs(testUser) {
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
    }

    // ── Backward compat: no entity filter returns all ──────────────────

    @IsTest
    static void testNoEntityFilterReturnsAll() {
        System.runAs(testUser) {
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

    /**
     * @description Stage_Change with null oldStage in the JSON should render
     *              as '(empty) → newStage' instead of an empty detail. This
     *              fixes the user-facing "Status changed (no context)" bug.
     */
    @IsTest
    static void testParseStageChangeRendersEmptyOldStageAsFallback() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            insert new ActivityLog__c(
                ActionTypePk__c    = 'Stage_Change',
                RecordIdTxt__c     = wi.Id,
                UserIdTxt__c       = UserInfo.getUserId(),
                ContextDataTxt__c  = '{"oldStage":null,"newStage":"Backlog","workItemId":"' + wi.Id + '"}'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            Boolean foundFallback = false;
            for (Object ev : events) {
                Map<String, Object> event = (Map<String, Object>) ev;
                String detail = (String) event.get('detail');
                if (detail != null && detail.contains('(empty)') && detail.contains('Backlog')) {
                    foundFallback = true;
                    break;
                }
            }
            System.assert(foundFallback,
                'Stage_Change with null oldStage should render detail as "(empty) → Backlog"');
        }
    }

    /**
     * @description Field_Change with null oldValue/newValue in JSON should
     *              render as '(empty) → ...' instead of literal "null → ..."
     *              that the previous String.valueOf(null) path produced.
     */
    @IsTest
    static void testParseFieldChangeRendersNullValuesAsFallback() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            insert new ActivityLog__c(
                ActionTypePk__c    = 'Field_Change',
                RecordIdTxt__c     = wi.Id,
                UserIdTxt__c       = UserInfo.getUserId(),
                ContextDataTxt__c  = '{"fieldLabel":"Status","oldValue":null,"newValue":"In Progress"}'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            Boolean foundFallback = false;
            for (Object ev : events) {
                Map<String, Object> event = (Map<String, Object>) ev;
                String detail = (String) event.get('detail');
                if (detail != null && detail.contains('(empty)')
                    && detail.contains('In Progress')
                    && !detail.contains('null')) {
                    foundFallback = true;
                    break;
                }
            }
            System.assert(foundFallback,
                'Field_Change with null oldValue should render detail as "(empty) → In Progress" (no literal "null")');
        }
    }

    /**
     * @description Malformed JSON in ContextDataTxt__c should not silently
     *              produce an empty-detail row; renders a fallback so the
     *              user sees signal and the WARN debug log surfaces the bug.
     */
    @IsTest
    static void testParseChangeContextHandlesMalformedJson() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            insert new ActivityLog__c(
                ActionTypePk__c    = 'Field_Change',
                RecordIdTxt__c     = wi.Id,
                UserIdTxt__c       = UserInfo.getUserId(),
                ContextDataTxt__c  = '{this is not valid json'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryActivityFeedController.getActivityFeed(
                'changes', 0, null, null, null, null
            );
            Test.stopTest();

            List<Object> events = (List<Object>) result.get('events');
            Boolean foundFallback = false;
            for (Object ev : events) {
                Map<String, Object> event = (Map<String, Object>) ev;
                String detail = (String) event.get('detail');
                if (detail != null && detail.contains('unparseable')) {
                    foundFallback = true;
                    break;
                }
            }
            System.assert(foundFallback,
                'Malformed JSON should render fallback detail "(change context unparseable)"');
        }
    }
}
