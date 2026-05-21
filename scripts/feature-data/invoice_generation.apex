// ============================================================
// Delivery Hub — Invoice Generation Feature Loader
// ------------------------------------------------------------
// Primes 5 WorkItem__c records with WorkLog__c rows ready to
// invoice. Values are intentionally OBVIOUS PLACEHOLDERS per
// CLAUDE.md rule "NEVER fabricate realistic financial data".
//
// Run: cci task run execute_anon \
//        --path scripts/feature-data/invoice_generation.apex \
//        --org <alias>
//
// Idempotent: skips insertion if 5+ records already exist with
// the loader marker prefix in BriefDescriptionTxt__c.
// ============================================================

final String MARKER = '[invoice_generation loader]';
final Integer TARGET_COUNT = 5;
final Decimal PLACEHOLDER_HOURS = 1.0;

Integer existing = [
    SELECT COUNT()
    FROM WorkItem__c
    WHERE BriefDescriptionTxt__c LIKE :('%' + MARKER + '%')
];
if (existing >= TARGET_COUNT) {
    System.debug(LoggingLevel.INFO,
        '[invoice_generation] Skipping — ' + existing + ' loader records already exist.');
    return;
}

// ------------------------------------------------------------
// Step 1: ensure two placeholder vendor NetworkEntity__c rows.
// Names are deliberately tagged "Sample Vendor A/B" so a reader
// immediately sees these are not real customers.
// ------------------------------------------------------------
List<NetworkEntity__c> vendors = [
    SELECT Id, Name FROM NetworkEntity__c
    WHERE Name IN ('Sample Vendor A', 'Sample Vendor B')
];
Map<String, NetworkEntity__c> byName = new Map<String, NetworkEntity__c>();
for (NetworkEntity__c v : vendors) {
    byName.put(v.Name, v);
}
List<NetworkEntity__c> toInsert = new List<NetworkEntity__c>();
for (String n : new List<String>{ 'Sample Vendor A', 'Sample Vendor B' }) {
    if (!byName.containsKey(n)) {
        toInsert.add(new NetworkEntity__c(
            Name = n,
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://example.invalid'
        ));
    }
}
if (!toInsert.isEmpty()) {
    insert toInsert;
    for (NetworkEntity__c v : toInsert) {
        byName.put(v.Name, v);
    }
}

NetworkEntity__c sampleVendorA = byName.get('Sample Vendor A');
NetworkEntity__c sampleVendorB = byName.get('Sample Vendor B');

// ------------------------------------------------------------
// Step 2: insert 5 WorkItem__c records. Use placeholder text in
// BriefDescriptionTxt__c so the loader marker survives in case
// the loader is run multiple times.
// ------------------------------------------------------------
List<WorkItem__c> workItems = new List<WorkItem__c>();
for (Integer i = 1; i <= TARGET_COUNT; i++) {
    workItems.add(new WorkItem__c(
        BriefDescriptionTxt__c = MARKER + ' Placeholder WI ' + i,
        StatusPk__c = 'Active',
        StageNamePk__c = 'Backlog',
        ActivatedDateTime__c = Datetime.now()
    ));
}
insert workItems;

// ------------------------------------------------------------
// Step 3: insert one WorkRequest__c bridge per WI (required MD
// parent of WorkLog__c.RequestId__c). Then insert 2 WLs per WI.
// HoursLoggedNumber__c is fixed at 1.0 — a deliberately obvious
// placeholder, NOT a realistic rate / amount.
// ------------------------------------------------------------
List<WorkRequest__c> bridges = new List<WorkRequest__c>();
for (WorkItem__c wi : workItems) {
    bridges.add(new WorkRequest__c(
        WorkItemId__c = wi.Id,
        StatusPk__c = 'Active'
    ));
}
insert bridges;

Map<Id, Id> bridgeByWi = new Map<Id, Id>();
for (WorkRequest__c b : bridges) {
    bridgeByWi.put(b.WorkItemId__c, b.Id);
}

List<WorkLog__c> logs = new List<WorkLog__c>();
for (WorkItem__c wi : workItems) {
    Id bridgeId = bridgeByWi.get(wi.Id);
    for (Integer k = 0; k < 2; k++) {
        logs.add(new WorkLog__c(
            WorkItemLookup__c = wi.Id,
            RequestId__c = bridgeId,
            HoursLoggedNumber__c = PLACEHOLDER_HOURS,
            WorkDateDate__c = Date.today().addDays(-k),
            WorkDescriptionTxt__c = MARKER + ' placeholder log ' + (k + 1)
        ));
    }
}
insert logs;

System.debug(LoggingLevel.INFO,
    '[invoice_generation] Loaded '
    + workItems.size() + ' WorkItem__c + '
    + bridges.size() + ' WorkRequest__c + '
    + logs.size() + ' WorkLog__c (placeholder values).');
