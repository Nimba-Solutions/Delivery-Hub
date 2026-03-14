// =============================================================================
// Sync State Audit — Nimba Sandbox (run via: sf apex run -f scripts/audit_sync_state_nimba.apex --target-org nimba)
// No namespace prefix — unmanaged org.
// =============================================================================

System.debug('========== NETWORK ENTITIES ==========');
for (NetworkEntity__c ne : [
    SELECT Name, EntityTypePk__c, StatusPk__c, EndpointUrlTxt__c,
           OrgIdTxt__c, EnableVendorPushBool__c
    FROM NetworkEntity__c
    ORDER BY EntityTypePk__c, Name
]) {
    System.debug('Entity: ' + ne.Name
        + ' | Type: ' + ne.EntityTypePk__c
        + ' | Status: ' + ne.StatusPk__c
        + ' | Endpoint: ' + ne.EndpointUrlTxt__c
        + ' | OrgId: ' + ne.OrgIdTxt__c
        + ' | VendorPush: ' + ne.EnableVendorPushBool__c);
}

System.debug('========== MF NETWORK ENTITY DETAILS ==========');
List<NetworkEntity__c> mfEntities = [
    SELECT Name, EntityTypePk__c, StatusPk__c, EndpointUrlTxt__c, OrgIdTxt__c
    FROM NetworkEntity__c
    WHERE Name LIKE '%Mobilization%' OR Name LIKE '%MF%'
];
if (mfEntities.isEmpty()) {
    System.debug('WARNING: No NetworkEntity found matching "Mobilization" or "MF"');
} else {
    for (NetworkEntity__c ne : mfEntities) {
        System.debug('MF Entity: ' + ne.Name
            + ' | Type: ' + ne.EntityTypePk__c
            + ' | Status: ' + ne.StatusPk__c
            + ' | Endpoint: ' + ne.EndpointUrlTxt__c
            + ' | OrgId: ' + ne.OrgIdTxt__c);
    }
}

System.debug('========== WORK REQUESTS (with WorkItem + Entity) ==========');
for (WorkRequest__c wr : [
    SELECT WorkItemId__r.Name, WorkItemId__r.BriefDescriptionTxt__c,
           DeliveryEntityId__r.Name, StatusPk__c,
           RemoteWorkItemIdTxt__c
    FROM WorkRequest__c
    ORDER BY StatusPk__c, CreatedDate DESC
    LIMIT 100
]) {
    System.debug('WR: ' + wr.WorkItemId__r.Name
        + ' | Desc: ' + wr.WorkItemId__r.BriefDescriptionTxt__c
        + ' | Entity: ' + wr.DeliveryEntityId__r.Name
        + ' | Status: ' + wr.StatusPk__c
        + ' | RemoteId: ' + wr.RemoteWorkItemIdTxt__c);
}

System.debug('========== SYNC ITEMS (grouped by Status+Direction+ObjectType) ==========');
for (AggregateResult ar : [
    SELECT StatusPk__c status, DirectionPk__c direction,
           ObjectTypePk__c objType, COUNT(Id) cnt
    FROM SyncItem__c
    GROUP BY StatusPk__c, DirectionPk__c, ObjectTypePk__c
    ORDER BY StatusPk__c
]) {
    System.debug('SyncItem: ' + ar.get('status')
        + ' | ' + ar.get('direction')
        + ' | ' + ar.get('objType')
        + ' | Count: ' + ar.get('cnt'));
}

System.debug('========== WORK ITEMS: ClientNetworkEntityId populated vs null ==========');
Integer withClient = [SELECT COUNT() FROM WorkItem__c WHERE ClientNetworkEntityId__c != null];
Integer withoutClient = [SELECT COUNT() FROM WorkItem__c WHERE ClientNetworkEntityId__c = null];
System.debug('WorkItems WITH ClientNetworkEntityId: ' + withClient);
System.debug('WorkItems WITHOUT ClientNetworkEntityId: ' + withoutClient);

System.debug('========== WORK ITEMS WITH ClientNetworkEntityId ==========');
for (WorkItem__c wi : [
    SELECT Name, BriefDescriptionTxt__c, ClientNetworkEntityId__c,
           ClientNetworkEntityId__r.Name
    FROM WorkItem__c
    WHERE ClientNetworkEntityId__c != null
    LIMIT 50
]) {
    System.debug('WI: ' + wi.Name
        + ' | Desc: ' + wi.BriefDescriptionTxt__c
        + ' | ClientEntity: ' + wi.ClientNetworkEntityId__r.Name);
}

System.debug('========== WORK ITEMS WITHOUT ClientNetworkEntityId (first 20) ==========');
for (WorkItem__c wi : [
    SELECT Name, BriefDescriptionTxt__c, StageNamePk__c
    FROM WorkItem__c
    WHERE ClientNetworkEntityId__c = null
    ORDER BY CreatedDate DESC
    LIMIT 20
]) {
    System.debug('WI (no client): ' + wi.Name
        + ' | Desc: ' + wi.BriefDescriptionTxt__c
        + ' | Stage: ' + wi.StageNamePk__c);
}

System.debug('========== WORK LOGS (summary) ==========');
Integer totalLogs = [SELECT COUNT() FROM WorkLog__c];
Decimal totalHours = 0;
for (AggregateResult ar : [
    SELECT SUM(HoursLoggedNumber__c) total FROM WorkLog__c
]) {
    totalHours = (Decimal) ar.get('total');
}
System.debug('Total WorkLogs: ' + totalLogs + ' | Total Hours: ' + totalHours);

for (WorkLog__c wl : [
    SELECT WorkItemId__r.Name, HoursLoggedNumber__c,
           WorkDateDate__c, WorkDescriptionTxt__c
    FROM WorkLog__c
    ORDER BY WorkDateDate__c DESC
    LIMIT 50
]) {
    System.debug('Log: ' + wl.WorkItemId__r.Name
        + ' | ' + wl.HoursLoggedNumber__c + 'h'
        + ' | Date: ' + wl.WorkDateDate__c
        + ' | Desc: ' + wl.WorkDescriptionTxt__c);
}

System.debug('========== DUPLICATE CHECK (by BriefDescription) ==========');
for (AggregateResult ar : [
    SELECT BriefDescriptionTxt__c desc, COUNT(Id) cnt
    FROM WorkItem__c
    GROUP BY BriefDescriptionTxt__c
    HAVING COUNT(Id) > 1
]) {
    System.debug('DUPLICATE: "' + ar.get('desc') + '" appears ' + ar.get('cnt') + ' times');
}

System.debug('========== AUDIT COMPLETE ==========');
