# Delivery Hub Cockpit — 8-Layer Architecture

This document describes the **cockpit-era architecture** of Delivery Hub: 8 logical layers covering domain, sync, observability, feature lifecycle, onboarding, dev-loop tooling, dataset provisioning, and approvals.

Layers 1-3 are the original delivery platform. Layers 4-8 were added by the cockpit plan (10 PRs, ~50h, shipped in `release/0.243.x` → `release/0.246.x`) and hardened in `release/0.247.x` → `release/0.248.x`.

For the deep object / Apex class / trigger reference, see [ARCHITECTURE.md](ARCHITECTURE.md). For install + smoke-test, see [SETUP.md](SETUP.md).

---

## Layer 1 — Core domain objects

The original work-item model. Everything Delivery Hub does ties back to a `WorkItem__c`.

- **Objects**: `WorkItem__c`, `WorkRequest__c` (vendor bridge), `WorkLog__c` (time entries), `WorkItemComment__c`, `WorkItemDependency__c`
- **Key classes**: `DeliveryWorkItemController`, `DeliveryTimeLoggerController`, `DeliveryWorkflowConfigService`, `DeliveryWorkItemETAService`, `DeliveryWorkItemQueryService`
- **Where to look in the UI**: Delivery Hub → **Board**, **Timeline**, **WorkItem** tab, **Workspace** tab
- **Triggers**: `DeliveryWorkItemTrigger`, `DeliveryWorkLogTrigger`, `DeliveryWorkItemCommentTrigger`, `DeliveryDependencyTrigger`, `DeliveryWorkRequestTrigger`

---

## Layer 2 — Sync & integration

Bidirectional REST sync between Salesforce orgs plus inbound channels (email, Slack, webhooks).

- **Objects**: `SyncItem__c` (audit ledger; `StatusPk__c` = Queued / Staged / Synced / Failed / Pending), `NetworkEntity__c` (connected org or external system)
- **Key classes**: `DeliverySyncEngine`, `DeliverySyncItemProcessor`, `DeliverySyncItemIngestor`, `DeliverySyncItemPendingResolver`, `DeliveryHubSyncService` (REST gateway), `DeliveryHubPoller`, `DeliveryInboundEmailHandler`, `DeliverySlackInboundHandler`, `DeliverySlackOutboundService`, `DeliveryWebhookReceiver`
- **REST surfaces**: `/deliveryhub/v1/sync/*` (org-to-org), inbound webhook handlers for `IntegrationProvider__mdt` (Stripe ships out of box), Slack Event API at `/services/apexrest/slack/events`
- **Where to look in the UI**: **NetworkEntity** tab (connection management), **SyncItem** tab (audit ledger), admin Home → **Sync Retry Panel**, **WorkRequest** tab

