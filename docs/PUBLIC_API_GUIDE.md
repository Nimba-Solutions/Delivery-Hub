# Delivery Hub Public API Guide

## Quick Start

Get your first API response in 3 steps:

**Step 1** -- Generate an API key and create a NetworkEntity:

```apex
NetworkEntity__c entity = new NetworkEntity__c(
    Name = 'My App',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    ApiKeyTxt__c = DeliveryPublicApiService.generateApiKey(),
    ConnectionStatusPk__c = 'Connected'
);
insert entity;
System.debug('API Key: ' + entity.ApiKeyTxt__c);
```

**Step 2** -- Get your org's access token:

```bash
sf org display --target-org YOUR_ORG_ALIAS --json
```

**Step 3** -- Make your first call:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/dashboard" \
  | python -m json.tool
```

You should see a JSON response with `"success": true` and your dashboard data.

---

## Overview

The Public API allows non-Salesforce clients (websites, mobile apps, external platforms) to interact with Delivery Hub data. All requests are authenticated via API key and scoped to a single NetworkEntity.

**Endpoint base**: `/services/apexrest/delivery/deliveryhub/v1/api/`

**Authentication**: Every request must include an `X-Api-Key` header containing a valid API key associated with a Connected NetworkEntity record.

**Response format**: All responses return JSON with this envelope:

```json
{
    "success": true,
    "data": { ... }
}
```

Error responses:

```json
{
    "success": false,
    "error": "Error message describing what went wrong."
}
```

---

## Endpoints

### GET /api/dashboard

Returns a portal dashboard scoped to the authenticated NetworkEntity. Includes active/completed/attention counts, phase distribution, recently completed items, and a recent activity feed.

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/dashboard"
```

**Response** (200):

```json
{
    "success": true,
    "data": {
        "entityName": "cloudnimbusllc.com",
        "activeCount": 12,
        "completedCount": 47,
        "attentionCount": 3,
        "phases": [
            { "label": "Planning", "count": 2 },
            { "label": "Approval", "count": 1 },
            { "label": "Development", "count": 5 },
            { "label": "Testing", "count": 2 },
            { "label": "UAT", "count": 1 },
            { "label": "Deployment", "count": 1 }
        ],
        "recentCompleted": [
            {
                "id": "a00xx0000000001AAA",
                "name": "WI-0042",
                "title": "Deploy analytics dashboard",
                "stage": "Done",
                "lastModified": "2026-03-08T14:30:00.000Z"
            }
        ],
        "recentActivity": [
            {
                "id": "a00xx0000000002AAA",
                "name": "WI-0043",
                "title": "Build login page",
                "stage": "In Development",
                "lastModified": "2026-03-09T09:15:00.000Z"
            }
        ]
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `entityName` | String | Name of the authenticated NetworkEntity |
| `activeCount` | Integer | Work items not in a terminal stage |
| `completedCount` | Integer | Work items in a terminal stage (all time) |
| `attentionCount` | Integer | Work items in an attention stage (needs client input) |
| `phases` | Array | Distribution of active items across 6 delivery phases |
| `phases[].label` | String | Phase name: Planning, Approval, Development, Testing, UAT, Deployment |
| `phases[].count` | Integer | Number of active items in this phase |
| `recentCompleted` | Array | Last 5 completed work items |
| `recentActivity` | Array | Last 5 modified work items (any status) |

---

### GET /api/work-items

Returns work items for the authenticated entity, optionally filtered by status.

**Query parameters**:

| Parameter | Required | Values | Description |
|-----------|----------|--------|-------------|
| `status` | No | `active`, `completed`, `attention` | Filter by status group. Omit for all items. |

**Request**:

```bash
# All items
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items"

# Filtered by status
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items?status=active"
```

**Response** (200):

```json
{
    "success": true,
    "data": [
        {
            "id": "a00xx0000000001AAA",
            "name": "WI-0001",
            "title": "Build login page",
            "stage": "In Development",
            "lastModified": "2026-03-09T09:15:00.000Z",
            "priority": "High",
            "eta": "2026-03-15",
            "descriptionPreview": "Create a responsive login page with OAuth support...",
            "requestType": "Internal"
        }
    ]
}
```

**Response fields per item**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Salesforce record ID |
| `name` | String | Auto-number (e.g., WI-0001) |
| `title` | String | Brief description / title |
| `stage` | String | Current workflow stage |
| `lastModified` | DateTime | Last modification timestamp |
| `priority` | String | Priority level (Critical, High, Medium, Low) |
| `eta` | Date | Calculated estimated completion date (may be null) |
| `descriptionPreview` | String | First 150 chars of description, HTML stripped |
| `requestType` | String | Request type (Internal, External, Bug, Enhancement, etc.) |

**Limit**: Returns up to 100 items per request.

---

### GET /api/work-items/{id}

Returns full detail for a single work item including comments, file count, and the stage pipeline.

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items/a00xx0000000001AAA"
```

