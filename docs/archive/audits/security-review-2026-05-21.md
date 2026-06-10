# Security Review — 2026-05-21

## Headline

**Net posture: ACCEPTABLE with one medium remediation.** No PMD-missed CRUD violations, no SOQL injection, no FLS bypass. Authentication + tenant-scoping are solid across the cockpit + Watcher + REST surface.

**One medium-severity finding:** `DeliveryFeatureApprovalService.grant/reject` does not guard against a `null` `ApproverUserLookup__c`. Any authenticated user could grant/reject an approval whose approver was never assigned. Mitigated in practice by PR 9-era auto-assignment plans but should be hardened now.

Two low-severity polish items below (rate-limit opt-in visibility, optional request-body size cap).

---

## 1. FLS / Sharing — PASS

`DeliveryPublicApiService` is `without sharing` (intentional REST gate, all DML uses `AccessLevel.SYSTEM_MODE`). `DeliveryFeatureCatalogController`, `DeliveryFeatureApprovalService`, `DeliveryOnboardingService`, `DeliveryDevLoopController`, `DeliveryDatasetController` all `with sharing`. `DeliveryRateLimitService` and `DeliveryPortalAccessService` are `without sharing` (appropriate for cross-cutting utilities), use `WITH SYSTEM_MODE` on internal reads. No `Security.stripInaccessible()` needed given explicit access-level discipline.

## 2. CRUD — PASS

All DML reviewed. `DeliveryPublicApiService.cls` insert/update sites at lines 608, 672, 711 all `AccessLevel.SYSTEM_MODE`. `DeliveryFeatureApprovalService` DML at lines 143, 364, 382, 485, 516, 528, 578 runs under class-level `@SuppressWarnings('PMD.ApexCRUDViolation')` (line 44) justified by `with sharing` context + multi-step approval workflow + comprehensive test coverage.

## 3. SOQL Injection — PASS

All user-supplied input either cast to known types with try/catch (`Id.valueOf()`, `Integer.valueOf()`, `Decimal`) or used as bind variables (`:featureName`, `:statusFilter`, `:offset` at `DeliveryPublicApiService.cls:438-484`). No string concatenation in SOQL queries. `JSON.deserializeUntyped()` results are accessed via typed `.get(key)` calls — no eval risk.

## 4. REST Authentication + Tenant Scoping — PASS

`authenticateRequest()` fires on every `@HttpGet`/`@HttpPost`/`@HttpPatch` entry (lines 18, 54, 75). X-Api-Key validates against `NetworkEntity__c.ApiKeyTxt__c` with `ConnectionStatusPk__c='Connected'` constraint (lines 727-733). Returns 401 on failure.

`resolveEffectiveEntity()` (lines 736-749) enforces per-entity access via `DeliveryPortalAccessService.validateAccess()`. Pre-entity routes (`my-entities`, `portal-users`) require X-Portal-User header before resolution — correct pattern.

Routes that intentionally bypass entity-scoping (`/scratch-orgs` POST/PATCH, feature-cockpit POSTs) are org-wide tooling and rate-limited on the API-key NetworkEntity ID. Documented at lines 94-96.

## 5. Sensitive Data Exposure — PASS

`ActivityLog__c` writes contain only IDs, hours, optional notes, action types — no secrets / passwords / API keys logged. No `System.debug()` calls with sensitive payloads. Slack webhook URLs / API keys are never in test classes or response bodies. Error responses are generic.

## 6. Cross-Org / Namespace — PASS

PSG check at `DeliveryFeatureCatalogController.isAdmin()` lines 391-398 accepts both `'DeliveryHubAdmin'` (dev) and `'delivery__DeliveryHubAdmin'` (subscriber). No `Schema.getGlobalDescribe().get()` patterns remain after hotfixes #797 + #800. No `getName()` vs `getLocalName()` mismatches.

## 7. Auth Bypass Paths

**`isAdmin()` PSG query:** uses `UserInfo.getUserId()` — platform-supplied, not user-input. Cannot be spoofed.

