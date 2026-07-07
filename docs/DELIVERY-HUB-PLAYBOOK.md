# Delivery Hub — Operating Playbook

> **Purpose.** A durable, handoff-grade framework for getting Delivery Hub **installed, seeded, and running** — written so a less-capable model (or a tired human) can follow it mechanically without rediscovering today's landmines. Every command here was executed and verified on 2026-07-06 unless marked otherwise.
>
> **Read this first, then do exactly what it says.** Where it says "do NOT," a prior session ignored that and burned hours.

---

## 0. The one thing to understand before touching anything

Delivery Hub **works**. The product installs 100% and the core loop runs. The reason it has *felt* broken is not the product — it's two things that lie to you:

1. **The install toolchain reports false success** on Windows (`cci` auth bug; `sf` source-tracking failing at 0% while printing "Succeeded"). → **Solution: use the one install path in §2. Do not use `cci flow run` or plain `sf project deploy --source-dir` for a fresh org.**
2. **Metadata-deployed custom fields have NO field-level security by default** — not even for System Admin. A field can be fully deployed and still be invisible: SOQL says `No such column`, Apex says `Field does not exist`. This looks *exactly* like "the field didn't deploy," but it did. → **Solution: the permsets must grant FLS (see §5). Verify field existence with the Tooling API, not SOQL (see §6).**

If you internalize only those two facts, you will avoid ~90% of the wasted effort.

---

## 1. What Delivery Hub is (30-second version)

A free, Salesforce-native platform for running client delivery work: track work from request → delivery, with the client seeing progress. Unlocked package, `delivery` namespace. The **simple loop** is:

`install → sign → send (intake) → size → approve → deliver → confirm → invoice`

There are **two apps**: `DeliveryHub` (simple, buyer-facing) and `DeliveryHubAdmin` (everything). See §7 (architecture map) for which permset backs each.

---

## 2. THE reliable install path (one command)

```bash
bash scripts/spin-up-demo-org.sh [alias]      # default alias: dh-demo
```

That script does the whole thing and is the canonical path. It exists because the "official" paths are broken on this machine. What it does, and **why each step is necessary**:

| Step | What | Why (the landmine it dodges) |
|---|---|---|
| 1 | `sf org create scratch -f orgs/dev.json -v MF` | Dev Hub is aliased **`MF`** (NOT `dh-prod` — that is not a scratch-capable Dev Hub). `orgs/dev.json` is non-namespaced/unmanaged. |
| 2 | Resolve `%%%NAMESPACE%%%`→`''`, `%%%NAMESPACE_DOT%%%`→`''`, `%%%NAMESPACE_OR_C%%%`→`'c'` in a temp copy | These are CumulusCI tokens. If you skip `cci` you must resolve them yourself or every LWC/Aura that imports Apex fails to compile. |
| 2 | Strip `__tests__/`, `jsconfig.json`, `.eslintrc.json` | These are `.forceignore`'d; a raw deploy from outside the project root tries to compile Jest files (`LWC1702: createElement`) and rolls back. |
| 3 | `sf project convert source → mdapi` | Converting to metadata format lets you deploy with `--metadata-dir`, which **bypasses source tracking** — the Windows source-tracking bug fails deploys at 0% while reporting an old job "Succeeded." |
| 4 | `sf project deploy start --metadata-dir …` | The only reliable deploy. ~1670 components, a few minutes. |
| 5 | `sf org assign permset --name DeliveryHubAdmin_App` | **Required.** Deploying a permset installs its definition; it grants nothing until assigned. FLS (§5) only takes effect after assignment. |
| 6 | `sf apex run -f scripts/load-demo-data.apex` | Seeds the board: 2 entities, 10 work items across 9 stages, requests, logs, comments, an invoice. |

