# Delivery Hub — Architecture Overhaul Roadmap

> **Owner:** David (architecture overhaul lane). **Drafted:** 2026-07-13.
> **Relationship to the ship team:** the feature team is driving the current build to a finish line on `main`. This overhaul runs *alongside* it, behind seams and flags, and never freezes their work. See the assessment in `docs/mental-model.md` for the current-state diagrams.

---

## 0. The thesis

Delivery Hub today is **strongly configured but weakly layered**. Its config is metadata-driven, its dependency graph is inverted (REST and services reach up into UI controllers), it has no repository or constants tier, and its delivery *pipeline* is welded to hardcoded stage strings even though the *board* that renders it is data-driven.

This roadmap moves the app to: **records-as-config, tight bounded contexts, one-way dependencies, and a record-driven lifecycle that a second firm could re-wire without touching Apex.**

### Non-negotiable principles (the rubric everything is measured against)

1. **Config is data, in records.** Custom Metadata Types are eliminated. All config lives in custom objects, editable at runtime, seeded as version-controlled data via post-install Apex / MetaDeploy.
2. **Secrets are credentials, never fields.** API keys, HMAC secrets, and the OpenAI key move to Named / External Credentials, deployed and managed out-of-band.
3. **Each major feature is a bounded context.** A domain owns its objects, its rules, and its data access. No context reaches into another's internals; they talk through published interfaces only.
4. **Dependencies flow one way:** `trigger → domain → repository → data`, and `edge (REST/LWC controller) → domain`. Nothing calls *up* into a controller. Ever.
5. **No hardcoded domain vocabulary.** Stage names, statuses, transitions, and namespace prefixes resolve from a constants layer or from config records — not string literals scattered across 50 files.
6. **The lifecycle is a record-driven state machine.** Write-side transitions resolve their target stage from per-workflow-type transition records, so the pipeline shape is configurable, not compiled in.

---

## 1. Target architecture

### 1.1 Module layout (bounded contexts)

Reorganize by **domain**, not by technical role. Each context is a self-contained module with a single public contract:

```
domains/
  workflow/        (stages, transitions, the lifecycle state machine)
  intake/          (capture, triage, routing)
  approval/        (estimate → decision → cap)
  delivery/        (work items, logs, dependencies)
  billing/         (documents, invoices, transactions, payments)
  signing/         (document actions, hash chain, certificates)
  sync/            (the cross-org spine)
  observability/   (activity log, watcher, escalation)
  bounty/          (public discovery + claim lifecycle)
  config/          (the records-as-config engine + seed)
  platform/        (shared kernel: constants, IDs, credentials, results, errors)
```

Each domain module holds four kinds of class and nothing else:

| Kind | Responsibility | Rule |
|---|---|---|
| **Model** (`Invoice`, `WorkItemAggregate`) | In-memory domain object + invariants | No SOQL/DML |
| **Repository** (`BillingRepository`) | ALL SOQL + DML for the context's objects | Only place queries live |
| **Service** (`BillingService`) | Use-cases / orchestration | Depends on its own repo + other domains' *interfaces* |
| **Contract** (`IBilling`) | The published surface other domains call | The ONLY thing another domain may import |

> **Decision I made (veto if wrong): lightweight hand-rolled modules, not fflib.** You dislike CMT clunk; fflib's Selector/Domain/UnitOfWork/Application-factory ceremony is the same tax in a different place. Plain `Service + Repository + Model + Interface` gives you the boundaries and the mockability without the framework. If you'd rather adopt fflib or the Trigger Actions Framework, this is the one structural fork to settle before Phase 3.

### 1.2 Dependency rule (enforced, not hoped)

```
LWC / REST edge ─┐
                 ├─► Domain Service ─► Repository ─► SObjects
Trigger ─────────┘          │
                            └─► other Domain's Interface (never its internals)
```

Add a CI guard (PMD custom rule or a lightweight AST/grep check) that **fails the build** when:
- an `*ApiService` or `*RestResource` references a `*Controller`,
- a `*Service` references a `*Controller`,
- a class outside `domains/X/` references a non-interface class inside `domains/X/`,
- raw SOQL/DML appears outside a `*Repository`.

The rule is what makes principle 3 and 4 durable instead of aspirational. Without it we regress in a month.

### 1.3 Config-as-data engine

Every CMT becomes a custom object. Config resolves through one path:

```
ConfigService.resolve(context) ─► live records (org-editable) ─► seeded defaults (same records, shipped as data)
```

