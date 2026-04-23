# Delivery Hub Sync API Guide

Org-to-org synchronization API for bidirectional data replication between Salesforce orgs running Delivery Hub.

**Endpoint base**: `/services/apexrest/delivery/deliveryhub/v1/sync/`

---

## Overview

The Sync API enables two Salesforce orgs to keep work items, comments, and files in lock-step. Changes made in one org are automatically replicated to the other through a combination of push (real-time POST) and pull (polling GET) flows.

**Key features**:
- Bidirectional sync of work items, comments, and file attachments
- Echo suppression prevents infinite loops between connected orgs
- Global Source ID tracing for multi-hop routing
- Opt-in API key validation (backward compatible with existing connections)
- Retry logic with up to 3 attempts on failure
- Namespace-aware field mapping for managed packages

---

## Endpoints

### POST /sync/{ObjectType}

Receives an inbound sync payload and creates or updates the corresponding local record.

**URL pattern**: `/services/apexrest/delivery/deliveryhub/v1/sync/WorkItem__c`

Supported object types: `WorkItem__c`, `WorkItemComment__c`, `ContentVersion`

**Headers**:

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | Must be `application/json` |
| `X-Api-Key` | No | API key for opt-in authentication. If sent, must match a Connected NetworkEntity. If omitted, request is allowed through (backward compatible). |
| `X-Global-Source-Id` | No | Global traceability ID for loop prevention. If this ID matches an existing outbound SyncItem in the receiving org, the payload is suppressed as an echo. |
| `X-Signature` | No | HMAC-SHA256 hex digest for payload integrity verification. Validated when `HmacSecretTxt__c` is configured on the matched NetworkEntity. See [HMAC Request Signing](#hmac-request-signing). |

**Request body**:

```json
{
    "BriefDescriptionTxt__c": "Build login page",
    "DetailsTxt__c": "Create a responsive login page with OAuth support.",
    "StageNamePk__c": "In Development",
    "PriorityPk__c": "High",
    "ActivatedDateTime__c": "2026-01-01T00:00:00.000Z",
    "StatusPk__c": "New",
    "SourceId": "a00xx0000000001AAA",
    "TargetId": "a00xx0000000099AAA",
    "GlobalSourceId": "a00xx0000000001AAA",
    "SenderOrgId": "00Dxx0000000001"
}
```

**Payload fields**:

| Field | Description |
|-------|-------------|
| `SourceId` | Record ID in the sending org. Used for ledger-based deduplication. |
| `TargetId` | Expected local record ID or remote work item ID for bridge resolution. |
| `GlobalSourceId` | Trace ID for the original record that initiated the sync chain. Used for kill-switch loop prevention. |
| `SenderOrgId` | Organization ID of the sending org. Used for auto-parenting the upstream client NetworkEntity. |
| `VendorPush` | Boolean. When `true`, indicates this is a vendor-push sync item (upstream to client). |
| *(other fields)* | SObject field API names (namespace-stripped). Mapped dynamically to the target object. |

**Response** (200 -- Success):

```json
{
    "status": "Success",
    "processedId": "a00xx0000000099AAA",
    "orgId": "00Dxx0000000002"
}
```

**Response** (200 -- Echo suppressed):

```json
{
    "status": "Echo suppressed",
    "globalSourceId": "a00xx0000000001AAA"
}
```

**Error responses**:

| Code | Body | Condition |
|------|------|-----------|
| 400 | `{"error": "Empty Payload"}` | Request body is empty |
| 400 | `{"error": "WorkItem insert payload missing both BriefDescriptionTxt__c and Name"}` | v0.200 blank-create guard. Fires only on INSERT payloads (no existing local record resolved via bridge/ledger/id). Sparse UPDATE payloads with a subset of fields remain allowed. |
| 401 | `{"error": "Invalid API key or entity not connected."}` | X-Api-Key header sent but key not found or entity not Connected; or HMAC signature validation failed |
| 429 | `{"error": "Rate limit exceeded. Try again later."}` | Sync API rate limit exceeded for this API key (opt-in via `SyncApiRateLimitNumber__c`) |
| 500 | `{"error": "..."}` | Unexpected server error |

---

### GET /sync/changes

Pull flow endpoint. Returns staged outbound sync items waiting to be collected by the client org. Items are marked as `Synced` after being returned so they are not re-delivered.

**URL pattern**: `/services/apexrest/delivery/deliveryhub/v1/sync/changes?clientId=ENTITY_ID&since=DATETIME`

**Query parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `clientId` | Yes | The Salesforce ID of the NetworkEntity representing the polling client. Required for multi-tenant data segregation. |
| `since` | No | ISO datetime filter. Only returns items created after this timestamp. Format: `YYYY-MM-DDTHH:MM:SS` or `YYYY-MM-DD HH:MM:SS`. Defaults to `1900-01-01` if omitted. |

**Headers**:

| Header | Required | Description |
|--------|----------|-------------|
| `X-Api-Key` | No | API key for opt-in authentication (same behavior as POST) |

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/sync/changes?clientId=a01xx0000000001AAA&since=2026-03-01T00:00:00"
```

**Response** (200):

```json
[
    {
        "objectType": "WorkItem__c",
        "payload": "{\"BriefDescriptionTxt__c\":\"Build login page\",\"StageNamePk__c\":\"In Development\",...}",
        "syncItemId": "a03xx0000000001AAA",
        "createdDate": "2026-03-09T10:00:00.000Z"
    },
    {
        "objectType": "WorkItemComment__c",
        "payload": "{\"BodyTxt__c\":\"Started OAuth work.\",\"WorkItemId__c\":\"a00xx0000000001AAA\",...}",
        "syncItemId": "a03xx0000000002AAA",
        "createdDate": "2026-03-09T10:05:00.000Z"
    }
]
```

**Response fields per item**:

| Field | Type | Description |
|-------|------|-------------|
| `objectType` | String | SObject API name (namespace-stripped): WorkItem__c, WorkItemComment__c, ContentVersion |
| `payload` | String | JSON-serialized field map. Parse this to get the actual record data. |
| `syncItemId` | String | The SyncItem__c record ID (for audit/debugging) |
| `createdDate` | DateTime | When the sync item was created |

**Behavior**:
- Returns up to 200 items per request, ordered by `CreatedDate ASC`
- Only returns items with `StatusPk__c = 'Staged'` and `DirectionPk__c = 'Outbound'`
- Items are filtered by `WorkItemId__r.ClientNetworkEntityId__c = :clientId`
- After returning items, the endpoint updates their status to `Synced` so they are not re-delivered on the next poll

**Error responses**:

| Code | Body | Condition |
|------|------|-----------|
| 400 | `{"error": "Missing required parameter: clientId..."}` | clientId query parameter is missing |
| 401 | `{"error": "Invalid API key or entity not connected."}` | X-Api-Key header sent but invalid; or HMAC signature validation failed |
| 404 | `{"error": "Endpoint not found. Please use /sync/changes"}` | URL path does not end with `/changes` |
| 429 | `{"error": "Rate limit exceeded. Try again later."}` | Sync API rate limit exceeded for this API key |
| 500 | `{"error": "..."}` | Unexpected server error |

---

## Authentication

### Opt-In API Key Validation

The Sync API uses **opt-in** authentication for backward compatibility:

- **No `X-Api-Key` header sent**: Request is allowed through (legacy behavior). This ensures existing connections without API keys continue to work.
- **`X-Api-Key` header sent**: The key is validated against `NetworkEntity__c.ApiKeyTxt__c` where `ConnectionStatusPk__c = 'Connected'`. Invalid keys return 401.

This allows gradual migration: configure API keys on NetworkEntity records in both orgs, then start sending the header on outbound callouts.

### How Keys Are Sent Automatically

When `DeliverySyncItemProcessor` pushes a sync item to a remote org, it automatically reads the API key from the target NetworkEntity and injects it:

```
SyncItemProcessor
  -> Push Mode:  reads RequestId__r.DeliveryEntityId__r.ApiKeyTxt__c
  -> Hub Mode:   reads WorkItemId__r.ClientNetworkEntityId__r.ApiKeyTxt__c
  -> Sets req.setHeader('X-Api-Key', apiKey) on outbound HTTP
```

---

## Echo Suppression

Echo suppression prevents sync loops when two orgs are connected bidirectionally.

### Gateway-Level Suppression (X-Global-Source-Id)

When a sync item is pushed to a remote org, the `X-Global-Source-Id` HTTP header carries the original record's ID. The receiving org checks if it has an existing outbound SyncItem with that GlobalSourceId. If it does, the payload originated here and is suppressed immediately:

```
Org A creates WorkItem → Syncs to Org B
Org B receives payload → Creates local WorkItem → Trigger fires → Queues outbound sync
Org B's outbound sync hits Org A → Org A checks X-Global-Source-Id
  → Finds matching outbound SyncItem → Returns "Echo suppressed"
```

### In-Memory Origin Blocking

During inbound processing, `DeliverySyncItemIngestor` registers the origin route (either the WorkRequest bridge ID or the Client NetworkEntity ID) in `DeliverySyncEngine.blockedOrigins`. This static Set prevents the trigger from re-queuing an outbound sync item back to the same origin within the same transaction.

### GlobalSourceId Inheritance

When the sync engine creates outbound SyncItems, it checks the ledger for an existing GlobalSourceId. If the record was originally synced from another org, the inherited GlobalSourceId is carried forward rather than being replaced with the local record ID. This enables loop prevention across multi-hop topologies (Org A -> Org B -> Org C).

---

## Sync Flows

### Push Flow (Real-Time)

Triggered immediately when a work item, comment, or file is created/updated:

```
1. Trigger fires (WorkItemTrigger, WorkItemCommentTrigger, ContentDocumentLinkTrigger)
2. DeliverySyncEngine.captureChanges() evaluates routing edges:
   - Downstream: WorkRequest__c records with active Vendor/Both entities
   - Upstream: WorkItem's ClientNetworkEntityId with enabled vendor push
3. SyncItem__c records created with StatusPk__c = 'Queued'
4. DeliverySyncItemProcessor queued immediately
5. Processor resolves endpoint URL and API key from the NetworkEntity
6. HTTP POST to /sync/{ObjectType} with payload + headers
7. Response ID captured and mapped to WorkRequest bridge
8. SyncItem status updated to 'Synced' or 'Failed'
9. If more items remain, processor chains another execution
```

### Pull Flow (Polling)

Client org polls the vendor org for staged changes:

```
1. DeliveryHubPoller (schedulable) or manual poll trigger runs
2. GET /sync/changes?clientId={entityId}&since={lastSync}
3. Vendor org returns array of staged SyncItems
4. Vendor marks returned items as 'Synced'
5. Client org processes each item through DeliverySyncItemIngestor
6. Local records created/updated with echo suppression registered
```

### Vendor Push (Real-Time Upstream)

When `EnableVendorPushDateTime__c` is set (non-null) on the client NetworkEntity and an endpoint URL is configured, the vendor org pushes changes upstream to the client in real time (instead of staging for polling):

```
1. Change made on vendor's WorkItem
2. SyncEngine detects ClientNetworkEntity has vendor push enabled
3. SyncItem created with StatusPk__c = 'Queued' (not 'Staged')
4. Payload includes "VendorPush": true
5. Processor resolves endpoint from WorkItem -> ClientNetworkEntity
6. HTTP POST to client's /sync/{ObjectType} endpoint
```

---

## WorkLog Sync with Approval Gate

WorkLog records (hours logged against a Work Item) participate in the sync pipeline. An optional approval gate controls when WorkLogs become eligible for synchronization.

### How Approval Works

The approval gate is controlled by the org-level custom setting `DeliveryHubSettings__c.RequireWorkLogApprovalDateTime__c`. When this DateTime field is populated, the approval policy is active.

| Approval Setting | Insert Behavior | Update Behavior |
|-------------------|-----------------|-----------------|
| **Not set** (default) | All WorkLogs sync immediately on insert (backward compatible) | No sync-relevant update handling needed |
| **Set** (approval required) | Only WorkLogs with `StatusPk__c = 'Approved'` (or `null` for legacy records) create SyncItems on insert. Draft WorkLogs are blocked. | When a WorkLog transitions to `Approved`, `onAfterUpdate` detects the `Draft -> Approved` change and creates a SyncItem |

### Lifecycle with Approval Enabled

```
1. User logs hours → WorkLog__c created with StatusPk__c = 'Draft'
2. onAfterInsert fires → filterEligibleForSync() blocks Draft logs → NO SyncItem created
3. Manager approves → StatusPk__c updated to 'Approved'
4. onAfterUpdate fires → detects old.StatusPk__c != 'Approved' AND new.StatusPk__c == 'Approved'
5. createSyncItemsForLogs() queries parent WorkItem for ClientNetworkEntityId__c
6. If ClientNetworkEntityId__c is set → SyncItem__c created with StatusPk__c = 'Queued'
7. DeliverySyncItemProcessor picks up the SyncItem and pushes it to the remote org
```

### Rejected WorkLogs

WorkLogs with `StatusPk__c = 'Rejected'` never create SyncItems. The `onAfterUpdate` handler only acts on the transition **to** `Approved`, so a log that moves to `Rejected` (or any other non-Approved status) is ignored.

### SyncItem Payload

The outbound SyncItem payload for a WorkLog includes:

| Payload Field | Source Field | Description |
|---------------|-------------|-------------|
| `WorkItemId__c` | `WorkLog__c.WorkItemId__c` | Parent Work Item reference |
| `HoursLoggedNumber__c` | `WorkLog__c.HoursLoggedNumber__c` | Number of hours logged |
| `WorkDateDate__c` | `WorkLog__c.WorkDateDate__c` | Date the work was performed |
| `WorkDescriptionTxt__c` | `WorkLog__c.WorkDescriptionTxt__c` | Description of the work done |

### Filtering Rules

- Only WorkLogs whose parent Work Item has `ClientNetworkEntityId__c != null` generate SyncItems
- The handler queries `WorkItem__c` to confirm the client entity link before creating any SyncItem
- When approval is **not** enabled, all WorkLogs on client-linked Work Items sync immediately on insert

---

## ContentDocumentLink Sync

Files attached to Work Items are synced through the `ContentDocumentLinkTrigger` and its handler `DeliveryContentDocLinkTriggerHandler`.

### Trigger Flow

```
1. User attaches a file to a WorkItem__c → ContentDocumentLink inserted
2. handleAfterInsert() fires
3. Echo suppression check: if DeliverySyncEngine.isSyncContext is true, abort (prevents re-syncing inbound files)
4. Handler identifies links where LinkedEntityId is a WorkItem__c
5. Queries ContentVersion (IsLatest = true) to get file data: Title, VersionData, PathOnClient, FileExtension, FileType
6. Queries WorkRequest__c routes for the parent Work Item (same pattern as DeliverySyncEngine)
7. Builds SyncItem__c with ObjectTypePk__c = 'ContentVersion' and StatusPk__c = 'Queued'
8. Enqueues DeliverySyncItemProcessor to push the file to the remote org
```

### Payload Contents

The ContentVersion sync payload includes:

| Payload Field | Description |
|---------------|-------------|
| `Title` | File name/title |
| `PathOnClient` | Original file path |
| `VersionData` | Base64-encoded file content |
| `SourceId` | ContentVersion record ID in the sending org |
| `TargetId` | Remote Work Item ID or local Work Item ID (depending on routing model) |
| `GlobalSourceId` | ContentVersion ID for echo suppression tracing |
| `SenderOrgId` | Organization ID of the sending org |

### Routing Models

The handler supports two routing models, matching the same patterns used by the core sync engine:

- **Push Model (Client Side)**: Routes through `WorkRequest__c` bridge records. Each request with a `RemoteWorkItemIdTxt__c` gets its own SyncItem.
- **Hub Model (Vendor Side)**: When no routed WorkRequest exists (or routes have blank remote IDs), creates a passive SyncItem using the local Work Item ID as the target. The hub processor resolves routing at delivery time.

### Size Limitation

File content is Base64-encoded into the `PayloadTxt__c` field, which is a Long Text Area. Salesforce Long Text Area fields support approximately 131,000 characters, which limits the maximum file size that can be synced inline. Larger files may be truncated or fail to sync.

---

## Conflict Resolution

The sync architecture uses a **last-write-wins** strategy with echo suppression to handle conflicts and prevent synchronization loops.

### Last-Write-Wins

When the same record is modified in both orgs, the most recent inbound sync payload overwrites the local field values. There is no merge or field-level conflict detection. The `SyncItem__c` ledger provides an audit trail of all changes for manual review if needed.

### Echo Suppression

Echo suppression operates at two levels to prevent bounce-back loops:

1. **Gateway-level (HTTP header)**: The `X-Global-Source-Id` header is checked on inbound requests. If the receiving org finds a matching outbound SyncItem with that GlobalSourceId, the payload is suppressed immediately with an "Echo suppressed" response.

2. **In-memory (transaction-scoped)**: During inbound processing, `DeliverySyncItemIngestor` registers the origin route in `DeliverySyncEngine.blockedOrigins`. This static Set prevents the after-trigger from creating a new outbound SyncItem back to the same origin within the same transaction.

### GlobalSourceIdTxt__c Origin Tracking

The `GlobalSourceIdTxt__c` field on `SyncItem__c` tracks the original record that initiated the sync chain. This enables loop prevention across multi-hop topologies:

```
Org A (origin) → Org B → Org C
                         ↓
              Org C checks GlobalSourceId against Org A's original ID
              → Match found → Echo suppressed (no sync back to Org A)
```

When the sync engine creates outbound SyncItems for a record that was itself synced from another org, it inherits the existing GlobalSourceId rather than replacing it with the local record ID. This ensures the original origin is preserved across any number of hops.

---

## Record Resolution (Inbound)

When processing an inbound sync payload, the ingestor resolves the local record using a multi-step strategy:

1. **Request Bridge lookup**: For WorkItems, checks `WorkRequest__c.RemoteWorkItemIdTxt__c` to find the local work item linked via a delivery request.
2. **Ledger lookup**: Checks `SyncItem__c` records where `RemoteExternalIdTxt__c` matches the `SourceId` from the payload.
3. **Direct ID fallback**: If the `TargetId` is a valid Salesforce ID of the correct type, uses it directly.
4. **New record**: If no existing record is found, creates a new one and writes a ledger entry.

For child objects (WorkItemComment, ContentVersion), the ingestor resolves the parent work item using the same strategy before creating the child record.

### Auto-Parenting

When a work item is received with a `SenderOrgId`, the ingestor looks up the NetworkEntity registered for that org. If the entity is of type `Client` or `Both`, it is automatically set as the `ClientNetworkEntityId__c` on the work item. This enables automatic routing of future sync events back to the originating org.

---

## Field Mapping

The ingestor maps payload fields to the target SObject dynamically:

- Fields are matched by API name (case-insensitive, namespace-stripped)
- Date, DateTime, and Base64 fields are type-converted automatically
- System fields (`SourceId`, `TargetId`, `GlobalSourceId`, `SenderOrgId`) are excluded from mapping
- Unknown fields are silently skipped (no error thrown)
- Namespace translation handles both `delivery__FieldName__c` and `FieldName__c` formats

---

## Setup: Connecting Two Orgs

### Prerequisites

Both orgs must have Delivery Hub installed (same or compatible versions).

### Step 1: Configure the Vendor Org

In the vendor org, create a NetworkEntity for the client:

```apex
NetworkEntity__c clientEntity = new NetworkEntity__c(
    Name = 'Client Org',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    ConnectionStatusPk__c = 'Connected',
    OrgIdTxt__c = 'CLIENT_ORG_ID_15CHAR'
);
insert clientEntity;
```

### Step 2: Configure the Client Org

In the client org, create a NetworkEntity for the vendor:

```apex
NetworkEntity__c vendorEntity = new NetworkEntity__c(
    Name = 'Vendor Org',
    EntityTypePk__c = 'Vendor',
    StatusPk__c = 'Active',
    ConnectionStatusPk__c = 'Connected',
    IntegrationEndpointUrlTxt__c = 'https://VENDOR_INSTANCE.salesforce.com/services/apexrest/delivery/deliveryhub/v1/sync',
    ApiKeyTxt__c = DeliveryPublicApiService.generateApiKey(),
    OrgIdTxt__c = 'VENDOR_ORG_ID_15CHAR'
);
insert vendorEntity;
```

### Step 3: Add Remote Site Settings

In both orgs, add a Remote Site Setting for the other org's domain:

- **Remote Site Name**: `DeliveryHubSync`
- **Remote Site URL**: `https://OTHER_INSTANCE.salesforce.com`

### Step 4: Create Work Request (Client Org)

Link a work item to the vendor for downstream sync:

```apex
WorkRequest__c req = new WorkRequest__c(
    WorkItemId__c = 'WORK_ITEM_ID',
    DeliveryEntityId__c = vendorEntity.Id,
    StatusPk__c = 'Active'
);
insert req;
```

### Step 5: Enable API Key Validation (Optional)

To secure the connection with API keys:

1. Set `ApiKeyTxt__c` on both orgs' NetworkEntity records
2. The outbound processor automatically sends the key in the `X-Api-Key` header
3. The receiving org validates it against its NetworkEntity records

### Step 6: Enable Real-Time Vendor Push (Optional)

To have the vendor push changes to the client in real time (instead of polling):

1. On the vendor org's client NetworkEntity, set `EnableVendorPushDateTime__c = Datetime.now()`
2. Set `IntegrationEndpointUrlTxt__c` to the client's sync endpoint URL
3. Changes will be pushed immediately instead of staged for polling

---

## Retry Behavior

Failed sync items are retried up to a configurable limit (default: 3):

- The retry limit is read from `DeliveryHubSettings__c.SyncRetryLimitNumber__c` at runtime; if not set, defaults to 3
- On each failure, `RetryCountNumber__c` is incremented and `ErrorLogTxt__c` is populated
- The scheduled poller (`DeliveryHubPoller`) picks up failed items on its next run
- After reaching the retry limit, items remain in `Failed` status for manual investigation
- The `deliverySyncRetryPanel` LWC component provides a UI for viewing and retrying failed items

---

## Pending Queue (Child-Before-Parent Race)

v0.200 added a Pending queue to handle the case where an inbound child payload (most commonly a WorkLog) lands before its parent WorkItem's payload. Previously the ingestor would hard-throw and the child row would sit as `Failed` until someone manually requeued it.

**Flow**:

1. Inbound payload arrives. Ingestor resolves the parent (bridge → ledger → direct-id).
2. If the parent cannot be resolved, the `SyncItem__c` is inserted with `StatusPk__c = 'Pending'` and the parent's remote id stashed in `ParentRefTxt__c`.
3. `DeliverySyncItemPendingResolver` is enqueued inline for an immediate retry.
4. `DeliveryHubScheduler.requeuePendingItems()` re-sweeps every Pending row every 15 minutes on the scheduler tick, so the backlog drains automatically the moment the parent shows up.
5. When the resolver finds the parent, it calls `DeliverySyncItemIngestor.replayPendingPayload` and the row transitions Pending → Synced with the matching local record created/updated.
6. Rows that can't resolve after `DEFAULT_MAX_RETRIES` (10 attempts) flip to `Failed` with a descriptive `ErrorLogTxt__c` for manual review.

**Monitoring**: Query `SyncItem__c` where `StatusPk__c = 'Pending'` for the live Pending backlog. Volumes should be transient (minutes, not hours); sustained growth indicates the parent WorkItem is never going to arrive (deleted on the source side, routing misconfigured, etc.).

**Backward compatibility**: The `Pending` picklist value and `ParentRefTxt__c` field are added by the package install. Existing Failed rows from pre-v0.200 orgs are unaffected and can still be retried manually via `deliverySyncRetryPanel`.

---

## Rate Limiting

The Sync API supports opt-in rate limiting to protect org resources from excessive inbound sync traffic.

### Configuration

Set `SyncApiRateLimitNumber__c` on the `DeliveryHubSettings__c` custom setting to activate rate limiting:

```apex
DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
s.SyncApiRateLimitNumber__c = 60; // 60 requests per hour per API key
upsert s;
```

**Default behavior**: When `SyncApiRateLimitNumber__c` is `null` (the default), rate limiting is **disabled** and all sync requests are allowed through without throttling.

### How It Works

- Each inbound sync request is counted per API key (from the `X-Api-Key` header)
- The counter resets every hour
- When the limit is exceeded, the endpoint returns HTTP **429 Too Many Requests**

### 429 Response

```json
{
    "error": "Rate limit exceeded. Try again later."
}
```

**Headers on 429 response**:

| Header | Value | Description |
|--------|-------|-------------|
| `Retry-After` | `3600` | Number of seconds until the rate limit window resets |

### Recommendations

- Start with the default (off) and enable only if you need to throttle specific partner orgs
- A limit of **60 requests per hour** is a reasonable starting point for bidirectional sync
- Requests without an `X-Api-Key` header are not rate-limited (consistent with opt-in auth behavior)

---

## HMAC Request Signing

For organizations that require payload integrity verification, the Sync API supports HMAC-SHA256 request signing. When configured, outbound sync payloads are signed with a shared secret and the receiving org validates the signature before processing.

### Configuration

Set `HmacSecretTxt__c` on the target `NetworkEntity__c` record to enable signing:

```apex
NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Vendor Org' LIMIT 1];
entity.HmacSecretTxt__c = 'your-shared-secret-here';
update entity;
```

Both orgs must share the same secret value. The secret should be a strong, random string (32+ characters recommended).

### How It Works

**Outbound (sending org)**:

1. `DeliverySyncItemProcessor` reads `HmacSecretTxt__c` from the target NetworkEntity
2. If a secret is configured, `DeliveryCryptoService` computes an HMAC-SHA256 signature of the request body
3. The signature is sent in the `X-Signature` HTTP header

**Inbound (receiving org)**:

1. `DeliverySyncItemIngestor` checks for the `X-Signature` header
2. If present, it recomputes the HMAC-SHA256 of the request body using the local NetworkEntity's `HmacSecretTxt__c`
3. If the signatures match, processing continues normally
4. If the signatures do not match, the request is rejected with a 401 response

### Backward Compatibility

HMAC signing is **fully backward compatible**:

- **No secret on NetworkEntity**: No `X-Signature` header is sent, and the receiving org does not validate signatures. Existing connections work without any changes.
- **Secret on one side only**: The sending org signs the request, but the receiving org without a secret skips validation. This allows gradual rollout.
- **Secret on both sides**: Full integrity verification is active. Both orgs sign outbound requests and validate inbound signatures.

### Headers

| Header | Description |
|--------|-------------|
| `X-Signature` | HMAC-SHA256 hex digest of the request body, computed with the shared secret from `HmacSecretTxt__c` |

---

## Troubleshooting

### Common Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| 401 on inbound sync | API key mismatch | Verify the key matches a Connected NetworkEntity in the receiving org |
| Items not syncing | Missing WorkRequest bridge | Create an active WorkRequest linking the WorkItem to the vendor entity |
| Echo loop detected | Missing Global Source ID | Ensure both orgs are on the same package version with echo suppression |
| "Configuration Error: Missing Endpoint URL" | NetworkEntity missing URL | Set `IntegrationEndpointUrlTxt__c` on the target NetworkEntity |
| Items stuck in "Staged" | Polling not configured | Set up `DeliveryHubPoller` scheduled job or enable vendor push |
| 429 Too Many Requests | Rate limit exceeded | Increase `SyncApiRateLimitNumber__c` or set to `null` to disable throttling |
| 401 with valid API key | HMAC signature mismatch | Verify both orgs share the same `HmacSecretTxt__c` value on their NetworkEntity records |

### Viewing Sync Logs

- Each sync event creates a `SyncItem__c` record with direction, status, payload, and error details
- Use the `deliverySyncRetryPanel` component on the admin home page to monitor sync health
- Query `SyncItem__c` directly for detailed investigation:

```sql
SELECT Id, ObjectTypePk__c, DirectionPk__c, StatusPk__c, ErrorLogTxt__c,
       GlobalSourceIdTxt__c, CreatedDate
FROM SyncItem__c
ORDER BY CreatedDate DESC
LIMIT 50
```
