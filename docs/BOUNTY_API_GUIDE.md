# Bounty Marketplace API Guide

## Overview

The Bounty Marketplace lets organizations publish work items as fixed-price bounties that external developers can browse, claim, and complete. Bounties are just WorkItems with `BountyEnabledDateTime__c` set (non-null) -- they inherit all existing workflow stages, SLAs, and reporting.

**Endpoint base**: `/services/apexrest/delivery/deliveryhub/v1/bounties/`

**Authentication**: GET endpoints are public (no auth required). POST endpoints require an `X-Api-Key` header.

**Response format**: All responses use the standard envelope:

```json
{ "success": true, "data": { ... } }
{ "success": false, "error": "Error message" }
```

---

## Data Model

### Bounty Fields on WorkItem__c

| Field | Type | Description |
|-------|------|-------------|
| `BountyEnabledDateTime__c` | DateTime | Publishes this work item to the marketplace (non-null = enabled) |
| `BountyAmountCurrency__c` | Currency | Fixed payout amount |
| `BountyDeadlineDate__c` | Date | Completion deadline |
| `BountyStatusPk__c` | Picklist | Open, Claimed, In Review, Completed, Expired, Cancelled |
| `BountyTokenTxt__c` | Text (unique) | Public URL-safe identifier (auto-generated) |
| `BountyDifficultyPk__c` | Picklist | Beginner, Intermediate, Advanced, Expert |
| `BountySkillsTxt__c` | Long Text | Semicolon-delimited skills (e.g. `Apex;LWC;Flow`) |
| `BountyMaxClaimsNumber__c` | Number | Max simultaneous active claims (default 3) |

### BountyClaim__c

| Field | Type | Description |
|-------|------|-------------|
| `WorkItemId__c` | Master-Detail | Parent bounty work item |
| `ClaimantEntityId__c` | Lookup | NetworkEntity of the developer (auto-linked by email) |
| `ClaimantEmailTxt__c` | Email | Developer's email address |
| `ClaimantNameTxt__c` | Text | Developer's display name |
| `StatusPk__c` | Picklist | Active, Submitted, Under Review, Approved, Rejected, Withdrawn |
| `ClaimedDateTime__c` | DateTime | When the claim was created |
| `SubmittedDateTime__c` | DateTime | When work was submitted |
| `NoteTxt__c` | Long Text | Developer's note about approach or submission |
| `WorkProofUrlTxt__c` | URL | Link to PR, demo, or completed work |

---

## Endpoints

### GET /bounties

List all open bounties. No authentication required.

**Query Parameters**:
- `difficulty` (optional) -- Filter by difficulty level (e.g. `?difficulty=Advanced`)
- `skill` (optional) -- Filter by skill keyword (e.g. `?skill=Apex`)

**Response**:

```json
{
  "success": true,
  "data": [
    {
      "token": "a1b2c3d4e5f6g7h8i9j0",
      "number": "T-0042",
      "title": "Build Custom LWC Dashboard",
      "description": "Create a reusable dashboard component...",
      "amount": 500.00,
      "deadline": "2026-04-15",
      "status": "Open",
      "difficulty": "Intermediate",
      "skills": ["LWC", "Apex", "SOQL"],
      "maxClaims": 3,
      "claimCount": 1,
      "posterName": "Acme Corp",
      "postedDate": "2026-03-18T10:00:00.000Z"
    }
  ]
}
```

### GET /bounties/{token}

Get a single bounty by its public token. Includes acceptance criteria and active claims. No authentication required.

**Response**:

```json
{
  "success": true,
  "data": {
    "token": "a1b2c3d4e5f6g7h8i9j0",
    "title": "Build Custom LWC Dashboard",
    "acceptanceCriteria": "1. Shows live data\n2. Refreshes every 30s",
    "activeClaims": [
      { "name": "Jane Dev", "status": "Active", "claimedDate": "2026-03-20T14:00:00.000Z" }
    ],
    ...
  }
}
```

Returns `404` if the token is not found.

### POST /bounties/{token}/claim

Claim a bounty. Requires `X-Api-Key` header.

**Request Body**:

```json
{
  "email": "developer@example.com",
  "name": "Jane Dev",
  "note": "I have 3 years of LWC experience and can complete this in a week."
}
```

**Validation**:
- `email` is required
- Bounty must be in `Open` status
- Bounty must not be past its deadline
- Developer must not already have an active claim on this bounty
- Bounty must not have reached its max claims

**Response** (201):

