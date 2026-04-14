// ─── load-more-data.apex ─────────────────────────────────────────────────────
// Adds MISSING workstream and legacy T-NNNN items to the scratch org.
// DOES NOT delete existing records — additive only.
// Checks by BriefDescriptionTxt__c to skip already-present items.
// Run: sf apex run --file scripts/load-more-data.apex
//      --target-org test-bcqaurrchjr9@example.com
// ─────────────────────────────────────────────────────────────────────────────

// ── Step 1: Find the "Mobilization Funding" NetworkEntity __c ────────────────
List<NetworkEntity__c> entities = [
    SELECT Id FROM NetworkEntity__c WHERE Name = 'Mobilization Funding' LIMIT 1
];
if (entities.isEmpty()) {
    System.debug('ERROR: NetworkEntity "Mobilization Funding" not found. Aborting.');
    return;
}
Id entityId = entities[0].Id;
System.debug('Found NetworkEntity: ' + entityId);

// ── Step 2: Collect existing BriefDescriptionTxt__c values to avoid dupes ───
Set<String> existingTitles = new Set<String>();
for (WorkItem__c wi : [
    SELECT BriefDescriptionTxt__c FROM WorkItem__c
    WHERE ClientNetworkEntityLookup__c = :entityId
    LIMIT 10000
]) {
    if (wi.BriefDescriptionTxt__c != null) {
        existingTitles.add(wi.BriefDescriptionTxt__c);
    }
}
System.debug('Existing item count: ' + existingTitles.size());

// ── Step 3: Build the list of items to insert ────────────────────────────────
List<WorkItem__c> toInsert = new List<WorkItem__c>();

// ── WORKSTREAM ROOT ITEMS (no parent) ────────────────────────────────────────

// WS-TXN-PHASE-1
String txnTitle = 'Transaction Actions Phase 1 \u2014 5-click flow surgery fixes';
if (!existingTitles.contains(txnTitle)) {
    toInsert.add(new WorkItem__c(
        BriefDescriptionTxt__c       = txnTitle,
        StageNamePk__c               = 'Ready for Development',
        PriorityPk__c                = 'Critical',
        PriorityGroupPk__c           = 'top-priority',
        EstimatedStartDevDate__c     = Date.newInstance(2026, 4, 1),
        EstimatedEndDevDate__c       = Date.newInstance(2026, 4, 30),
        EstimatedHoursNumber__c      = 12,
        ActivatedDateTime__c         = Datetime.now(),
        ClientNetworkEntityLookup__c = entityId,
        SortOrderNumber__c           = 5
    ));
    System.debug('Queued: ' + txnTitle);
} else {
    System.debug('Skipping (exists): ' + txnTitle);
}

// WS-RLM-IDEMPOTENCY
String rlmTitle = 'QB Sync Idempotency Fix \u2014 QB sync idempotency fix';
if (!existingTitles.contains(rlmTitle)) {
    toInsert.add(new WorkItem__c(
        BriefDescriptionTxt__c       = rlmTitle,
        StageNamePk__c               = 'In Development',
        PriorityPk__c                = 'High',
        PriorityGroupPk__c           = 'active',
        EstimatedStartDevDate__c     = Date.newInstance(2026, 4, 8),
        EstimatedEndDevDate__c       = Date.newInstance(2026, 4, 25),
        EstimatedHoursNumber__c      = 12,
        ActivatedDateTime__c         = Datetime.now(),
        ClientNetworkEntityLookup__c = entityId,
        SortOrderNumber__c           = 6
    ));
    System.debug('Queued: ' + rlmTitle);
} else {
    System.debug('Skipping (exists): ' + rlmTitle);
}

// WS-OBLIGATION-JES
String oblTitle = 'Obligation JEs \u2014 4th JE type build (Mail scaffolding)';
if (!existingTitles.contains(oblTitle)) {
    toInsert.add(new WorkItem__c(
        BriefDescriptionTxt__c       = oblTitle,
        StageNamePk__c               = 'Paused',
        PriorityPk__c                = 'Medium',
        PriorityGroupPk__c           = 'deferred',
        EstimatedStartDevDate__c     = Date.newInstance(2026, 4, 1),
        EstimatedEndDevDate__c       = null,
        EstimatedHoursNumber__c      = 35,
        ActivatedDateTime__c         = Datetime.now(),
        ClientNetworkEntityLookup__c = entityId,
        SortOrderNumber__c           = 7
    ));
    System.debug('Queued: ' + oblTitle);
} else {
    System.debug('Skipping (exists): ' + oblTitle);
}

// ── LEGACY T-NNNN ITEMS (root, no parent) ───────────────────────────────────

// T-0036
String t36Title = 'Permission Set Audit & Rationalization';
if (!existingTitles.contains(t36Title)) {
    toInsert.add(new WorkItem__c(
        BriefDescriptionTxt__c       = t36Title,
        StageNamePk__c               = 'In Development',
        PriorityPk__c                = 'Critical',
        PriorityGroupPk__c           = 'top-priority',
        EstimatedStartDevDate__c     = Date.newInstance(2026, 4, 1),
        EstimatedEndDevDate__c       = Date.newInstance(2026, 4, 18),
        EstimatedHoursNumber__c      = 12,
        ActivatedDateTime__c         = Datetime.now(),
        ClientNetworkEntityLookup__c = entityId,
        SortOrderNumber__c           = 11
    ));
    System.debug('Queued: ' + t36Title);
} else {
    System.debug('Skipping (exists): ' + t36Title);
}

// T-0007
String t07Title = 'QB Integration Stabilization (RLM Duplicate JE \u2014 QB sync idempotency fix)';
if (!existingTitles.contains(t07Title)) {
    toInsert.add(new WorkItem__c(
        BriefDescriptionTxt__c       = t07Title,
        StageNamePk__c               = 'Paused',
        PriorityPk__c                = 'High',
        PriorityGroupPk__c           = 'deferred',
        EstimatedStartDevDate__c     = Date.newInstance(2026, 4, 1),
        EstimatedEndDevDate__c       = null,
        EstimatedHoursNumber__c      = 100,
        ActivatedDateTime__c         = Datetime.now(),
        ClientNetworkEntityLookup__c = entityId,
        SortOrderNumber__c           = 26
    ));
    System.debug('Queued: ' + t07Title);
} else {
    System.debug('Skipping (exists): ' + t07Title);
}

// ── Step 4: Insert ───────────────────────────────────────────────────────────
if (toInsert.isEmpty()) {
    System.debug('Nothing new to insert — all items already present.');
} else {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' new WorkItem__c records.');
}
