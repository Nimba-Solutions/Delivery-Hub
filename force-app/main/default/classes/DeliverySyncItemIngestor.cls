/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Strictly enforces DAG topology (no reverse-bridges) and maintains PMD compliance.
 * Captures routing origins and Global Traceability IDs to explicitly prevent echo loops.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ApexCRUDViolation')
public without sharing class DeliverySyncItemIngestor {

    // Cache the namespace prefix per transaction. Without this, getNamespacePrefix is
    // called 6+ times per processInboundItem invocation, each firing a SOQL against
    // Organization. An 8-item poll exceeded the 100-SOQL governor on the per-call cost
    // alone before the rest of the ingestor's queries.
    private static Boolean cachedNamespacePrefixSet = false;
    private static String cachedNamespacePrefix;

    private static String getNamespacePrefix() {
        if (!cachedNamespacePrefixSet) {
            String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
            cachedNamespacePrefix = String.isBlank(ns) ? '' : ns + '__';
            cachedNamespacePrefixSet = true;
        }
        return cachedNamespacePrefix;
    }

    private static String stripNamespace(String apiName) {
        if (String.isNotBlank(apiName) && apiName.countMatches('__') > 1) {
            return apiName.substringAfter('__');
        }
        return apiName;
    }

    /**
     * @description Processes an inbound sync payload by resolving the local record via ledger/bridge
     * lookup, mapping fields, auto-parenting upstream clients, and registering echo suppression.
     * @param objectType The API name of the SObject type being synced.
     * @param payload The deserialized JSON payload containing field values and routing metadata.
     * @return The Id of the upserted local record.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    public static Id processInboundItem(String objectType, Map<String, Object> payload) {
        // Use the senderOrgId-aware setter so DeliverySyncEngine.captureChanges
        // can fan out to non-source destinations during this transaction
        // (enables the daisy-chain relay MF → Nimba → dh-prod). Falls back
        // to the legacy full-suppress when SenderOrgId is missing from the
        // payload — safe default.
        String inboundSenderOrgId = (String) payload.get('SenderOrgId');
        DeliverySyncEngine.setInboundContext(inboundSenderOrgId);

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        // Cross-org file-byte transport (2026-04-21 rewrite):
        //   New senders emit metadata-only ContentVersion payloads with
        //   FileTransport="pull-callout" and NO VersionData. Route those to
        //   DeliveryFileBytesFetcher which fetches bytes via authenticated
        //   callout to the source org. Legacy inline-bytes payloads
        //   (VersionData present) continue to flow through the generic
        //   mapFields/insert path below for 30d backward compat.
        if (objectType.equalsIgnoreCase('ContentVersion')
                && 'pull-callout'.equalsIgnoreCase(String.valueOf(payload.get('FileTransport')))) {
            return handlePullCalloutFile(payload);
        }
        if (objectType.equalsIgnoreCase('ContentVersion') && payload.containsKey('VersionData')) {
            System.debug(LoggingLevel.WARN,
                'Deprecated: inbound ContentVersion with inline VersionData. ' +
                'Senders should emit FileTransport="pull-callout" — legacy path retained for 30d backward compat.');
        }

        String sourceId = (String) payload.get('SourceId');
        String targetId = (String) payload.get('TargetId');
        
        // Extract Traceability & Identity IDs from the incoming payload
        String globalSourceId = (String) payload.get('GlobalSourceId'); 
        String senderOrgId = (String) payload.get('SenderOrgId'); 
        
        Id localRequestId = null;
        Id localRecordId = findLocalId(targetType, sourceId);

        // Cross-path dedup via GlobalSourceId. When a record arrives via two
        // different sync paths (e.g. MF → dh-prod direct AND MF → Nimba →
        // dh-prod), the two payloads carry DIFFERENT SourceIds (each one is
        // the immediate sender's local record Id) but the SAME GlobalSourceId
        // (the origin record Id, set once at the birthplace per
        // DeliverySyncEngine.captureChanges:117-119 and propagated unchanged
        // across hops). Without this check, findLocalId returns null on the
        // second-path SourceId because the inbound ledger entry was created
        // against the FIRST path's SourceId, and the ingestor inserts a
        // duplicate local record. Verified 2026-05-10: dh-prod ended up with
        // 8 copies of 4 RR Phase WIs because the 4 originals each arrived
        // via both MF-direct and MF→Nimba paths.
        if (localRecordId == null && String.isNotBlank(globalSourceId)) {
            Id globalMatch = findLocalIdByGlobalSource(targetType, globalSourceId);
            if (globalMatch != null) {
                localRecordId = globalMatch;
            }
        }

        // If it's a Work Item, also check the WorkRequest__c bridge (Downstream Origin).
        // The bridge carries explicit downstream routing context (localRequestId), so
        // we always capture it when present. But we only promote bridge.WorkItemId__c
        // to localRecordId if (a) the ledger lookup didn't already find one and
        // (b) the bridge target still exists locally. Stale bridges that point at
        // deleted records used to silently win and cause permanent sync no-ops.
        if (objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            WorkRequest__c bridge = findWorkItemBridge(sourceId);
            if (bridge != null) {
                localRequestId = bridge.Id;
                if (localRecordId == null && validateLocalIdExists(targetType, bridge.WorkItemId__c)) {
                    localRecordId = bridge.WorkItemId__c;
                }
            }
        }

        // Final fallback: explicit TargetId from the payload. Validate it points
        // at a live record before trusting it — without validation, Database.update
        // against a deleted Id silently returns success and the sync becomes a
        // permanent no-op. Falling through to localRecordId == null routes to the
        // insert path, which creates a fresh record AND a ledger entry, allowing
        // the sender's bridge to auto-heal on its next response handshake.
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            try {
                Id castId = (Id) targetId;
                if (validateLocalIdExists(targetType, castId)) {
                    localRecordId = castId;
                } else {
                    System.debug(LoggingLevel.WARN, 'Inbound TargetId ' + targetId + ' resolves to deleted/missing record — falling through to insert path');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'TargetId invalid: ' + e.getMessage());
            }
        }

        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();

        // Set true only when the WorkLog content-dedup fallback (below) converts
        // an apparent INSERT into an UPDATE against a pre-existing local row. The
        // post-write block uses it to auto-heal the SourceId ledger so the next
        // poll resolves via the cheap ledger lookup instead of re-running the
        // content query.
        Boolean contentMatched = false;

        // For WorkLogs, resolve the parent WorkItem ID from the payload (not TargetId).
        // We intentionally do NOT strip cross-org lookup IDs from the caller's
        // payload here. The Pending-queue path (queuePendingChild) stashes
        // the raw payload via JSON.serialize(payload) for later replay, and
        // callers may re-invoke processInboundItem with the same Map instance
        // (idempotent re-delivery). Mutating the caller's map would:
        //   (1) cause the second call to lose the parent ref and fall into the
        //       insert path with a null WorkItemLookup__c, tripping the trigger's
        //       "A Work Item is required" addError, and
        //   (2) strip the stashed PayloadTxt__c of the WorkItemLookup__c key so
        //       DeliverySyncItemPendingResolver.replayPendingPayload cannot
        //       resolve the parent once it lands.
        // Strip now happens on a scoped copy just before mapFields runs.
        String parentWorkItemRef = targetId;
        if (objectType.endsWithIgnoreCase('WorkLog__c')) {
            String wiRef = (String) payload.get('WorkItemLookup__c');
            if (String.isBlank(wiRef)) {
                wiRef = (String) payload.get('delivery__WorkItemLookup__c');
            }
            // Legacy / peer-org outbounds may emit WorkItemId__c instead of
            // WorkItemLookup__c (a stale outbound payload assembly path used
            // the text-named field). Fall back to it when the lookup-named
            // key is absent. Without this, Nimba's 80 historical WorkLog
            // failures stayed Failed even after PR #737 because their
            // payloads only carry WorkItemId__c. Audit 2026-04-30 17:30Z.
            if (String.isBlank(wiRef)) {
                wiRef = (String) payload.get('WorkItemId__c');
            }
            if (String.isBlank(wiRef)) {
                wiRef = (String) payload.get('delivery__WorkItemId__c');
            }
            if (String.isNotBlank(wiRef)) {
                parentWorkItemRef = wiRef;
            }
        }
        // Same pattern for WorkItemComment — parent FK lives in the comment's
        // own WorkItemId__c field, NOT in TargetId. Without this lookup the
        // outer guard at the localParentId resolution block short-circuits
        // (parentWorkItemRef stays blank when sender didn't populate TargetId)
        // and the comment falls through to mapFields without WorkItemId__c
        // set → REQUIRED_FIELD_MISSING. Caused 6 MF-Prod failures still
        // present after the 2026-04-29 ingestor fix because that fix only
        // wired the Pending-queue fallback, not the parentRef resolution.
        if (objectType.containsIgnoreCase('WorkItemComment__c')) {
            String wiRef = (String) payload.get('WorkItemId__c');
            if (String.isBlank(wiRef)) {
                wiRef = (String) payload.get('delivery__WorkItemId__c');
            }
            if (String.isNotBlank(wiRef)) {
                parentWorkItemRef = wiRef;
            }
        }

        Id localParentId = null;
        if (localRecordId == null && String.isNotBlank(parentWorkItemRef) && (objectType.containsIgnoreCase('WorkItemComment__c') || objectType.equalsIgnoreCase('ContentVersion') || objectType.endsWithIgnoreCase('WorkLog__c'))) {
            
            // 1. Try to find parent via Request Bridge (Downstream Origin)
            WorkRequest__c parentBridge = findWorkItemBridge(parentWorkItemRef);
            if (parentBridge != null) {
                localParentId = parentBridge.WorkItemId__c;
                localRequestId = parentBridge.Id;
            }

            // 2. Try to find parent via the Ledger (Upstream Origin).
            // Route through findLocalId(), the canonical resolver: it filters to
            // Inbound rows, orders by CreatedDate DESC, and validates the
            // candidate still EXISTS (not deleted) before returning it. The
            // previous inline lookup took an unordered LIMIT 1 with no existence
            // check, so when a WorkItem was re-created in this org the ledger
            // held multiple rows for the same remote id and this could grab one
            // pointing at a now-deleted local WorkItem — stranding the child
            // WorkLog/Comment against a dead parent (root cause of the dh-prod
            // inbound stall, 2026-06-02).
            if (localParentId == null) {
                Schema.SObjectType wiType = findSObjectType('WorkItem__c');
                if (wiType != null) {
                    localParentId = findLocalId(wiType, parentWorkItemRef);
                }
            }

            // 3. Fallback: Check if parentWorkItemRef is actually a local ID
            if (localParentId == null) {
                try {
                    Id castId = (Id) parentWorkItemRef;
                    // getLocalName() (not getName()) — endsWithIgnoreCase works
                    // either way; bare form keeps the check readable.
                    if (castId.getSobjectType().getDescribe().getLocalName().endsWithIgnoreCase('WorkItem__c')) {
                        localParentId = castId;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'Parent resolution failed: ' + e.getMessage());
                }
            }

            if (objectType.containsIgnoreCase('WorkItemComment__c')) {
                if (localParentId == null) {
                    // Parent WorkItem hasn't synced yet → REQUIRED_FIELD_MISSING
                    // would fire on insert. Stage as Pending so the resolver
                    // re-runs after the parent lands. Same pattern WorkLog uses.
                    // Pre-fix this caused 6+ MF-Prod comment failures (2026-04-29
                    // audit) when chat fired before the parent WI sync.
                    return queuePendingChild(objectType, parentWorkItemRef, payload);
                }
                putSafe(recordToUpsert, 'WorkItemId__c', localParentId);
            }
            if (objectType.endsWithIgnoreCase('WorkLog__c')) {
                if (localParentId == null) {
                    // Parent WorkItem hasn't synced yet. Rather than hard-failing
                    // (which strands 165+ WorkLogs on nimba currently), stage
                    // the payload in a Pending SyncItem__c and enqueue the
                    // resolver. When the parent WorkItem lands via its own
                    // inbound, requeuePendingItems()/the resolver will flip
                    // this row to Queued and the processor retries the insert.
                    // See DeliverySyncItemPendingResolver.
                    return queuePendingChild(objectType, parentWorkItemRef, payload);
                }
                putSafe(recordToUpsert, 'WorkItemLookup__c', localParentId);
                // Find a local WorkRequest for the Master-Detail parent
                List<WorkRequest__c> localRequests = [
                    SELECT Id FROM WorkRequest__c
                    WHERE WorkItemId__c = :localParentId
                    WITH SYSTEM_MODE LIMIT 1
                ];
                if (!localRequests.isEmpty()) {
                    putSafe(recordToUpsert, 'RequestId__c', localRequests[0].Id);
                }

                // Content-based dedup FALLBACK. We only reach here when the
                // SourceId ledger AND the GlobalSourceId cross-path lookup both
                // missed (localRecordId == null is the outer guard). A WorkLog
                // re-synced after a manual reconciliation, or a relayed copy
                // whose ledger row was lost, would otherwise be inserted as a
                // billing-corrupting twin. Match on parent + date + hours +
                // description and convert to an UPDATE of the existing row.
                Id contentMatch = findWorkLogByContent(localParentId, payload);
                if (contentMatch != null) {
                    // Convert to an UPDATE of the existing row. Do NOT re-stamp the
                    // parent FKs: the matched record already carries the correct
                    // WorkItemLookup__c / RequestId__c, and RequestId__c is a
                    // master-detail field that is not editable on update — stamping
                    // it threw "Field RequestId__c is not editable". Leaving the FKs
                    // off the update SObject preserves the record's existing values.
                    localRecordId = contentMatch;
                    recordToUpsert = targetType.newSObject(localRecordId);
                    contentMatched = true;
                }
            }
        }

        // WorkItemDependency__c — dual-FK translation. Both endpoint
        // lookups (BlockingWorkItemLookup__c + BlockedWorkItemLookup__c)
        // carry sender-org WorkItem Ids that won't resolve locally. Translate
        // each via the inbound SyncItem ledger. Queue as Pending if EITHER
        // parent hasn't synced yet. Self-healing semantics match WorkLog and
        // WorkItemComment — when whichever parent arrives later, the
        // resolver replays this payload; if the OTHER parent is still
        // missing the replay re-queues against that one. Eventually
        // consistent. Lives outside the WorkLog/Comment/ContentVersion
        // conditional above because dep has its own dual-parent shape that
        // doesn't fit the single-parentWorkItemRef pattern.
        if (objectType.endsWithIgnoreCase('WorkItemDependency__c') && localRecordId == null) {
            String blockingRef = (String) payload.get('BlockingWorkItemLookup__c');
            if (String.isBlank(blockingRef)) {
                blockingRef = (String) payload.get('delivery__BlockingWorkItemLookup__c');
            }
            String blockedRef = (String) payload.get('BlockedWorkItemLookup__c');
            if (String.isBlank(blockedRef)) {
                blockedRef = (String) payload.get('delivery__BlockedWorkItemLookup__c');
            }
            Id localBlocking = resolveDependencyEndpoint(blockingRef);
            Id localBlocked = resolveDependencyEndpoint(blockedRef);
            if (localBlocking == null) {
                return queuePendingChild(objectType, blockingRef, payload);
            }
            if (localBlocked == null) {
                return queuePendingChild(objectType, blockedRef, payload);
            }
            putSafe(recordToUpsert, 'BlockingWorkItemLookup__c', localBlocking);
            putSafe(recordToUpsert, 'BlockedWorkItemLookup__c', localBlocked);
        }

        // For WorkLogs: now that the Pending-queue early-return is past, strip
        // the remote-ref lookup keys on a scoped copy so mapFields doesn't
        // overwrite the resolved local parent Id with a cross-org string value.
        // Non-WorkLog paths pass the payload through unchanged.
        Map<String, Object> fieldPayload = payload;
        if (objectType.endsWithIgnoreCase('WorkItemDependency__c')) {
            // Same defense as WorkLog — strip the raw sender-org FK strings
            // on a scoped copy so mapFields doesn't overwrite the local Ids
            // we just resolved via the ledger.
            fieldPayload = new Map<String, Object>(payload);
            fieldPayload.remove('BlockingWorkItemLookup__c');
            fieldPayload.remove('delivery__BlockingWorkItemLookup__c');
            fieldPayload.remove('BlockedWorkItemLookup__c');
            fieldPayload.remove('delivery__BlockedWorkItemLookup__c');
        }
        if (objectType.endsWithIgnoreCase('WorkLog__c')) {
            fieldPayload = new Map<String, Object>(payload);
            fieldPayload.remove('WorkItemLookup__c');
            fieldPayload.remove('delivery__WorkItemLookup__c');
            fieldPayload.remove('RequestId__c');
            fieldPayload.remove('delivery__RequestId__c');
            // Strip raw cross-org Id text fields too. WorkLog has WorkItemId__c
            // alongside WorkItemLookup__c — without stripping, mapFields writes
            // the sender-org Id straight into the local field and SF rejects with
            // FIELD_INTEGRITY_EXCEPTION ("id value of incorrect type"). Caused 150
            // failures on Nimba 2026-04-23..29 before this fix.
            fieldPayload.remove('WorkItemId__c');
            fieldPayload.remove('delivery__WorkItemId__c');
        }
        // Same defense for WorkItemComment — strip the raw cross-org parent
        // FK from payload so mapFields can't overwrite the resolved local Id
        // we set via putSafe in the comment branch above.
        if (objectType.containsIgnoreCase('WorkItemComment__c')) {
            if (fieldPayload == payload) {
                fieldPayload = new Map<String, Object>(payload);
            }
            fieldPayload.remove('WorkItemId__c');
            fieldPayload.remove('delivery__WorkItemId__c');
        }

        // Cross-org parent FK translation for WorkItem__c: the payload's
        // ParentWorkItemLookup__c is the sender-org Id and won't resolve locally.
        // Use the SyncItem ledger to find the local twin; if not found yet
        // (parent hasn't synced), leave unset — child arrives flat and re-syncs
        // when source touches the field again. Children typically follow parents
        // in dispatch order, so the not-found case is rare.
        if (objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            Object parentRefRaw = payload.get('ParentWorkItemLookup__c');
            if (parentRefRaw == null) {
                parentRefRaw = payload.get('delivery__ParentWorkItemLookup__c');
            }
            String parentRef = parentRefRaw == null ? null : String.valueOf(parentRefRaw);
            if (String.isNotBlank(parentRef)) {
                // WorkItem and WorkLog branches are mutually exclusive on objectType,
                // so fieldPayload still aliases payload here — clone to avoid mutating
                // the caller's map and to strip the cross-org Id before mapFields runs
                // (otherwise mapFields would attempt to write a stranger-org Id into
                // the Lookup field and fail with INVALID_CROSS_REFERENCE_KEY).
                fieldPayload = new Map<String, Object>(payload);
                fieldPayload.remove('ParentWorkItemLookup__c');
                fieldPayload.remove('delivery__ParentWorkItemLookup__c');

                Id localParent = null;
                List<SyncItem__c> parentLedger = [
                    SELECT LocalRecordIdTxt__c FROM SyncItem__c
                    WHERE RemoteExternalIdTxt__c = :parentRef
                      AND ObjectTypePk__c = 'WorkItem__c'
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
                if (!parentLedger.isEmpty() && String.isNotBlank((String) parentLedger[0].LocalRecordIdTxt__c)) {
                    try { localParent = (Id) parentLedger[0].LocalRecordIdTxt__c; } catch (Exception e) {
                        System.debug(LoggingLevel.FINE, 'Parent ledger Id cast failed: ' + e.getMessage());
                    }
                }
                // Fallback: maybe parentRef is already a valid local Id (echo path).
                if (localParent == null) {
                    localParent = tryAsLocalWorkItemId(parentRef);
                }
                if (localParent != null) {
                    putSafe(recordToUpsert, 'ParentWorkItemLookup__c', localParent);
                }
                // If localParent is null, we deliberately leave the field unset.
                // Children typically arrive after parents in dispatcher order; the
                // rare out-of-order case heals when the source touches the field
                // and re-emits the payload (eventual consistency).
            }
        }

        mapFields(recordToUpsert, fieldPayload, targetType);

        // ==========================================
        // NEW: AUTO-PARENTING THE UPSTREAM CLIENT
        // ==========================================
        // Check for Default Billing Entity override
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        String defaultBillingEntityId = settings != null ? (String) settings.get('DefaultBillingEntityIdTxt__c') : null;

        if (String.isNotBlank(defaultBillingEntityId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            // Override: Use the configured billing entity instead of sender-org auto-detection
            try {
                putSafe(recordToUpsert, 'ClientNetworkEntityLookup__c', (Id) defaultBillingEntityId);
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Invalid DefaultBillingEntityIdTxt__c: ' + e.getMessage());
            }
        } else if (String.isNotBlank(senderOrgId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            try {
                // Grab the 15-char base ID to prevent 18-char mismatch failures on Text fields
                String baseOrgId = senderOrgId.length() >= 15 ? senderOrgId.substring(0, 15) + '%' : senderOrgId;

                // Look at BOTH OrgIdTxt__c and RemoteExternalIdTxt__c, AND restrict to
                // Client/Both entity types so we never accidentally auto-parent to a
                // Vendor record when both Vendor and Client entities exist for the same
                // org id. Pre-fix this query just took LIMIT 1 with no type filter, which
                // could attach an inbound WorkItem to the wrong NetworkEntity record.
                String query = 'SELECT Id, EntityTypePk__c FROM NetworkEntity__c'
                    + ' WHERE (OrgIdTxt__c LIKE :baseOrgId OR RemoteExternalIdTxt__c LIKE :baseOrgId)'
                    + ' AND EntityTypePk__c IN (\'Client\', \'Both\')'
                    + ' ORDER BY CreatedDate ASC LIMIT 1';

                if (String.isNotBlank(getNamespacePrefix())) {
                    query = query.replace('NetworkEntity__c', getNamespacePrefix() + 'NetworkEntity__c')
                                 .replace('OrgIdTxt__c', getNamespacePrefix() + 'OrgIdTxt__c')
                                 .replace('RemoteExternalIdTxt__c', getNamespacePrefix() + 'RemoteExternalIdTxt__c')
                                 .replace('EntityTypePk__c', getNamespacePrefix() + 'EntityTypePk__c');
                }

                List<SObject> entities = Database.query(query); // NOPMD
                if (!entities.isEmpty()) {
                    String eType = (String)entities[0].get(entities[0].getSObjectType().getDescribe().fields.getMap().containsKey('EntityTypePk__c') ? 'EntityTypePk__c' : getNamespacePrefix() + 'EntityTypePk__c');

                    // If the sender is registered as a Client in our org, lock them in as the Client for this Work Item
                    if (eType == 'Client' || eType == 'Both') {
                        putSafe(recordToUpsert, 'ClientNetworkEntityLookup__c', (Id)entities[0].get('Id'));
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Failed to resolve Sender Network Entity for Auto-Parenting: ' + e.getMessage());
            }
        }

        // Connection Approval: New inbound NetworkEntity records require admin approval
        if (objectType.endsWithIgnoreCase('NetworkEntity__c') && recordToUpsert.Id == null) {
            putSafe(recordToUpsert, 'ConnectionStatusPk__c', 'Pending Approval');
        }

        // v0.200 defense-in-depth: reject blank WorkItem creates. Background —
        // cloudnimbus's Slack approval handler once POSTed empty
        // suggestedWorkRequest objects and dh-prod accepted them, creating
        // 40 blank WorkItems. Only applies on INSERT (recordToUpsert.Id null);
        // legitimate cross-org updates may arrive with sparse payloads that
        // intentionally leave name/description unchanged.
        if (recordToUpsert.Id == null
                && objectType.endsWithIgnoreCase('WorkItem__c')
                && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            String incomingBrief = (String) payload.get('BriefDescriptionTxt__c');
            if (String.isBlank(incomingBrief)) {
                incomingBrief = (String) payload.get(getNamespacePrefix() + 'BriefDescriptionTxt__c');
            }
            String incomingName = (String) payload.get('Name');
            if (String.isBlank(incomingBrief) && String.isBlank(incomingName)) {
                throw new DeliverySyncEngine.SyncException(
                    'Blank WorkItem create rejected at ingestor: payload must '
                    + 'include BriefDescriptionTxt__c or Name. SourceId: ' + sourceId);
            }
        }

        // Predecisional gate (5/5 incident): refuse inbound WorkItem writes
        // whose payload carries a non-null MarkedPredecisionalDateTime__c
        // unless the receiving org has opted in via DeliveryHubSettings__c.
        // EnablePredecisionalIngestDateTime__c. The 5 QBAG-* records leaked
        // from a sandbox into production because nothing on the receiver
        // side knew they were proposal-staging only. Applies to both insert
        // and update so a sandbox-side flip can't mutate already-promoted
        // production records back into a predecisional state.
        if (objectType.endsWithIgnoreCase('WorkItem__c')
                && !objectType.endsWithIgnoreCase('WorkItemComment__c')
                && isPredecisionalPayload(payload)) {
            DeliveryHubSettings__c gateSettings = DeliveryHubSettings__c.getOrgDefaults();
            Boolean ingestEnabled = gateSettings != null
                && gateSettings.EnablePredecisionalIngestDateTime__c != null;
            if (!ingestEnabled) {
                throw new DeliverySyncEngine.SyncException(
                    'Predecisional WorkItem refused at ingestor: receiving org '
                    + 'has not enabled predecisional ingest. Mark the source '
                    + 'record non-predecisional or set '
                    + 'DeliveryHubSettings__c.EnablePredecisionalIngestDateTime__c '
                    + 'to opt-in. SourceId: ' + sourceId);
            }
        }

        // Tell trigger handlers that the source org owns auto-populated fields
        // (e.g. WorkItem__c.ActivatedDateTime__c) so receiver-side defaults
        // don't overwrite the source value during ingest.
        Boolean priorInboundFlag = DeliveryTriggerControl.inboundSyncContext;
        DeliveryTriggerControl.inboundSyncContext = true;
        try {
            // Capture insert-vs-update BEFORE the write stamps an Id onto a
            // freshly-inserted record — used to gate the post-commit Slack
            // notification to NetworkEntity INSERTs only (not updates).
            Boolean wasInsert = (recordToUpsert.Id == null);

            // Atomicity: the record write and its ledger write must commit or
            // roll back together. If the ledger insert fails after the record
            // write succeeds, the item would otherwise be silently un-tracked
            // (insert) or re-content-queried forever (content match) while the
            // record persists. A savepoint + rethrow lets the sync item
            // legitimately re-deliver clean instead.
            Savepoint sp = Database.setSavepoint();
            try {
                if (recordToUpsert.Id != null) {
                    Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);

                    // Auto-heal the SourceId ledger after a content-matched
                    // UPDATE. createLedgerEntry only fires on the INSERT branch,
                    // so without this a content match leaves no SourceId ledger
                    // row and the next poll re-runs the expensive content query.
                    // Guard against duplicating a row that already exists.
                    if (contentMatched
                            && String.isNotBlank(sourceId)
                            && !ledgerEntryExists(objectType, sourceId)) {
                        createLedgerEntry(objectType, sourceId, recordToUpsert.Id, localRequestId, globalSourceId);
                    }
                } else {
                    Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);

                    // Pass the localRequestId and globalSourceId down to link the Sync Item
                    createLedgerEntry(objectType, sourceId, recordToUpsert.Id, localRequestId, globalSourceId);

                    if (objectType.equalsIgnoreCase('ContentVersion') && localParentId != null) {
                        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :recordToUpsert.Id LIMIT 1].ContentDocumentId;
                        Database.insert(new ContentDocumentLink(
                            ContentDocumentId = contentDocId, LinkedEntityId = localParentId, ShareType = 'V', Visibility = 'AllUsers'
                        ), AccessLevel.SYSTEM_MODE);
                    }
                }
            } catch (Exception e) {
                Database.rollback(sp);
                throw e;
            }

            // Notify admins of pending connection requests AFTER the atomic
            // write+ledger commits. Kept outside the savepoint block because
            // notifyPendingConnection issues an HTTP callout, and an open
            // savepoint counts as uncommitted work that blocks callouts. Only
            // reachable on a fresh NetworkEntity insert (recordToUpsert was just
            // created in the else-branch, so it carries a new Id and the
            // Pending-Approval status stamped earlier).
            if (wasInsert && objectType.endsWithIgnoreCase('NetworkEntity__c') && recordToUpsert.Id != null) {
                notifyPendingConnection(recordToUpsert);
            }
        } finally {
            DeliveryTriggerControl.inboundSyncContext = priorInboundFlag;
        }

        // ==========================================
        // ECHO SUPPRESSION: REGISTER ORIGIN ROUTE
        // ==========================================
        if (localRequestId != null) {
            // Origin was a Downstream Vendor via WorkRequest__c
            DeliverySyncEngine.ignoreOrigin(localRequestId);
        } else {
            // No Request found. Origin must be the Upstream Client.
            Id parentWorkItemId = (objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) ? recordToUpsert.Id : localParentId;
            
            if (parentWorkItemId != null) {
                try {
                    // Look up the ClientNetworkEntityLookup__c of the target Work Item (which we just stamped!)
                    String query = 'SELECT ClientNetworkEntityLookup__c FROM WorkItem__c WHERE Id = :parentWorkItemId LIMIT 1';
                    if (String.isNotBlank(getNamespacePrefix())) {
                        query = query.replace('WorkItem__c', getNamespacePrefix() + 'WorkItem__c')
                                     .replace('ClientNetworkEntityLookup__c', getNamespacePrefix() + 'ClientNetworkEntityLookup__c');
                    }
                    
                    List<SObject> tix = Database.query(query); // NOPMD
                    if (!tix.isEmpty()) {
                        Id clientId = (Id)tix[0].get(tix[0].getSObjectType().getDescribe().fields.getMap().containsKey('ClientNetworkEntityLookup__c') ? 'ClientNetworkEntityLookup__c' : getNamespacePrefix() + 'ClientNetworkEntityLookup__c');
                        if (clientId != null) {
                            DeliverySyncEngine.ignoreOrigin(clientId);
                        }
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'Failed to resolve Upstream Client entity for Echo Suppression: ' + e.getMessage());
                }
            }
        }

        return recordToUpsert.Id;
    }

    /**
     * @description Resolves a remote source Id to a local record Id by walking the
     * Inbound ledger newest-first and returning the first entry whose local target
     * still exists. Stale ledger entries (whose local record has been deleted) are
     * skipped, which is essential to prevent the receiver from resolving to a
     * deleted Id and silently no-op'ing the upsert.
     *
     * Previously this lookup was skipped entirely for WorkItem__c (the bridge was
     * assumed sufficient), but bridges go stale when their local target is deleted
     * and there was no ledger fallback — leaving the receiver with no way to
     * relocate the canonical record.
     * @param type The SObjectType of the record being resolved.
     * @param remoteId The remote source Id to look up in the inbound ledger.
     * @return The local record Id of the active record, or null if no live mapping exists.
     */
    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        if (String.isBlank(remoteId)) {
            return null;
        }
        // getLocalName() (not getName()) — returns the bare form directly.
        // The stripNamespace() wrapper becomes a no-op safety net (kept for
        // defense in depth in case the schema describe ever returns prefixed).
        String cleanName = stripNamespace(type.getDescribe().getLocalName());

        List<SyncItem__c> ledger = [
            SELECT LocalRecordIdTxt__c
            FROM SyncItem__c
            WHERE RemoteExternalIdTxt__c = :remoteId
            AND ObjectTypePk__c = :cleanName
            AND DirectionPk__c = 'Inbound'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        for (SyncItem__c entry : ledger) {
            Id candidate = (Id) entry.LocalRecordIdTxt__c;
            if (validateLocalIdExists(type, candidate)) {
                return candidate;
            }
        }
        return null;
    }

    /**
     * @description Translates a sender-org WorkItem reference to a local Id
     *              for use in dual-FK records (currently
     *              WorkItemDependency__c). Mirrors the inline lookup pattern
     *              used for single-parent records (WorkLog/WorkItemComment)
     *              but extracted as a helper since dep needs it called twice.
     *              Order: ledger lookup, then "is it already a local Id"
     *              fallback (echo path).
     * @param ref The sender-org WorkItem Id string from the payload.
     * @return The validated local WorkItem Id, or null if unresolvable.
     */
    private static Id resolveDependencyEndpoint(String ref) {
        if (String.isBlank(ref)) {
            return null;
        }
        // Route through findLocalId(): Inbound-filtered, CreatedDate DESC,
        // existence-validated — same hardening as the WorkLog/Comment parent
        // path. The previous inline LIMIT 1 (unordered) could pick a stale row
        // pointing at a re-created WorkItem's deleted predecessor.
        Schema.SObjectType wiType = findSObjectType('WorkItem__c');
        if (wiType != null) {
            Id resolved = findLocalId(wiType, ref);
            if (resolved != null) {
                return resolved;
            }
        }
        // Echo-path fallback: maybe ref is already a local Id.
        return tryAsLocalWorkItemId(ref);
    }

    /**
     * @description Content-based dedup fallback for inbound WorkLogs. When the
     *              SourceId ledger AND the GlobalSourceId cross-path lookup both
     *              miss (e.g. a WorkLog was inserted manually during a
     *              reconciliation replay, or a relayed copy lost its ledger row),
     *              this finds an existing local WorkLog whose billing-identity
     *              tuple matches the payload so the ingestor converts to an
     *              UPDATE instead of inserting a duplicate that corrupts the
     *              monthly invoice.
     *
     *              Key = parent WorkItem + work date + hours (scale 2) +
     *              description ONLY. ResourceTitleTxt__c is deliberately excluded
     *              because it is NOT transmitted on the outbound WorkLog payload
     *              (confirmed) — including it would never match.
     * @param localParentId The resolved local parent WorkItem Id.
     * @param payload The deserialized inbound WorkLog payload.
     * @return The matching local WorkLog Id, or null when no safe content key
     *         can be formed or no row matches.
     */
    private static Id findWorkLogByContent(Id localParentId, Map<String, Object> payload) {
        if (localParentId == null) {
            return null;
        }
        Object hours = payload.get('HoursLoggedNumber__c');
        if (hours == null) {
            hours = payload.get('delivery__HoursLoggedNumber__c');
        }
        String dateStr = (String) payload.get('WorkDateDate__c');
        if (String.isBlank(dateStr)) {
            dateStr = (String) payload.get('delivery__WorkDateDate__c');
        }
        Object descRaw = payload.get('WorkDescriptionTxt__c');
        if (descRaw == null) {
            descRaw = payload.get('delivery__WorkDescriptionTxt__c');
        }
        String descTxt = descRaw == null ? null : String.valueOf(descRaw);

        // Can't form a safe billing-identity key without both hours and date.
        if (hours == null || String.isBlank(dateStr)) {
            return null;
        }

        Date d;
        Decimal h;
        try {
            d = Date.valueOf(dateStr);
            // Route through String.valueOf so a JSON.deserializeUntyped value
            // arriving as Double (the wire shape, e.g. 4.5) casts cleanly to
            // Decimal — a direct (Decimal) cast on a boxed Double throws.
            h = Decimal.valueOf(String.valueOf(hours)).setScale(2);
        } catch (Exception e) {
            // Unparseable date/hours → no safe content key; fall through to insert.
            return null;
        }

        List<WorkLog__c> candidates = [
            SELECT Id, WorkDescriptionTxt__c
            FROM WorkLog__c
            WHERE WorkItemLookup__c = :localParentId
            AND WorkDateDate__c = :d
            AND HoursLoggedNumber__c = :h
            WITH SYSTEM_MODE
        ];

        for (WorkLog__c wl : candidates) {
            // Treat null and '' as equal so a blank-description payload still
            // dedupes against a blank-description existing row.
            Boolean descMatches = String.isBlank(descTxt)
                ? String.isBlank(wl.WorkDescriptionTxt__c)
                : descTxt == wl.WorkDescriptionTxt__c;
            if (descMatches) {
                return wl.Id;
            }
        }
        return null;
    }

    /**
     * @description Cross-path dedup: returns the local record Id of any
     *              existing inbound ledger entry for the same GlobalSourceId,
     *              regardless of which sender's SourceId originally created
     *              it. Used to prevent duplicate inserts when the same record
     *              arrives via two transitive paths (e.g. MF-direct AND
     *              MF → Nimba → dh-prod) — those paths carry the same
     *              GlobalSourceId but different SourceIds.
     *
     *              Returns null when no matching ledger entry exists OR when
     *              every candidate's local record has been deleted. Falls
     *              through to the normal insert path in either case.
     * @param type The expected SObjectType of the local record.
     * @param globalSourceId The origin-record Id stamped at the birthplace.
     * @return The validated local record Id, or null if none.
     */
    private static Id findLocalIdByGlobalSource(Schema.SObjectType type, String globalSourceId) {
        if (String.isBlank(globalSourceId)) {
            return null;
        }
        // getLocalName() (not getName()) — same rationale as findLocalId() above.
        String cleanName = stripNamespace(type.getDescribe().getLocalName());

        List<SyncItem__c> ledger = [
            SELECT LocalRecordIdTxt__c
            FROM SyncItem__c
            WHERE GlobalSourceIdTxt__c = :globalSourceId
            AND ObjectTypePk__c = :cleanName
            AND DirectionPk__c = 'Inbound'
            AND LocalRecordIdTxt__c != NULL
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        for (SyncItem__c entry : ledger) {
            Id candidate = (Id) entry.LocalRecordIdTxt__c;
            if (validateLocalIdExists(type, candidate)) {
                return candidate;
            }
        }
        return null;
    }

    /**
     * @description Verifies that a candidate local record Id refers to a live row
     * (not deleted or in the recycle bin). Returns false for null Ids, Ids of the
     * wrong sobject type, and Ids that no longer resolve to a record.
     *
     * This guard exists because Salesforce's Database.update accepts a deleted
     * record's Id without throwing — the call returns success and silently
     * does nothing, which is exactly how stale bridges produced multi-day sync
     * drift before this fix.
     * @param type The expected SObjectType of the candidate Id.
     * @param candidateId The Id to validate.
     * @return True if the Id refers to an active local record of the expected type.
     */
    private static Boolean validateLocalIdExists(Schema.SObjectType type, Id candidateId) {
        if (candidateId == null || candidateId.getSobjectType() != type) {
            return false;
        }
        // getName() (NOT getLocalName()) — LOAD-BEARING: dynamic SOQL requires
        // the namespace-prefixed form ('delivery__Foo__c') in the packaging /
        // subscriber context, otherwise the query fails to resolve the SObject.
        // Per [[get-local-name-vs-get-name-nuance]] memory — do NOT migrate.
        String soql = 'SELECT Id FROM ' + type.getDescribe().getName() + ' WHERE Id = :candidateId LIMIT 1';
        List<SObject> existing = Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'candidateId' => candidateId },
            AccessLevel.SYSTEM_MODE
        );
        return !existing.isEmpty();
    }

    /**
     * @description Handles the "metadata + binary-by-reference" inbound file
     *              path. Resolves the local parent WorkItem, inserts an
     *              inbound SyncItem__c ledger row carrying the metadata, and
     *              enqueues DeliveryFileBytesFetcher to pull the bytes from
     *              the source org via authenticated callout. Idempotent per
     *              GlobalSourceId — duplicate inbounds (e.g. re-polls) re-use
     *              the existing ledger row rather than forking new fetchers.
     * @param payload Deserialized ContentVersion metadata payload.
     * @return The SyncItem__c Id that owns this fetch (sync row Id, not the
     *         eventual ContentVersion Id — that populates once bytes arrive).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    private static Id handlePullCalloutFile(Map<String, Object> payload) {
        String sourceId = (String) payload.get('SourceId');
        String targetId = (String) payload.get('TargetId');
        String globalSourceId = (String) payload.get('GlobalSourceId');
        Id localParentId = resolveParentWorkItem(targetId);

        // Idempotency: de-dupe by (GlobalSourceId or SourceId) — if we already
        // have an inbound ledger row for this file we do NOT re-enqueue the
        // fetcher. This mirrors the create-once semantics the generic inbound
        // path gets for free via findLocalId.
        String dedupeKey = String.isNotBlank(globalSourceId) ? globalSourceId : sourceId;
        if (String.isNotBlank(dedupeKey)) {
            List<SyncItem__c> existing = [
                SELECT Id FROM SyncItem__c
                WHERE DirectionPk__c = 'Inbound'
                AND ObjectTypePk__c = 'ContentVersion'
                AND (GlobalSourceIdTxt__c = :dedupeKey OR RemoteExternalIdTxt__c = :dedupeKey)
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }
        }

        SyncItem__c ledger = new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'ContentVersion',
            RemoteExternalIdTxt__c = sourceId,
            GlobalSourceIdTxt__c = globalSourceId,
            WorkItemLookup__c = localParentId,
            PayloadTxt__c = JSON.serialize(payload)
        );
        Database.insert(ledger, AccessLevel.SYSTEM_MODE);

        // Enqueue the callout Queueable unless we're in a context that
        // already has pending callouts pending commit (avoid nested queueable
        // limit). Tests rely on Test.startTest/stopTest boundaries to flush.
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new DeliveryFileBytesFetcher(ledger.Id, localParentId));
        }

        return ledger.Id;
    }

    /**
     * @description Resolves a metadata payload's TargetId into a local
     *              WorkItem Id, walking bridge → ledger → direct-id fallback.
     * @param targetRef Identifier string from payload.TargetId (bridge
     *                  RemoteWorkItemIdTxt__c, ledger RemoteExternalIdTxt__c,
     *                  or a local Id as last resort).
     * @return Local WorkItem Id, or null when nothing resolves.
     */
    private static Id resolveParentWorkItem(String targetRef) {
        if (String.isBlank(targetRef)) {
            return null;
        }
        WorkRequest__c bridge = findWorkItemBridge(targetRef);
        if (bridge != null && bridge.WorkItemId__c != null) {
            return bridge.WorkItemId__c;
        }
        List<SyncItem__c> ledger = [
            SELECT LocalRecordIdTxt__c FROM SyncItem__c
            WHERE RemoteExternalIdTxt__c = :targetRef
            AND ObjectTypePk__c = 'WorkItem__c'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!ledger.isEmpty()) {
            try {
                return (Id) ledger[0].LocalRecordIdTxt__c;
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Invalid ledger LocalRecordIdTxt__c: ' + e.getMessage());
            }
        }
        try {
            Id castId = (Id) targetRef;
            // getLocalName() (not getName()) — endsWithIgnoreCase works either way.
            if (castId.getSobjectType().getDescribe().getLocalName().endsWithIgnoreCase('WorkItem__c')) {
                return castId;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'TargetId not a local WorkItem Id: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description Cast a string to an Id and confirm it points at a local
     *              WorkItem__c record. Returns null on any cast/describe failure
     *              (silent — callers fall through to other resolution strategies).
     * @param candidate String that may or may not be a local 15/18-char WorkItem__c Id.
     * @return Validated WorkItem__c Id, or null if the cast fails or the
     *         resulting record points at a different SObject type.
     */
    private static Id tryAsLocalWorkItemId(String candidate) {
        if (String.isBlank(candidate)) {
            return null;
        }
        try {
            Id castId = (Id) candidate;
            // getLocalName() (not getName()) — endsWithIgnoreCase works either way.
            return castId.getSobjectType().getDescribe().getLocalName().endsWithIgnoreCase('WorkItem__c') ? castId : null;
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Candidate is not a local WorkItem Id: ' + e.getMessage());
            return null;
        }
    }

    // Helper to grab both the Work Item ID and the Request ID
    private static WorkRequest__c findWorkItemBridge(String remoteWorkItemId) {
        List<WorkRequest__c> reqs = [SELECT Id, WorkItemId__c FROM WorkRequest__c WHERE RemoteWorkItemIdTxt__c = :remoteWorkItemId WITH SYSTEM_MODE LIMIT 1];
        return reqs.isEmpty() ? null : reqs[0];
    }

    /**
     * @description Returns true when an Inbound ledger row already exists for
     *              the given (objType, remoteId/SourceId) pair. Used to guard
     *              the content-match auto-heal so a converted UPDATE doesn't
     *              write a duplicate ledger row when one is already present.
     * @param objType The (possibly namespaced) object type.
     * @param remoteId The sender's SourceId.
     * @return True if an inbound ledger entry already exists.
     */
    private static Boolean ledgerEntryExists(String objType, String remoteId) {
        if (String.isBlank(remoteId)) {
            return false;
        }
        String cleanName = stripNamespace(objType);
        List<SyncItem__c> existing = [
            SELECT Id FROM SyncItem__c
            WHERE DirectionPk__c = 'Inbound'
            AND ObjectTypePk__c = :cleanName
            AND RemoteExternalIdTxt__c = :remoteId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return !existing.isEmpty();
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void createLedgerEntry(String objType, String remoteId, Id localId, Id requestId, String globalSourceId) {
        String cleanName = stripNamespace(objType);
        SyncItem__c ledger = new SyncItem__c(
            DirectionPk__c = 'Inbound', 
            StatusPk__c = 'Synced', 
            ObjectTypePk__c = cleanName,
            RemoteExternalIdTxt__c = remoteId, 
            LocalRecordIdTxt__c = (String)localId, 
            PayloadTxt__c = 'Ledger Mapping Created',
            RequestLookup__c = requestId,
            GlobalSourceIdTxt__c = globalSourceId // Stamps the trace ID!
        );
        
        populateLookupField(ledger, cleanName, localId);
        Database.insert(ledger, AccessLevel.SYSTEM_MODE);
    }

    private static void populateLookupField(SObject item, String cleanName, Id recordId) {
        String lookupField;
        if (cleanName.endsWithIgnoreCase('__c')) {
            lookupField = cleanName.substringBeforeLast('__c').replace('_', '') + 'Id__c';
        } else {
            lookupField = cleanName + 'Id__c';
        }
        
        try {
            item.put(lookupField, recordId);
        } catch (Exception e1) {
            try {
                item.put('delivery__' + lookupField, recordId);
            } catch (Exception e2) {
                System.debug(LoggingLevel.FINE, 'Ledger mapping skipped for ' + cleanName + ': ' + e2.getMessage());
            }
        }
    }

    @SuppressWarnings('PMD.CyclomaticComplexity')
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        Map<String, SObjectField> cleanNameIndex = new Map<String, SObjectField>();
        for (String fieldApi : fieldMap.keySet()) {
            cleanNameIndex.put(stripNamespace(fieldApi).toLowerCase(), fieldMap.get(fieldApi));
        }

        for (String key : payload.keySet()) {
            // Ensure the system fields are ignored during standard field mapping
            if (key == 'SourceId' || key == 'TargetId' || key == 'GlobalSourceId' || key == 'SenderOrgId') { continue; }
            
            String searchKey = stripNamespace(key).toLowerCase();
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                Object val = payload.get(key);
                Schema.DescribeFieldResult dfr = field.getDescribe();
                // Schema-inherent skip: formula/calculated fields. `isCalculated()` is
                // safe across all permission contexts. Do NOT use `isUpdateable()`/
                // `isCreateable()` — those are user-FLS-dependent and will false-positive
                // on legit writable fields in non-admin contexts (bit us in PR #681).
                if (dfr.isCalculated()) { continue; }
                // Defensively wrap each put: system-maintained fields (CreatedDate,
                // SystemModstamp, auto-numbers) and any other platform-immutable field
                // throw SObjectException on put. We swallow per-field so one bad payload
                // key doesn't strand the whole record. Logged at FINE for forensics.
                try {
                    if (val == null) {
                        record.put(field, null);
                        continue;
                    }
                    Schema.DisplayType dtype = dfr.getType();
                    if (dtype == Schema.DisplayType.DATE) {
                        record.put(field, Date.valueOf((String)val));
                    } else if (dtype == Schema.DisplayType.DATETIME) {
                        record.put(field, (DateTime)JSON.deserialize('"' + val + '"', DateTime.class));
                    } else if (dtype == Schema.DisplayType.BASE64) {
                        record.put(field, EncodingUtil.base64Decode((String)val));
                    } else {
                        record.put(field, val);
                    }
                } catch (Exception putEx) {
                    System.debug(LoggingLevel.FINE, 'mapFields skipped ' + key + ': ' + putEx.getMessage());
                }
            }
        }
    }

    private static void putSafe(SObject rec, String fieldName, Object val) {
        Map<String, SObjectField> fieldMap = rec.getSObjectType().getDescribe().fields.getMap();
        String target = stripNamespace(fieldName).toLowerCase();
        for (String fieldApi : fieldMap.keySet()) {
            if (stripNamespace(fieldApi).toLowerCase() == target) {
                rec.put(fieldMap.get(fieldApi), val);
                return;
            }
        }
    }

    /**
     * @description Checks whether an inbound WorkItem payload carries a
     * non-null MarkedPredecisionalDateTime__c value. Tolerates both the
     * bare and namespaced field keys; tolerates the value arriving as a
     * String, DateTime, or pre-serialized number (different sender stacks
     * shape DateTimes differently).
     * @param payload Deserialized inbound payload.
     * @return True when the payload marks the record predecisional.
     */
    private static Boolean isPredecisionalPayload(Map<String, Object> payload) {
        if (payload == null) {
            return false;
        }
        Object raw = payload.get('MarkedPredecisionalDateTime__c');
        if (raw == null) {
            raw = payload.get(getNamespacePrefix() + 'MarkedPredecisionalDateTime__c');
        }
        if (raw == null) {
            return false;
        }
        if (raw instanceof String) {
            return String.isNotBlank((String) raw);
        }
        return true;
    }

    private static Boolean hasField(Schema.SObjectType type, String fieldName) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        String target = stripNamespace(fieldName).toLowerCase();
        for (String fieldApi : fieldMap.keySet()) {
            if (stripNamespace(fieldApi).toLowerCase() == target) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Sends a Slack notification when a new NetworkEntity arrives with
     * Pending Approval status so admins are aware of incoming connection requests.
     * @param entity The newly inserted NetworkEntity__c SObject
     */
    private static void notifyPendingConnection(SObject entity) {
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
                return;
            }
            String entityName = (String) entity.get('Name');
            if (String.isBlank(entityName)) {
                entityName = 'Unknown Org';
            }
            String orgUrl = Url.getOrgDomainUrl().toExternalForm();
            // getName() (NOT getLocalName()) — LOAD-BEARING: Lightning record URL
            // requires the namespace-prefixed form. /lightning/r/delivery__NetworkEntity__c/...
            // resolves in subscriber installs; the bare form 404s.
            // Per [[get-local-name-vs-get-name-nuance]] memory — do NOT migrate.
            String recordUrl = orgUrl + '/lightning/r/' + entity.getSObjectType().getDescribe().getName() + '/' + entity.Id + '/view';
            Map<String, String> notificationContext = new Map<String, String>{
                'entityName' => entityName,
                'recordUrl' => recordUrl
            };
            DeliverySlackService.postConnectionApprovalRequest(JSON.serialize(notificationContext));
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Failed to notify pending connection: ' + e.getMessage());
        }
    }

    /**
     * @description Inserts an inbound Pending SyncItem__c carrying the raw child
     *              payload (WorkLog or Comment) so it can be re-processed once
     *              the parent WorkItem lands. Enqueues DeliverySyncItemPendingResolver
     *              unless we're already at the queueable limit — the scheduled
     *              tick sweep (DeliveryHubScheduler.requeuePendingItems) is a
     *              safety net that catches anything we couldn't enqueue inline.
     *              Idempotent on (objectType, parentWorkItemRef, SourceId):
     *              duplicate re-deliveries reuse the existing Pending row.
     *
     *              Generalized from queuePendingWorkLog 2026-04-29 to also handle
     *              WorkItemComment__c (was hard-failing with REQUIRED_FIELD_MISSING
     *              when parent hadn't synced).
     * @param objectType        The payload object type ('WorkLog__c' or 'WorkItemComment__c').
     * @param parentWorkItemRef Remote WorkItem identifier the child is parented to.
     * @param payload           Full deserialized payload, stashed as JSON for replay.
     * @return The Pending SyncItem__c Id so the caller can return a non-null Id
     *         to the sync service (which treats null as failure).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Id queuePendingChild(String objectType, String parentWorkItemRef, Map<String, Object> payload) {
        String sourceId = (String) payload.get('SourceId');
        String globalSourceId = (String) payload.get('GlobalSourceId');
        String stripped = stripNamespace(objectType);

        // Idempotency: if we already hold a Pending row for this (objectType, parentRef, sourceId)
        // tuple just return the existing Id. Re-deliveries should not multiply Pending rows.
        if (String.isNotBlank(sourceId) && String.isNotBlank(parentWorkItemRef)) {
            List<SyncItem__c> existing = [
                SELECT Id FROM SyncItem__c
                WHERE DirectionPk__c = 'Inbound'
                AND StatusPk__c = 'Pending'
                AND ObjectTypePk__c = :stripped
                AND RemoteExternalIdTxt__c = :sourceId
                AND ParentRefTxt__c = :parentWorkItemRef
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }
        }

        SyncItem__c pending = new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Pending',
            ObjectTypePk__c = stripNamespace(objectType),
            RemoteExternalIdTxt__c = sourceId,
            GlobalSourceIdTxt__c = globalSourceId,
            // ParentRefTxt__c carries the parent WorkItem ref so the resolver
            // can efficiently re-query by that key without re-parsing the
            // full payload.
            ParentRefTxt__c = parentWorkItemRef,
            PayloadTxt__c = JSON.serialize(payload),
            RetryCountNumber__c = 0
        );
        Database.insert(pending, AccessLevel.SYSTEM_MODE);

        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new DeliverySyncItemPendingResolver(parentWorkItemRef));
        }

        return pending.Id;
    }

    /**
     * @description Re-entry point used by DeliverySyncItemPendingResolver to
     *              replay a stashed Pending payload once its parent WorkItem
     *              has appeared locally. Deserializes the stored payload and
     *              calls processInboundItem again. The caller is responsible
     *              for sweeping the Pending row to Synced/Failed based on the
     *              return.
     * @param objectType Stored object type (e.g., 'WorkLog__c').
     * @param payloadJson The JSON-serialized original payload.
     * @return The resolved local record Id.
     */
    public static Id replayPendingPayload(String objectType, String payloadJson) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
        return processInboundItem(objectType, payload);
    }

    // Typed tokens for the object types this ingestor actually handles
    // (WorkItem__c / WorkItemComment__c / WorkLog__c sync payloads plus
    // ContentVersion file transport). Typed tokens resolve correctly in the
    // delivery__ packaging/namespaced context, where bare-name
    // Schema.getGlobalDescribe() lookups silently miss (keys are
    // namespace-prefixed). Keys are namespace-stripped + lowercased so both
    // the bare ('WorkItem__c') and prefixed ('delivery__WorkItem__c') forms
    // remote payloads send resolve through the token path.
    private static final Map<String, Schema.SObjectType> KNOWN_DH_TYPES =
        new Map<String, Schema.SObjectType>{
            'workitem__c' => WorkItem__c.SObjectType,
            'workitemcomment__c' => WorkItemComment__c.SObjectType,
            'worklog__c' => WorkLog__c.SObjectType,
            'contentversion' => ContentVersion.SObjectType
        };

    /**
     * @description Resolves an SObject type from a payload-supplied API name.
     * Token-first: the KNOWN_DH_TYPES map of compile-time typed tokens is
     * consulted before any dynamic describe, because getGlobalDescribe-based
     * resolution of DH objects breaks in the delivery__ packaging context
     * (feature-test scratch orgs are non-namespaced and miss it). The
     * getGlobalDescribe dual lookup (bare name, then delivery__-prefixed)
     * survives ONLY as the fallback for genuinely-unknown / non-DH names —
     * processInboundItem's objectType is a dynamic string from remote-org
     * sync payloads, so arbitrary names must still resolve.
     * @param apiName The object API name from the sync payload (bare or namespace-prefixed).
     * @return The resolved SObjectType token, or null when the name is blank or unknown.
     */
    @TestVisible
    private static Schema.SObjectType findSObjectType(String apiName) {
        if (String.isBlank(apiName)) { return null; }
        Schema.SObjectType known = KNOWN_DH_TYPES.get(stripNamespace(apiName).toLowerCase());
        if (known != null) { return known; }

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) { return gd.get(apiName); }
        if (gd.containsKey('delivery__' + apiName)) { return gd.get('delivery__' + apiName); }

        String target = stripNamespace(apiName).toLowerCase();
        for (String key : gd.keySet()) {
            if (stripNamespace(key).toLowerCase() == target) {
                return gd.get(key);
            }
        }
        return null;
    }
}