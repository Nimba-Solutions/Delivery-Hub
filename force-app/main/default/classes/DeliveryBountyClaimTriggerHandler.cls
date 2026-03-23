/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for BountyClaim__c. Routes claim data to origin orgs
 *               via the sync engine so that orgs posting bounties see claims in real time.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
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

    /**
     * @description Entry point from trigger. Routes to insert or update handler.
     * @param newClaims List of new or updated BountyClaim__c records.
     * @param oldMap Map of old BountyClaim__c records (null on insert).
     * @param isInsert True if trigger context is insert.
     * @param isUpdate True if trigger context is update.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static void handleAfter(List<BountyClaim__c> newClaims, Map<Id, BountyClaim__c> oldMap, Boolean isInsert, Boolean isUpdate) {
        if (isInsert) { handleAfterInsert(newClaims); }
        if (isUpdate) { handleAfterUpdate(newClaims, oldMap); }
    }

    /**
     * @description Creates outbound SyncItem__c records when claims are inserted,
     * routing them to the origin org via the parent WorkItem's ClientNetworkEntity.
     * @param newClaims List of newly inserted BountyClaim__c records.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    private static void handleAfterInsert(List<BountyClaim__c> newClaims) {
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

    /**
     * @description Captures field changes on updated claims and syncs them via the sync engine.
     * @param newClaims List of updated BountyClaim__c records.
     * @param oldMap Map of pre-update BountyClaim__c records.
     */
    private static void handleAfterUpdate(List<BountyClaim__c> newClaims, Map<Id, BountyClaim__c> oldMap) {
        DeliverySyncEngine.captureChanges(newClaims, oldMap, SYNC_FIELDS);
    }
}