**Response** (200):

```json
{
    "success": true,
    "data": {
        "id": "a00xx0000000001AAA",
        "name": "WI-0001",
        "title": "Build login page",
        "stage": "In Development",
        "priority": "High",
        "lastModified": "2026-03-09T09:15:00.000Z",
        "eta": "2026-03-15",
        "description": "Create a responsive login page with OAuth support.",
        "requestType": "Internal",
        "createdDate": "2026-03-01T10:00:00.000Z",
        "networkEntityId": "a01xx0000000001AAA",
        "estimatedDays": 3.0,
        "estimatedHours": 24.0,
        "loggedHours": 8.5,
        "comments": [
            {
                "id": "a02xx0000000001AAA",
                "body": "Started working on the OAuth integration.",
                "author": "Developer",
                "createdDate": "2026-03-02T14:00:00.000Z",
                "source": "Salesforce"
            }
        ],
        "fileCount": 2,
        "stages": [
            "Backlog", "Scoping In Progress", "Ready for Sizing",
            "Ready for Development", "In Development", "Ready for QA",
            "QA In Progress", "Ready for Client UAT", "In Client UAT",
            "Ready for Deployment", "Deploying", "Done"
        ]
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Salesforce record ID |
| `name` | String | Auto-number |
| `title` | String | Brief description / title |
| `stage` | String | Current workflow stage |
| `priority` | String | Priority level |
| `lastModified` | DateTime | Last modification timestamp |
| `eta` | Date | Calculated estimated completion date |
| `description` | String | Full description (may contain HTML) |
| `requestType` | String | Request type |
| `createdDate` | DateTime | Record creation timestamp |
| `networkEntityId` | String | Owning NetworkEntity ID |
| `estimatedDays` | Decimal | Developer-day size estimate |
| `estimatedHours` | Decimal | Estimated hours |
| `loggedHours` | Decimal | Total logged hours |
| `comments` | Array | All comments (up to 200), ordered by creation date ascending |
| `comments[].id` | String | Comment record ID |
| `comments[].body` | String | Comment text |
| `comments[].author` | String | Author name (defaults to "System" if blank) |
| `comments[].createdDate` | DateTime | Comment creation timestamp |
| `comments[].source` | String | Origin: Salesforce, Client, Sync, Portal |
| `fileCount` | Integer | Number of files attached to this work item |
| `stages` | Array | Ordered list of major stage labels for rendering a progress bar |

**Errors**:

| Code | Condition |
|------|-----------|
| 403 | Work item exists but belongs to a different NetworkEntity |
| 500 | Work item ID not found or invalid |

---

### POST /api/work-items

Creates a new work item request associated with the authenticated entity.

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Add dark mode",
    "description": "Users want a dark theme option for the dashboard.",
    "priority": "Medium",
    "type": "Enhancement"
  }' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `title` | Yes | String | Brief description of the request. Prefixed with `[Portal]` automatically. |
| `description` | No | String | Detailed description |
| `priority` | No | String | Priority level. Defaults to `Medium`. Values: Critical, High, Medium, Low. |
| `type` | No | String | Request type. Defaults to `Internal`. Values: Internal, External, Bug, Enhancement, etc. |

**Response** (201):

```json
{
    "success": true,
    "data": {
        "id": "a00xx0000000003AAA",
        "status": "Created"
    }
}
```

The created work item starts in stage `Backlog` with `StatusPk__c = 'New'` and `IsActiveBool__c = true`.

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing request body or title is blank |

---

### POST /api/work-items/{id}/comments

Adds a comment to an existing work item. The work item must belong to the authenticated entity.

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"body": "Can we get an update on this?"}' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-items/a00xx0000000001AAA/comments"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `body` | Yes | String | Comment text |

**Response** (201):

```json
{
    "success": true,
    "data": {
        "id": "a02xx0000000002AAA",
        "status": "Created"
    }
}
```

Comments created via the API are automatically tagged with `AuthorTxt__c = 'Portal User'` and `SourcePk__c = 'Client'`.

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing request body, blank comment body, or missing work item ID in URL |
| 403 | Work item belongs to a different NetworkEntity |
| 404 | Work item not found |

---

## Authentication

### How It Works

Every request must include an `X-Api-Key` header. The API matches this key against `NetworkEntity__c.ApiKeyTxt__c` where `ConnectionStatusPk__c = 'Connected'`.

```
External Client                    Salesforce (Delivery Hub)
     |                                    |
     |  GET /api/dashboard                |
     |  X-Api-Key: abc123...              |
     |----------------------------------->|
     |                                    |
     |         authenticateRequest()      |
     |         SELECT FROM NetworkEntity  |
     |         WHERE ApiKeyTxt__c = key   |
     |         AND ConnectionStatus =     |
     |             'Connected'            |
     |                                    |
     |         Match found? -> entity.Id  |
     |         No match?   -> 401         |
     |                                    |
     |         DeliveryPortalController   |
     |         .getPortalDashboard(       |
     |              entity.Id)            |
     |                                    |
     |  200 { success: true, data: {...}} |
     |<-----------------------------------|
