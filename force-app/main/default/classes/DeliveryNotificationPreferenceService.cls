/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service for managing per-user notification preferences. Backed
 *               by DeliveryHubSettings__c.NotificationPreferencesJsonTxt__c
 *               (Hierarchy custom setting, per-user via SetupOwnerId).
 *               Replaces the prior NotificationPreference__c custom object —
 *               same data, same opt-out semantics (default = send), no slot
 *               cost against the namespaced custom-object cap.
 *
 *               JSON shape:
 *               { "Email": { "Stage_Change": { "enabled": true,
 *                 "digestFrequency": "Immediate" }, ... }, "Slack": { ... } }
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryNotificationPreferenceService {

    /**
     * @description One preference row — used as the public return shape so
     *              callers don't have to know the underlying JSON structure.
     */
    public class PreferenceRow {
        @AuraEnabled public String channel;
        @AuraEnabled public String eventType;
        @AuraEnabled public Boolean enabled;
        @AuraEnabled public String digestFrequency;
    }

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
        Map<String, Object> channelMap = readChannel(userId, channel);
        if (channelMap == null) {
            return true; // no preference at all → send
        }
        Object eventNode = channelMap.get(eventType);
        if (!(eventNode instanceof Map<String, Object>)) {
            return true; // no row for this event → send
        }
        Object enabled = ((Map<String, Object>) eventNode).get('enabled');
        return enabled == null || enabled == true;
    }

    /**
     * @description Returns all notification preferences for a user.
     * @param userId The Salesforce User Id
     * @return List of PreferenceRow ordered by channel+eventType.
     */
    public static List<PreferenceRow> getPreferences(Id userId) {
        List<PreferenceRow> rows = new List<PreferenceRow>();
        if (userId == null) {
            return rows;
        }
        Map<String, Object> all = readAllForUser(userId);
        for (String channel : new List<String>(all.keySet())) {
            Object channelNode = all.get(channel);
            if (!(channelNode instanceof Map<String, Object>)) { continue; }
            Map<String, Object> eventMap = (Map<String, Object>) channelNode;
            for (String eventType : new List<String>(eventMap.keySet())) {
                Object eventNode = eventMap.get(eventType);
                if (!(eventNode instanceof Map<String, Object>)) { continue; }
                Map<String, Object> ev = (Map<String, Object>) eventNode;
                PreferenceRow r = new PreferenceRow();
                r.channel = channel;
                r.eventType = eventType;
                Object enabled = ev.get('enabled');
                r.enabled = enabled == null ? true : (Boolean) enabled;
                r.digestFrequency = ev.containsKey('digestFrequency')
                    ? (String) ev.get('digestFrequency')
                    : null;
                rows.add(r);
            }
        }
        return rows;
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
    public static void upsertPreference(Id userId, String channel, String eventType,
        Boolean enabled, String digestFrequency) {
        if (userId == null || String.isBlank(channel) || String.isBlank(eventType)) {
            return;
        }
        Map<String, Object> all = readAllForUser(userId);
        Object channelNode = all.get(channel);
        Map<String, Object> eventMap = channelNode instanceof Map<String, Object>
            ? (Map<String, Object>) channelNode
            : new Map<String, Object>();
        Map<String, Object> eventEntry = new Map<String, Object>{
            'enabled' => enabled == true,
            'digestFrequency' => digestFrequency
        };
        eventMap.put(eventType, eventEntry);
        all.put(channel, eventMap);
        writeAllForUser(userId, all);
    }

    @TestVisible
    private static Map<String, Object> readAllForUser(Id userId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance(userId);
        if (settings == null || String.isBlank(settings.NotificationPreferencesJsonTxt__c)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(settings.NotificationPreferencesJsonTxt__c);
            return parsed instanceof Map<String, Object>
                ? (Map<String, Object>) parsed
                : new Map<String, Object>();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationPreferenceService] Bad NotificationPreferencesJsonTxt__c: '
                + e.getMessage());
            return new Map<String, Object>();
        }
    }

    private static Map<String, Object> readChannel(Id userId, String channel) {
        Map<String, Object> all = readAllForUser(userId);
        Object node = all.get(channel);
        return node instanceof Map<String, Object> ? (Map<String, Object>) node : null;
    }

    @TestVisible
    private static void writeAllForUser(Id userId, Map<String, Object> all) {
        List<DeliveryHubSettings__c> existing = [
            SELECT Id FROM DeliveryHubSettings__c
            WHERE SetupOwnerId = :userId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        DeliveryHubSettings__c row = existing.isEmpty()
            ? new DeliveryHubSettings__c(SetupOwnerId = userId)
            : existing[0];
        row.NotificationPreferencesJsonTxt__c = JSON.serialize(all);
        Database.upsert(row, AccessLevel.SYSTEM_MODE);
    }
}
