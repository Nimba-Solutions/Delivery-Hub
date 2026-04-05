/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service for managing per-user notification preferences.
 *               Checks whether a user should receive a notification on a given channel
 *               for a given event type. Falls back to enabled (send) when no preference exists.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryNotificationPreferenceService {

    /**
     * @description Checks if a user should receive notifications for the given channel/event.
     *              Returns true (send) when no preference record exists (opt-out model).
     * @param userId The Salesforce User Id to check
     * @param channel The notification channel (e.g., Email, Slack)
     * @param eventType The event type (e.g., Stage_Change, Escalation)
     * @return true if the user should receive the notification
     */
    public static Boolean shouldNotify(Id userId, String channel, String eventType) {
        if (userId == null || String.isBlank(channel) || String.isBlank(eventType)) {
            return true; // default: send
        }
        List<NotificationPreference__c> prefs = [
            SELECT EnabledDateTime__c
            FROM NotificationPreference__c
            WHERE UserIdTxt__c = :String.valueOf(userId).left(18)
            AND ChannelPk__c = :channel
            AND EventTypePk__c = :eventType
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (prefs.isEmpty()) {
            return true; // no preference = send by default
        }
        return prefs[0].EnabledDateTime__c != null;
    }

    /**
     * @description Returns all notification preferences for a user.
     * @param userId The Salesforce User Id
     * @return List of NotificationPreference__c records
     */
    public static List<NotificationPreference__c> getPreferences(Id userId) {
        return [
            SELECT ChannelPk__c, EventTypePk__c, EnabledDateTime__c, DigestFrequencyPk__c
            FROM NotificationPreference__c
            WHERE UserIdTxt__c = :String.valueOf(userId).left(18)
            WITH SYSTEM_MODE
            ORDER BY ChannelPk__c, EventTypePk__c
        ];
    }

    /**
     * @description Creates or updates a notification preference for a user.
     * @param userId The Salesforce User Id
     * @param channel The notification channel
     * @param eventType The event type
     * @param enabled Whether the preference is enabled
     * @param digestFrequency The digest frequency (Immediate, Daily, Weekly)
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static void upsertPreference(Id userId, String channel, String eventType, Boolean enabled, String digestFrequency) {
        String userIdStr = String.valueOf(userId).left(18);
        List<NotificationPreference__c> existing = [
            SELECT Id, EnabledDateTime__c
            FROM NotificationPreference__c
            WHERE UserIdTxt__c = :userIdStr
            AND ChannelPk__c = :channel
            AND EventTypePk__c = :eventType
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        NotificationPreference__c pref;
        if (!existing.isEmpty()) {
            pref = existing[0];
        } else {
            pref = new NotificationPreference__c(
                UserIdTxt__c = userIdStr,
                ChannelPk__c = channel,
                EventTypePk__c = eventType
            );
        }
        pref.EnabledDateTime__c = enabled ? (pref.EnabledDateTime__c != null ? pref.EnabledDateTime__c : Datetime.now()) : null;
        pref.DigestFrequencyPk__c = digestFrequency;
        Database.upsert(pref, AccessLevel.SYSTEM_MODE);
    }
}