```json
{
  "success": true,
  "data": {
    "claimId": "a0BXX000000XXXXX",
    "status": "Active"
  }
}
```

### POST /bounties/{token}/submit

Submit completed work for a claimed bounty. Requires `X-Api-Key` header.

**Request Body**:

```json
{
  "email": "developer@example.com",
  "workProofUrl": "https://github.com/org/repo/pull/42",
  "note": "All acceptance criteria met. Tests passing."
}
```

**Validation**:
- `email` and `workProofUrl` are required
- Developer must have an active claim on this bounty

**Response** (201):

```json
{ "success": true, "data": { "status": "Submitted" } }
```

### POST /bounties/{token}/withdraw

Withdraw an active claim. Requires `X-Api-Key` header.

**Request Body**:

```json
{ "email": "developer@example.com" }
```

**Response** (200):

```json
{ "success": true, "data": { "status": "Withdrawn" } }
```

---

## Bounty Lifecycle

```
Organization creates WorkItem
  └─ Sets BountyEnabledDateTime__c = Datetime.now()
  └─ Sets amount, deadline, difficulty, skills
  └─ Token auto-generated on save
       │
       ▼
  Bounty Status: OPEN
  (visible on marketplace)
       │
       ▼
  Developer claims ──► BountyClaim created (Active)
       │                  │
       │                  ▼
       │              Developer works on it
       │                  │
       │                  ▼
       │              Developer submits work
       │              (claim → Submitted, bounty → In Review)
       │                  │
       │                  ▼
       │              Admin reviews
       │              ┌───┴───┐
       │              ▼       ▼
       │          Approved  Rejected
       │              │       │
       │              ▼       ▼
       │          COMPLETED  Developer can
       │          (payout)   re-submit or withdraw
       │
       └─ If max claims reached ──► Status: CLAIMED
          (no new claims until one withdraws)
```

---

## Sync Behavior

When a bounty is created or updated in one org, the sync engine automatically pushes the bounty fields to connected orgs. The following fields are included in the sync payload:

- `BountyEnabledDateTime__c`, `BountyAmountCurrency__c`, `BountyDeadlineDate__c`
- `BountyStatusPk__c`, `BountyTokenTxt__c`, `BountyDifficultyPk__c`
- `BountySkillsTxt__c`, `BountyMaxClaimsNumber__c`

When a `BountyClaim__c` is created or updated, the `DeliveryBountyClaimTrigger` creates outbound `SyncItem__c` records that route the claim data back to the origin org (the org that posted the bounty). This uses the same push/staged pattern as the core sync engine:

- If the origin org has `EnableVendorPushDateTime__c` set and an integration endpoint, claims push in real-time
- Otherwise, claims are staged for the origin org to poll via `GET /sync/changes`

---

## Publishing a Bounty

### Via Salesforce UI

1. Create or open a WorkItem
2. Set **Bounty Enabled** (DateTime toggle)
3. Fill in **Bounty Amount**, **Bounty Deadline**, **Bounty Difficulty**, and **Bounty Skills**
4. Save -- the token is auto-generated

### Via Apex

```apex
WorkItem__c bounty = new WorkItem__c(
    BriefDescriptionTxt__c = 'Build Custom Report Generator',
    DetailsTxt__c = 'Create an Apex service that generates...',
    AcceptanceCriteriaTxt__c = '1. Supports 3 output formats\n2. Handles 10k+ rows',
    BountyEnabledDateTime__c = Datetime.now(),
    BountyAmountCurrency__c = 750.00,
    BountyDeadlineDate__c = Date.today().addDays(30),
    BountyDifficultyPk__c = 'Advanced',
    BountySkillsTxt__c = 'Apex;SOQL;REST',
    BountyMaxClaimsNumber__c = 3
);
insert bounty;
// Token is auto-generated in the before-insert trigger
```

---

## Connecting to cloudnimbusllc.com

The public marketplace at [cloudnimbusllc.com/bounties](https://cloudnimbusllc.com/bounties) can receive bounty data from any Delivery Hub org. Configure a NetworkEntity with your website's webhook endpoint:

```apex
NetworkEntity__c website = new NetworkEntity__c(
    Name = 'Cloud Nimbus Website',
    EntityTypePk__c = 'Client',
    StatusPk__c = 'Active',
    ConnectionStatusPk__c = 'Connected',
    EnableVendorPushDateTime__c = Datetime.now(),
    IntegrationEndpointUrlTxt__c = 'https://cloudnimbusllc.com/api/bounties/sync'
);
insert website;
```

When bounties are created or updated, the sync engine will push them to the website automatically.
