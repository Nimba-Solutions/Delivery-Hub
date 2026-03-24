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

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard` | Portal dashboard with counts and phase distribution |
| GET | `/api/work-items` | List work items, optionally filtered by status |
| GET | `/api/work-items/{id}` | Full detail for a single work item |
| POST | `/api/work-items` | Create a new work item request |
| POST | `/api/work-items/{id}/comments` | Add a comment to a work item |
| GET | `/api/activity-feed` | Unified timeline of comments, work logs, and changes |
| GET | `/api/work-logs` | All work logs for the authenticated entity |
| POST | `/api/log-hours` | Create a new work log entry |
| GET | `/api/pending-approvals` | Draft work logs awaiting approval |
| POST | `/api/approve-worklogs` | Batch approve draft work logs |
| POST | `/api/reject-worklogs` | Batch reject draft work logs |
| GET | `/api/board-summary` | AI-generated board summary |
| GET | `/api/files` | Files attached to the entity's work items |
| GET | `/api/documents` | Generated documents (invoices, statements) for the entity |
| GET | `/api/documents/{token}` | Document detail by public token |
| POST | `/api/document-approve` | Approve a document by public token |
| POST | `/api/document-dispute` | Dispute a document with reason by public token |

---

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

### GET /api/activity-feed

Returns a unified, chronologically-sorted timeline of comments, work logs, and activity logs (stage/field changes) across all work items for the authenticated entity. Supports filtering by event type and pagination.

**Query parameters**:

| Parameter | Required | Values | Description |
|-----------|----------|--------|-------------|
| `filterType` | No | `all`, `comments`, `hours`, `changes` | Filter by event type. Defaults to `all`. |
| `pageOffset` | No | Integer (0-based) | Page offset for pagination. Defaults to `0`. |

**Request**:

```bash
# All activity
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/activity-feed"

