/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryStageHistoryController.
 *               Verifies that stage change ActivityLog__c records are correctly
 *               queried, deserialized, and returned for a given Work Item.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryStageHistoryControllerTest {

    @TestSetup
    static void setup() {
        // Enable activity logging
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingBool__c = true;
        upsert settings;

        // Work Item
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Stage History Test Item',
            StageNamePk__c = 'Code Review'
        );
        insert wi;

        String userId = UserInfo.getUserId();

        // Stage change 1: Backlog -> In Development
        ActivityLog__c log1 = new ActivityLog__c(
            ActionTypePk__c     = 'Stage_Change',
            ComponentNameTxt__c = 'DeliveryWorkItemTrigger',
            UserIdTxt__c        = userId,
            RecordIdTxt__c      = wi.Id,
            ContextDataTxt__c   = JSON.serialize(new Map<String, Object>{
                'workItemId'       => wi.Id,
                'workItemName'     => wi.Name,
                'oldStage'         => 'Backlog',
                'newStage'         => 'In Development',
                'durationHours'    => 12.5,
                'oldStageEnteredAt' => '2026-03-01T10:00:00.000Z'
            })
        );

        // Stage change 2: In Development -> Code Review
        ActivityLog__c log2 = new ActivityLog__c(
            ActionTypePk__c     = 'Stage_Change',
            ComponentNameTxt__c = 'DeliveryWorkItemTrigger',
            UserIdTxt__c        = userId,
            RecordIdTxt__c      = wi.Id,
            ContextDataTxt__c   = JSON.serialize(new Map<String, Object>{
                'workItemId'       => wi.Id,
                'workItemName'     => wi.Name,
                'oldStage'         => 'In Development',
                'newStage'         => 'Code Review',
                'durationHours'    => 48.0,
                'oldStageEnteredAt' => '2026-03-02T08:00:00.000Z'
            })
        );

        // Stage change 3: minimal context (no stages)
        ActivityLog__c log3 = new ActivityLog__c(
            ActionTypePk__c     = 'Stage_Change',
            ComponentNameTxt__c = 'DeliveryWorkItemTrigger',
            RecordIdTxt__c      = wi.Id,
            ContextDataTxt__c   = '{"workItemId":"' + wi.Id + '"}'
        );

        insert new List<ActivityLog__c>{ log1, log2, log3 };
    }

    // ── Positive: returns all stage changes for a work item ──────────

    @IsTest
    static void testGetStageHistoryReturnsEntries() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(wi.Id);
        Test.stopTest();

        System.assertEquals(3, results.size(),
            'Expected 3 stage change entries');

        // Verify required keys exist on each entry
        for (Map<String, Object> entry : results) {
            System.assertNotEquals(null, entry.get('id'),
                'Each entry must have an id');
            System.assertNotEquals(null, entry.get('timestamp'),
                'Each entry must have a timestamp');
            System.assertNotEquals(null, entry.get('userName'),
                'Each entry must have a userName');
        }
    }

    // ── Verify deserialized context data ─────────────────────────────

    @IsTest
    static void testContextDataDeserialized() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(wi.Id);
        Test.stopTest();

        // Find the Backlog -> In Development entry
        Boolean foundFirst = false;
        for (Map<String, Object> entry : results) {
            if ('Backlog' == (String) entry.get('oldStage')
                && 'In Development' == (String) entry.get('newStage')) {
                foundFirst = true;
                System.assertEquals(12.5, (Decimal) entry.get('durationHours'),
                    'Duration hours should match serialized value');
            }
        }
        System.assert(foundFirst,
            'Should find the Backlog -> In Development transition');
    }

    // ── User name resolution ─────────────────────────────────────────

    @IsTest
    static void testUserNameResolved() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(wi.Id);
        Test.stopTest();

        String runningUserName = UserInfo.getName();
        Boolean foundNamedUser = false;
        for (Map<String, Object> entry : results) {
            if (runningUserName == (String) entry.get('userName')) {
                foundNamedUser = true;
                break;
            }
        }
        System.assert(foundNamedUser,
            'At least one entry should resolve to the running user name');
    }

    // ── Missing userId resolves to System ────────────────────────────

    @IsTest
    static void testMissingUserIdResolvesToSystem() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(wi.Id);
        Test.stopTest();

        Boolean foundSystem = false;
        for (Map<String, Object> entry : results) {
            if ('System' == (String) entry.get('userName')) {
                foundSystem = true;
                break;
            }
        }
        System.assert(foundSystem,
            'Entry without UserIdTxt__c should have userName = System');
    }

    // ── Null workItemId returns empty list ───────────────────────────

    @IsTest
    static void testNullWorkItemId() {
        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(null);
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'Null workItemId should return empty list');
    }

    // ── Different work item returns no results ───────────────────────

    @IsTest
    static void testDifferentWorkItemReturnsEmpty() {
        WorkItem__c other = new WorkItem__c(
            BriefDescriptionTxt__c = 'Other Item',
            StageNamePk__c = 'Backlog'
        );
        insert other;

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(other.Id);
        Test.stopTest();

        System.assertEquals(0, results.size(),
            'Work item with no stage changes should return empty list');
    }

    // ── Invalid JSON context handled gracefully ──────────────────────

    @IsTest
    static void testInvalidJsonContextHandled() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        // Insert a log with invalid JSON
        ActivityLog__c badLog = new ActivityLog__c(
            ActionTypePk__c     = 'Stage_Change',
            ComponentNameTxt__c = 'DeliveryWorkItemTrigger',
            UserIdTxt__c        = UserInfo.getUserId(),
            RecordIdTxt__c      = wi.Id,
            ContextDataTxt__c   = 'NOT VALID JSON'
        );
        insert badLog;

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(wi.Id);
        Test.stopTest();

        // Should have 4 entries (3 from setup + 1 bad JSON) without throwing
        System.assertEquals(4, results.size(),
            'Should return entries even with invalid JSON context');

        // The bad JSON entry should have empty defaults
        Boolean foundDefault = false;
        for (Map<String, Object> entry : results) {
            if ('' == (String) entry.get('oldStage')
                && '' == (String) entry.get('newStage')
                && entry.get('durationHours') == null) {
                foundDefault = true;
                break;
            }
        }
        System.assert(foundDefault,
            'Invalid JSON entry should fall back to empty defaults');
    }

    // ── Results ordered newest first ─────────────────────────────────

    @IsTest
    static void testResultsOrderedDescending() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryStageHistoryController.getStageHistory(wi.Id);
        Test.stopTest();

        Datetime previous = Datetime.now().addYears(1);
        for (Map<String, Object> entry : results) {
            Datetime ts = (Datetime) entry.get('timestamp');
            System.assert(ts <= previous,
                'Entries should be ordered newest first');
            previous = ts;
        }
    }
}
