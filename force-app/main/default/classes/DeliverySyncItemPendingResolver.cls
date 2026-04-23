/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Queueable that re-attempts inbound sync items parked in
 *               Pending status because their parent WorkItem had not synced
 *               yet when the payload arrived. Replaces the prior hard-throw
 *               behavior in DeliverySyncItemIngestor that stranded ~165
 *               WorkLog payloads on nimba. When a resolver run finds the
 *               parent now resolves, the Pending row is promoted to Synced
 *               and the replayed payload inserts the local record. After
 *               PendingMaxRetries attempts the row flips to Failed so the
 *               standard Failed-item dashboards surface the problem.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier, PMD.CyclomaticComplexity')
global inherited sharing class DeliverySyncItemPendingResolver implements Queueable {

    /** @description Default max retry attempts before a Pending row flips to Failed. */
    @TestVisible
    private static final Integer DEFAULT_MAX_RETRIES = 10;

    /**
     * @description Optional parent WorkItem ref to scope the resolver to a
     *              single branch (set by the inline inbound path). Null means
     *              "sweep everything Pending" — used by the scheduled tick.
     */
    private final String parentWorkItemRef;

    /**
     * @description Constructs a resolver scoped to one parent WorkItem ref.
     * @param parentWorkItemRef The remote identifier stashed in
     *                          ParentRefTxt__c of Pending rows.
     */
    global DeliverySyncItemPendingResolver(String parentWorkItemRef) {
        this.parentWorkItemRef = parentWorkItemRef;
    }

    /**
     * @description Constructs a resolver that sweeps every Pending row. Used
     *              by DeliveryHubScheduler.requeuePendingItems.
     */
    global DeliverySyncItemPendingResolver() {
        this.parentWorkItemRef = null;
    }

    /**
     * @description Queueable entry point. Queries Pending WorkLog SyncItems
     *              scoped to parentWorkItemRef (or everything when null),
     *              re-attempts parent resolution, and updates the row state
     *              accordingly. Bounded to 50 rows per run to stay well
     *              inside DML limits — the scheduled tick keeps draining
     *              until the Pending queue empties.
     * @param ctx Standard Queueable context.
     */
    global void execute(QueueableContext ctx) {
        resolvePending();
    }

    /**
     * @description Core resolver loop. Extracted for reuse by the scheduler
     *              path which wants to invoke synchronously in tests.
     * @return Number of rows promoted to Synced in this run.
     */
    public Integer resolvePending() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Integer maxRetries = settings != null && settings.SyncRetryLimitNumber__c != null
            ? (Integer) settings.SyncRetryLimitNumber__c : DEFAULT_MAX_RETRIES;
        // Floor at DEFAULT_MAX_RETRIES — we want race-condition forgiveness
        // here, not the same 3-strikes budget we give outbound pushes.
        if (maxRetries < DEFAULT_MAX_RETRIES) {
            maxRetries = DEFAULT_MAX_RETRIES;
        }

        List<SyncItem__c> pendingRows;
        if (String.isNotBlank(this.parentWorkItemRef)) {
            String scopedRef = this.parentWorkItemRef;
            pendingRows = [
                SELECT Id, ObjectTypePk__c, PayloadTxt__c, ParentRefTxt__c,
                       RemoteExternalIdTxt__c, RetryCountNumber__c
                FROM SyncItem__c
                WHERE DirectionPk__c = 'Inbound'
                AND StatusPk__c = 'Pending'
                AND ParentRefTxt__c = :scopedRef
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT 50
            ];
        } else {
            pendingRows = [
                SELECT Id, ObjectTypePk__c, PayloadTxt__c, ParentRefTxt__c,
                       RemoteExternalIdTxt__c, RetryCountNumber__c
                FROM SyncItem__c
                WHERE DirectionPk__c = 'Inbound'
                AND StatusPk__c = 'Pending'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT 50
            ];
        }

        if (pendingRows.isEmpty()) {
            return 0;
        }

        List<SyncItem__c> toUpdate = new List<SyncItem__c>();
        Integer promoted = 0;
        for (SyncItem__c row : pendingRows) {
            if (processRow(row, maxRetries)) {
                promoted++;
            }
            toUpdate.add(row);
        }

        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
        }
        return promoted;
    }

    /**
     * @description Processes a single Pending row in place: resolves parent,
     *              replays payload on hit, bumps retry counter on miss, and
     *              flips to Failed when retries are exhausted.
     * @param row The Pending SyncItem__c row to mutate.
     * @param maxRetries Retry ceiling before the row flips to Failed.
     * @return true when the row was promoted to Synced in this call.
     */
    private static Boolean processRow(SyncItem__c row, Integer maxRetries) {
        Integer currentRetries = row.RetryCountNumber__c == null ? 0 : row.RetryCountNumber__c.intValue();
        Id localParent = resolveParent(row.ParentRefTxt__c);

        if (localParent != null) {
            try {
                DeliverySyncItemIngestor.replayPendingPayload(row.ObjectTypePk__c, row.PayloadTxt__c);
                row.StatusPk__c = 'Synced';
                return true;
            } catch (Exception e) {
                row.RetryCountNumber__c = currentRetries + 1;
                row.ErrorLogTxt__c = e.getMessage();
                if (row.RetryCountNumber__c >= maxRetries) {
                    row.StatusPk__c = 'Failed';
                }
                return false;
            }
        }

        row.RetryCountNumber__c = currentRetries + 1;
        if (row.RetryCountNumber__c >= maxRetries) {
            row.StatusPk__c = 'Failed';
            row.ErrorLogTxt__c = 'Parent WorkItem did not arrive within '
                + maxRetries + ' retry attempts. Parent ref: ' + row.ParentRefTxt__c;
        }
        return false;
    }

    /**
     * @description Attempts to resolve a remote WorkItem ref to a local Id
     *              using the same bridge → ledger → direct-id fallback the
     *              ingestor uses on the inline path.
     * @param remoteRef The stashed parent WorkItem identifier.
     * @return Local WorkItem Id or null.
     */
    private static Id resolveParent(String remoteRef) {
        if (String.isBlank(remoteRef)) {
            return null;
        }
        // 1. WorkRequest bridge (downstream origin)
        List<WorkRequest__c> bridges = [
            SELECT Id, WorkItemId__c
            FROM WorkRequest__c
            WHERE RemoteWorkItemIdTxt__c = :remoteRef
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!bridges.isEmpty() && bridges[0].WorkItemId__c != null) {
            return bridges[0].WorkItemId__c;
        }

        // 2. Inbound ledger (upstream origin)
        List<SyncItem__c> ledger = [
            SELECT LocalRecordIdTxt__c
            FROM SyncItem__c
            WHERE RemoteExternalIdTxt__c = :remoteRef
            AND ObjectTypePk__c = 'WorkItem__c'
            AND DirectionPk__c = 'Inbound'
            AND StatusPk__c = 'Synced'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!ledger.isEmpty() && String.isNotBlank(ledger[0].LocalRecordIdTxt__c)) {
            try {
                return (Id) ledger[0].LocalRecordIdTxt__c;
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Invalid ledger LocalRecordIdTxt__c: ' + e.getMessage());
            }
        }

        // 3. Ref may itself be a local Id (same-org test scenarios)
        try {
            Id castId = (Id) remoteRef;
            if (castId.getSobjectType().getDescribe().getName().endsWithIgnoreCase('WorkItem__c')) {
                return castId;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'remoteRef not a local WorkItem Id: ' + e.getMessage());
        }
        return null;
    }
}
