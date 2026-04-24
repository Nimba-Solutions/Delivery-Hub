/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryPicklistIntegrityService — unit tests on the
 *               service itself plus per-object integration tests proving the
 *               trigger wiring rejects unknown picklist values on all 4 fields.
 *
 *               Direct-service tests use in-memory SObject instances (no DML)
 *               so they never depend on platform-level restricted enforcement.
 *               Integration tests use Database.insert(records, false) so the
 *               partial-success path surfaces the trigger-added error even if
 *               platform-level restricted=true also rejects it — either way,
 *               the error we added must be present.
 *
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexCRUDViolation')
private class DeliveryPicklistIntegrityServiceTest {

    // ── Direct service tests (no DML, no trigger) ──────────────────────

    @IsTest
    static void testValidateAcceptsAllowedValue() {
        DeliveryPicklistIntegrityService.resetForTest();
        SyncItem__c si = new SyncItem__c(StatusPk__c = 'Queued', DirectionPk__c = 'Outbound');

        Test.startTest();
        DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        Test.stopTest();

        System.assertEquals(false, si.hasErrors(),
            'Allowed value "Queued" should not produce an error');
    }

    @IsTest
    static void testValidateRejectsUnknownValue() {
        DeliveryPicklistIntegrityService.resetForTest();
        SyncItem__c si = new SyncItem__c(StatusPk__c = 'Bogus', DirectionPk__c = 'Outbound');

        Test.startTest();
        DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        Test.stopTest();

        System.assertEquals(true, si.hasErrors(),
            'Unknown value "Bogus" should produce an error');
        List<Database.Error> errors = si.getErrors();
        System.assertEquals(1, errors.size(), 'Exactly one error expected');
        System.assert(errors[0].getMessage().contains('Bogus'),
            'Error message should name the rejected value, got: ' + errors[0].getMessage());
        System.assert(errors[0].getMessage().contains('DeliverySyncItemStatus'),
            'Error message should name the GVS, got: ' + errors[0].getMessage());
    }

    @IsTest
    static void testValidateIgnoresNullValue() {
        DeliveryPicklistIntegrityService.resetForTest();
        SyncItem__c si = new SyncItem__c(DirectionPk__c = 'Outbound');
        // StatusPk__c is null

        Test.startTest();
        DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        Test.stopTest();

        System.assertEquals(false, si.hasErrors(),
            'Null picklist value should not produce an error (integrity enforces value-in-set, not non-null)');
    }

    @IsTest
    static void testValidateIgnoresBlankValue() {
        DeliveryPicklistIntegrityService.resetForTest();
        SyncItem__c si = new SyncItem__c(StatusPk__c = '', DirectionPk__c = 'Outbound');

        Test.startTest();
        DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        Test.stopTest();

        System.assertEquals(false, si.hasErrors(),
            'Blank picklist value should not produce an error');
    }

    @IsTest
    static void testBulkRunUsesCache() {
        DeliveryPicklistIntegrityService.resetForTest();
        List<SyncItem__c> batch = new List<SyncItem__c>();
        for (Integer i = 0; i < 200; i++) {
            batch.add(new SyncItem__c(StatusPk__c = 'Queued', DirectionPk__c = 'Outbound'));
        }

        Test.startTest();
        for (SyncItem__c si : batch) {
            DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        }
        Test.stopTest();

        System.assertEquals(1, DeliveryPicklistIntegrityService.describeCallCount,
            'Cache should collapse 200 validate() calls on same field to a single describe. Got: '
                + DeliveryPicklistIntegrityService.describeCallCount);
    }

    @IsTest
    static void testCacheIsPerFieldNotPerRecord() {
        DeliveryPicklistIntegrityService.resetForTest();
        SyncItem__c si = new SyncItem__c(StatusPk__c = 'Queued', ObjectTypePk__c = 'WorkItem__c', DirectionPk__c = 'Outbound');

        Test.startTest();
        DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        DeliveryPicklistIntegrityService.validate(si, 'ObjectTypePk__c', 'DeliverySyncItemObjectType');
        // A second call on StatusPk__c should not re-describe
        DeliveryPicklistIntegrityService.validate(si, 'StatusPk__c', 'DeliverySyncItemStatus');
        Test.stopTest();

        System.assertEquals(2, DeliveryPicklistIntegrityService.describeCallCount,
            'Two distinct fields → two describes; a repeat on the first field should hit cache');
        System.assertEquals(false, si.hasErrors(), 'All values are valid; no errors expected');
    }

