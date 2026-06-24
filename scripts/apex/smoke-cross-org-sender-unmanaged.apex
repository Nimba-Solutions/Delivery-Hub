// AUTO-VARIANT of smoke-cross-org-sender.apex with the delivery__ namespace stripped.
// Use this on NON-NAMESPACED dev scratch orgs (the managed-prefixed original fails to
// compile there: 'Invalid type: delivery__WorkRequest__c'). Keep both in sync.
//
// =============================================================================
// Cross-org sync smoke test — SENDER side
//
// Run on the sender org (e.g. MF-Prod). Inserts a tagged WorkItem + Comment +
// WorkLog under an existing routed WorkRequest, then prints the GlobalSourceIds
// for the receiver-side script to look up.
//
// Usage:
//   sf apex run --target-org MF-Prod --file scripts/apex/smoke-cross-org-sender.apex
//
// Pair with smoke-cross-org-receiver.apex on the receiver org.
//
// Tag: SMOKE_<UTC_TIMESTAMP> — unique per run, written into BriefDescriptionTxt__c
// + WorkItemComment.BodyTxt__c + WorkLog.WorkDescriptionTxt__c so all three can be
// found on the receiver side via simple LIKE queries.
//
// Cleanup: the script does NOT delete the records. Run scripts/apex/smoke-
// cross-org-cleanup.apex (uses the SMOKE_ prefix) to remove them once you're
// satisfied with the round-trip.
// =============================================================================

String tag = 'SMOKE_' + Datetime.now().formatGmt('yyyyMMdd_HHmmss');
System.debug('=== SMOKE TAG: ' + tag + ' ===');

// 1. Find an active routed WorkRequest so the WI fans out to the configured Vendor
// Mirror DeliverySyncEngine.captureChanges connection filter: any status
// except Inactive, vendor entity with endpoint, Active+Connected.
List<WorkRequest__c> reqs = [
    SELECT Id, WorkItemId__c, DeliveryEntityLookup__c
    FROM WorkRequest__c
    WHERE StatusPk__c != 'Inactive'
    AND DeliveryEntityLookup__c != NULL
    AND DeliveryEntityLookup__r.StatusPk__c = 'Active'
    AND DeliveryEntityLookup__r.ConnectionStatusPk__c = 'Connected'
    AND DeliveryEntityLookup__r.EntityTypePk__c IN ('Vendor', 'Both')
    AND DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c != NULL
    LIMIT 1
];
if (reqs.isEmpty()) {
    System.debug('FAIL | No active routed WorkRequest found. Sync fan-out cannot fire. Aborting.');
    return;
}
WorkRequest__c req = reqs[0];
System.debug('PASS | Found routed WorkRequest: ' + req.Id);

// 2. Insert a tagged WorkItem under that request's parent WI's network
WorkItem__c parentWi = [
    SELECT Id, ClientNetworkEntityLookup__c
    FROM WorkItem__c
    WHERE Id = :req.WorkItemId__c
    LIMIT 1
];
WorkItem__c smokeWi = new WorkItem__c(
    BriefDescriptionTxt__c = tag + ' — smoke test WorkItem',
    StageNamePk__c = 'Backlog',
    StatusPk__c = 'New',
    ClientNetworkEntityLookup__c = parentWi.ClientNetworkEntityLookup__c
);
insert smokeWi;
System.debug('PASS | Inserted WorkItem ' + smokeWi.Id + ' under network ' + parentWi.ClientNetworkEntityLookup__c);

// 3. Bridge it to the same vendor so it actually fans out
WorkRequest__c smokeReq = new WorkRequest__c(
    WorkItemId__c = smokeWi.Id,
    DeliveryEntityLookup__c = req.DeliveryEntityLookup__c,
    StatusPk__c = 'Active'
);
insert smokeReq;
System.debug('PASS | Inserted bridge WorkRequest ' + smokeReq.Id);

// 4. Insert a tagged Comment + WorkLog
WorkItemComment__c smokeComment = new WorkItemComment__c(
    WorkItemId__c = smokeWi.Id,
    BodyTxt__c = tag + ' — smoke test Comment',
    SourcePk__c = 'Client',
    AuthorTxt__c = 'Smoke Test'
);
insert smokeComment;
System.debug('PASS | Inserted Comment ' + smokeComment.Id);

WorkLog__c smokeLog = new WorkLog__c(
    WorkItemLookup__c = smokeWi.Id,
    RequestId__c = smokeReq.Id,
    HoursLoggedNumber__c = 0.25,
    WorkDateDate__c = Date.today(),
    WorkDescriptionTxt__c = tag + ' — smoke test WorkLog',
    StatusPk__c = 'Approved'
);
insert smokeLog;
System.debug('PASS | Inserted WorkLog ' + smokeLog.Id);

// 5. Report what to look for on receiver side
System.debug('=== SENDER COMPLETE ===');
System.debug('TAG: ' + tag);
System.debug('WorkItem GlobalSourceId: ' + smokeWi.Id);
System.debug('Comment GlobalSourceId : ' + smokeComment.Id);
System.debug('WorkLog GlobalSourceId : ' + smokeLog.Id);
System.debug('');
System.debug('On receiver org, run:');
System.debug('  sf apex run --target-org <receiver> --file scripts/apex/smoke-cross-org-receiver.apex');
System.debug('  (it will pick up the most recent SMOKE_ tag automatically)');