```

### API Key Generation

Keys are 64-character hex strings generated from cryptographically random bytes:

```apex
String newKey = DeliveryPublicApiService.generateApiKey();
```

### Data Scoping

All data is scoped to the authenticated NetworkEntity. The API key determines which entity you are. You can only see WorkItems where `ClientNetworkEntityId__c` matches your entity. Attempting to access another entity's work items returns 403.

### Connection Lifecycle

| ConnectionStatusPk__c | Meaning |
|------------------------|---------|
| Pending | Entity created, API key generated, but not yet activated |
| Connected | Active -- API requests are accepted |
| Disabled | Revoked -- API requests return 401 |

---

## Error Codes

| HTTP Status | Meaning | Common Causes |
|-------------|---------|---------------|
| 200 | Success | Request processed normally |
| 201 | Created | Resource created (POST work-items, POST comments) |
| 400 | Bad Request | Missing body, blank required field, invalid parameters |
| 401 | Unauthorized | Missing `X-Api-Key` header, invalid key, or entity not Connected |
| 403 | Forbidden | Work item belongs to a different NetworkEntity |
| 404 | Not Found | Unknown endpoint or work item ID not found |
| 500 | Server Error | Unexpected exception in Apex |

---

## Setup

### 1. Generate an API Key

In the Developer Console (Execute Anonymous):

```apex
// Create a NetworkEntity for the external client
NetworkEntity__c entity = new NetworkEntity__c(
    Name = 'cloudnimbusllc.com',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    ApiKeyTxt__c = DeliveryPublicApiService.generateApiKey(),
    ConnectionStatusPk__c = 'Connected'
);
insert entity;

System.debug('API Key: ' + entity.ApiKeyTxt__c);
System.debug('Entity ID: ' + entity.Id);
```

### 2. Get Your Org's Access Token

```bash
sf org display --target-org YOUR_ORG_ALIAS --json
```

Note the `instanceUrl` and `accessToken` from the output.

### 3. Configure Access for External Callers

> **Note**: When testing via access token (authenticated user), the REST endpoint
> works directly. In production, the endpoint is exposed via Salesforce Sites to
> allow unauthenticated (guest user) access -- the API key handles authorization.

For production (website integration):

1. **Salesforce Site** must be configured to allow guest user access to `DeliveryPublicApiService` (the `DeliveryHubGuestUser` permission set already grants this)
2. **CORS** -- add your domain to the CORS whitelist in Setup if calling from browser JavaScript
3. **Remote Site Setting** is NOT needed (the website calls Salesforce, not the other way around)

### 4. Test Error Cases

```bash
# Missing API Key (expect 401)
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/dashboard"

# Invalid API Key (expect 401)
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: wrong-key-here" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/dashboard"
```

---

## Production Deployment Checklist

### For Website Integration

1. Deploy the package (or install latest version) to the production org
2. Create a NetworkEntity for the website with an API key
3. Configure Salesforce Site to expose the endpoint to guest users
4. Add the website domain to the CORS whitelist in Setup
5. Build the fetch calls in your website code using the API key

### For Outbound Sync Authentication

When Delivery Hub sends sync payloads to another org, it includes the API key:

```
DeliverySyncItemProcessor
  -> Queries NetworkEntity.ApiKeyTxt__c alongside EndpointUrl
  -> Sets req.setHeader('X-Api-Key', apiKey) on outbound HTTP
  -> Remote org validates the key if opt-in validation is enabled
```

See the [Sync API Guide](SYNC_API_GUIDE.md) for full org-to-org setup instructions.
