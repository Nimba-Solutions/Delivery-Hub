/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Verifies TestDataFactory's public builders + bulk variants:
 *               - records insert without REQUIRED_FIELD_MISSING (no missing MDs)
 *               - default picklist values land in the field's allowed set
 *               - date-anchored helpers actually land logs on Date.today()
 *               - overrides override
 *               - the per-WI bridge cache reuses one WorkRequest__c across
 *                 stacked WorkLog inserts on the same WorkItem
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList')
@IsTest
private class TestDataFactoryTest {

    @IsTest
    static void testCreateNetworkEntityDefaults() {
        Test.startTest();
        NetworkEntity__c e = TestDataFactory.createNetworkEntity(null);
        Test.stopTest();

        System.assertNotEquals(null, e.Id, 'NetworkEntity should insert');
        NetworkEntity__c reloaded = [SELECT Id, EntityTypePk__c, StatusPk__c, Name FROM NetworkEntity__c WHERE Id = :e.Id];
        System.assertEquals('Vendor', reloaded.EntityTypePk__c, 'Default entity type should be Vendor');
        System.assertEquals('Active', reloaded.StatusPk__c, 'Default status should be Active');
        System.assert(reloaded.Name.startsWith('TDF '), 'Name should have TDF prefix');
    }

    @IsTest
    static void testCreateNetworkEntityWithOverrides() {
        Test.startTest();
        NetworkEntity__c e = TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'Name' => 'Custom Name',
            'EntityTypePk__c' => 'Client'
        });
        Test.stopTest();

        NetworkEntity__c reloaded = [SELECT Name, EntityTypePk__c FROM NetworkEntity__c WHERE Id = :e.Id];
        System.assertEquals('Custom Name', reloaded.Name, 'Name override applied');
        System.assertEquals('Client', reloaded.EntityTypePk__c, 'EntityType override applied');
    }

    @IsTest
    static void testCreateNetworkEntitiesBulk() {
        Test.startTest();
        List<NetworkEntity__c> rows = TestDataFactory.createNetworkEntities(5, null);
        Test.stopTest();

        System.assertEquals(5, rows.size(), 'Bulk variant returns N rows');
        Set<Id> ids = new Set<Id>();
        for (NetworkEntity__c e : rows) {
            ids.add(e.Id);
        }
        System.assertEquals(5, ids.size(), 'All rows have distinct Ids');
    }

    @IsTest
    static void testDefaultVendorIsCached() {
        Test.startTest();
        NetworkEntity__c a = TestDataFactory.defaultVendor();
        NetworkEntity__c b = TestDataFactory.defaultVendor();
        Test.stopTest();

        System.assertEquals(a.Id, b.Id, 'defaultVendor should return same record on subsequent calls');
        System.assertEquals('Vendor', a.EntityTypePk__c, 'defaultVendor returns Vendor type');
    }

    @IsTest
    static void testDefaultClientIsDistinctFromVendor() {
        TestDataFactory.resetCache();
        Test.startTest();
        NetworkEntity__c v = TestDataFactory.defaultVendor();
        NetworkEntity__c c = TestDataFactory.defaultClient();
        Test.stopTest();

        System.assertNotEquals(v.Id, c.Id, 'Vendor and Client should be distinct records');
        System.assertEquals('Client', c.EntityTypePk__c, 'defaultClient returns Client type');
    }

    @IsTest
    static void testCreateWorkItemDefaults() {
        Test.startTest();
        WorkItem__c wi = TestDataFactory.createWorkItem(null);
        Test.stopTest();

        WorkItem__c reloaded = [SELECT Id, StatusPk__c, StageNamePk__c, ActivatedDateTime__c, BriefDescriptionTxt__c
                                FROM WorkItem__c WHERE Id = :wi.Id];
        System.assertEquals('Active', reloaded.StatusPk__c, 'Default Status is Active (gantt-visible)');
        System.assertEquals('Backlog', reloaded.StageNamePk__c, 'Default StageName is Backlog');
        System.assertNotEquals(null, reloaded.ActivatedDateTime__c, 'ActivatedDateTime set so gantt filter passes');
        System.assert(reloaded.BriefDescriptionTxt__c.startsWith('TDF '), 'BriefDescription has TDF prefix');
    }

    @IsTest
    static void testCreateWorkItemWithOverridesAndRunTriggers() {
        Test.startTest();
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Override Desc',
            'StatusPk__c' => 'In Progress',
            '_runTriggers' => true
        });
        Test.stopTest();

        WorkItem__c reloaded = [SELECT BriefDescriptionTxt__c, StatusPk__c FROM WorkItem__c WHERE Id = :wi.Id];
        System.assertEquals('Override Desc', reloaded.BriefDescriptionTxt__c, 'Override applied');
        System.assertEquals('In Progress', reloaded.StatusPk__c, 'Status override applied');
    }

    @IsTest
    static void testCreateWorkItemsBulk() {
        Test.startTest();
        List<WorkItem__c> rows = TestDataFactory.createWorkItems(10, null);
        Test.stopTest();

        System.assertEquals(10, rows.size(), 'Bulk variant returns N rows');
        Set<String> descs = new Set<String>();
        for (WorkItem__c w : rows) {
            descs.add(w.BriefDescriptionTxt__c);
        }
        System.assertEquals(10, descs.size(), 'All rows have distinct BriefDescription (uniq counter advances)');
    }

    @IsTest
    static void testCreateWorkRequestDefaults() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        WorkRequest__c wr = TestDataFactory.createWorkRequest(wi.Id, null);
        Test.stopTest();

        WorkRequest__c reloaded = [SELECT WorkItemId__c, StatusPk__c FROM WorkRequest__c WHERE Id = :wr.Id];
        System.assertEquals(wi.Id, reloaded.WorkItemId__c, 'Master-Detail parent set');
        System.assertEquals('Active', reloaded.StatusPk__c, 'Default status applied');
    }

    @IsTest
    static void testCreateWorkLogAutoMintsBridge() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        WorkLog__c log = TestDataFactory.createWorkLog(wi.Id, 4.5, Date.today(), null);
        Test.stopTest();

        WorkLog__c reloaded = [SELECT Id, RequestId__c, WorkItemLookup__c, HoursLoggedNumber__c, WorkDateDate__c
                               FROM WorkLog__c WHERE Id = :log.Id];
        System.assertNotEquals(null, reloaded.RequestId__c, 'RequestId__c auto-populated by bridge factory');
        System.assertEquals(wi.Id, reloaded.WorkItemLookup__c, 'WorkItemLookup matches WI');
        System.assertEquals(4.5, reloaded.HoursLoggedNumber__c, 'Hours echoed');
        System.assertEquals(Date.today(), reloaded.WorkDateDate__c, 'Date echoed');

        // Verify the bridge actually exists
        Integer wrCount = [SELECT count() FROM WorkRequest__c WHERE WorkItemId__c = :wi.Id];
        System.assertEquals(1, wrCount, 'Exactly one bridge WorkRequest auto-minted');
    }

    @IsTest
    static void testStackedWorkLogsReuseOneBridge() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        // Three logs for the same WI should share one bridge WR
        TestDataFactory.createWorkLog(wi.Id, 1, Date.today(), null);
        TestDataFactory.createWorkLog(wi.Id, 2, Date.today().addDays(-1), null);
        TestDataFactory.createWorkLog(wi.Id, 3, Date.today().addDays(-2), null);
        Test.stopTest();

        Integer wrCount = [SELECT count() FROM WorkRequest__c WHERE WorkItemId__c = :wi.Id];
        System.assertEquals(1, wrCount, 'Stacked logs on same WI reuse one bridge (cached)');
        Integer logCount = [SELECT count() FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id];
        System.assertEquals(3, logCount, 'All 3 logs inserted');
    }

    @IsTest
    static void testCreateWeeklyWorkLogsAnchorsOnToday() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        List<WorkLog__c> rows = TestDataFactory.createWeeklyWorkLogs(wi.Id, new List<Decimal>{10, 10, 10, 10});
        Test.stopTest();

        System.assertEquals(4, rows.size(), '4 logs created');
        // Newest log lands on today
        WorkLog__c newest = [SELECT WorkDateDate__c FROM WorkLog__c
                             WHERE WorkItemLookup__c = :wi.Id
                             ORDER BY WorkDateDate__c DESC LIMIT 1];
        System.assertEquals(Date.today(), newest.WorkDateDate__c,
            'Most-recent log anchored on Date.today() — rolling-window math gets the current bucket');
    }

    @IsTest
    static void testCreateWorkLogsFlatBulk() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        TestDataFactory.createWorkLogs(wi.Id, 5, 2.0);
        Test.stopTest();

        AggregateResult ar = [SELECT SUM(HoursLoggedNumber__c) total FROM WorkLog__c WHERE WorkItemLookup__c = :wi.Id];
        System.assertEquals(10.0, (Decimal) ar.get('total'), '5 logs × 2h = 10h total');
    }

    @IsTest
    static void testCreateWorkItemCommentDefaults() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        WorkItemComment__c c = TestDataFactory.createWorkItemComment(wi.Id, 'hello', null);
        Test.stopTest();

        WorkItemComment__c reloaded = [SELECT WorkItemId__c, BodyTxt__c, SourcePk__c FROM WorkItemComment__c WHERE Id = :c.Id];
        System.assertEquals(wi.Id, reloaded.WorkItemId__c, 'Master-Detail parent set');
        System.assertEquals('hello', reloaded.BodyTxt__c, 'Body echoed');
        System.assertEquals('Salesforce', reloaded.SourcePk__c, 'Default source applied');
    }

    @IsTest
    static void testCreateWorkItemCommentsBulk() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        TestDataFactory.createWorkItemComments(wi.Id, 4, null);
        Test.stopTest();

        Integer cnt = [SELECT count() FROM WorkItemComment__c WHERE WorkItemId__c = :wi.Id];
        System.assertEquals(4, cnt, '4 comments created');
    }

    @IsTest
    static void testCreateSyncItemDefaults() {
        Test.startTest();
        SyncItem__c s = TestDataFactory.createSyncItem(null);
        Test.stopTest();

        SyncItem__c reloaded = [SELECT ObjectTypePk__c, StatusPk__c, DirectionPk__c, ChangeTypeTxt__c
                                FROM SyncItem__c WHERE Id = :s.Id];
        System.assertEquals('WorkItem__c', reloaded.ObjectTypePk__c, 'Default object type applied');
        System.assertEquals('Queued', reloaded.StatusPk__c, 'Default status applied');
        System.assertEquals('Outbound', reloaded.DirectionPk__c, 'Default direction applied');
        System.assertEquals('record_change', reloaded.ChangeTypeTxt__c, 'Default change type applied');
    }

    @IsTest
    static void testCreateSyncItemsBulk() {
        Test.startTest();
        List<SyncItem__c> rows = TestDataFactory.createSyncItems(3, new Map<String, Object>{
            'DirectionPk__c' => 'Inbound'
        });
        Test.stopTest();

        System.assertEquals(3, rows.size(), 'Bulk variant returns N rows');
        for (SyncItem__c s : [SELECT DirectionPk__c FROM SyncItem__c WHERE Id IN :rows]) {
            System.assertEquals('Inbound', s.DirectionPk__c, 'Override applied to every row');
        }
    }

    @IsTest
    static void testResetCacheClearsBridgeAndDefaults() {
        WorkItem__c wi = TestDataFactory.createWorkItem(null);
        TestDataFactory.createWorkLog(wi.Id, 1, Date.today(), null);
        NetworkEntity__c v1 = TestDataFactory.defaultVendor();

        Test.startTest();
        TestDataFactory.resetCache();
        NetworkEntity__c v2 = TestDataFactory.defaultVendor();
        // After reset, a new log on the same WI should mint a NEW bridge
        TestDataFactory.createWorkLog(wi.Id, 1, Date.today(), null);
        Test.stopTest();

        System.assertNotEquals(v1.Id, v2.Id, 'defaultVendor returns new record after resetCache');
        Integer wrCount = [SELECT count() FROM WorkRequest__c WHERE WorkItemId__c = :wi.Id];
        System.assertEquals(2, wrCount, 'After resetCache, a new bridge was minted for the same WI');
    }
}
