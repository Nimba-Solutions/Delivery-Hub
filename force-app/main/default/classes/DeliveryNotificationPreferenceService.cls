/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service for managing per-user notification preferences.
 *               Checks whether a user should receive a notification on a given channel
 *               for a given event type. Falls back to enabled (send) when no preference exists.
 * @author Cloud Nimbus LLC
 */
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
     * @description Bulk variant of shouldNotify — fetches preferences for all
     *              (userId, channel) tuples for a single eventType in ONE SOQL.
     *              Callers that dispatch over many recipients × channels should
     *              prefer this to avoid per-call SOQL fan-out (the forecast-alert
     *              sweep was hitting the 100-SOQL governor at ~8 candidate WIs
     *              before this helper existed).
     * @param userIds   Set of User Ids to evaluate.
     * @param channels  Set of channel keys (e.g. {'Bell','Email'}).
     * @param eventType Event type (e.g. 'Forecast_Risk').
     * @return Map keyed by 'userId|channel' → true (notify) / false (suppressed).
     *         Missing keys default to true (opt-out model), matching shouldNotify.
     */
    public static Map<String, Boolean> shouldNotifyBulk(Set<Id> userIds, Set<String> channels, String eventType) {
        Map<String, Boolean> out = new Map<String, Boolean>();
        if (userIds == null || userIds.isEmpty() || channels == null || channels.isEmpty()
                || String.isBlank(eventType)) {
            return out;
        }
        Set<String> userIdStrs = new Set<String>();
        for (Id u : userIds) {
            if (u != null) {
                userIdStrs.add(String.valueOf(u).left(18));
            }
        }
        if (userIdStrs.isEmpty()) {
            return out;
        }
        for (NotificationPreference__c pref : [
            SELECT UserIdTxt__c, ChannelPk__c, EnabledDateTime__c
            FROM NotificationPreference__c
            WHERE UserIdTxt__c IN :userIdStrs
              AND ChannelPk__c IN :channels
              AND EventTypePk__c = :eventType
            WITH SYSTEM_MODE
        ]) {
            String key = pref.UserIdTxt__c + '|' + pref.ChannelPk__c;
            out.put(key, pref.EnabledDateTime__c != null);
        }
        return out;
    }

    /**
     * @description Companion lookup for bulk results. Returns true when the user
     *              should be notified (no row in the map = opt-in by default).
     */
    public static Boolean shouldNotifyFromMap(Map<String, Boolean> bulkMap, Id userId, String channel) {
        if (bulkMap == null || userId == null || String.isBlank(channel)) {
            return true;
        }
        String key = String.valueOf(userId).left(18) + '|' + channel;
        if (!bulkMap.containsKey(key)) {
            return true;
        }
        return bulkMap.get(key);
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
