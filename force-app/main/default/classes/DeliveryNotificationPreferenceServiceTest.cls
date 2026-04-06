/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryNotificationPreferenceService.
 *               Covers shouldNotify default opt-in, opt-out behavior,
 *               upsertPreference create/update, and getPreferences.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryNotificationPreferenceServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testDefaultOptIn() {
        System.runAs(testUser) {
            // No preference record exists — should default to send (true)
            Test.startTest();
            Boolean result = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Stage_Change'
            );
            Test.stopTest();

            System.assertEquals(true, result, 'Should return true (opt-in) when no preference exists');
        }
    }

    @IsTest
    static void testOptOut() {
        System.runAs(testUser) {
            // Create a preference with EnabledDateTime = null (opted out)
            insert new NotificationPreference__c(
                UserIdTxt__c = String.valueOf(testUser.Id).left(18),
                ChannelPk__c = 'Email',
                EventTypePk__c = 'Escalation',
                EnabledDateTime__c = null
            );

            Test.startTest();
            Boolean result = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Escalation'
            );
            Test.stopTest();

            System.assertEquals(false, result, 'Should return false when preference has null EnabledDateTime');
        }
    }

    @IsTest
    static void testOptedIn() {
        System.runAs(testUser) {
            // Create a preference with EnabledDateTime set (opted in)
            insert new NotificationPreference__c(
                UserIdTxt__c = String.valueOf(testUser.Id).left(18),
                ChannelPk__c = 'Slack',
                EventTypePk__c = 'Comment',
                EnabledDateTime__c = Datetime.now()
            );

            Test.startTest();
            Boolean result = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Slack', 'Comment'
            );
            Test.stopTest();

            System.assertEquals(true, result, 'Should return true when preference has EnabledDateTime set');
        }
    }

    @IsTest
    static void testNullInputsReturnTrue() {
        System.runAs(testUser) {
            Test.startTest();
            System.assertEquals(true,
                DeliveryNotificationPreferenceService.shouldNotify(null, 'Email', 'Stage_Change'),
                'Null userId should return true');
            System.assertEquals(true,
                DeliveryNotificationPreferenceService.shouldNotify(testUser.Id, '', 'Stage_Change'),
                'Blank channel should return true');
            System.assertEquals(true,
                DeliveryNotificationPreferenceService.shouldNotify(testUser.Id, 'Email', null),
                'Null eventType should return true');
            Test.stopTest();
        }
    }

    @IsTest
    static void testUpsertPreferenceCreate() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Stage_Change', true, 'Immediate'
            );
            Test.stopTest();

            List<NotificationPreference__c> prefs = [
                SELECT ChannelPk__c, EventTypePk__c, EnabledDateTime__c, DigestFrequencyPk__c
                FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
                AND ChannelPk__c = 'Email'
                AND EventTypePk__c = 'Stage_Change'
            ];
            System.assertEquals(1, prefs.size(), 'Should create one preference record');
            System.assertNotEquals(null, prefs[0].EnabledDateTime__c, 'Enabled should have a DateTime');
            System.assertEquals('Immediate', prefs[0].DigestFrequencyPk__c, 'Digest frequency should match');
        }
    }

    @IsTest
    static void testUpsertPreferenceUpdate() {
        System.runAs(testUser) {
            // Create initial preference
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Escalation', true, 'Immediate'
            );

            // Now update to disable
            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Escalation', false, 'Daily'
            );
            Test.stopTest();

            List<NotificationPreference__c> prefs = [
                SELECT EnabledDateTime__c, DigestFrequencyPk__c
                FROM NotificationPreference__c
                WHERE UserIdTxt__c = :String.valueOf(testUser.Id).left(18)
                AND ChannelPk__c = 'Slack'
                AND EventTypePk__c = 'Escalation'
            ];
            System.assertEquals(1, prefs.size(), 'Should still have only one preference (upsert)');
            System.assertEquals(null, prefs[0].EnabledDateTime__c, 'Enabled should be null after disabling');
            System.assertEquals('Daily', prefs[0].DigestFrequencyPk__c, 'Digest frequency should be updated');
        }
    }

    @IsTest
    static void testGetPreferences() {
        System.runAs(testUser) {
            // Insert two preferences for the user
            insert new List<NotificationPreference__c>{
                new NotificationPreference__c(
                    UserIdTxt__c = String.valueOf(testUser.Id).left(18),
                    ChannelPk__c = 'Email',
                    EventTypePk__c = 'Stage_Change',
                    EnabledDateTime__c = Datetime.now()
                ),
                new NotificationPreference__c(
                    UserIdTxt__c = String.valueOf(testUser.Id).left(18),
                    ChannelPk__c = 'Slack',
                    EventTypePk__c = 'Escalation',
                    EnabledDateTime__c = null
                )
            };

            Test.startTest();
            List<NotificationPreference__c> prefs =
                DeliveryNotificationPreferenceService.getPreferences(testUser.Id);
            Test.stopTest();

            System.assertEquals(2, prefs.size(), 'Should return 2 preferences');
        }
    }

    @IsTest
    static void testGetPreferencesEmpty() {
        System.runAs(testUser) {
            Test.startTest();
            List<NotificationPreference__c> prefs =
                DeliveryNotificationPreferenceService.getPreferences(testUser.Id);
            Test.stopTest();

            System.assertEquals(0, prefs.size(), 'Should return empty list when no preferences exist');
        }
    }
}
