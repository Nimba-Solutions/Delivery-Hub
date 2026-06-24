# Delivery Hub — Fix Register

> **What this is.** The itemized fix-list distilled from the live two-org validation campaign (see [`cowork-validation-log.md`](cowork-validation-log.md) UI lane + [`dh-claude-validation-evidence.md`](dh-claude-validation-evidence.md) Apex/DML lane). One row per **confirmed** defect → severity · evidence · routing · effort · PR. Separate sections for **by-design/content gaps** (not bugs) and **belief-corrections** (audit was wrong in DH's favor — nothing to fix).
>
> **Compiled:** 2026-06-23 (overnight). **Scope honesty:** the spine + surfaces are green and the confirmed bug list is **short** (4 items, 2 already fixed). The real open risk is concentrated in **billing completeness (T11)**, still uncharacterized.

---

## A. Confirmed defects (the bug list)

| ID | Defect | Sev | Evidence | Location / routing | Effort | Status |
|---|---|---|---|---|---|---|
| **F9** | **On-Budget % inverted** — pill computes `estimated / logged` under a "% consumed" label. T-0005: 60÷14=**429%**; T-0000: 40÷22=**182%** (correct: 23% / 55%). Isolated to the pills component (same-record variance cards compute correctly). | 🔴 | Cowork metric audit, 2 records; arithmetic-confirmed | `deliveryHoursPills.js:91` — flip numerator/denominator | XS (1 line + tests) | ✅ **FIXED — PR #932** |
| **F6** | **Smoke scripts namespace-prefixed** — `smoke-cross-org-*.apex` are `delivery__`-prefixed → won't compile on non-namespaced scratch orgs (`Invalid type: delivery__WorkRequest__c`); the runbook inherits the gap. | 🟢 | Compile failure on dh-child; bare-name variant passed live | `scripts/apex/` — ship bare-name variants | XS | ✅ **FIXED — PR #933** |
| **T6 / B11 / F10** | **Inbound ContentVersion sync stuck Queued** — file *dispatches* Synced on the sender, but the **receiver's inbound** ContentVersion SyncItem parks `Queued` and the file never materializes (0 ContentVersion landed). **Root-caused 2026-06-23:** the pull-callout transport parks the row `Queued` (`DeliverySyncItemIngestor.handlePullCalloutFile`) then enqueues `DeliveryFileBytesFetcher` **best-effort only** — guarded by `getQueueableJobs() < limit` (ingestor ~L895). On the **poll path** the ingestor runs inside `@future runSyncAsync` → `DeliveryHubPoller` *after* its own HTTP callout, so the depth guard declines the enqueue and **nothing ever re-dispatches it** (the author's own "unless we're in a context that already has pending callouts" comment = the smoking gun). No sweep covered inbound Queued ContentVersion: `requeueFailedItems` is Outbound-only, `requeuePendingItems`=Pending, `requeueStagedItemsWithEndpoint`=Staged. *(Observed Queued — not Failed — confirms never-enqueued, since a fetcher that ran against our keys-blank scratch peers would have marked it Failed at fetcher L92–95.)* | 🔴 | Attached file to routed WI on child → parent inbound SyncItem `Queued`, `SELECT … ContentVersion` = 0; confirmed by code trace + obs 11212 | **FIX:** new `DeliveryHubScheduler.requeueOrphanedInboundFiles()` recovery sweep (sibling to `requeuePendingItems`) re-enqueues the fetcher for inbound `Queued` ContentVersion rows **aged > 1 cycle (15 min)** — age gate prevents racing a live ingest-time fetcher. | **S** (done) | 🟢 **FIX PUSHED — PR pending CI** (`fix/inbound-contentversion-orphan-redispatch`). ⚠️ Makes orphans recoverable + turns silent-Queued into visible Synced/Failed; **full file round-trip in scratch still needs keys + the `/fileBytes` Site endpoint wired** (peers were keys-blank → re-dispatched fetch will land Failed until auth is configured). |
| **F7** | **Capture-path `WorkItemId__c` noise** — every WorkItem-related insert logs a *caught* `System.SObjectException: Invalid field WorkItemId__c for SyncItem__c` (both bare + `delivery__`). Non-fatal (transactions succeed) but it's a dynamic-field probe against a field that isn't on `SyncItem__c`. | 🟡 | Debug logs on demo-load, sync seed, smoke run | capture/serialization path — locate the dynamic `WorkItemId__c` reference; DH-FIX cleanup | S | 🟡 open — tech-debt |

---

## B. Needs a product decision (defect vs. design — don't auto-fix)