Echo suppression is three-layered (X-Global-Source-Id gateway check, in-memory `blockedOrigins`, kill-switch in `captureChanges`). The pending queue (PR #758 added dual-FK support for WorkItemDependency) self-heals via the 15-minute scheduler.

---

## Layer 3 — Observability

Audit trail + daily operations digest.

- **Objects**: `ActivityLog__c` (with SHA-256 hash chain via `DeliveryAuditChainService`), `WatcherDigest__c` (per-run digest snapshot)
- **Key classes**: `DeliveryAuditChainService`, `DeliveryActivityLogCleanup`, `DeliveryWatcherService` (orchestrator), `WatcherDigestRunQueueable`, signal query services (`WatcherARAgingQueryService`, `WatcherFailedSyncTrendQueryService`, etc.), `DeliveryWatcherDigestFormatter`, `deliveryWatcherDigestHistory` (LWC), `deliveryAuditChainViewer` (LWC), `deliveryOnboardingHistory` (LWC)
- **CMT**: `TrackedField__mdt` (declarative field-change tracking — add a row to track any field)
- **Where to look in the UI**: **WatcherDigest** tab (history), **ActivityLog** tab, admin Home → activity dashboard, Permission Analyzer tab
- **Watcher v1 signals shipped**: Signal 1 (SLA Breach), Signal 2 (Stuck Stage), Signal 3 (A/R Aging). 4 additional signal slots are stubbed for activation.

Master flag: `EnableWatcherDigestDateTime__c` on `DeliveryHubSettings__c`. Recipient list: `WatcherDigestRecipientUserIdsTxt__c`. Per-signal toggles: `EnableWatcherSLABreachDateTime__c`, `EnableWatcherStuckStageDateTime__c`, `EnableWatcherARAgingDateTime__c` (all defaulted on install).

---

## Layer 4 — Feature Catalog

Self-describing registry of all toggleable features in the package. Driven by `FeatureDefinition__mdt` (static catalog) + `Feature__c` (runtime state).

- **Objects**: `Feature__c` (runtime — one per shipped feature, install handler seeds), `FeatureDependency__c` (Hard/Soft dependencies, optional CascadeDirection)
- **CMT**: `FeatureDefinition__mdt` (catalog entries; each Feature__c links back via `FeatureDefinitionTxt__c`)
- **Key classes**: `DeliveryFeatureCatalogController` (LWC controller), `DeliveryFeatureGraphService` (BFS cascade computation), `DeliveryFeatureSyncService` (bidirectional Feature__c ↔ DeliveryHubSettings__c.Enable*DateTime__c mirror), `DeliveryFeatureTriggerHandler`, `DeliveryFeatureDepEditorController`
- **LWCs**: `deliveryFeatureCockpit` (catalog browse + admin toggle), `deliveryFeatureCascadePreview` (modal — shows what else would flip), `deliveryFeatureDependencyEditor` (inline dependency edit on Feature__c record page from PR #819)
- **Where to look in the UI**: **Feature** tab, admin Home → **Feature Catalog** card, Feature record page → Dependencies inline editor

When an admin toggles a feature, `toggleFeature` → onboarding gate check → cascade enforcement (refuses Hard violations and auto-opens the preview modal) → `Feature__c` update → trigger → `ActivityLog__c` row + Settings mirror.

---

## Layer 5 — Onboarding gates

Checkr-style gated onboarding tracks. A non-admin cannot enable a feature until they've walked the linked track.

- **Objects**: `OnboardingProgress__c` (per-user per-track runtime state — lessons completed, quiz score + attempts, checklist state JSON, completion stamp)
- **CMTs**: `OnboardingTrack__mdt` (the track itself, links to a FeatureDefinition), `OnboardingLesson__mdt`, `OnboardingQuiz__mdt` (with `AllowRetryDateTime__c` catalog flag), `OnboardingChecklistItem__mdt` (Manual / SoqlQuery / RestCall / WebhookReceived types)
- **Key classes**: `DeliveryOnboardingService` (Manual evaluator + completion stamp), `DeliveryClientOnboardingController` (LWC controller)
- **LWCs**: `deliveryFeatureOnboarding` (lessons → quiz → checklist), `deliveryClientOnboarding`
- **Where to look in the UI**: Feature card → "Start onboarding" when the user lacks the gate; **Feature** record page side panel
- **Sample track shipped**: `Invoice_Generation_Track` (3 lessons + 1 quiz + 3 checklist items). Clone this as a template for custom tracks.
- **Status**: Manual evaluator is fully implemented. SoqlQuery / RestCall / WebhookReceived evaluators are PR 4 stubs (items render and gate, but always fail eval) — see [e2e-walkthrough audit](audits/e2e-walkthrough-2026-05-21.md) Flow 3.

---

## Layer 6 — Dev-loop mirror

DH is the **mirror**, not the orchestrator. Scratch-org provisioning happens in CumulusCI / GitHub Actions; DH records the result.

- **Objects**: `ScratchOrgInstance__c` (per-scratch-org record — orgId, branch, login URL, CCI flow, state, expiry, optional WorkItem link)
- **CMT**: `DevLoopGuide__mdt` (named workflow guides — 4 seed records ship)
- **Key classes**: REST endpoints in `DeliveryPublicApiService.cls` (`postScratchOrg`, `patchScratchOrg`)
- **LWCs**: `deliveryDevLoopGuide`
- **REST routes**: `POST /deliveryhub/v1/api/scratch-orgs` (create on provision), `PATCH /deliveryhub/v1/api/scratch-orgs/{id}` (update state on teardown)
- **Where to look in the UI**: **ScratchOrgInstance** tab, **DevLoopGuide** card
- **Status**: REST endpoints exist and ship; an example `.github/workflows/` file calling them is **not yet shipped** (subscriber devs must write their own).

---

## Layer 7 — Dataset templates

Per-feature sample-data loading via the `load_feature_data` CCI task.

- **Objects**: `DatasetTemplate__c` (catalog entry — feature, NetworkEntity scope, mapping YAML path, Apex script path, estimated record count), `DatasetTemplateAssignment__c` (audit trail of which org loaded which template — currently no writer)
- **Key classes**: `DeliveryDatasetController`
- **LWC**: `deliveryDatasetTemplates` (lists available templates + copies the CLI command)
- **CCI task**: `load_feature_data` in `cumulusci.yml` (parameterized wrapper around `scripts/feature-data/<name>.apex`)
- **Where to look in the UI**: cockpit → **Dataset Templates** card
- **Status**: `invoice_generation.apex` ships as the only per-feature dataset script. Other features will need their own scripts. `DatasetTemplateAssignment__c` rows are not auto-inserted after a successful load — manual provenance only.

---

## Layer 8 — Approval framework

Multi-step cascading approvals for feature toggle requests, with caller-is-approver enforcement and in-app notifications.

- **Objects**: `FeatureToggleRequest__c` (the request — feature, Enable/Disable action, reason, status), `FeatureToggleApproval__c` (one per step in the BFS-derived approval chain — assigned approver, required-by date, decision, note, StepNumber)
- **Key classes**: `DeliveryFeatureApprovalService` (`submit` / `grant` / `reject` / `apply` — caller-is-approver enforced from PR #815), `DeliveryFeatureGraphService` (BFS cascade graph that determines the approval chain depth)
- **LWCs**: `deliveryFeatureApprovalInbox` (admin inbox — pending approvals for the current user), `deliveryFeatureApprovalSubmit` (submission modal from cockpit entry point — PR #818)
- **Notification layer (PR #822)**: `DeliveryNotificationService` + `DeliveryNotificationQueueable` fire on submit / grant / reject / onboarding-completion via the `Delivery_Hub_Alert` CustomNotificationType. Bell notifications + mobile push.
- **REST**: `POST /features/{name}/toggle` (submit), `POST /feature-toggle-approvals/{id}/grant`, `POST /feature-toggle-approvals/{id}/reject`, `GET /feature-toggle-requests` (paginated)
- **Where to look in the UI**: admin Home → **Approval Inbox** card, cockpit → **Submit Request** button on any feature with `RequiresApprovalCheckbox__c` semantics, **FeatureToggleRequest** tab (audit)
- **Gaps**: `ApproverUserLookup__c` is null at create — admin must edit each row to assign the approver (auto-routing via `ApprovalRouting__mdt` is on the v2 roadmap).

---

## Cross-layer integration

The layers are independently testable but compose at runtime:

```
admin clicks Enable in deliveryFeatureCockpit (Layer 4)
  ↓
toggleFeature(featureId)
  ↓
Layer 5: onboarding gate check (DeliveryOnboardingService — refuses non-admins without complete track)
  ↓
Layer 4: cascade enforcement (DeliveryFeatureGraphService — refuses Hard violations, opens preview modal)
  ↓
Layer 8: if RequiresApproval, submit FeatureToggleRequest instead of flipping (deliveryFeatureApprovalSubmit)
  ↓
Layer 4: Feature__c.EnabledDateTime__c stamped
  ↓
Layer 2/3: DeliveryFeatureTriggerHandler → ActivityLog__c row (Layer 3 hash chain) + Settings mirror (Layer 4 sync)
  ↓
Layer 8 notification: DeliveryNotificationService.notifyFeatureToggled (in-app bell)
```

Watcher (Layer 3) reads from all layers (sync drift, SLA-breached WorkItems, A/R aging from DeliveryDocument__c / DeliveryTransaction__c) and publishes the daily digest to `WatcherDigest__c` + Slack.

---

## What's *not* in the cockpit (yet)

Documented for transparency in [docs/audits/e2e-walkthrough-2026-05-21.md](audits/e2e-walkthrough-2026-05-21.md):

- Approver **auto-assignment** (currently null at create — admin opens row to set)
- Non-Manual onboarding **checklist evaluators** (SoqlQuery / RestCall / WebhookReceived stubs)
- **Example GitHub Action** workflow for the `/scratch-orgs` endpoint
- Per-feature **dataset scripts** beyond `invoice_generation.apex`
- `DatasetTemplateAssignment__c` **auto-write** after a successful load
- Approval **chain auto-routing** via `ApprovalRouting__mdt`

These are tracked as follow-on cycles; the cockpit is **roughly 60% end-to-end** for the happy-path user as of `release/0.248.0.3`.