**Onboarding gate:** `assertCanToggle` → `isAdmin` → `isTrackComplete(trackName, UserInfo.getUserId())`. No spoofable input path.

**Approval grant/reject — FINDING (Medium severity):**
- `DeliveryFeatureApprovalService.grant(approvalId, note)` and `.reject(approvalId, note)` load the approval row by ID, then call `stampDecision()` and apply.
- They do **NOT** verify that the calling `UserInfo.getUserId()` equals `row.ApproverUserLookup__c`. They also don't verify `ApproverUserLookup__c` is non-null.
- `getInbox()` filters its returned rows by `ApproverUserLookup__c = :UserInfo.getUserId()`, so the LWC won't surface approvals not assigned to you. BUT the underlying methods are callable directly (`@AuraEnabled global static`) — any authenticated DH user could call `grant(approvalId, '')` with any approval ID.
- Particularly risky for approvals with `ApproverUserLookup__c = null` (which PR 9-era auto-assignment was supposed to wire). Until then, those rows are open to any caller.

**Scratch-Org POST:** X-Api-Key only. Comment at lines 94-96 confirms intentional "developer-tooling scoped." Acceptable for GH Actions CI/CD context.

## 8. Webhook + Queueable Safety — PASS

`JSON.deserializeUntyped` wrapped in try-catch with 400-on-malformed (line 104-108). Blank body check at line 93. Salesforce platform enforces 6MB REST body limit globally — no app-level cap needed. Watcher queueables (`WatcherDigestRunQueueable`) reviewed in PR-B; no concerns.

---

## Recommended Remediation PRs

### Fix 1 — `FeatureToggleApproval` grant/reject: assert calling user is the approver
- **Scope:** `DeliveryFeatureApprovalService.cls` (add a `assertCallerIsApprover(row)` helper before `stampDecision`)
- **Effort:** ~15 min
- **Severity:** **Medium**

```apex
private static void assertCallerIsApprover(FeatureToggleApproval__c row) {
    if (row.ApproverUserLookup__c == null) {
        throw new AuraHandledException('Approval has no assigned approver — cannot decide.');
    }
    if (row.ApproverUserLookup__c != UserInfo.getUserId()) {
        throw new AuraHandledException('You are not the assigned approver for this row.');
    }
}
```

Call at the top of both `grant()` and `reject()`. Existing tests need a tiny update to set `ApproverUserLookup__c = UserInfo.getUserId()` on the test approval rows.

### Fix 2 — Rate-limit opt-in visibility
- **Scope:** `DeliveryPublicApiService.cls` startup log OR a runtime warning if `PublicApiRateLimitNumber__c` is null on the first call of the day
- **Effort:** ~10 min
- **Severity:** Low — ops/observability gap

The current opt-in gating at lines 23 + 80 silently disables rate limiting if `PublicApiRateLimitNumber__c` is null. Should at least log a `System.debug(LoggingLevel.WARN, ...)` when un-set so it shows up in audit traces.

### Fix 3 — Optional request-body size cap on POST
- **Scope:** `DeliveryPublicApiService.handlePost()` — add an early `requestBody.size() > 1_000_000` check
- **Effort:** ~10 min
- **Severity:** Low — Salesforce enforces 6MB platform-wide; this is belt-and-suspenders

---

## Net verdict

The cockpit + Watcher ship cycle introduced **20+ new classes with strong security fundamentals**:

- ✅ Authentication present and correct on all REST routes
- ✅ Sharing/access-level discipline is explicit and intentional
- ✅ CRUD violations are either zero or class-level suppressed with documented justification
- ✅ SOQL injection: zero risk (bind vars only)
- ✅ Multi-tenant boundaries correctly enforced via `resolveEffectiveEntity` + portal-access service
- ✅ ActivityLog audit writes are safe (no PII/secrets)
- ⚠ One medium gap: approval grant/reject should verify caller-is-approver before stamping a decision

**Recommendation:** ship Fix 1 in a small PR (~15min) before any production deploy that exposes the REST approval routes to external clients. Fixes 2 + 3 are optional polish.
