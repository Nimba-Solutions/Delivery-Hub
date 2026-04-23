/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryNotificationPreferenceService. Covers
 *               shouldNotify's opt-out default model, getPreferences ordering,
 *               upsertPreference insert+update paths, and all null-guard
 *               branches. Critical because every notification path in DH
 *               (email, slack, bell) funnels through shouldNotify.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
private class DeliveryNotificationPreferenceServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testShouldNotifyDefaultsToSendWhenNoPreference() {
        System.runAs(testUser) {
            Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Stage_Change'
            );
            System.assertEquals(true, send,
                'Opt-out model: absence of a preference record should default to sending');
        }
    }

    @IsTest
    static void testShouldNotifyNullUserIdReturnsTrue() {
        Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
            null, 'Email', 'Stage_Change'
        );
        System.assertEquals(true, send, 'Null userId should fall through to default-send');
    }

    @IsTest
    static void testShouldNotifyBlankChannelReturnsTrue() {
        Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
            testUser.Id, '', 'Stage_Change'
        );
        System.assertEquals(true, send, 'Blank channel should fall through to default-send');
    }

    @IsTest
    static void testShouldNotifyBlankEventTypeReturnsTrue() {
        Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
            testUser.Id, 'Email', null
        );
        System.assertEquals(true, send, 'Null eventType should fall through to default-send');
    }

    @IsTest
    static void testShouldNotifyRespectsExplicitDisablePreference() {
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Stage_Change', false, 'Immediate'
            );

            Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Stage_Change'
            );

            System.assertEquals(false, send,
                'EnabledDateTime__c null (disabled) should suppress the send');
        }
    }

    @IsTest
    static void testShouldNotifyRespectsExplicitEnablePreference() {
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Escalation', true, 'Immediate'
            );

            Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Slack', 'Escalation'
            );

            System.assertEquals(true, send,
                'EnabledDateTime__c populated should allow the send');
        }
    }

    @IsTest
    static void testShouldNotifyIsolatesByChannelAndEvent() {
        // A disable on (Email, Stage_Change) must not suppress a different
        // (Slack, Escalation) combination — prevents cross-channel bleed.
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Stage_Change', false, 'Immediate'
            );

            Boolean otherChannel = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Slack', 'Stage_Change'
            );
            Boolean otherEvent = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Escalation'
            );

            System.assertEquals(true, otherChannel,
                'Disable on Email channel should not suppress Slack channel');
            System.assertEquals(true, otherEvent,
                'Disable on Stage_Change event should not suppress Escalation event');
        }
    }

    @IsTest
    static void testUpsertPreferenceInsertsNewRecord() {
        System.runAs(testUser) {
            Integer beforeCount = [
                SELECT COUNT() FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
            ];

            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Weekly_Digest', true, 'Weekly'
            );
            Test.stopTest();

            List<NotificationPreference__c> prefs = [
                SELECT ChannelPk__c, EventTypePk__c, EnabledDateTime__c, DigestFrequencyPk__c
                FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
            ];
            System.assertEquals(beforeCount + 1, prefs.size(), 'One new pref record should exist');
            NotificationPreference__c created;
            for (NotificationPreference__c p : prefs) {
                if (p.ChannelPk__c == 'Email' && p.EventTypePk__c == 'Weekly_Digest') {
                    created = p;
                }
            }
            System.assertNotEquals(null, created, 'New pref for (Email, Weekly_Digest) should be persisted');
            System.assertNotEquals(null, created.EnabledDateTime__c, 'Enabled insert should stamp EnabledDateTime');
            System.assertEquals('Weekly', created.DigestFrequencyPk__c, 'Digest frequency should round-trip');
        }
    }

    @IsTest
    static void testUpsertPreferenceUpdatesExistingRecord() {
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Daily_Digest', true, 'Daily'
            );

            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Daily_Digest', false, 'Weekly'
            );
            Test.stopTest();

            List<NotificationPreference__c> prefs = [
                SELECT EnabledDateTime__c, DigestFrequencyPk__c
                FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
                AND ChannelPk__c = 'Slack'
                AND EventTypePk__c = 'Daily_Digest'
            ];
            System.assertEquals(1, prefs.size(), 'Upsert should reuse the existing row, not insert a duplicate');
            System.assertEquals(null, prefs[0].EnabledDateTime__c, 'Disable update should null EnabledDateTime');
            System.assertEquals('Weekly', prefs[0].DigestFrequencyPk__c, 'Digest frequency should be updated');
        }
    }

    @IsTest
    static void testGetPreferencesReturnsRowsOrdered() {
        System.runAs(testUser) {
            // Insert in a NON-sorted order so the ORDER BY has work to do.
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Stage_Change', true, 'Immediate'
            );
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Escalation', true, 'Immediate'
            );
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Stage_Change', true, 'Immediate'
            );

            Test.startTest();
            List<NotificationPreference__c> prefs =
                DeliveryNotificationPreferenceService.getPreferences(testUser.Id);
            Test.stopTest();

            System.assertEquals(3, prefs.size(), 'Should return all 3 prefs for the user');
            // Ordering: ChannelPk__c ASC, EventTypePk__c ASC.
            // Email rows come before Slack, and within Email, Escalation before Stage_Change.
            System.assertEquals('Email', prefs[0].ChannelPk__c, 'First row should be Email (alpha)');
            System.assertEquals('Escalation', prefs[0].EventTypePk__c, 'First Email row should be Escalation');
            System.assertEquals('Email', prefs[1].ChannelPk__c, 'Second row should still be Email');
            System.assertEquals('Stage_Change', prefs[1].EventTypePk__c, 'Second Email row should be Stage_Change');
            System.assertEquals('Slack', prefs[2].ChannelPk__c, 'Third row should be Slack');
        }
    }

    @IsTest
    static void testGetPreferencesEmptyForUnknownUser() {
        // Build a plausible fake User Id — 005 prefix + 12 chars — that
        // won't match any existing row. getPreferences should return [].
        String fakeUserId = '005000000000001AAA';
        System.runAs(testUser) {
            List<NotificationPreference__c> prefs =
                DeliveryNotificationPreferenceService.getPreferences(Id.valueOf(fakeUserId));
            System.assertEquals(0, prefs.size(), 'Unknown user should return empty list, not null');
        }
    }

    @IsTest
    static void testUpsertPreservesExistingEnabledDateTimeOnReEnable() {
        // When a pref is already enabled and the caller re-enables it,
        // the service should NOT overwrite the original EnabledDateTime.
        // This preserves "enabled since..." audit semantics.
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Boundary_Test', true, 'Immediate'
            );
            Datetime original = [
                SELECT EnabledDateTime__c FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
                AND ChannelPk__c = 'Email' AND EventTypePk__c = 'Boundary_Test' LIMIT 1
            ].EnabledDateTime__c;
            System.assertNotEquals(null, original, 'Precondition: first upsert sets EnabledDateTime');

            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Boundary_Test', true, 'Daily'
            );
            Test.stopTest();

            NotificationPreference__c after = [
                SELECT EnabledDateTime__c, DigestFrequencyPk__c
                FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
                AND ChannelPk__c = 'Email' AND EventTypePk__c = 'Boundary_Test' LIMIT 1
            ];
            System.assertEquals(original, after.EnabledDateTime__c,
                'Re-enable should preserve original EnabledDateTime (audit semantics)');
            System.assertEquals('Daily', after.DigestFrequencyPk__c,
                'Re-enable should still update the digest frequency');
        }
    }
}
