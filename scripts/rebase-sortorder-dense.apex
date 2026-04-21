// Rebase SortOrderNumber__c on every active WorkItem__c to contiguous 1..N
// within each priority bucket (top-priority / active / follow-on / proposed /
// deferred). One-time cleanup after installing the NG 0.185.35 + DH bundle
// that ships the dense-renumber path; going forward every drag re-densifies
// its bucket on its own. Safe to re-run anytime.
//
// Run with:
//   sf apex run -f scripts/rebase-sortorder-dense.apex --target-org <alias>
//
// Uses delivery__ namespace prefix since subscriber orgs are managed installs.

delivery.DeliverySyncEngine.setSyncContext(); // suppress outbound sync echo

List<delivery__WorkItem__c> actives = [
    SELECT Id, delivery__PriorityPk__c, delivery__StageNamePk__c,
           delivery__PriorityGroupPk__c, delivery__SortOrderNumber__c, Name
    FROM delivery__WorkItem__c
    WHERE delivery__IsActiveBool__c = true
    WITH SYSTEM_MODE
];

// Bucket derivation — mirrors DeliveryGanttController.derivePriorityGroup,
// inlined because the controller method is package-private.
Set<String> activeStages = new Set<String>{
    'Clarification','Ready for Development','In Development','Ready for Tech Review',
    'Tech Review In Progress','Pending Deploy','Ready for UAT','Ready for UAT Sign-off',
    'QA In Progress'
};
Set<String> proposedStages = new Set<String>{
    'Backlog','Scoping In Progress','Clarification Requested (Pre-Dev)',
    'Ready for Sizing'
};
Set<String> terminalStages = new Set<String>{
    'Done','Deployed to Prod','Cancelled','Closed','Rejected'
};
Set<String> pausedStages = new Set<String>{
    'Paused','On Hold','Blocked','Awaiting Client'
};

Map<String, List<delivery__WorkItem__c>> byBucket = new Map<String, List<delivery__WorkItem__c>>();
for (delivery__WorkItem__c w : actives) {
    String bucket;
    if (String.isNotBlank(w.delivery__PriorityGroupPk__c)) {
        bucket = w.delivery__PriorityGroupPk__c;
    } else {
        String stage = w.delivery__StageNamePk__c;
        String prio = w.delivery__PriorityPk__c;
        String lower = stage == null ? '' : stage.toLowerCase();
        if (String.isBlank(stage)) {
            bucket = 'follow-on';
        } else if (pausedStages.contains(stage) || lower.contains('hold') || lower.contains('blocked') || lower.contains('paused')) {
            bucket = 'deferred';
        } else if (terminalStages.contains(stage)) {
            bucket = 'follow-on';
        } else if (activeStages.contains(stage)) {
            bucket = (prio == 'High' || prio == 'Critical') ? 'top-priority' : 'active';
        } else if (proposedStages.contains(stage)) {
            bucket = 'proposed';
        } else {
            bucket = 'follow-on';
        }
    }
    if (!byBucket.containsKey(bucket)) {
        byBucket.put(bucket, new List<delivery__WorkItem__c>());
    }
    byBucket.get(bucket).add(w);
}

List<delivery__WorkItem__c> toUpdate = new List<delivery__WorkItem__c>();
for (String bucket : byBucket.keySet()) {
    List<delivery__WorkItem__c> items = byBucket.get(bucket);
    // Stable sort by current sortOrder (nulls last), then Name for ties
    items.sort(new SortOrderThenNameComparator());
    System.debug(LoggingLevel.INFO, '>>> Bucket "' + bucket + '": ' + items.size() + ' items');
    for (Integer i = 0; i < items.size(); i++) {
        Decimal desired = Decimal.valueOf(i + 1);
        if (items[i].delivery__SortOrderNumber__c != desired) {
            System.debug(LoggingLevel.INFO, '    ' + items[i].Name + ' ' + items[i].delivery__SortOrderNumber__c + ' -> ' + desired);
            toUpdate.add(new delivery__WorkItem__c(Id = items[i].Id, delivery__SortOrderNumber__c = desired));
        }
    }
}

System.debug(LoggingLevel.INFO, '>>> Total rows to update: ' + toUpdate.size());
if (!toUpdate.isEmpty()) {
    Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
    System.debug(LoggingLevel.INFO, '>>> Updated.');
} else {
    System.debug(LoggingLevel.INFO, '>>> No changes needed — already dense.');
}

class SortOrderThenNameComparator implements Comparator<delivery__WorkItem__c> {
    public Integer compare(delivery__WorkItem__c a, delivery__WorkItem__c b) {
        Decimal aS = a.delivery__SortOrderNumber__c;
        Decimal bS = b.delivery__SortOrderNumber__c;
        if (aS != bS) {
            if (aS == null) return 1;
            if (bS == null) return -1;
            return aS > bS ? 1 : -1;
        }
        // Tiebreak by Name for deterministic ordering
        String aN = a.Name == null ? '' : a.Name;
        String bN = b.Name == null ? '' : b.Name;
        return aN.compareTo(bN);
    }
}
