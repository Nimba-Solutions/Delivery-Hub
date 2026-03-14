// =============================================================================
// Sync State Audit — MF Prod (run via: sf apex run -f scripts/audit_sync_state_mf.apex --target-org MF-Prod)
// Namespace-prefixed queries for managed package org.
// =============================================================================

System.debug('========== NETWORK ENTITIES ==========');
for (delivery__NetworkEntity__c ne : [
    SELECT Name, delivery__EntityTypePk__c, delivery__StatusPk__c,
           delivery__EndpointUrlTxt__c, delivery__OrgIdTxt__c,
           delivery__EnableVendorPushBool__c
    FROM delivery__NetworkEntity__c
    ORDER BY delivery__EntityTypePk__c, Name
]) {
    System.debug('Entity: ' + ne.Name
        + ' | Type: ' + ne.delivery__EntityTypePk__c
        + ' | Status: ' + ne.delivery__StatusPk__c
        + ' | Endpoint: ' + ne.delivery__EndpointUrlTxt__c
        + ' | OrgId: ' + ne.delivery__OrgIdTxt__c
        + ' | VendorPush: ' + ne.delivery__EnableVendorPushBool__c);
}

System.debug('========== WORK REQUESTS (with WorkItem + Entity) ==========');
for (delivery__WorkRequest__c wr : [
    SELECT delivery__WorkItemId__r.Name, delivery__WorkItemId__r.delivery__BriefDescriptionTxt__c,
           delivery__DeliveryEntityId__r.Name, delivery__StatusPk__c,
           delivery__RemoteWorkItemIdTxt__c
    FROM delivery__WorkRequest__c
    ORDER BY delivery__StatusPk__c, CreatedDate DESC
    LIMIT 100
]) {
    System.debug('WR: ' + wr.delivery__WorkItemId__r.Name
        + ' | Desc: ' + wr.delivery__WorkItemId__r.delivery__BriefDescriptionTxt__c
        + ' | Entity: ' + wr.delivery__DeliveryEntityId__r.Name
        + ' | Status: ' + wr.delivery__StatusPk__c
        + ' | RemoteId: ' + wr.delivery__RemoteWorkItemIdTxt__c);
}

System.debug('========== SYNC ITEMS (grouped by Status+Direction+ObjectType) ==========');
for (AggregateResult ar : [
    SELECT delivery__StatusPk__c status, delivery__DirectionPk__c direction,
           delivery__ObjectTypePk__c objType, COUNT(Id) cnt
    FROM delivery__SyncItem__c
    GROUP BY delivery__StatusPk__c, delivery__DirectionPk__c, delivery__ObjectTypePk__c
    ORDER BY delivery__StatusPk__c
]) {
    System.debug('SyncItem: ' + ar.get('status')
        + ' | ' + ar.get('direction')
        + ' | ' + ar.get('objType')
        + ' | Count: ' + ar.get('cnt'));
}

System.debug('========== WORK ITEMS: ClientNetworkEntityId populated vs null ==========');
Integer withClient = [SELECT COUNT() FROM delivery__WorkItem__c WHERE delivery__ClientNetworkEntityId__c != null];
Integer withoutClient = [SELECT COUNT() FROM delivery__WorkItem__c WHERE delivery__ClientNetworkEntityId__c = null];
System.debug('WorkItems WITH ClientNetworkEntityId: ' + withClient);
System.debug('WorkItems WITHOUT ClientNetworkEntityId: ' + withoutClient);

System.debug('========== WORK ITEMS WITH ClientNetworkEntityId ==========');
for (delivery__WorkItem__c wi : [
    SELECT Name, delivery__BriefDescriptionTxt__c, delivery__ClientNetworkEntityId__c,
           delivery__ClientNetworkEntityId__r.Name
    FROM delivery__WorkItem__c
    WHERE delivery__ClientNetworkEntityId__c != null
    LIMIT 50
]) {
    System.debug('WI: ' + wi.Name
        + ' | Desc: ' + wi.delivery__BriefDescriptionTxt__c
        + ' | ClientEntity: ' + wi.delivery__ClientNetworkEntityId__r.Name);
}

System.debug('========== DUPLICATE CHECK (by BriefDescription) ==========');
for (AggregateResult ar : [
    SELECT delivery__BriefDescriptionTxt__c desc, COUNT(Id) cnt
    FROM delivery__WorkItem__c
    GROUP BY delivery__BriefDescriptionTxt__c
    HAVING COUNT(Id) > 1
]) {
    System.debug('DUPLICATE: "' + ar.get('desc') + '" appears ' + ar.get('cnt') + ' times');
}

System.debug('========== WORK LOGS (summary) ==========');
Integer totalLogs = [SELECT COUNT() FROM delivery__WorkLog__c];
Decimal totalHours = 0;
for (AggregateResult ar : [
    SELECT SUM(delivery__HoursLoggedNumber__c) total FROM delivery__WorkLog__c
]) {
    totalHours = (Decimal) ar.get('total');
}
System.debug('Total WorkLogs: ' + totalLogs + ' | Total Hours: ' + totalHours);

for (delivery__WorkLog__c wl : [
    SELECT delivery__WorkItemId__r.Name, delivery__HoursLoggedNumber__c,
           delivery__WorkDateDate__c, delivery__WorkDescriptionTxt__c
    FROM delivery__WorkLog__c
    ORDER BY delivery__WorkDateDate__c DESC
    LIMIT 50
]) {
    System.debug('Log: ' + wl.delivery__WorkItemId__r.Name
        + ' | ' + wl.delivery__HoursLoggedNumber__c + 'h'
        + ' | Date: ' + wl.delivery__WorkDateDate__c
        + ' | Desc: ' + wl.delivery__WorkDescriptionTxt__c);
}

System.debug('========== AUDIT COMPLETE ==========');