There is no CMT fallback tier because there is no CMT. First-install seed is **data**, delivered by MetaDeploy / post-install Apex from version-controlled files in `datasets/` (which already exists in the repo). Admins edit the same records at runtime; no deploy required to retune.

### 1.4 Secrets

`NetworkEntity__c.ApiKeyTxt__c` / `HmacSecretTxt__c`, `IntegrationProvider` signature secrets, and the OpenAI key move to **Named Credentials + External Credentials**. Callouts reference the named credential; nothing stores a secret in a queryable field. This also retires the plaintext-key finding from `DELIVERY-HUB-FUTURE.md`.

---

## 2. Migration strategy — strangler-fig behind flags

> **Decision I made (veto if wrong):** we do NOT freeze `main` for a v2 rebuild, and we do NOT refactor the shipping team's hot files in place. We build new contexts beside the old code, put a seam in front, and cut over one domain at a time behind a `*DateTime__c` flag — the same flag pattern the app already uses. Each cutover is independently shippable and independently revertible.

The loop for every context:
1. Stand up the new module (`domains/X/`) with repo + service + interface + tests.
2. Introduce a seam: the old call site delegates to the new service when `UseNewXDateTime__c` is set.
3. Dark-launch in a scratch/demo org, verify parity against the old path.
4. Flip the flag in prod; leave the old path dormant one release.
5. Delete the old path.

---

## 3. Phased roadmap

Phases are ordered by **leverage and safety**: cheap foundational wins first, the highest-blast-radius domain (sync) last.

### Phase 0 — Foundations & guardrails  *(no behavior change, unblocks everything)*
- [ ] Create `platform/` shared kernel: `DeliveryConstants` (stages, statuses, action types), `Namespace` resolver (retire the 28 hardcoded `delivery__` literals), `Result`/`Error` types.
- [ ] Replace scattered status/stage string literals (~40 files) with `DeliveryConstants` references. Mechanical, high-confidence, immediately kills the copy-paste brittleness.
- [ ] Land the CI dependency-guard rule (§1.2) in **warn** mode. Baseline the existing violations.
- [ ] Add a `domains/` folder convention + a one-page CONTRIBUTING note so the ship team stops adding to the god controllers.

**Done when:** no raw stage/status/namespace literal survives outside `platform/`, and the guard reports a frozen baseline.

### Phase 1 — Config-as-data: kill CMT  *(the thing you actually asked for)*
- [ ] Build the `config/` domain: for each CMT, a mirror custom object + a repository + `ConfigService.resolve()`.
- [ ] Author the seed as version-controlled data in `datasets/`; wire post-install Apex + MetaDeploy to load it.
- [ ] Migrate CMTs in dependency order (see §4). Start with the leaf configs (DashboardCard, SLARule, TrackedField), finish with the workflow trio.
- [ ] Dual-read seam: `ConfigService` reads records, falls back to CMT only until each type is cut over; delete CMT type once its object is live.

**Done when:** zero `__mdt` reads remain in Apex; a fresh install seeds config as records; an admin can retune without a deploy.

### Phase 2 — Repository layer  *(centralize data access)*
- [ ] Per context, extract every `[SELECT ...]` and `Database.*` into `XRepository`. 31 non-test classes have inline SOQL today; 67 have DML.
- [ ] Repositories become the only `WITH SYSTEM_MODE` / `AccessLevel` authority — one place to reason about sharing and FLS.

**Done when:** no SOQL/DML outside a `*Repository`; the guard rule enforces it.

### Phase 3 — Domain extraction & dependency inversion  *(break the god controllers)*
- [ ] Split `DeliveryGanttController` (1776 lines) and `DeliveryHoursAnalyticsController` (1489) into domain services; leave the controllers as thin edges.
- [ ] Invert the REST→controller and service→controller dependencies: `DeliveryPublicApiService`, `DeliveryInvoiceGenerationService` et al. call domain *services*, not controllers.
- [ ] Replace controller-to-controller calls (17 of them) with interface calls between domains.
- [ ] Flip the CI guard from **warn** to **block**.

**Done when:** the guard passes in block mode; no class calls up into a controller.

### Phase 4 — Record-driven lifecycle engine  *(the flexibility thesis)*
- [ ] Model transitions as records: `StageTransition__c` (workflow type, from-stage, to-stage, trigger event, guard, gate). This is the write-side twin of the read-side semantics that already work.
- [ ] Rewrite `routeToDev` / `markDone` / the approval transitions to `resolveTransition(item.workflowType, EVENT)` instead of literal `'Ready for Sizing'` / `'Done'` / `'Accepted'`.
- [ ] The lifecycle becomes one `WorkflowEngine.transition(item, event)` in the `workflow/` domain that every context calls; no context hardcodes a stage.

