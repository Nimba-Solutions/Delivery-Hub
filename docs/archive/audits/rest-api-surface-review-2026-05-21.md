# REST API Surface Review — 2026-05-21

## Headline

The 6 new feature-cockpit (PR 8) + dev-loop mirror (PR 9) routes follow solid foundational patterns, but **three issues warrant action**:

1. **`PATCH /scratch-orgs/{id}` is not rate-limited** (POST is; PATCH path skipped the gate) — High
2. **`POST /features/{name}/toggle` has no idempotency guard** — duplicate submissions create duplicate FeatureToggleRequest__c rows — High
3. **`GET /feature-toggle-requests` lacks pagination metadata** — clients can't tell if more rows exist beyond the LIMIT 50 cap — Medium

Authentication, tenant-scoping, error envelope, response shape, and versioning are all consistent across the surface.

---

## 1. Authentication Consistency — PASS

- All 6 new routes call `authenticateRequest()` before processing.
- X-Api-Key validates against `NetworkEntity__c.ApiKeyTxt__c` with `ConnectionStatusPk__c = 'Connected'`.
- Intentionally tenant-less routes (`/scratch-orgs`) skip `resolveEffectiveEntity()` by design (lines 94-100, documented in comments).

**Note:** feature-cockpit routes are org-wide (no per-tenant scope). Any NetworkEntity with a valid X-Api-Key can call ANY feature toggle. Comment at L151-154 acknowledges; if the design intent is per-tenant feature-flag scoping eventually, that's PR 11+ scope.

## 2. Tenant Scoping — PASS by design

Routes that should be tenant-scoped use `resolveEffectiveEntity()`; routes that intentionally bypass (`/scratch-orgs`) are documented.

## 3. Rate Limiting — FAIL (PATCH ungated)

GET (lines 22-32) ✅. POST (lines 78-89) ✅. PATCH (lines 51-69) ❌ — no rate-limit gate.

**Impact:** an attacker with a valid X-Api-Key can submit unlimited `PATCH /scratch-orgs/{id}` requests.

**Fix:** copy lines 78-89 from `handlePost()` into `handlePatch()` after `authenticateRequest()`. ~10 min.

## 4. Error Envelope Shape — PASS

`sendError(code, msg)` → `{success: false, error: ...}` and `sendSuccess(data)` → `{success: true, data: ...}` used consistently. Status codes appropriate (200/201/400/401/404/500). Minor: both grant + reject return 200 — semantically different outcomes, could clarify.

## 5. Response Shape Stability — PASS (minor naming inconsistency)

All POSTs include stable `id`-like field. `POST /features/{name}/toggle` returns `requestId` rather than `id` — minor REST-convention drift but doesn't break clients.

## 6. Idempotency — FAIL

### Issue 1: `POST /features/{name}/toggle` (lines 339-360)

Submitting the same (feature, action) twice creates two `FeatureToggleRequest__c` rows. No deduplication.

**Fix (~15 min):** before insert, query for an existing `Pending` or `Granted` row with the same `FeatureLookup__c + ActionPk__c`; if found, return its ID with status 200 (not 201).

```apex
List<FeatureToggleRequest__c> existing = [
    SELECT Id FROM FeatureToggleRequest__c
    WHERE FeatureLookup__c = :featureId
      AND ActionPk__c = :action
      AND StatusPk__c IN ('Pending', 'Granted')
    WITH SYSTEM_MODE LIMIT 1
];
if (!existing.isEmpty()) {
    sendSuccess(new Map<String, Object>{
        'requestId' => existing[0].Id,
        'featureId' => featureId,
        'status' => 'Pending'
    });
    return;
}
```

### Issue 2: `POST /scratch-orgs` (lines 640-681)

Submitting the same `OrgIdTxt__c` twice creates two `ScratchOrgInstance__c` rows. GH Actions retry on network blip → duplicate rows.

**Fix (~10 min):** either add a `<unique>true</unique>` constraint on `OrgIdTxt__c.field-meta.xml`, or query-before-insert pattern as above.

## 7. Input Validation — PASS

JSON parsing is wrapped in the outer try/catch (lines 104). Validation after retrieval. DateTime parsing defensive (try/catch with safe fallbacks). URL path-segment decoding handled by the REST framework before `extractResource()` runs.

Minor: PATCH `state` value is not enum-validated against the StatePk__c picklist — the database constraint rejects bad values, but a pre-DML check would give a cleaner 400.

## 8. Pagination — FAIL (no metadata)

`GET /feature-toggle-requests` has LIMIT 50 + optional `?pageOffset`, but the response is a bare list. Clients can't tell if row 51 exists.

**Fix (~20 min):** wrap in pagination envelope:
```apex
Map<String, Object> resp = new Map<String, Object>{
    'data'     => data,
    'offset'   => offset,
    'pageSize' => maxRows,
    'hasMore'  => data.size() >= maxRows
};
sendSuccess(resp);
```

Or fetch `LIMIT maxRows+1` to actually know.

## 9. Versioning — PASS

All new routes are additive to `/v1/`. No breaking changes.

## 10. CORS / Hostname — PASS

Salesforce-internal REST endpoints; CORS handled by platform.

## 11. Webhook Safety (`POST /scratch-orgs`) — PARTIAL

ANY NetworkEntity with a valid API key can submit scratch-org rows that show up org-wide. If GH Actions is the only caller, low risk. If multi-tenant, add a `CreatedByNetworkEntityLookup__c` lookup or an `IsScratchOrgPublisherDateTime__c` permission gate on NetworkEntity.

## Top 3 Fixes (priority order)

| # | Fix | Effort | Severity |
|---|---|---|---|
| 1 | Add rate limiting to `handlePatch()` (copy from `handlePost()` lines 78-89) | 10 min | High — unlimited PATCH bypasses the gate |
| 2 | Idempotency guard on `POST /features/{name}/toggle` (query-before-insert) | 15 min | High — duplicate Pending rows from network-retry |
| 3 | Pagination envelope on `GET /feature-toggle-requests` (hasMore + offset) | 20 min | Medium — client UX hole |

**Bundle as one cleanup PR:** ~45 min total. Read-test webhook + toggle flows after.

## Recommended next-cycle work

**v2 surface (not for this cycle):**
- Auto-resolve `ApproverUserLookup__c` at submit (PR 8 leaves null)
- Per-tenant feature-flag scoping (currently org-wide)
- Feature-specific approval policies (currently all features share cascade graph)
- `OrgIdTxt__c` uniqueness constraint on `ScratchOrgInstance__c`

**v1 polish (debt, not blocker):**
- Refactor `queryFeatureToggleRequests` 4-branch query into a single builder
- Add `X-RateLimit-Remaining` / `X-RateLimit-Reset` headers on 429s
- Improve feature-not-found errors with available-names list

## Bottom line

The REST surface is **well-structured and follows consistent patterns**. The 3 fixes above are the only hardening needed before production traffic. The underlying `DeliveryFeatureApprovalService` design is mature; the entry points need ~45 minutes of additional hardening.
