/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryFieldChangeService.
 *               Verifies invocable field change logging, settings toggle,
 *               history queries, field filtering, and trend ordering.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ExcessiveParameterList')
@IsTest
private class DeliveryFieldChangeServiceTest {

    @TestSetup
    static void setup() {
        // Enable activity logging
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingBool__c = true;
        upsert settings;
    }

    // ── Helper: build a fully-populated FieldChangeRequest ────────────

    private static DeliveryFieldChangeService.FieldChangeRequest buildRequest(
        String recordId,
        String fieldName,
        String oldValue,
        String newValue
    ) {
        DeliveryFieldChangeService.FieldChangeRequest req =
            new DeliveryFieldChangeService.FieldChangeRequest();
        req.recordId    = recordId;
        req.fieldName   = fieldName;
        req.fieldLabel  = 'Test Field';
        req.objectName  = 'Account';
        req.oldValue    = oldValue;
        req.newValue    = newValue;
        req.notes       = 'Test change note';
        return req;
    }

    // ── 1. Basic capture ──────────────────────────────────────────────

    @IsTest
    static void testCaptureFieldChangeBasic() {
        Account testAcct = new Account(Name = 'Field Change Test Account');
        insert testAcct;

        DeliveryFieldChangeService.FieldChangeRequest req = buildRequest(
            testAcct.Id, 'IUW_Risk_Rating__c', 'Low', 'High'
        );
        req.fieldLabel   = 'IUW Risk Rating';
        req.extraContext = '{"relatedScore":85}';

        Test.startTest();
        DeliveryFieldChangeService.captureFieldChanges(
            new List<DeliveryFieldChangeService.FieldChangeRequest>{ req }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ActionTypePk__c, RecordIdTxt__c, ComponentNameTxt__c,
                   UserIdTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(1, logs.size(), 'One field change log should be created');
        System.assertEquals('Field_Change', logs[0].ActionTypePk__c, 'Action type should be Field_Change');
        System.assertEquals(testAcct.Id, logs[0].RecordIdTxt__c, 'Record ID should match');
        System.assertEquals('IUW_Risk_Rating__c', logs[0].ComponentNameTxt__c, 'ComponentName should store field name');
        System.assertEquals(UserInfo.getUserId(), logs[0].UserIdTxt__c, 'User ID should be set');
        System.assert(logs[0].ContextDataTxt__c.contains('IUW Risk Rating'), 'Context should contain field label');
    }

    // ── 2. Numeric delta calculation ─────────────────────────────────

    @IsTest
    static void testCaptureFieldChangeNumericDelta() {
        Account testAcct = new Account(Name = 'Delta Test Account');
        insert testAcct;

        DeliveryFieldChangeService.FieldChangeRequest req = buildRequest(
            testAcct.Id, 'Score__c', '75', '92'
        );

        Test.startTest();
        DeliveryFieldChangeService.captureFieldChanges(
            new List<DeliveryFieldChangeService.FieldChangeRequest>{ req }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(1, logs.size(), 'One log should be created');

        Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(
            logs[0].ContextDataTxt__c
        );
        System.assertEquals(17, (Integer) ctx.get('delta'), 'Delta should be 17 (92 - 75)');
    }

    // ── 3. Logging disabled → no records ─────────────────────────────

    @IsTest
    static void testCaptureFieldChangeLoggingDisabled() {
        // Override settings to disable logging
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingBool__c = false;
        upsert settings;

        Account testAcct = new Account(Name = 'Disabled Log Test');
        insert testAcct;

        DeliveryFieldChangeService.FieldChangeRequest req = buildRequest(
            testAcct.Id, 'Status__c', 'Draft', 'Active'
        );

        Test.startTest();
        DeliveryFieldChangeService.captureFieldChanges(
            new List<DeliveryFieldChangeService.FieldChangeRequest>{ req }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(0, logs.size(), 'No logs should be created when logging is disabled');
    }

    // ── 4. getFieldChangeHistory returns results ─────────────────────

    @IsTest
    static void testGetFieldChangeHistory() {
        Account testAcct = new Account(Name = 'History Test Account');
        insert testAcct;

        // Insert activity logs directly
        List<ActivityLog__c> testLogs = new List<ActivityLog__c>();
        for (Integer i = 0; i < 3; i++) {
            testLogs.add(new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                RecordIdTxt__c      = testAcct.Id,
                UserIdTxt__c        = UserInfo.getUserId(),
                ComponentNameTxt__c = 'Risk_Rating__c',
                ContextDataTxt__c   = JSON.serialize(new Map<String, Object>{
                    'fieldName'  => 'Risk_Rating__c',
                    'fieldLabel' => 'Risk Rating',
                    'objectName' => 'Account',
                    'oldValue'   => String.valueOf(i),
                    'newValue'   => String.valueOf(i + 1)
                })
            ));
        }
        insert testLogs;

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryFieldChangeService.getFieldChangeHistory(testAcct.Id, null, null);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return 3 history entries');

        // Verify keys exist on first entry
        Map<String, Object> first = results[0];
        System.assertNotEquals(null, first.get('id'), 'Entry should have an id');
        System.assertNotEquals(null, first.get('timestamp'), 'Entry should have a timestamp');
        System.assertNotEquals(null, first.get('userName'), 'Entry should have a userName');
    }

    // ── 5. getFieldChangeHistory filters by field ────────────────────

    @IsTest
    static void testGetFieldChangeHistoryFilterByField() {
        Account testAcct = new Account(Name = 'Filter Test Account');
        insert testAcct;

        // Logs for two different fields
        insert new List<ActivityLog__c>{
            new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                RecordIdTxt__c      = testAcct.Id,
                UserIdTxt__c        = UserInfo.getUserId(),
                ComponentNameTxt__c = 'Risk_Rating__c',
                ContextDataTxt__c   = '{"fieldName":"Risk_Rating__c","oldValue":"Low","newValue":"High"}'
            ),
            new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                RecordIdTxt__c      = testAcct.Id,
                UserIdTxt__c        = UserInfo.getUserId(),
                ComponentNameTxt__c = 'Status__c',
                ContextDataTxt__c   = '{"fieldName":"Status__c","oldValue":"Draft","newValue":"Active"}'
            ),
            new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                RecordIdTxt__c      = testAcct.Id,
                UserIdTxt__c        = UserInfo.getUserId(),
                ComponentNameTxt__c = 'Risk_Rating__c',
                ContextDataTxt__c   = '{"fieldName":"Risk_Rating__c","oldValue":"High","newValue":"Critical"}'
            )
        };

