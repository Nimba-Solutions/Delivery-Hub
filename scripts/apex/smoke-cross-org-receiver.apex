// =============================================================================
// Cross-org sync smoke test — RECEIVER side
//
// Run on the receiver org (e.g. Nimba, dh-prod, MF-Prod) AFTER sending from the
// sender side. Looks for the most recent SMOKE_ tag and asserts each record
// landed locally with full data + has an Inbound SyncItem ledger entry.
//
// Usage:
//   sf apex run --target-org <receiver> --file scripts/apex/smoke-cross-org-receiver.apex
//
// PASS criteria per leg:
//   - Local record exists on this org (sender's Outbound dispatched + ingestor accepted)
//   - The actual field value (description / body / hours) propagated, not just the row
//   - An Inbound SyncItem with StatusPk__c='Synced' exists for the local record's Id
//
// FAIL signals:
//   - Local record missing → outbound never dispatched OR ingestor rejected pre-insert
//     (check sender for a Failed Outbound SyncItem with the smoke tag in PayloadTxt__c)
//   - Local record exists but field is empty → namespace-stripping bug in outbound
//     payload builder (PR #742 class) OR receiver mapFields path
//   - No Inbound SyncItem → record was created by a non-sync path (manual, local trigger)
//
// Routing note:
//   WorkItem fans out BOTH ways (Hub via parent's ClientNetworkEntity AND Push via
//   the bridge WorkRequest), so it lands on multiple receivers. WorkLog and Comment
//   typically only Hub-route to the parent WI's ClientNetworkEntity. If you point
//   the receiver script at the wrong org for the leg, you'll see a real PASS
//   somewhere else and a missing-record FAIL here. That's not the test failing —
//   it's the test telling you about the route.
// =============================================================================