**Do NOT:**
- ❌ `cci flow run demo_org` — dies on scratch creation (`INVALID_AUTH_HEADER`, stale token, not refreshed).
- ❌ `sf project deploy start --source-dir force-app` against a fresh org — hits the Windows source-tracking file-handle limit; leaves a *partially* deployed org while reporting success.
- ❌ Re-import/re-deploy into an org that already had failed deploys — source tracking gets poisoned (marks components "Unchanged" and skips sending them). **When in doubt, cut a fresh org.** It's cheaper than debugging a poisoned one.

---

## 3. Verify the install actually worked (don't trust "Succeeded")

```bash
P="<username or alias>"
# authoritative field catalog (ignores FLS) — use THIS to confirm deploy, not SOQL:
sf data query --use-tooling-api -o "$P" -q \
  "SELECT COUNT() FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName='NetworkEntity__c'"
# Apex class count:
sf data query --use-tooling-api -o "$P" -q "SELECT COUNT() FROM ApexClass WHERE Name LIKE 'Delivery%'"   # expect 318
# board populated:
sf data query -o "$P" -q "SELECT StageNamePk__c, COUNT(Id) FROM WorkItem__c GROUP BY StageNamePk__c"
```

A good install: **318** `Delivery*` Apex classes, **22** custom fields on `NetworkEntity__c`, work items spread across ~9 stages.

---

## 4. Drive / open the loop

```bash
sf org open -o dh-demo                                        # the org
sf org open -o dh-demo --path lightning/n/Delivery_Board      # the board
```
The seed places records at every stage plus a Draft invoice, so the whole loop is visible immediately. (Live record-driving steps: see §8 once agent findings land.)

---

## 5. The FLS rule (why fields "disappear") — the #1 recurring trap

**Metadata-deployed custom fields grant zero FLS by default.** A field present in the org is still invisible unless a permission set grants it and that permset is assigned.

Fix pattern (proven this session — branch `fix/networkentity-fls-permset-gap`):
- Add `<fieldPermissions>` to `DeliveryHubAdmin_App` (admin sees everything) and the client-relevant subset to `DeliveryHubApp`.
- **Skip** three kinds of field — SF *rejects* `fieldPermissions` on them, and they're visible without it anyway:
  - **Master-Detail** (`<type>MasterDetail</type>`) — always accessible.
  - **Required** (`<required>true</required>`) — always visible.
  - **Custom-setting fields** (object has `<customSettingsType>`, e.g. `DeliveryHubSettings__c`) — FLS-exempt; they need `classAccess` only.
- Formula/rollup/auto-number fields → grant `readable` only (`editable=false`).

Deploy the permset with `--ignore-conflicts` (source tracking will otherwise block it), then re-assign. See §_C (permset completeness audit) for the org-wide gap list.

---

## 6. Verification recipes (how to know what's real)

| Question | WRONG tool (lies) | RIGHT tool |
|---|---|---|
| Does field X exist in the org? | `SELECT X FROM …` (fails on missing FLS → "No such column") | `SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName='Obj__c'` (Tooling API, ignores FLS) |
| Did the deploy commit? | the CLI "Succeeded" line (may be a stale job) | `sf project deploy report --job-id <id>` server status, then query real records |
| Can a user *see* field X? | Tooling `FieldDefinition` (ignores FLS) | `SELECT X …` as that user, or check permset `<fieldPermissions>` |

The two views disagreeing (`FieldDefinition` says present, SOQL says missing) is the **signature of an FLS gap**, not a deploy failure.

---

## 7. Architecture map (navigation for a weaker model)

**Scale:** 357 Apex classes, 92 LWC bundles, 51 custom objects, 19 flexipages, 22 tabs, 4 permsets, 3 apps.

**Open these first:** `lwc/deliveryHubWorkspace` (the shell), `lwc/deliveryHubBoard` (the board), `classes/DeliveryTriageController.cls` (intake + close-out), `classes/DeliveryHubBoardController.cls` (board data), `flexipages/DeliveryHubHome.flexipage-meta.xml` (buyer landing), `cumulusci.yml` (build/install), `objects/WorkItem__c/fields/StageNamePk__c.field-meta.xml` (the 36-stage spine).