        Test.startTest();
        List<Map<String, Object>> riskResults =
            DeliveryFieldChangeService.getFieldChangeHistory(testAcct.Id, 'Risk_Rating__c', null);
        List<Map<String, Object>> statusResults =
            DeliveryFieldChangeService.getFieldChangeHistory(testAcct.Id, 'Status__c', null);
        List<Map<String, Object>> allResults =
            DeliveryFieldChangeService.getFieldChangeHistory(testAcct.Id, null, null);
        Test.stopTest();

        System.assertEquals(2, riskResults.size(), 'Should return 2 Risk_Rating entries');
        System.assertEquals(1, statusResults.size(), 'Should return 1 Status entry');
        System.assertEquals(3, allResults.size(), 'Should return all 3 entries without filter');
    }

    // ── 6. getFieldChangeTrend returns chronological order ───────────

    @IsTest
    static void testGetFieldChangeTrend() {
        Account testAcct = new Account(Name = 'Trend Test Account');
        insert testAcct;

        // Insert logs
        insert new List<ActivityLog__c>{
            new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                RecordIdTxt__c      = testAcct.Id,
                UserIdTxt__c        = UserInfo.getUserId(),
                ComponentNameTxt__c = 'Score__c',
                ContextDataTxt__c   = '{"fieldName":"Score__c","fieldLabel":"Score","newValue":"10"}'
            ),
            new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                RecordIdTxt__c      = testAcct.Id,
                UserIdTxt__c        = UserInfo.getUserId(),
                ComponentNameTxt__c = 'Score__c',
                ContextDataTxt__c   = '{"fieldName":"Score__c","fieldLabel":"Score","newValue":"20"}'
            )
        };

        Test.startTest();
        List<Map<String, Object>> results =
            DeliveryFieldChangeService.getFieldChangeTrend(testAcct.Id, 'Score__c', null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 trend entries');

        // Verify chronological ordering (ASC)
        Datetime previous = Datetime.newInstance(1900, 1, 1);
        for (Map<String, Object> entry : results) {
            Datetime ts = (Datetime) entry.get('timestamp');
            System.assert(ts >= previous, 'Entries should be ordered chronologically (ASC)');
            previous = ts;
        }

        // Verify simplified keys
        Map<String, Object> first = results[0];
        System.assert(first.containsKey('timestamp'), 'Should have timestamp');
        System.assert(first.containsKey('value'), 'Should have value');
        System.assert(first.containsKey('label'), 'Should have label');
    }

    // ── 7. Malformed extraContext JSON handled gracefully ────────────

    @IsTest
    static void testCaptureFieldChangeMalformedExtraContext() {
        Account testAcct = new Account(Name = 'Malformed Context Test');
        insert testAcct;

        DeliveryFieldChangeService.FieldChangeRequest req = buildRequest(
            testAcct.Id, 'Status__c', 'Draft', 'Active'
        );
        req.extraContext = 'not valid json {';

        Test.startTest();
        DeliveryFieldChangeService.captureFieldChanges(
            new List<DeliveryFieldChangeService.FieldChangeRequest>{ req }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(1, logs.size(), 'Log should still be created with malformed extraContext');
        System.assert(logs[0].ContextDataTxt__c.contains('not valid json'),
            'Malformed extraContext should be stored as raw string');
    }

    // ── Null recordId returns empty ──────────────────────────────────

    @IsTest
    static void testNullRecordId() {
        Test.startTest();
        List<Map<String, Object>> historyResults =
            DeliveryFieldChangeService.getFieldChangeHistory(null, null, null);
        List<Map<String, Object>> trendResults =
            DeliveryFieldChangeService.getFieldChangeTrend(null, null, null);
        Test.stopTest();

        System.assertEquals(0, historyResults.size(), 'Null recordId should return empty history');
        System.assertEquals(0, trendResults.size(), 'Null recordId should return empty trend');
    }
}