| ID | Item | Evidence | Question for Glen |
|---|---|---|---|
| **B12** | **Forecast slider input source** — the buyer capacity slider (`DeliveryHoursAnalyticsController`) reads `RecurringHoursPerMonthNumber__c` from settings; it has **zero references to `TeamPoolTxt__c`**. | Code inspection | Is `TeamPoolTxt__c` *supposed* to feed the slider (→ bug), or is settings-driven the intended source and TeamPool is for a different surface (→ design)? Cowork flagged both readings. **Decide before building.** |

---

## C. By-design / content gaps (not bugs — scope lines)

| Item | Why it's not a code defect |
|---|---|
| **Auto-diagnose ships ruleless** (`DiagnoseRule__mdt` = 0) | The engine works; it has no rules to run. This is **content authoring** (write the rules), not a code fix. |
| **Cart Stripe/Approve checkout = stubs** | Intentionally-incomplete payment modes; the cart + invoice-proposal path renders. Build-out, not a regression. |

---

## D. Belief-corrections (audit was too pessimistic — nothing to fix)

These were audited 🔴/blocker but evidence shows they work — they **shrink** the fix list:

| Was | Now |
|---|---|
| SEE field-capture ships **OFF** (🔴) | **ON** — `EnableActivityLogging`/`EnableFieldTracking` set; `ActivityLog__c` populating (36 events). |
| **No UI** to create estimate / submit for approval (🔴 *#1 ranked blocker*) | Surfaces **ship**: `deliveryManageRequest`, `deliveryQuickRequest`, `deliveryWorkItemQuotes`, `deliveryFeatureApprovalSubmit` + `NewWorkRequest` QA + submit controllers. (Loop *completeness* = open Cowork UI test, not a missing-surface 🔴.) |
| Cross-org sync **unproven** (🟡) | **Proven both directions**, all 3 legs, + dedup + Failed-recovery + reconciler. 1594 Apex tests / 0 fail. |

---

## E. PRs opened this session

| PR | What | Gate |
|---|---|---|
| **#931** | `deliveryHoursBurnup` — hours burn-up card on WorkItem record page (new feature; also shows the F9 number correctly) | 12 jest green; deploy-verified live |
| **#932** | F9 — correct the inverted On-Budget % | 5 jest green; LWC (no PMD) |
| **#933** | F6 — bare-name smoke-cross-org variants | scripts only |

---

## F. T11 — invoice/billing completeness (now code-characterized → 🟡, was 🔴 structural)

Characterized from `DeliveryDocGenerationService` + `DeliveryDocDeferralService` (full detail in `dh-claude-validation-evidence.md` §3d). The audit's "frozen snapshot silently drops late billables" is **partly right, partly too pessimistic**:
- **Frozen snapshot is by design** — the period's worklogs are SHA-256-hashed into `SnapshotTxt__c` so signed docs are tamper-evident. Not a bug.
- **Pre-invoice defer/preview EXISTS** (`deliveryInvoicePreviewDeferPanel` + deferral service) — audit missed it.
- **Regeneration recovers** late in-period billables (supersedes prior version).
- **Real bounded gap → DH-BUILD:** **no post-generation "missing-billable" detector / stale-invoice health card** — nothing tells you to regenerate when an in-period billable lands after the invoice froze. Small, scoped build (a health-card check + a query).
- **Remaining to stamp:** empirical DML repro (deferred — unattended stateful DML).

## G. Recommended build queue (post-validation)
1. ~~**T6 inbound ContentVersion ingest**~~ — ✅ root-caused + fix pushed (`fix/inbound-contentversion-orphan-redispatch`, PR pending CI). **Follow-ups (separate, smaller):** (a) inbound **Failed** ContentVersion rows aren't retried — `requeueFailedItems` is Outbound-only, so a fetcher that fails (e.g. keys-blank, transient 5xx) is not re-dispatched even with retries remaining; extend the new sweep or the retry engine to cover inbound files. (b) wire `ApiKeyTxt__c`/`HmacSecretTxt__c` + the `/fileBytes` Site endpoint on the scratch peers so the file actually round-trips (env/config, not code).
2. **Missing-billable detector / stale-invoice health card** (🟡 T11) — small DH-BUILD, high client value.
3. **F7 capture-path `WorkItemId__c` cleanup** (🟡 tech-debt).
4. **B12** — only after Glen's bug-vs-design call on the slider source.

---
*Updated 2026-06-23 overnight. Confirmed defect list: 2 fixed + merged (#932/#933), 1 open (T6), 1 tech-debt (F7). T11 refined to a scoped DH-BUILD. Everything else green or belief-corrected.*