**Loop object relationships** (read `child.field ──► parent`; MD = Master-Detail):
```
NetworkEntity__c (client/vendor + sync config)
  ├─MD◄ DeliveryDocument__c.NetworkEntityId__c
  ├─lkp◄ WorkItem__c.ClientNetworkEntityLookup__c
  └─lkp◄ WorkRequest__c.DeliveryEntityLookup__c (the "vendor")
WorkItem__c (central record — one unit of client work)
  ├─MD◄ WorkRequest__c.WorkItemId__c
  ├─MD◄ WorkItemComment__c.WorkItemId__c
  ├─lkp◄ WorkLog__c.WorkItemLookup__c
  └─lkp◄ WorkItem__c.ParentWorkItemLookup__c (epics/subtasks)
WorkRequest__c
  └─MD◄ WorkLog__c.RequestId__c   ← hours roll up here
DeliveryDocument__c
  ├─MD◄ DocumentAction__c.DocumentId__c (e-sign slots, reparent OFF = tamper-evident)
  └─MD◄ DeliveryTransaction__c.DocumentId__c (payments)
```

**Loop step → code** (the "8 steps" are a product narrative; code is organized by object/service, so steps share classes):

| Step | Object/field | Apex | LWC |
|---|---|---|---|
| Install | `DeliveryHubSettings__c`; permset assign; scheduled jobs | `DeliveryHubSetupController`, `DeliveryHubScheduler.scheduleAll` | `deliveryHubSetup`, `deliveryGettingStarted` |
| Sign | `DocumentAction__c`; `DeliveryDocument__c.RequireSigningDateTime__c` | `DeliveryDocActionController/Service`, `DeliveryCryptoService` | `deliveryDocumentSignPortal`, `deliverySignaturePad` |
| Send/Intake | `WorkItem__c` (`ActivatedDateTime__c` null = intake, `StatusPk__c`='New') | `DeliveryTriageController` (intake **and** close-out), `DeliveryQuickRequestController` | `deliveryIntakeQueue`, `deliveryQuickRequest` |
| Size | `WorkItem__c.EstimatedHoursNumber__c`; `WorkRequest__c.QuotedHoursNumber__c` | `DeliveryWorkItemQuotesController`, ETA service | `deliveryWorkItemQuotes`, `deliveryManageRequest` |
| Approve | `WorkRequest__c` (`ApproverUserLookup__c`, `AutoApprovedDateTime__c`); `EnforceApprovalCapDateTime__c` | `DeliveryWorkRequestTriggerHandler`, `DeliveryDocApprovalService` | `deliveryApprovalQueue`, `deliveryHoursBurnup` |
| Deliver | `WorkLog__c.HoursLoggedNumber__c`; board stages | `DeliveryTimeLoggerController`, `DeliveryHubBoardController` | `deliveryTimeLogger`, `deliveryHubBoard` |
| Confirm/Close-out | `WorkItem__c` `Deployed to Prod`→`Done` (`markDone`) | `DeliveryTriageController` (close-out mode) | `deliveryCloseOutQueue` |
| Invoice | `DeliveryDocument__c` (Total/Period); `DeliveryTransaction__c` | `DeliveryInvoiceGenerationService`+`Queueable`, `DeliveryDocPaymentService` | `deliveryBillingPreview`, `deliveryDocumentViewer` |

> ⚠️ "Sign" and "Confirm" both ride `DocumentAction__c`/`DeliveryDocActionService` — not cleanly separated; distinguish by `SignatureTypePk__c`/stage. Intake vs close-out are the **same controller**, different queue mode.

**The two apps** (`applications/*.app-meta.xml`):
- **DeliveryHub** = simple buyer surface. Home = `DeliveryHubHome` flexipage. 9 tabs (Home, Delivery_Workspace, Board, Timeline, Activity, WorkItem, Comments, Guide, Cart). Nav locked down. Backed by permset **`DeliveryHubApp`**.
- **DeliveryHubAdmin** = everything (~22 tabs incl. NetworkEntity, WorkRequest, SyncItem, Features, Settings, reports). Backed by **`DeliveryHubAdmin_App`**.
- Install assigns the **`DeliveryHubAdmin` permission set *group*** (distinct from the permsets). New cacheable controllers need `classAccess` in **both** permsets or they no-op for buyers.

