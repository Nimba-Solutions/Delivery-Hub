/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for BountyClaim__c. Routes claim data to origin orgs
 *               via the sync engine so that orgs posting bounties see claims in real time.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryBountyClaimTriggerHandler {

    private static final Set<String> SYNC_FIELDS = new Set<String>{
        'StatusPk__c',
        'ClaimantEmailTxt__c',
        'ClaimantNameTxt__c',
        'NoteTxt__c',
        'WorkProofUrlTxt__c',
        'ClaimedDateTime__c',
        'SubmittedDateTime__c'
    };

    public static void handleAfterInsert(List<BountyClaim__c> newClaims) {
        if (DeliverySyncEngine.isSyncContext) { return; }

        // Query parent WorkItem -> ClientNetworkEntity for routing
        Set<Id> workItemIds = new Set<Id>();
        for (BountyClaim__c c : newClaims) {
            workItemIds.add(c.WorkItemId__c);
        }

        Map<Id, WorkItem__c> parentItems = new Map<Id, WorkItem__c>([
            SELECT Id, ClientNetworkEntityId__c,
                   ClientNetworkEntityId__r.IntegrationEndpointUrlTxt__c,
                   ClientNetworkEntityId__r.ApiKeyTxt__c,
                   ClientNetworkEntityId__r.EnableVendorPushBool__c,
                   ClientNetworkEntityId__r.EntityTypePk__c,
                   ClientNetworkEntityId__r.ConnectionStatusPk__c
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
        ]);

        List<SyncItem__c> syncItems = new List<SyncItem__c>();

        for (BountyClaim__c claim : newClaims) {
            WorkItem__c parent = parentItems.get(claim.WorkItemId__c);
            if (parent == null || parent.ClientNetworkEntityId__c == null) { continue; }
            if (parent.ClientNetworkEntityId__r.ConnectionStatusPk__c == 'Pending Approval') { continue; }

            Boolean hasPushEndpoint = parent.ClientNetworkEntityId__r.EnableVendorPushBool__c == true
                && String.isNotBlank(parent.ClientNetworkEntityId__r.IntegrationEndpointUrlTxt__c);

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('SourceId', claim.Id);
            payload.put('SenderOrgId', UserInfo.getOrganizationId());
            payload.put('GlobalSourceId', (String) claim.Id);
            payload.put('WorkItemId__c', claim.WorkItemId__c);
            for (String field : SYNC_FIELDS) {
                payload.put(field, claim.get(field));
            }

            SyncItem__c si = new SyncItem__c(
                StatusPk__c = hasPushEndpoint ? 'Queued' : 'Staged',
                DirectionPk__c = 'Outbound',
                ObjectTypePk__c = 'BountyClaim__c',
                LocalRecordIdTxt__c = (String) claim.Id,
                WorkItemId__c = claim.WorkItemId__c,
                GlobalSourceIdTxt__c = (String) claim.Id,
                PayloadTxt__c = JSON.serialize(payload)
            );
            syncItems.add(si);
        }

        if (!syncItems.isEmpty()) {
            Database.insert(syncItems, AccessLevel.SYSTEM_MODE);
            if (Limits.getQueueableJobs() == 0 && !System.isQueueable() && !System.isFuture()) {
                System.enqueueJob(new DeliverySyncItemProcessor());
            }
        }
    }

    public static void handleAfterUpdate(List<BountyClaim__c> newClaims, Map<Id, BountyClaim__c> oldMap) {
        DeliverySyncEngine.captureChanges(newClaims, oldMap, SYNC_FIELDS);
    }
}
