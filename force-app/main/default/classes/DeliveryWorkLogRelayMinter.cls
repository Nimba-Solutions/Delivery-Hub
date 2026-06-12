/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Relay-mint path for WorkLog__c outbound sync, extracted from
 *              DeliveryWorkLogTriggerHandler (which stays `with sharing`).
 *              Evaluates Hub-mode (upstream-to-Client) and Push-mode
 *              (downstream-to-Vendor via WorkRequest bridge) eligibility for a
 *              set of WorkLogs and inserts the outbound SyncItem__c relays.
 * @author Cloud Nimbus LLC
 */
// without sharing: Required so WorkLog relay minting succeeds regardless of the running
// user's record access — specifically the Delivery Hub Site Guest User. Inbound worklogs
// arrive via REST (DeliveryHubSyncService → DeliverySyncItemIngestor → WorkLog trigger)
// under the guest user, whose record access is forced Private. The eligibility queries on
// WorkItem__c / WorkRequest__c are WITH SYSTEM_MODE, which bypasses FLS but NOT sharing —
// inside a `with sharing` class they returned empty for the guest and the mint silently
// no-opped: no relay, worklogs never synced onward (2026-06 nimba: 65 rows / 138.5h went
// invisible to the billing org). DeliverySyncEngine is `without sharing` for the same
// reason, which is why WorkItem relays in the SAME guest transactions DID mint.
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity')
public without sharing class DeliveryWorkLogRelayMinter {

    /**
     * @description Mints outbound SyncItem__c relays for sync-eligible WorkLogs.
     *              Hub mode: parent WorkItem linked to a Client/Both NetworkEntity
     *              with an endpoint. Push mode: parent WorkItem fans out via active
     *              WorkRequest bridges to Vendor/Both entities with endpoints.
     *              Inserts the relays in SYSTEM_MODE and enqueues the dispatcher.
     *              Callers (the WorkLog trigger handler) apply the approval gate
     *              BEFORE calling — every log passed in is presumed sync-eligible.
     * @param logs The WorkLog__c records to evaluate and relay outbound.
     */
    public static void mintForLogs(List<WorkLog__c> logs) {
        Set<Id> workItemIds = new Set<Id>();
        for (WorkLog__c wl : logs) {
            if (wl.WorkItemLookup__c != null) {
                workItemIds.add(wl.WorkItemLookup__c);
            }
        }
        if (workItemIds.isEmpty()) {
            return;
        }

        // ── Hub mode: upstream to Client ───────────────────────────────
        // Eligible iff the parent WorkItem's ClientNetworkEntityLookup__c
        // is Client/Both with a populated endpoint. Without this guard
        // WorkLogs shipped to orgs that never received the parent WorkItem
        // (T-0129: 8.5h on dh-prod as orphan inbound, permanently unbillable
        // until manual hand-firing).
        Map<Id, WorkItem__c> clientWorkItems = new Map<Id, WorkItem__c>([
            SELECT Id, ClientNetworkEntityLookup__c
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            AND ClientNetworkEntityLookup__c != null
            AND ClientNetworkEntityLookup__r.EntityTypePk__c IN ('Client', 'Both')
            AND ClientNetworkEntityLookup__r.IntegrationEndpointUrlTxt__c != null
            WITH SYSTEM_MODE
        ]);

        // ── Push mode: downstream to Vendor via WorkRequest bridge ─────
        // Mirrors the Push branch in DeliverySyncEngine.captureChanges
        // (lines 86-104) so WorkLog outbound also fans out via active
        // WorkRequest connections to Vendor/Both entities. Pre-fix the WL
        // handler ONLY did Hub mode — orgs whose WI parent had no Client
        // entry (e.g. MF-Prod, where the only NetworkEntity is Cloud Nimbus
        // as a Vendor) silently dropped every WorkLog outbound. Empirically:
        // MF-Prod 9 WLs inserted 2026-05-01 → zero SyncItems → 69.5h had
        // to be manually mirrored to dh-prod for the April invoice.
        Map<Id, List<WorkRequest__c>> pushRoutes = new Map<Id, List<WorkRequest__c>>();
        for (WorkRequest__c req : [
            SELECT Id, WorkItemId__c, RemoteWorkItemIdTxt__c
            FROM WorkRequest__c
            WHERE WorkItemId__c IN :workItemIds
            AND StatusPk__c != 'Inactive'
            AND DeliveryEntityLookup__c != null
            AND DeliveryEntityLookup__r.EntityTypePk__c IN ('Vendor', 'Both')
            AND DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            if (!pushRoutes.containsKey(req.WorkItemId__c)) {
                pushRoutes.put(req.WorkItemId__c, new List<WorkRequest__c>());
            }
            pushRoutes.get(req.WorkItemId__c).add(req);
        }

        if (clientWorkItems.isEmpty() && pushRoutes.isEmpty()) {
            return;
        }

        List<SyncItem__c> syncItems = buildSyncItems(logs, clientWorkItems);
        syncItems.addAll(buildPushSyncItems(logs, pushRoutes));
        if (!syncItems.isEmpty()) {
            Database.insert(syncItems, AccessLevel.SYSTEM_MODE);
            if (!Test.isRunningTest() && Limits.getQueueableJobs() == 0 && !System.isQueueable() && !System.isFuture()) {
                System.enqueueJob(new DeliverySyncItemProcessor());
            }
        }
    }

    /**
     * @description Builds the list of SyncItem__c records for WorkLogs on client-linked work items.
     * @param logs The WorkLog records to evaluate.
     * @param clientWorkItems Map of work item Ids that have a client entity linked.
     * @return List of SyncItem__c records ready for insert.
     */
    private static List<SyncItem__c> buildSyncItems(List<WorkLog__c> logs, Map<Id, WorkItem__c> clientWorkItems) {
        String senderOrgId = UserInfo.getOrganizationId();
        Map<Id, String> recordToGlobalSource = buildGlobalSourceMap(logs);
        List<SyncItem__c> items = new List<SyncItem__c>();
        for (WorkLog__c wl : logs) {
            if (!clientWorkItems.containsKey(wl.WorkItemLookup__c)) {
                continue;
            }
            // Inherit the ORIGIN GlobalSourceId if this WorkLog arrived via an
            // inbound relay; otherwise this org is the birthplace and the id
            // is minted from the local record. Without inheritance the origin
            // id is re-minted at every MF → Nimba → dh-prod hop, killing the
            // cross-path dedup on the receiver and duplicating invoice hours.
            String gsid = recordToGlobalSource.containsKey(wl.Id)
                ? recordToGlobalSource.get(wl.Id)
                : (String) wl.Id;
            Map<String, Object> payload = new Map<String, Object>{
                'SourceId'               => wl.Id,
                'SenderOrgId'            => senderOrgId,
                'GlobalSourceId'         => gsid,
                'WorkItemLookup__c'          => wl.WorkItemLookup__c,
                'HoursLoggedNumber__c'   => wl.HoursLoggedNumber__c,
                'WorkDateDate__c'        => String.valueOf(wl.WorkDateDate__c),
                'WorkDescriptionTxt__c'  => wl.WorkDescriptionTxt__c
            };
            items.add(new SyncItem__c(
                ObjectTypePk__c         = 'WorkLog__c',
                LocalRecordIdTxt__c     = wl.Id,
                WorkItemLookup__c           = wl.WorkItemLookup__c,
                DirectionPk__c          = 'Outbound',
                StatusPk__c             = 'Queued',
                GlobalSourceIdTxt__c    = gsid,
                PayloadTxt__c           = JSON.serialize(payload)
            ));
        }
        return items;
    }

    /**
     * @description Bulk-loads the origin GlobalSourceId for a set of WorkLogs by
     *              walking their Inbound SyncItem ledger rows. Mirrors the
     *              inheritance map built in DeliverySyncEngine.captureChanges so
     *              relayed WorkLogs keep their birthplace id across hops instead
     *              of re-minting it at every relay. One query, no SOQL-in-loop.
     * @param logs The WorkLog records about to be emitted outbound.
     * @return Map of WorkLog Id → inherited origin GlobalSourceId. WorkLogs with
     *         no inbound ledger row are absent (caller treats absence as birthplace).
     */
    private static Map<Id, String> buildGlobalSourceMap(List<WorkLog__c> logs) {
        Map<Id, String> recordToGlobalSource = new Map<Id, String>();
        Set<Id> idSet = new Set<Id>();
        for (WorkLog__c wl : logs) {
            idSet.add(wl.Id);
        }
        if (idSet.isEmpty()) {
            return recordToGlobalSource;
        }
        for (SyncItem__c inbound : [
            SELECT LocalRecordIdTxt__c, GlobalSourceIdTxt__c
            FROM SyncItem__c
            WHERE LocalRecordIdTxt__c IN :idSet
            AND GlobalSourceIdTxt__c != NULL
            AND DirectionPk__c = 'Inbound'
            WITH SYSTEM_MODE
        ]) {
            recordToGlobalSource.put((Id) inbound.LocalRecordIdTxt__c, inbound.GlobalSourceIdTxt__c);
        }
        return recordToGlobalSource;
    }

    /**
     * @description Builds Push-mode outbound SyncItem__c records — one per
     *              (WorkLog × WorkRequest-route) pair — for every WorkLog
     *              whose parent WorkItem fans out to a Vendor/Both
     *              NetworkEntity through an active WorkRequest bridge.
     *              Mirrors the Hub-mode buildSyncItems shape but populates
     *              RequestLookup__c + payload.TargetId so the dispatcher
     *              routes via the WorkRequest's DeliveryEntity endpoint.
     * @param logs The WorkLog__c records being synced.
     * @param pushRoutes Map of parent WorkItem Id → list of active
     *                   WorkRequest connections to Vendor/Both entities.
     * @return List of Push-mode SyncItem__c records ready for insert.
     */
    private static List<SyncItem__c> buildPushSyncItems(List<WorkLog__c> logs, Map<Id, List<WorkRequest__c>> pushRoutes) {
        String senderOrgId = UserInfo.getOrganizationId();
        Map<Id, String> recordToGlobalSource = buildGlobalSourceMap(logs);
        List<SyncItem__c> items = new List<SyncItem__c>();
        for (WorkLog__c wl : logs) {
            List<WorkRequest__c> reqs = pushRoutes.get(wl.WorkItemLookup__c);
            if (reqs == null || reqs.isEmpty()) {
                continue;
            }
            // Inherit origin GlobalSourceId across relay hops (see buildSyncItems).
            String gsid = recordToGlobalSource.containsKey(wl.Id)
                ? recordToGlobalSource.get(wl.Id)
                : (String) wl.Id;
            for (WorkRequest__c req : reqs) {
                Map<String, Object> payload = new Map<String, Object>{
                    'SourceId'               => wl.Id,
                    'SenderOrgId'            => senderOrgId,
                    'GlobalSourceId'         => gsid,
                    'TargetId'               => req.RemoteWorkItemIdTxt__c,
                    'WorkItemLookup__c'      => wl.WorkItemLookup__c,
                    'HoursLoggedNumber__c'   => wl.HoursLoggedNumber__c,
                    'WorkDateDate__c'        => String.valueOf(wl.WorkDateDate__c),
                    'WorkDescriptionTxt__c'  => wl.WorkDescriptionTxt__c
                };
                items.add(new SyncItem__c(
                    ObjectTypePk__c         = 'WorkLog__c',
                    LocalRecordIdTxt__c     = wl.Id,
                    WorkItemLookup__c       = wl.WorkItemLookup__c,
                    RequestLookup__c        = req.Id,
                    DirectionPk__c          = 'Outbound',
                    StatusPk__c             = 'Queued',
                    GlobalSourceIdTxt__c    = gsid,
                    PayloadTxt__c           = JSON.serialize(payload)
                ));
            }
        }
        return items;
    }
}
