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
List<delivery__WorkRequest__c> reqs = [
    SELECT Id, delivery__WorkItemId__c, delivery__DeliveryEntityLookup__c
    FROM delivery__WorkRequest__c
    WHERE delivery__StatusPk__c != 'Inactive'
    AND delivery__DeliveryEntityLookup__c != NULL
    AND delivery__DeliveryEntityLookup__r.delivery__StatusPk__c = 'Active'
    AND delivery__DeliveryEntityLookup__r.delivery__ConnectionStatusPk__c = 'Connected'
    AND delivery__DeliveryEntityLookup__r.delivery__EntityTypePk__c IN ('Vendor', 'Both')
    AND delivery__DeliveryEntityLookup__r.delivery__IntegrationEndpointUrlTxt__c != NULL
    LIMIT 1
];
if (reqs.isEmpty()) {
    System.debug('FAIL | No active routed WorkRequest found. Sync fan-out cannot fire. Aborting.');
    return;
}
delivery__WorkRequest__c req = reqs[0];
System.debug('PASS | Found routed WorkRequest: ' + req.Id);

// 2. Insert a tagged WorkItem under that request's parent WI's network
delivery__WorkItem__c parentWi = [
    SELECT Id, delivery__ClientNetworkEntityLookup__c
    FROM delivery__WorkItem__c
    WHERE Id = :req.delivery__WorkItemId__c
    LIMIT 1
];
delivery__WorkItem__c smokeWi = new delivery__WorkItem__c(
    delivery__BriefDescriptionTxt__c = tag + ' — smoke test WorkItem',
    delivery__StageNamePk__c = 'Backlog',
    delivery__StatusPk__c = 'New',
    delivery__ClientNetworkEntityLookup__c = parentWi.delivery__ClientNetworkEntityLookup__c
);
insert smokeWi;
System.debug('PASS | Inserted WorkItem ' + smokeWi.Id + ' under network ' + parentWi.delivery__ClientNetworkEntityLookup__c);

// 3. Bridge it to the same vendor so it actually fans out
delivery__WorkRequest__c smokeReq = new delivery__WorkRequest__c(
    delivery__WorkItemId__c = smokeWi.Id,
    delivery__DeliveryEntityLookup__c = req.delivery__DeliveryEntityLookup__c,
    delivery__StatusPk__c = 'Active'
);
insert smokeReq;
System.debug('PASS | Inserted bridge WorkRequest ' + smokeReq.Id);

// 4. Insert a tagged Comment + WorkLog
delivery__WorkItemComment__c smokeComment = new delivery__WorkItemComment__c(
    delivery__WorkItemId__c = smokeWi.Id,
    delivery__BodyTxt__c = tag + ' — smoke test Comment',
    delivery__SourcePk__c = 'Client',
    delivery__AuthorTxt__c = 'Smoke Test'
);
insert smokeComment;
System.debug('PASS | Inserted Comment ' + smokeComment.Id);

delivery__WorkLog__c smokeLog = new delivery__WorkLog__c(
    delivery__WorkItemLookup__c = smokeWi.Id,
    delivery__RequestId__c = smokeReq.Id,
    delivery__HoursLoggedNumber__c = 0.25,
    delivery__WorkDateDate__c = Date.today(),
    delivery__WorkDescriptionTxt__c = tag + ' — smoke test WorkLog',
    delivery__StatusPk__c = 'Approved'
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