# Filtered to comments only, page 2
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/activity-feed?filterType=comments&pageOffset=1"
```

**Response** (200):

```json
{
    "success": true,
    "data": {
        "events": [
            {
                "id": "a04xx0000000001AAA",
                "type": "comment",
                "timestamp": "2026-03-10T14:30:00.000Z",
                "userName": "Glen Bradford",
                "title": "Comment by Glen Bradford",
                "detail": "Started working on the OAuth integration.",
                "icon": "standard:feedback",
                "workItemId": "a00xx0000000001AAA",
                "workItemName": "WI-0042",
                "workItemDescription": "Deploy analytics dashboard",
                "source": "Salesforce"
            },
            {
                "id": "a05xx0000000001AAA",
                "type": "worklog",
                "timestamp": "2026-03-10T12:00:00.000Z",
                "userName": "Jane Smith",
                "title": "2.5h logged by Jane Smith",
                "detail": "Implemented login flow (Work date: 2026-03-10)",
                "icon": "standard:timesheet",
                "workItemId": "a00xx0000000002AAA",
                "workItemName": "WI-0043",
                "workItemDescription": "Build login page",
                "hours": 2.5,
                "status": "Draft"
            },
            {
                "id": "a06xx0000000001AAA",
                "type": "stage_change",
                "timestamp": "2026-03-09T16:45:00.000Z",
                "userName": "System",
                "title": "Stage changed to In Development",
                "detail": "Ready for Development \u2192 In Development",
                "icon": "standard:record",
                "workItemId": "a00xx0000000001AAA",
                "workItemName": "WI-0042",
                "workItemDescription": "Deploy analytics dashboard"
            }
        ],
        "totalCount": 87,
        "hasMore": true
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `events` | Array | Paginated list of activity events (25 per page), sorted newest first |
| `events[].id` | String | Record ID of the source record (comment, work log, or activity log) |
| `events[].type` | String | Event type: `comment`, `worklog`, `stage_change`, or `field_change` |
| `events[].timestamp` | DateTime | When the event occurred |
| `events[].userName` | String | User who performed the action (defaults to "System" if unknown) |
| `events[].title` | String | Human-readable summary of the event |
| `events[].detail` | String | Additional detail (comment preview, hour description, change values) |
| `events[].icon` | String | SLDS icon name for rendering |
| `events[].workItemId` | String | Associated WorkItem ID |
| `events[].workItemName` | String | Work item auto-number (e.g., WI-0042) |
| `events[].workItemDescription` | String | Work item title / brief description |
| `events[].source` | String | Comment source: Salesforce, Client, Sync, Portal (comments only) |
| `events[].hours` | Decimal | Hours logged (work log events only) |
| `events[].status` | String | Work log status: Draft, Approved, Rejected (work log events only) |
| `totalCount` | Integer | Total number of events matching the filter (before pagination) |
| `hasMore` | Boolean | Whether more pages are available |

---

### GET /api/work-logs

Returns all work logs for the authenticated entity's work items, ordered by creation date descending.

**Query parameters**:

| Parameter | Required | Values | Description |
|-----------|----------|--------|-------------|
| `workItemId` | No | Salesforce ID | Filter to work logs for a specific work item. Omit for all work logs. |

**Request**:

```bash
# All work logs for the entity
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-logs"

# Work logs for a specific work item
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/work-logs?workItemId=a00xx0000000001AAA"
```

**Response** (200):

```json
{
    "success": true,
    "data": [
        {
            "id": "a05xx0000000001AAA",
            "workItemId": "a00xx0000000001AAA",
            "workItemName": "WI-0042",
            "workItemTitle": "Deploy analytics dashboard",
            "hours": 2.5,
            "workDate": "2026-03-10",
            "description": "Implemented OAuth login flow",
            "status": "Draft",
            "userName": "Jane Smith",
            "createdDate": "2026-03-10T14:30:00.000Z"
        }
    ]
}
```

**Response fields per item**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | WorkLog record ID |
| `workItemId` | String | Parent WorkItem ID |
| `workItemName` | String | Work item auto-number (e.g., WI-0042) |
| `workItemTitle` | String | Work item brief description / title |
| `hours` | Decimal | Hours logged |
| `workDate` | Date | The date the work was performed |
| `description` | String | Work description / notes |
| `status` | String | Work log status: Draft, Approved, or Rejected |
| `userName` | String | Name of the user who created the log |
| `createdDate` | DateTime | Record creation timestamp |

**Limit**: Returns up to 200 work logs per request.

---

### POST /api/log-hours

Creates a new work log entry for a work item.

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workItemId": "a00xx0000000001AAA",
    "hours": 2.5,
    "workDate": "2026-03-10",
    "workNotes": "Implemented OAuth login flow"
  }' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/log-hours"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `workItemId` | Yes | String | The WorkItem ID to log hours against |
| `hours` | Yes | Decimal | Number of hours to log. Must be greater than 0. |
| `workDate` | No | Date (YYYY-MM-DD) | The date the work was performed. Defaults to today if omitted. |
| `workNotes` | No | String | Description of the work performed |

**Response** (201):

```json
{
    "success": true,
    "data": {
        "status": "Logged",
        "hours": 2.5
    }
}
```

The endpoint also creates an `ActivityLog__c` record for portal audit tracking.

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing request body, missing `workItemId`, or `hours` is null/zero/negative |
| 403 | Work item belongs to a different NetworkEntity than the authenticated entity |

---

### GET /api/pending-approvals

Returns draft work logs pending approval for the authenticated entity's work items, ordered by creation date descending.

**Query parameters**:

| Parameter | Required | Values | Description |
|-----------|----------|--------|-------------|
| `pageOffset` | No | Integer (0-based) | Page offset for pagination. Defaults to `0`. |

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/pending-approvals"
```

**Response** (200):

```json
{
    "success": true,
    "data": {
        "approvals": [
            {
                "id": "a05xx0000000001AAA",
                "workItemId": "a00xx0000000001AAA",
                "workItemName": "WI-0042",
                "workItemDescription": "Deploy analytics dashboard",
                "hours": 2.5,
                "workDate": "2026-03-10",
                "description": "Implemented OAuth login flow",
                "userName": "Jane Smith",
                "timestamp": "2026-03-10T14:30:00.000Z",
                "status": "Draft"
            }
        ],
        "totalCount": 5
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `approvals` | Array | List of draft work logs awaiting approval |
| `approvals[].id` | String | WorkLog record ID |
| `approvals[].workItemId` | String | Parent WorkItem ID |
| `approvals[].workItemName` | String | Work item auto-number (e.g., WI-0042) |
| `approvals[].workItemDescription` | String | Work item title / brief description |
| `approvals[].hours` | Decimal | Hours logged |
| `approvals[].workDate` | Date | The date the work was performed |
| `approvals[].description` | String | Work description / notes |
| `approvals[].userName` | String | Name of the user who created the log |
| `approvals[].timestamp` | DateTime | Work log creation timestamp |
| `approvals[].status` | String | Always `Draft` for pending approvals |
| `totalCount` | Integer | Total number of pending approvals |

**Limit**: Returns up to 200 pending approvals per request.

---

### POST /api/approve-worklogs

Batch approves one or more draft work logs. Changes their status from `Draft` to `Approved`.

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workLogIds": ["a05xx0000000001AAA", "a05xx0000000002AAA"]
  }' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/approve-worklogs"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `workLogIds` | Yes | Array of Strings | List of WorkLog IDs to approve |

**Response** (200):

```json
{
    "success": true,
    "data": {
        "status": "Approved",
        "count": 2
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `status` | String | Always `Approved` |
| `count` | Integer | Number of work logs that were approved |

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing request body |

---

### POST /api/reject-worklogs

Batch rejects one or more draft work logs. Changes their status from `Draft` to `Rejected`.

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workLogIds": ["a05xx0000000003AAA"]
  }' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/reject-worklogs"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `workLogIds` | Yes | Array of Strings | List of WorkLog IDs to reject |

**Response** (200):

```json
{
    "success": true,
    "data": {
        "status": "Rejected",
        "count": 1
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `status` | String | Always `Rejected` |
| `count` | Integer | Number of work logs that were rejected |

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing request body |

---

### GET /api/board-summary

Returns an AI-generated summary of the current board state. Uses the `DeliveryAiController.draftBoardSummary()` method internally. If AI generation fails, returns `null` for the summary field instead of an error.

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/board-summary"
```

**Response** (200):

```json
{
    "success": true,
    "data": {
        "summary": "The board has 12 active items across 3 clients. Development phase has the highest concentration with 5 items. 2 items are blocked awaiting client feedback. WI-0042 and WI-0045 were completed this week."
    }
}
```

**Response fields**:

| Field | Type | Description |
|-------|------|-------------|
| `summary` | String or null | AI-generated board summary text. Returns `null` if AI generation is unavailable. |

---

### GET /api/files

Returns files attached to the authenticated entity's work items. Optionally filter to a single work item.

**Query parameters**:

| Parameter | Required | Values | Description |
|-----------|----------|--------|-------------|
| `workItemId` | No | Salesforce ID | Filter to files attached to a specific work item. Omit for all files. |

**Request**:

```bash
# All files for the entity
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/files"

# Files for a specific work item
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/files?workItemId=a00xx0000000001AAA"
```

**Response** (200):

```json
{
    "success": true,
    "data": [
        {
            "id": "068xx0000000001AAA",
            "name": "Architecture Diagram",
            "extension": "png",
            "size": 245760,
            "createdDate": "2026-03-05T10:30:00.000Z",
            "workItemId": "a00xx0000000001AAA"
        }
    ]
}
```

**Response fields per item**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | ContentVersion ID (latest published version) |
| `name` | String | File title / name |
| `extension` | String | File extension (e.g., png, pdf, docx) |
| `size` | Integer | File size in bytes |
| `createdDate` | DateTime | File upload timestamp |
| `workItemId` | String | The WorkItem ID the file is attached to |

**Limit**: Returns up to 500 files per request.

---

### GET /api/documents

Returns generated documents (invoices, statements, reports) for the authenticated entity, ordered by creation date descending.

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/documents"
```

**Response** (200):

```json
{
    "success": true,
    "data": [
        {
            "id": "a07xx0000000001AAA",
            "name": "INV-0001",
            "template": "Invoice",
            "periodStart": "2026-03-01",
            "periodEnd": "2026-03-31",
            "status": "Draft",
            "totalHours": 42.5,
            "totalCost": 3825.00,
            "createdDate": "2026-03-15T09:00:00.000Z"
        }
    ]
}
```

**Response fields per item**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | DeliveryDocument record ID |
| `name` | String | Document name / number (e.g., INV-0001) |
| `template` | String | Document template type (e.g., Invoice, Statement, Account_Statement) |
| `periodStart` | Date | Billing period start date |
| `periodEnd` | Date | Billing period end date |
| `status` | String | Document status: Draft, Sent, Paid, Overdue, Cancelled |
| `totalHours` | Decimal | Total hours covered by the document |
| `totalCost` | Decimal | Total monetary amount |
| `createdDate` | DateTime | Document creation timestamp |

**Limit**: Returns up to 100 documents per request.

---

### GET /api/documents/{token}

Returns a single document by its public token. This allows clients to view document details from a shared link without authentication beyond the API key.

**Request**:

```bash
curl -s \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/documents/abc123def456..."
```

**Response** (200):

```json
{
    "success": true,
    "data": {
        "id": "a07xx0000000001AAA",
        "name": "INV-0001",
        "template": "Invoice",
        "periodStart": "2026-03-01",
        "periodEnd": "2026-03-31",
        "status": "Sent",
        "totalHours": 42.5,
        "totalCost": 3825.00,
        "createdDate": "2026-03-15T09:00:00.000Z",
        "snapshot": { ... },
        "versionNumber": 1,
        "disputeReason": null
    }
}
```

**Errors**:

| Code | Condition |
|------|-----------|
| 404 | No document found for the given token |

---

### POST /api/document-approve

Approves a document by its public token. The document must be in an approvable status (Sent, Ready, or Draft).

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"token": "abc123def456..."}' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/document-approve"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `token` | Yes | String | The document's 64-character public token |

**Response** (200):

```json
{
    "success": true,
    "data": {
        "status": "Approved",
        "documentId": "a07xx0000000001AAA"
    }
}
```

On approval:
- Document status transitions to **Approved**
- A `DeliveryTransaction__c` record of type "Approval" is created
- An `ActivityLog__c` record is created with action type "Document_Action"
- A `DeliveryDocEvent__e` platform event is published

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing token in request body |
| 404 | No document found for the given token |
| 400 | Document is not in an approvable status (already Approved, Paid, Cancelled, or Superseded) |

---

### POST /api/document-dispute

Disputes a document by its public token. Requires a reason explaining the dispute.

**Request**:

```bash
curl -s -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "token": "abc123def456...",
    "reason": "Hours for WI-0042 seem incorrect -- we agreed on 8 hours, not 12."
    "reason": "Hours for WI-0042 seem incorrect — we agreed on 8 hours, not 12."
  }' \
  "YOUR_INSTANCE_URL/services/apexrest/delivery/deliveryhub/v1/api/document-dispute"
```

**Request body**:

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `token` | Yes | String | The document's 64-character public token |
| `reason` | Yes | String | Explanation for the dispute (up to 5000 characters, stored in DisputeReasonTxt__c) |

**Response** (200):

```json
{
    "success": true,
    "data": {
        "status": "Disputed",
        "documentId": "a07xx0000000001AAA"
    }
}
```

On dispute:
- Document status transitions to **Disputed**
- The reason is stored in `DeliveryDocument__c.DisputeReasonTxt__c`
- An `ActivityLog__c` record is created with action type "Document_Action" and the dispute reason in context data
- A `DeliveryDocEvent__e` platform event is published

**Errors**:

| Code | Condition |
|------|-----------|
| 400 | Missing token or reason in request body |
| 404 | No document found for the given token |
| 400 | Document is not in a disputable status |

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
| 201 | Created | Resource created (POST work-items, POST comments, POST log-hours) |
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
