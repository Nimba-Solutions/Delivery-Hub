// AUTO-VARIANT of smoke-cross-org-cleanup.apex with the delivery__ namespace stripped.
// Use this on NON-NAMESPACED dev scratch orgs (the managed-prefixed original fails to
// compile there: 'Invalid type: delivery__WorkRequest__c'). Keep both in sync.
//
// =============================================================================
// Cross-org sync smoke test — CLEANUP
//
// Run on the sender org to delete the most recent SMOKE_-tagged records
// (and their downstream sync ledger). Receiver-side rows tombstone via
// the cross-org sync DELETE flow.
//
// Usage:
//   sf apex run --target-org <sender> --file scripts/apex/smoke-cross-org-cleanup.apex
// =============================================================================

List<WorkItem__c> smokeWis = [
    SELECT Id, BriefDescriptionTxt__c
    FROM WorkItem__c
    WHERE BriefDescriptionTxt__c LIKE 'SMOKE_%'
];
if (smokeWis.isEmpty()) {
    System.debug('NOTE | No SMOKE_ WorkItems on this org. Nothing to clean up.');
    return;
}

System.debug('=== Found ' + smokeWis.size() + ' SMOKE_ WorkItem(s) to remove ===');
for (WorkItem__c wi : smokeWis) {
    System.debug('  - ' + wi.Id + ' | ' + wi.BriefDescriptionTxt__c);
}

// Children cascade-delete on master-detail; lookup child WorkRequests + Comments + WorkLogs need explicit cleanup
Set<Id> wiIds = new Map<Id, WorkItem__c>(smokeWis).keySet();
delete [SELECT Id FROM WorkLog__c WHERE WorkItemLookup__c IN :wiIds];
delete [SELECT Id FROM WorkItemComment__c WHERE WorkItemId__c IN :wiIds];
delete [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c IN :wiIds];
delete smokeWis;

System.debug('=== CLEANUP COMPLETE ===');