    @IsTest
    static void testValidateTolerantOfMissingField() {
        // A non-existent field should not blow up — safer to no-op than to hard-block.
        DeliveryPicklistIntegrityService.resetForTest();
        SyncItem__c si = new SyncItem__c(DirectionPk__c = 'Outbound');

        Test.startTest();
        DeliveryPicklistIntegrityService.validate(si, 'NoSuchField__c', 'DeliverySyncItemStatus');
        Test.stopTest();

        System.assertEquals(false, si.hasErrors(),
            'Missing field lookup should be a no-op, not an error');
    }

    // ── Per-object integration tests (through triggers) ────────────────

    @IsTest
    static void testSyncItemTriggerRejectsBogusStatus() {
        SyncItem__c si = new SyncItem__c(
            StatusPk__c = 'NotAStatus',
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            PayloadTxt__c = '{}'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(si, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Insert with bogus StatusPk__c must fail');
        Boolean found = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('NotAStatus')) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found,
            'Error list should mention the rejected value: ' + sr.getErrors());
    }

    @IsTest
    static void testSyncItemTriggerRejectsBogusObjectType() {
        SyncItem__c si = new SyncItem__c(
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'NotARealObject',
            DirectionPk__c = 'Outbound',
            PayloadTxt__c = '{}'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(si, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Insert with bogus ObjectTypePk__c must fail');
        Boolean found = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('NotARealObject')) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found,
            'Error list should mention the rejected value: ' + sr.getErrors());
    }

    @IsTest
    static void testSyncItemTriggerAcceptsValidValues() {
        SyncItem__c si = new SyncItem__c(
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            PayloadTxt__c = '{}'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(si, false);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(),
            'Valid picklist values should insert cleanly. Errors: ' + sr.getErrors());
    }

    @IsTest
    static void testNotificationPreferenceTriggerRejectsBogusEventType() {
        NotificationPreference__c pref = new NotificationPreference__c(
            UserIdTxt__c = UserInfo.getUserId(),
            EventTypePk__c = 'NotARealEvent',
            ChannelPk__c = 'Email'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(pref, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Insert with bogus EventTypePk__c must fail');
        Boolean found = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('NotARealEvent')) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found,
            'Error list should mention the rejected value: ' + sr.getErrors());
    }

    @IsTest
    static void testNotificationPreferenceTriggerAcceptsValidEventType() {
        NotificationPreference__c pref = new NotificationPreference__c(
            UserIdTxt__c = UserInfo.getUserId(),
            EventTypePk__c = 'Stage_Change',
            ChannelPk__c = 'Email'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(pref, false);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(),
            'Valid picklist value should insert cleanly. Errors: ' + sr.getErrors());
    }

    @IsTest
    static void testActivityLogTriggerRejectsBogusActionType() {
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'NotARealAction',
            UserIdTxt__c = UserInfo.getUserId(),
            ContextDataTxt__c = '{}'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(log, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Insert with bogus ActionTypePk__c must fail');
        Boolean found = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('NotARealAction')) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found,
            'Error list should mention the rejected value: ' + sr.getErrors());
    }

    @IsTest
    static void testActivityLogTriggerAcceptsValidActionType() {
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'Navigation',
            UserIdTxt__c = UserInfo.getUserId(),
            ContextDataTxt__c = '{}'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(log, false);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(),
            'Valid picklist value should insert cleanly. Errors: ' + sr.getErrors());
    }

    @IsTest
    static void testActivityLogTriggerRejectsBogusOnUpdate() {
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'Navigation',
            UserIdTxt__c = UserInfo.getUserId(),
            ContextDataTxt__c = '{}'
        );
        insert log;

        log.ActionTypePk__c = 'Mutated_Bogus_Action';

        Test.startTest();
        Database.SaveResult sr = Database.update(log, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Update to bogus ActionTypePk__c must fail');
        Boolean found = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('Mutated_Bogus_Action')) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found,
            'Error list should mention the rejected value: ' + sr.getErrors());
    }

    @IsTest
    static void testSyncItemTriggerRejectsBogusOnUpdate() {
        SyncItem__c si = new SyncItem__c(
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            PayloadTxt__c = '{}'
        );
        insert si;

        si.StatusPk__c = 'MutatedBogusStatus';

        Test.startTest();
        Database.SaveResult sr = Database.update(si, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess(), 'Update to bogus StatusPk__c must fail');
        Boolean found = false;
        for (Database.Error err : sr.getErrors()) {
            if (err.getMessage().contains('MutatedBogusStatus')) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found,
            'Error list should mention the rejected value: ' + sr.getErrors());
    }
}
