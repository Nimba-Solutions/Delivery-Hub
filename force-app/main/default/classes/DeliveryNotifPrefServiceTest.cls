/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryNotificationPreferenceService. Covers
 *               shouldNotify's opt-out default model, getPreferences,
 *               upsertPreference insert+update paths, and null-guard
 *               branches against the JSON-backed storage on
 *               DeliveryHubSettings__c.NotificationPreferencesJsonTxt__c.
 *               Every notification path in DH (email, slack, bell) funnels
 *               through shouldNotify so the opt-out default is critical.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
@IsTest
private class DeliveryNotifPrefServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

    @IsTest
    static void testShouldNotifyDefaultsToSendWhenNoPreference() {
        System.runAs(testUser) {
            Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Stage_Change');
            System.assertEquals(true, send,
                'Opt-out model: no preference recorded → send by default');
        }
    }

    @IsTest
    static void testShouldNotifyHandlesNullArgs() {
        System.assertEquals(true,
            DeliveryNotificationPreferenceService.shouldNotify(null, 'Email', 'X'));
        System.assertEquals(true,
            DeliveryNotificationPreferenceService.shouldNotify(testUser.Id, null, 'X'));
        System.assertEquals(true,
            DeliveryNotificationPreferenceService.shouldNotify(testUser.Id, 'Email', null));
    }

    @IsTest
    static void testUpsertPreferenceInsertsAndShouldNotifyHonours() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Stage_Change', false, 'Daily');
            Test.stopTest();
            Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Email', 'Stage_Change');
            System.assertEquals(false, send,
                'After opt-out, shouldNotify should return false for that channel/event');
        }
    }

    @IsTest
    static void testUpsertPreferenceUpdatesExisting() {
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Escalation', false, 'Immediate');
            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Escalation', true, 'Daily');
            Test.stopTest();
            Boolean send = DeliveryNotificationPreferenceService.shouldNotify(
                testUser.Id, 'Slack', 'Escalation');
            System.assertEquals(true, send,
                'Re-enabling should flip shouldNotify back to true');
        }
    }

    @IsTest
    static void testGetPreferencesReturnsAll() {
        System.runAs(testUser) {
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', 'Stage_Change', false, 'Daily');
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Slack', 'Escalation', true, 'Immediate');

            Test.startTest();
            List<DeliveryNotificationPreferenceService.PreferenceRow> rows =
                DeliveryNotificationPreferenceService.getPreferences(testUser.Id);
            Test.stopTest();

            System.assertEquals(2, rows.size(),
                'Both saved preferences should come back from getPreferences');
        }
    }

    @IsTest
    static void testGetPreferencesNullUser() {
        Test.startTest();
        List<DeliveryNotificationPreferenceService.PreferenceRow> rows =
            DeliveryNotificationPreferenceService.getPreferences(null);
        Test.stopTest();
        System.assertEquals(0, rows.size(),
            'Null userId should return empty list, not throw');
    }

    @IsTest
    static void testUpsertPreferenceNullArgsAreNoOps() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryNotificationPreferenceService.upsertPreference(
                null, 'Email', 'X', true, null);
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, null, 'X', true, null);
            DeliveryNotificationPreferenceService.upsertPreference(
                testUser.Id, 'Email', null, true, null);
            Test.stopTest();
            // Just asserting no throws.
            System.assert(true, 'Null-arg upsertPreference calls should be silent no-ops');
        }
    }
}