**Buyer entry point:** DeliveryHub app → `DeliveryHubHome` flexipage (mounts intake/close-out/getting-started/dashboards) → the durable workspace is the `Delivery_Workspace` tab → LWC `deliveryHubWorkspace` (holds Board/Timeline/Activity/Docs/Guide/Settings as internal tabs).

**Build facts:** package dir `force-app` (+`unpackaged`), sourceApiVersion 61.0, `namespace: null` in sfdx-project (injected at build). Namespace `delivery` + token substitution defined in `cumulusci.yml` (`namespace_inject`, `tasks/deploy.py` find_replace). `run_tests` runs ONLY the `DH` ApexTestSuite — new `*Test.cls` must be registered there or they skip CI and break `beta_create`.

## 8. Minimum paid loop + feature flags

**The flag convention (verified in code):** every toggle is a `Datetime` field on `DeliveryHubSettings__c`; **NULL = OFF**, code checks `!= null`. `Hide*` flags are inverted (NULL = shown). No `Enable*` field has a `<defaultValue>`, so **everything is OFF on a fresh install** except the two the install handler seeds ON — `EnableActivityLoggingDateTime__c` and `EnableBoardMetricsDateTime__c` (both purely internal, no external side effect). **"Off by default" is already built and shipping** — the strategy David sketched is largely already implemented. The work is choosing which flags the paid loop turns ON, not building the flag layer.

**The minimum paid loop:** *get a request in → size it → do the work + log hours → confirm done → cut an invoice → record payment.*
- **Objects:** `WorkItem__c`, `WorkLog__c`, `DeliveryDocument__c`, `DeliveryTransaction__c`.
- **Code:** `DeliveryTriageController` (intake+closeout), `DeliveryGhostController` (intake create), `DeliveryTimeLoggerController`+`DeliveryWorkLogTriggerHandler` (hours), `DeliveryDocumentController.generateDocument`→`DeliveryDocGenerationService` (invoice), `DeliveryDocPaymentService` (payment). LWCs: `deliveryHubBoard`, `deliveryIntakeQueue`, `deliveryTimeLogger`, `deliveryCloseOutQueue`, `deliveryBillingPreview`.
- **Flags ON:** only the two already-seeded internal ones. A **manually-cut invoice** (`DeliveryDocumentController.generateDocument`) needs **no flag** — `EnableInvoiceGenerationDateTime__c` only gates the *nightly automated* job. Recommendation: cut invoices manually for v1; leave automation OFF.
- **Keep dark (OFF):** `EnableAutoActivateDateTime__c` (keeps intake-first), `RequireWorkLogApprovalDateTime__c` + `EnforceApprovalCapDateTime__c` (the whole `WorkRequest__c` approval-rail layer), all AI/Watcher/Cart/Slack/notifications/forecast/status-page. None are in the pay-for loop.
- **Declutter to "just works":** turn several `HideTab*`/`HideHome*` ON to strip the buyer surface to Board + Intake + Timeline + Documents (same declutter already applied for Jose).

**Risk in the minimum loop (verified against tests):** every node is production-solid with matching `*Test.cls` **except SIZE** — and that risk is **not code, it's org config**. The board create modal is a platform `lightning-record-edit-form` on `WorkItem__c`; the documented 6/27 "no access / no fields" breakage is an **FLS/permission failure** (the exact bug class fixed in §5/§10), not an Apex defect. **Before selling: verify FLS on `WorkItem__c` create + `DeveloperDaysSizeNumber__c` in-org.** One benign empty-catch in `DeliveryInvoiceGenerationService.cls:63` swallows per-entity invoice errors silently (acceptable for a batch loop).

