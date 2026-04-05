/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryNotificationPreferenceService — covers shouldNotify,
 *               getPreferences, upsertPreference, and default opt-out behavior.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexCRUDViolation')
private class DeliveryNotificationPreferenceServiceTest {

    @IsTest
    static void shouldNotify_returnsTrue_whenNoPreferenceExists() {
        // No preference records — opt-out model defaults to send
        Test.startTest();
        Boolean result = DeliveryNotificationPreferenceService.shouldNotify(
            UserInfo.getUserId(), 'Email', 'Stage_Change'
        );
        Test.stopTest();
        System.assertEquals(true, result, 'Should default to send when no preference exists');
    }

    @IsTest
    static void shouldNotify_returnsTrue_whenPreferenceEnabled() {
        Id userId = UserInfo.getUserId();
        insert new NotificationPreference__c(
            UserIdTxt__c = String.valueOf(userId).left(18),
            ChannelPk__c = 'Email',
            EventTypePk__c = 'Stage_Change',
            EnabledDateTime__c = Datetime.now()
        );

        Test.startTest();
        Boolean result = DeliveryNotificationPreferenceService.shouldNotify(userId, 'Email', 'Stage_Change');
        Test.stopTest();
        System.assertEquals(true, result, 'Should return true when preference is enabled');
    }

    @IsTest
    static void shouldNotify_returnsFalse_whenPreferenceDisabled() {
        Id userId = UserInfo.getUserId();
        insert new NotificationPreference__c(
            UserIdTxt__c = String.valueOf(userId).left(18),
            ChannelPk__c = 'Slack',
            EventTypePk__c = 'Escalation',
            EnabledDateTime__c = null
        );

        Test.startTest();
        Boolean result = DeliveryNotificationPreferenceService.shouldNotify(userId, 'Slack', 'Escalation');
        Test.stopTest();
        System.assertEquals(false, result, 'Should return false when preference is disabled (null EnabledDateTime)');
    }

    @IsTest
    static void shouldNotify_returnsTrue_whenNullInputs() {
        Test.startTest();
        Boolean nullUser = DeliveryNotificationPreferenceService.shouldNotify(null, 'Email', 'Stage_Change');
        Boolean nullChannel = DeliveryNotificationPreferenceService.shouldNotify(UserInfo.getUserId(), null, 'Stage_Change');
        Boolean nullEvent = DeliveryNotificationPreferenceService.shouldNotify(UserInfo.getUserId(), 'Email', null);
        Test.stopTest();
        System.assertEquals(true, nullUser, 'Null userId should default to send');
        System.assertEquals(true, nullChannel, 'Null channel should default to send');
        System.assertEquals(true, nullEvent, 'Null eventType should default to send');
    }

    @IsTest
    static void getPreferences_returnsRecords() {
        Id userId = UserInfo.getUserId();
        String userIdStr = String.valueOf(userId).left(18);
        insert new List<NotificationPreference__c>{
            new NotificationPreference__c(
                UserIdTxt__c = userIdStr,
                ChannelPk__c = 'Email',
                EventTypePk__c = 'Stage_Change',
                EnabledDateTime__c = Datetime.now(),
                DigestFrequencyPk__c = 'Immediate'
            ),
            new NotificationPreference__c(
                UserIdTxt__c = userIdStr,
                ChannelPk__c = 'Slack',
                EventTypePk__c = 'Comment',
                EnabledDateTime__c = Datetime.now(),
                DigestFrequencyPk__c = 'Daily'
            )
        };

        Test.startTest();
        List<NotificationPreference__c> prefs = DeliveryNotificationPreferenceService.getPreferences(userId);
        Test.stopTest();
        System.assertEquals(2, prefs.size(), 'Should return 2 preference records');
    }

    @IsTest
    static void upsertPreference_createsNew() {
        Id userId = UserInfo.getUserId();

        Test.startTest();
        DeliveryNotificationPreferenceService.upsertPreference(
            userId, 'Bell', 'Assignment', true, 'Immediate'
        );
        Test.stopTest();

        List<NotificationPreference__c> prefs = [
            SELECT EnabledDateTime__c, DigestFrequencyPk__c
            FROM NotificationPreference__c
            WHERE UserIdTxt__c = :String.valueOf(userId).left(18)
            AND ChannelPk__c = 'Bell'
            AND EventTypePk__c = 'Assignment'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(1, prefs.size(), 'Should create one preference record');
        System.assertNotEquals(null, prefs[0].EnabledDateTime__c, 'EnabledDateTime should be non-null');
        System.assertEquals('Immediate', prefs[0].DigestFrequencyPk__c);
    }

    @IsTest
    static void upsertPreference_updatesExisting() {
        Id userId = UserInfo.getUserId();
        String userIdStr = String.valueOf(userId).left(18);
        insert new NotificationPreference__c(
            UserIdTxt__c = userIdStr,
            ChannelPk__c = 'Chatter',
            EventTypePk__c = 'Document_Action',
            EnabledDateTime__c = Datetime.now(),
            DigestFrequencyPk__c = 'Immediate'
        );

        Test.startTest();
        // Disable the preference
        DeliveryNotificationPreferenceService.upsertPreference(
            userId, 'Chatter', 'Document_Action', false, 'Weekly'
        );
        Test.stopTest();

        List<NotificationPreference__c> prefs = [
            SELECT EnabledDateTime__c, DigestFrequencyPk__c
            FROM NotificationPreference__c
            WHERE UserIdTxt__c = :userIdStr
            AND ChannelPk__c = 'Chatter'
            AND EventTypePk__c = 'Document_Action'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(1, prefs.size(), 'Should still be one record (upserted)');
        System.assertEquals(null, prefs[0].EnabledDateTime__c, 'EnabledDateTime should be null after disabling');
        System.assertEquals('Weekly', prefs[0].DigestFrequencyPk__c);
    }
}