// 1. Find the most recent SMOKE_ tag on this org via the WorkItem
List<delivery__WorkItem__c> smokeWis = [
    SELECT Id, delivery__BriefDescriptionTxt__c, CreatedDate
    FROM delivery__WorkItem__c
    WHERE delivery__BriefDescriptionTxt__c LIKE 'SMOKE_%'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
if (smokeWis.isEmpty()) {
    System.debug('FAIL | No SMOKE_ WorkItem on this org. Sender may not have routed here, or sync still in flight.');
    System.debug('       Wait 30 sec after sender ran, then re-run this script.');
    return;
}
delivery__WorkItem__c wi = smokeWis[0];
String tag = wi.delivery__BriefDescriptionTxt__c.substringBefore(' ').trim();
System.debug('=== Found SMOKE tag on receiver: ' + tag + ' ===');
System.debug('     Receiver WorkItem.Id      = ' + wi.Id);
System.debug('     Receiver WorkItem.Created = ' + wi.CreatedDate);

// 2. WorkItem assertions — local record + Inbound SyncItem
String wiIdString = (String) wi.Id;
delivery__SyncItem__c wiSync = null;
for (delivery__SyncItem__c si : [
    SELECT Id, delivery__StatusPk__c, delivery__GlobalSourceIdTxt__c, CreatedDate
    FROM delivery__SyncItem__c
    WHERE delivery__DirectionPk__c = 'Inbound'
    AND delivery__ObjectTypePk__c = 'WorkItem__c'
    AND delivery__LocalRecordIdTxt__c = :wiIdString
    ORDER BY CreatedDate DESC
    LIMIT 1
]) {
    wiSync = si;
}
Boolean wiHasField = wi.delivery__BriefDescriptionTxt__c != null
    && wi.delivery__BriefDescriptionTxt__c.contains(tag);
if (wiSync == null) {
    System.debug('FAIL | WorkItem | local record exists but no Inbound SyncItem (created locally?)');
} else if (wiSync.delivery__StatusPk__c != 'Synced') {
    System.debug('FAIL | WorkItem | Inbound status=' + wiSync.delivery__StatusPk__c
        + ' | senderId=' + wiSync.delivery__GlobalSourceIdTxt__c);
} else if (!wiHasField) {
    System.debug('FAIL | WorkItem | Inbound Synced but BriefDescriptionTxt__c did not propagate. ' +
        'Likely outbound-payload bug class (PR #742). senderId=' + wiSync.delivery__GlobalSourceIdTxt__c);
} else {
    System.debug('PASS | WorkItem | Inbound Synced + description carries tag | senderId=' +
        wiSync.delivery__GlobalSourceIdTxt__c + ' | inboundCreated=' + wiSync.CreatedDate);
}

// 3. Comment assertions — walk children of the smoke WI
List<delivery__WorkItemComment__c> comments = [
    SELECT Id, delivery__BodyTxt__c
    FROM delivery__WorkItemComment__c
    WHERE delivery__WorkItemId__c = :wi.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];
if (comments.isEmpty()) {
    System.debug('SKIP | Comment | No matching record on this org. ' +
        'May have routed to a different receiver (Hub-routed via parent network).');
} else {
    String commentIdString = (String) comments[0].Id;
    delivery__SyncItem__c commentSync = null;
    for (delivery__SyncItem__c si : [
        SELECT Id, delivery__StatusPk__c
        FROM delivery__SyncItem__c
        WHERE delivery__DirectionPk__c = 'Inbound'
        AND delivery__ObjectTypePk__c = 'WorkItemComment__c'
        AND delivery__LocalRecordIdTxt__c = :commentIdString
        ORDER BY CreatedDate DESC
        LIMIT 1
    ]) {
        commentSync = si;
    }
    Boolean bodyHasTag = comments[0].delivery__BodyTxt__c != null
        && comments[0].delivery__BodyTxt__c.contains(tag);
    if (commentSync == null) {
        System.debug('FAIL | Comment | local record exists but no Inbound SyncItem');
    } else if (commentSync.delivery__StatusPk__c != 'Synced') {
        System.debug('FAIL | Comment | Inbound status=' + commentSync.delivery__StatusPk__c);
    } else if (!bodyHasTag) {
        System.debug('FAIL | Comment | Inbound Synced but BodyTxt__c did not propagate.');
    } else {
        System.debug('PASS | Comment | Inbound Synced + body carries tag');
    }
}

// 4. WorkLog assertions — walk children of the smoke WI
List<delivery__WorkLog__c> logs = [
    SELECT Id, delivery__WorkDescriptionTxt__c, delivery__HoursLoggedNumber__c
    FROM delivery__WorkLog__c
    WHERE delivery__WorkItemLookup__c = :wi.Id
    ORDER BY CreatedDate DESC
    LIMIT 1
];
if (logs.isEmpty()) {
    System.debug('SKIP | WorkLog | No matching record on this org. ' +
        'May have routed to a different receiver (Hub-routed via parent network).');
} else {
    String logIdString = (String) logs[0].Id;
    delivery__SyncItem__c logSync = null;
    for (delivery__SyncItem__c si : [
        SELECT Id, delivery__StatusPk__c
        FROM delivery__SyncItem__c
        WHERE delivery__DirectionPk__c = 'Inbound'
        AND delivery__ObjectTypePk__c = 'WorkLog__c'
        AND delivery__LocalRecordIdTxt__c = :logIdString
        ORDER BY CreatedDate DESC
        LIMIT 1
    ]) {
        logSync = si;
    }
    Boolean descHasTag = logs[0].delivery__WorkDescriptionTxt__c != null
        && logs[0].delivery__WorkDescriptionTxt__c.contains(tag);
    Boolean hoursPopulated = logs[0].delivery__HoursLoggedNumber__c != null
        && logs[0].delivery__HoursLoggedNumber__c > 0;
    if (logSync == null) {
        System.debug('FAIL | WorkLog | local record exists but no Inbound SyncItem');
    } else if (logSync.delivery__StatusPk__c != 'Synced') {
        System.debug('FAIL | WorkLog | Inbound status=' + logSync.delivery__StatusPk__c);
    } else if (!descHasTag || !hoursPopulated) {
        System.debug('FAIL | WorkLog | Inbound Synced but data did not propagate. ' +
            'descHasTag=' + descHasTag + ' hoursPopulated=' + hoursPopulated);
    } else {
        System.debug('PASS | WorkLog | Inbound Synced + description carries tag + hours populated');
    }
}

System.debug('=== RECEIVER COMPLETE for ' + tag + ' ===');
System.debug('Run smoke-cross-org-cleanup.apex on the SENDER org when satisfied.');
