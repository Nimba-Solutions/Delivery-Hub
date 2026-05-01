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

List<delivery__WorkItem__c> smokeWis = [
    SELECT Id, delivery__BriefDescriptionTxt__c
    FROM delivery__WorkItem__c
    WHERE delivery__BriefDescriptionTxt__c LIKE 'SMOKE_%'
];
if (smokeWis.isEmpty()) {
    System.debug('NOTE | No SMOKE_ WorkItems on this org. Nothing to clean up.');
    return;
}

System.debug('=== Found ' + smokeWis.size() + ' SMOKE_ WorkItem(s) to remove ===');
for (delivery__WorkItem__c wi : smokeWis) {
    System.debug('  - ' + wi.Id + ' | ' + wi.delivery__BriefDescriptionTxt__c);
}

// Children cascade-delete on master-detail; lookup child WorkRequests + Comments + WorkLogs need explicit cleanup
Set<Id> wiIds = new Map<Id, delivery__WorkItem__c>(smokeWis).keySet();
delete [SELECT Id FROM delivery__WorkLog__c WHERE delivery__WorkItemLookup__c IN :wiIds];
delete [SELECT Id FROM delivery__WorkItemComment__c WHERE delivery__WorkItemId__c IN :wiIds];
delete [SELECT Id FROM delivery__WorkRequest__c WHERE delivery__WorkItemId__c IN :wiIds];
delete smokeWis;

System.debug('=== CLEANUP COMPLETE ===');