**Done when:** a new workflow type with different stage names runs the full intake→paid loop with no Apex change — proven in a test org.

### Phase 5 — Secrets to credentials
- [ ] Move NetworkEntity/IntegrationProvider secrets + OpenAI key to Named/External Credentials.
- [ ] Callouts (`sync/`, AI, webhooks) reference named credentials; delete the secret fields.

**Done when:** no secret is stored in a queryable field; callouts authenticate via credentials.

### Phase 6 — Context-by-context cutover (highest blast radius last)
Order by fragility (from the ship team's own ranking): **billing → approval → signing → observability → sync last.** Sync is the most-patched, most load-bearing subsystem; it gets the mature engine and the most parity testing, and it cuts over only after every safer domain has proven the pattern.

**Done when:** every domain runs through its new module; the old `classes/` flat namespace is empty of business logic.

---

## 4. CMT inventory to migrate (Phase 1 work-list)

Concrete targets, roughly in cut-over order (leaf configs first, workflow core last):

| CMT today | → Object | Notes |
|---|---|---|
| `DashboardCard__mdt` | `DashboardCard__c` | Pure display config; safest first cut. |
| `TrackedField__mdt` | `TrackedField__c` | Small, self-contained. |
| `SLARule__mdt`, `WorkflowEscalationRule__mdt` | `SLARule__c`, `EscalationRule__c` | Rule configs. |
| `DocumentTemplate__mdt`, `DocumentTemplateSlot__mdt` | `DocumentTemplate__c`, `…Slot__c` | Billing/signing domain. |
| `IntegrationProvider__mdt` | `IntegrationProvider__c` | Secrets split out to External Credentials (Phase 5). |
| `DiagnoseRule__mdt`, `DeveloperCapacity__mdt`, `UserAutoAssignConfig__mdt` | records | Lower-traffic configs. |
| `FeatureDefinition__mdt`, onboarding `*__mdt`, `DevLoopGuide__mdt` | records | Cockpit layers (off by default; low risk). |
| `CloudNimbusGlobalSettings__mdt` | fold into `DeliveryHubSettings__c` or a `GlobalConfig__c` | Global defaults. |
| `WorkflowType__mdt` / `WorkflowStage__mdt` / `WorkflowPersonaView__mdt` | `WorkflowType__c` / `WorkflowStage__c` / `WorkflowPersonaView__c` | **Last and most careful.** This is the core the board + the new transition engine read. Cut over with the fullest parity suite. `WorkflowStageRequirement__mdt` → `StageGate__c` rides along. |

---

## 5. Risks & guardrails

- **Packaging:** moving config to records means a fresh subscriber install has *empty* config until seed runs. The post-install seed (Phase 1) is therefore load-bearing, not optional. Test the subscriber-upgrade path explicitly — the GVS saga in `CLAUDE.md` is the scar that proves upgrade ≠ fresh.
- **The ship team touches these files daily.** Strangler seams (not in-place rewrites) keep our blast radius off their hot path. Coordinate Phase 3 controller splits with whoever owns Gantt/Analytics.
- **CI cost:** each PR spins scratch orgs; batch related cutovers per the repo's CI rules.
- **Don't regress the sync fixes.** Sync is cut over *last*, with the most parity testing, precisely because it has the deepest fix history.
- **Guard rule is the keystone.** If the dependency-direction CI check doesn't land early (Phase 0) and go blocking (Phase 3), the whole structure erodes back to the current state.

---

## 6. Open decisions (settle before the phase that needs them)

1. **Arch backbone** (needed by Phase 3): lightweight hand-rolled modules (my recommendation) vs. fflib vs. Trigger Actions Framework.
2. **Tenancy timing** (needed by Phase 4): build the reconfigurable transition engine now (my recommendation — it's nearly free once config is records) vs. keep one pipeline shape and generalize when customer #2 is real.
3. **Trigger framework** (optional, Phase 0/3): keep the bespoke `*TriggerHandler` pattern (cleaned up) vs. adopt a real dispatcher. The current triggers are clean; this is low priority.
4. **CMT total-zero vs. pragmatic exceptions:** you want CMT gone entirely. Confirm we hold that line even for genuinely static, never-runtime-edited structural defaults (I'll assume yes and seed those as records too).

---

*Companion docs: `docs/mental-model.md` (current-state mermaid), `docs/ARCHITECTURE.md` (deep reference), `DELIVERY-HUB-FUTURE.md` (product roadmap — this is the architecture roadmap that runs under it).*