**Two flags that gate NOTHING in Apex** (surfaced in Settings UI but vestigial — wire up or remove so the settings screen doesn't promise dead features): `EnableAIEstimationDateTime__c`, `EnableAutoGenerateDescriptionsDateTime__c`. (`EnableAutoSyncNetworkEntityDateTime__c` is a UI proxy — outbound sync actually gates on `NetworkEntity__c.EnableVendorPushDateTime__c`.)

## 9. Known breakages + triage

**Headline: the codebase is far cleaner than the "wheels fall off" feeling suggests.** A full runtime-breakage sweep found the classic failure modes (invalid field refs, broken nav, empty catches hiding failures, unguarded card queries) **essentially absent or guarded** on the daily loop. The real throws are concentrated in **first-run setup**, not daily use.

| # | Severity | What breaks | Location | Status |
|---|---|---|---|---|
| 1 | **BLOCKER** (first-run) | "Connect to Mothership" NPEs — `performHandshake` deref'd the endpoint config with no guard on a fresh org | `DeliveryHubSetupController.cls:154` | ✅ **FIXED this session** (null/blank guard) |
| 2 | **MAJOR** | Admin Health Dashboard cards/repair silently no-op for permset-gated users (`public` controllers missing classAccess) | `DeliveryHubHealthService`, `DeliveryHubRepairService` | ✅ **FIXED this session** (classAccess added to both permsets) |
| 3 | minor | `sendRequestToVendor` raw QueryException if the request was deleted in another session (no list-guard) | `DeliveryRequestManagerController.cls:23` | ⬜ open (edge; add `isEmpty()` guard) |
| 4 | minor | `updateDocumentStatus` same deleted-record QueryException | `DeliveryDocumentController.cls:129` | ⬜ open (edge) |
| 5 | minor (latent) | Invoice-defer panel would wall if placed (`DeliveryDocDeferralService` classAccess) — not on any shipped flexipage today | `deliveryInvoicePreviewDeferPanel` | ✅ **FIXED this session** (preventive classAccess) |

**Verified CLEAN (do not re-hunt):**
- **No invalid field/relationship refs.** The `SyncItem__c.WorkItemId__c` scare is a *false alarm*: the sync engine reads `WorkItemId__c` off the **source** record via `getPopulatedFieldsAsMap()` (describe-safe) and writes to the real field `WorkItemLookup__c`. The `EXCEPTION_THROWN|Invalid field WorkItemId__c` line seen during the demo seed is a **caught, best-effort** describe probe — the seed completes fine; harmless.
- **No broken navigation** across 27 LWCs. **No truly-empty catches** — every swallow is debug-logged on a best-effort side path (audit/notify/parse), none hide a core write. Outbound sync degrades a failed row to `Status='Failed' + ErrorLogTxt__c` rather than throwing (so a broken sync shows as stuck "Failed" rows — a data/config symptom, not a crash).

**Interpretation of "the wheels fall off":** it was **#1 (first-run handshake NPE) + #2 (admin health dashboard dead under the permset)** — both now fixed — compounded by config symptoms (stuck "Failed" sync rows from an unconfigured endpoint), **not** code defects in the daily intake→invoice loop.

## 10. Permset completeness (FLS + classAccess) — org-wide

**Verdict: systemic.** The permsets are hand-maintained and lag the schema/controllers. Same drift that produced the core-loop FLS fix and #952. Exclusions applied (no false positives): `__mdt`/`__e` objects, the one custom setting (`DeliveryHubSettings__c`), 8 Master-Detail fields, 20 required fields.

### 10a. FLS — Tier 1: invisible to EVERYONE (missing from BOTH permsets) — pure bug, safe to grant
**17 fields, 5 objects.** This is the unambiguous fix-list (grant readable+editable in both permsets):
- **BountyClaim__c** (entire object absent from both): `ClaimantEntityLookup__c, ClaimantNameTxt__c, ClaimedDateTime__c, NoteTxt__c, StatusPk__c, SubmittedDateTime__c, WorkProofUrl__c`
- **ActivityLog__c**: `HashChainTxt__c, LegalHoldDateTime__c, PageUrlTxt__c, RecordIdTxt__c`
- **SyncItem__c**: `ChangeTypeTxt__c, DismissedDateTime__c, ParentRefTxt__c`
- **DeliverySavedFilter__c**: `FilterJsonTxt__c, WorkflowTypeTxt__c`
- **PortalAccess__c**: `AccessTokenTxt__c`

### 10b. FLS — Tier 2: in Admin, missing from buyer App only (56 fields) — NEEDS PRODUCT JUDGMENT
Do **not** blind-grant to the buyer app. Some are deliberate buyer-scoping (e.g. `NetworkEntity__c.ApiKeyTxt__c`/`HmacSecretTxt__c` are secrets; `DocumentAction__c` signing forensics). Objects affected: `DeliveryDocument__c` (20), `WorkItem__c` (19, mostly bounty/recurrence/forecast), `DocumentAction__c` (12), `NetworkEntity__c` (3), `WorkLog__c` (2 — `ResourceTitleTxt__c`, `StatusPk__c`). Decide per the minimum-paid-loop cut (see §8).

### 10c. classAccess — live LWC controllers dead for permset-gated users
⚠️ **A completeness-audit agent flagged 7 here; primary-source verification (checking each class's `global`/`public` modifier) cut it to 3 real gaps.** This is the load-bearing lesson: **`global` @AuraEnabled classes are reachable WITHOUT classAccess; only `public` ones need it.** Always check the modifier before "fixing."
- **Real gaps (all `public`) — ✅ FIXED this session** (classAccess added to both permsets): `DeliveryHubHealthService`, `DeliveryHubRepairService` (admin health dashboard), `DeliveryDocDeferralService` (invoice-defer panel, latent).
- **NOT gaps (all `global`, reachable without a grant — leave alone):** `DeliveryCartService`, `DeliveryHoursAnalyticsController`, `DeliveryForecastService`, `DeliveryDepthProbeService`. These back shipped-and-working buyer cards (cart/forecast/pacing/capacity). The agent's "cart is dead" claim was a **false positive** — the cart controller is `global`.

> Also not gaps: return-type DTOs / exception / portal-only services — `DeliveryPortalAccessService`, `CartExperienceProfile`, `SignalResultDTO`, `SignalEntryDTO`, `DeliveryHubHealthCheckResult`, `DeliveryHubException`. Return-type classes don't need class access.

**Gotcha for future audits:** LWC Apex imports carry a `%%%NAMESPACE_DOT%%%` token between `apex/` and the class name, so a naive `grep 'apex/DeliveryCartService'` returns nothing. Search for the class name alone. Also: Grep's `glob` starting with a bare `*__c/...` silently matches nothing — use `**/...`.

---

## Appendix: session facts (2026-07-06)
- Dev Hub for scratch orgs: alias **`MF`** (connected). `GSU-Prod` also a Dev Hub; `SAFE-PROD` dead (inactive user).
- **`scripts/spin-up-demo-org.sh` — CERTIFIED WORKING end-to-end.** Ran on a brand-new org (`dh-demo`, `test-ziaoc71wvput@example.com`) unattended: create → resolve tokens → mdapi deploy → assign permset → seed → "DEMO DATA LOADED SUCCESSFULLY". Result: **318** `Delivery*` Apex classes, work items across **9** stages, 2 entities / 17 requests / 20 logs / 1 invoice. One command, zero manual steps — this is the repeatable org-spin-up that removes the "I can't stand up an org without dev help" blocker.
- Also verified: `dhclean` (`test-inf2cnjzchle@example.com`) — the org where the FLS fix was first proven.
- The "silent field drop / tooling lies for months" claim from a prior session was a **misdiagnosed FLS gap**, not a product or deploy defect. Confirmed twice: (1) fixing FLS made the exact failing seed compile and run to completion; (2) the fixed permsets + spin-up script produce a fully seeded org from scratch in one command.
