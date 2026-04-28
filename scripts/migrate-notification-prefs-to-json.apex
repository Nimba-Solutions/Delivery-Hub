// ============================================================================
// MIGRATION: NotificationPreference__c rows → DeliveryHubSettings__c JSON map
// ============================================================================
// Run this BEFORE upgrading to the cap-recovery PR B package version.
// After upgrade the NotificationPreference__c custom object is destructively
// removed and any un-migrated rows are lost.
//
// Resulting JSON shape:
//   { "Email": { "Stage_Change": { "enabled": true, "digestFrequency": "Daily" }, ... } }
// ============================================================================

List<NotificationPreference__c> source = [
    SELECT UserIdTxt__c, ChannelPk__c, EventTypePk__c,
           EnabledDateTime__c, DigestFrequencyPk__c
    FROM NotificationPreference__c
];

System.debug('Found ' + source.size() + ' NotificationPreference__c rows to migrate.');

Map<Id, Map<String, Object>> mapByUser = new Map<Id, Map<String, Object>>();
for (NotificationPreference__c pref : source) {
    if (String.isBlank(pref.UserIdTxt__c)
        || String.isBlank(pref.ChannelPk__c)
        || String.isBlank(pref.EventTypePk__c)) {
        continue;
    }
    Id userId;
    try {
        userId = Id.valueOf(pref.UserIdTxt__c);
    } catch (Exception e) {
        continue;
    }
    if (!mapByUser.containsKey(userId)) {
        mapByUser.put(userId, new Map<String, Object>());
    }
    Map<String, Object> all = mapByUser.get(userId);
    Map<String, Object> channelMap = all.containsKey(pref.ChannelPk__c)
        ? (Map<String, Object>) all.get(pref.ChannelPk__c)
        : new Map<String, Object>();
    channelMap.put(pref.EventTypePk__c, new Map<String, Object>{
        'enabled'         => pref.EnabledDateTime__c != null,
        'digestFrequency' => pref.DigestFrequencyPk__c
    });
    all.put(pref.ChannelPk__c, channelMap);
}

Set<Id> userIds = mapByUser.keySet();
Map<Id, DeliveryHubSettings__c> existingByUser = new Map<Id, DeliveryHubSettings__c>();
for (DeliveryHubSettings__c row : [
    SELECT Id, SetupOwnerId, NotificationPreferencesJsonTxt__c
    FROM DeliveryHubSettings__c
    WHERE SetupOwnerId IN :userIds
]) {
    existingByUser.put(row.SetupOwnerId, row);
}

List<DeliveryHubSettings__c> toUpsert = new List<DeliveryHubSettings__c>();
for (Id userId : mapByUser.keySet()) {
    DeliveryHubSettings__c row = existingByUser.containsKey(userId)
        ? existingByUser.get(userId)
        : new DeliveryHubSettings__c(SetupOwnerId = userId);
    row.NotificationPreferencesJsonTxt__c = JSON.serialize(mapByUser.get(userId));
    toUpsert.add(row);
}

if (!toUpsert.isEmpty()) {
    upsert toUpsert;
    System.debug('Upserted ' + toUpsert.size() + ' DeliveryHubSettings__c rows with notification prefs.');
} else {
    System.debug('Nothing to migrate.');
}

System.debug('---');
System.debug('Migration complete. Verify with:');
System.debug('  SELECT SetupOwnerId, NotificationPreferencesJsonTxt__c FROM DeliveryHubSettings__c WHERE NotificationPreferencesJsonTxt__c != null');
System.debug('Then it is safe to install the package upgrade that destroys NotificationPreference__c.');
