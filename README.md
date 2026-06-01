<p align="center">
  <h1 align="center">Delivery Hub</h1>
  <p align="center">
    <strong>Track Work. See Progress. Skip the Chaos.</strong>
  </p>
  <p align="center">
    A free Salesforce-native app that replaces spreadsheets, email chains, and status meetings<br>with one dashboard your whole team actually uses.
  </p>
  <p align="center">
    <a href="https://github.com/Nimba-Solutions/Delivery-Hub/actions"><img src="https://img.shields.io/github/actions/workflow/status/Nimba-Solutions/Delivery-Hub/feature.yml?branch=main&label=CI&logo=github" alt="CI"></a>
    <a href="LICENSE.md"><img src="https://img.shields.io/badge/license-BSL_1.1-blue" alt="License"></a>
    <a href="https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest"><img src="https://img.shields.io/github/v/release/Nimba-Solutions/Delivery-Hub?label=latest&logo=salesforce" alt="Latest Release"></a>
    <a href="https://cloudnimbusllc.com"><img src="https://img.shields.io/badge/docs-cloudnimbusllc.com-0070d2" alt="Docs"></a>
  </p>
  <p align="center">
    <a href="#install">Install</a> &middot; <a href="#architecture-the-8-layer-cockpit">Architecture</a> &middot; <a href="docs/ARCHITECTURE.md">Docs</a> &middot; <a href="docs/PUBLIC_API_GUIDE.md">REST API</a> &middot; <a href="#contributing">Contributing</a>
  </p>
</p>

---

## What is Delivery Hub?

Delivery Hub is a Salesforce-native delivery operations platform. It gives teams a Kanban board, cross-org sync, time tracking, document generation, AI-powered estimates, a public REST API, and an **admin cockpit** for feature lifecycle management (toggle, approve, onboard, observe) — all running inside Salesforce, tied to the accounts and contacts they belong to.

It is open source under the [BSL 1.1 license](LICENSE.md) and ships as an unlocked 2GP package in the `delivery` namespace.

---

## Install

**Current release**: [`release/0.256.0.2`](https://github.com/Nimba-Solutions/Delivery-Hub/releases) (production-promoted 2026-05-31). See [GitHub Releases](https://github.com/Nimba-Solutions/Delivery-Hub/releases) for the full version history.

| Environment | Link |
|---|---|
| **Production** | [![Install in Production](https://img.shields.io/badge/Install-Production-0070d2?logo=salesforce&style=for-the-badge)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000VhdNIAS) |
| **Sandbox** | [![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-3e8b3e?logo=salesforce&style=for-the-badge)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000VhdNIAS) |

**Quickstart (≈5 minutes):**

1. Install the package (select **Install for All Users**)
2. Assign permsets — see [Permission Sets](#permission-sets) below
3. Open the **Delivery Hub Admin** app
4. Run **Quickstart Connection** on the Home tab (configures scheduler, settings, handshake)
5. Open the **Feature Catalog** card on the home page to see what's available

Full step-by-step is in [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

---

## Permission Sets

| Permset | Audience | What it grants |
|---|---|---|
| `DeliveryHubApp` | End users | Read/write on work items, time logging, board access, portal user access |
| `DeliveryHubAdmin_App` | Admins | Everything in `DeliveryHubApp` plus settings, cockpit, Watcher digest, REST keys, audit-trail viewers |
| `DeliveryHubGuestUser` | Salesforce Site guest profile | Minimal access for the public REST API + portal signing |
| `Delivery_Hub_Gantt_Fullscreen` | Optional | Full-screen Gantt experience |

Assign via Setup → Permission Sets → click the permset → **Manage Assignments**.

Or via Apex (one-shot for the current user):

```apex
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App'];
insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);
```

---

## Apps and Tabs

Delivery Hub ships **two Lightning apps**:

- **Delivery Hub** — end-user app: Home, Workspace, Board, Timeline, Activity Feed, Voice Notes, Guide
- **Delivery Hub Admin** — admin/superuser app: everything above plus all object tabs, cockpit objects, Permission Analyzer, Settings

### Admin app tabs (current as of `release/0.256.0.2`)

`Home` · `Workspace` · `WorkItem` · `Board` · `Timeline` · `Activity` · `Activity Dashboard` · `NetworkEntity` · `WorkRequest` · `WorkItemComment` · `SyncItem` · `ActivityLog` · **`Feature`** · **`FeatureToggleRequest`** · **`WatcherDigest`** · **`ScratchOrgInstance`** · `Permission Analyzer` · `Settings` · `Guide` · `Reports`

The four bolded tabs are the cockpit additions from the 50-hour cockpit plan + Watcher v1 (shipped in `release/0.245.0.4` and `release/0.246.0.4`).

---

## Architecture: the 8-layer cockpit

Delivery Hub is organized into 8 layers. Layers 1–3 are the original delivery platform; Layers 4–8 were added in the cockpit plan (`release/0.243.x` → `0.246.x`) and hardened in `release/0.247.x` → `0.248.x`.

| Layer | Name | Purpose |
|---|---|---|
| **1** | Core domain | `WorkItem__c`, `WorkRequest__c`, `WorkLog__c`, `WorkItemComment__c`, `WorkItemDependency__c` |
| **2** | Sync & integration | `SyncItem__c`, `NetworkEntity__c`, Slack inbound/outbound, inbound email, IntegrationProvider webhooks |
| **3** | Observability | `ActivityLog__c` (hash-chained), `WatcherDigest__c`, daily Watcher digest (Signals 1-3) |
| **4** | Feature Catalog | `Feature__c` + `FeatureDefinition__mdt` + `FeatureDependency__c` + `deliveryFeatureCockpit` LWC |
| **5** | Onboarding gates | `OnboardingTrack__mdt` + `OnboardingLesson/Quiz/ChecklistItem__mdt` + `OnboardingProgress__c` |
| **6** | Dev-loop mirror | `ScratchOrgInstance__c` + `DevLoopGuide__mdt` + REST `POST/PATCH /scratch-orgs` |
| **7** | Dataset templates | `DatasetTemplate__c` + `DatasetTemplateAssignment__c` + `load_feature_data` CCI task |
| **8** | Approval framework | `FeatureToggleRequest__c` + `FeatureToggleApproval__c` + multi-step cascading approvals + in-app notifications |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the deep object/class/trigger reference, [docs/COCKPIT.md](docs/COCKPIT.md) for the per-layer cockpit detail, and [docs/SETUP.md](docs/SETUP.md) for the install/smoke-test runbook.

---

## REST API

Three REST surfaces ship with the package, all under `/services/apexrest/delivery/`:

| Surface | Base path | Use case | Auth |
|---|---|---|---|
| **Public API** | `/deliveryhub/v1/api/*` | Websites, mobile apps, portal, cockpit clients | `X-Api-Key` header |
| **Sync API** | `/deliveryhub/v1/sync/*` | Org-to-org bidirectional sync | `X-Api-Key` + HMAC (opt-in) |
| **Task API** | `/deliveryhub/v1/tasks/*` | CI/CD agents, AI agents | `X-Api-Key` |

The Public API covers dashboard reads, work items, comments, work logs, activity feed, documents, document signing, feature toggle requests, scratch-org mirror writes, entity-scoped Watcher health (`GET /watcher-health`), and onboarding-track progress (`GET /onboarding-progress`).

Highlights from the recent hardening pass (`release/0.247.x` PR #813):

- **Rate limiting** on GET / POST / PATCH (opt-in via `PublicApiRateLimitNumber__c` on `DeliveryHubSettings__c`; HTTP 429 + `Retry-After: 3600` on breach)
- **Idempotency** on `POST /features/{name}/toggle` (deduplicates Pending/Granted rows on retry)
- **Pagination envelope** (`{data, offset, pageSize, hasMore}`) on `GET /feature-toggle-requests`

Full endpoint reference: [docs/PUBLIC_API_GUIDE.md](docs/PUBLIC_API_GUIDE.md). For org-to-org sync: [docs/SYNC_API_GUIDE.md](docs/SYNC_API_GUIDE.md). For the bounty marketplace surface: [docs/BOUNTY_API_GUIDE.md](docs/BOUNTY_API_GUIDE.md).

---

## What's in the box

A short cross-reference. The deep narrative is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

**Delivery platform** — Kanban board (40+ stages, persona views, stage gates), Nimbus Gantt timeline (5 visualization modes, Auto-Schedule modal, phone remote), cross-org sync (bidirectional REST with echo suppression, HMAC signing, retry, pending queue for child-before-parent races), inbound email handler, Slack bidirectional comment sync.

**Time tracking & billing** — WorkLog approval pipeline (Draft → Approved → Synced), invoice automation (Daily/Weekly/Monthly/Quarterly per NetworkEntity), document engine (invoices, status reports, agreements, certificates of completion), native multi-party signing (no DocuSign integration, ESIGN/UETA-compliant via SHA-256 hash chain), client-portal approval/dispute flow.

**AI & escalation** — OpenAI-backed work-item drafting (description + acceptance criteria + estimate), weekly digest, ETA engine, rule-based escalation engine (`WorkflowEscalationRule__mdt`), no-response detection, business-hours SLAs.

**Observability** — `ActivityLog__c` audit trail with SHA-256 hash chain (legal-hold mode), `WatcherDigest__c` daily ops digest (Signals 1-3 active: SLA Breach / Stuck Stage / A/R Aging; 4 stubs ready for activation), Permission Analyzer (30-day usage → permset recommendations), Activity Dashboard, audit-trail viewer LWCs.

**Cockpit (Layers 4-8)** — Feature Catalog with toggle/approve/cascade workflow, gated onboarding tracks (Checkr-style), FeatureDependency editor on record page, dev-loop mirror (scratch org provenance), dataset templates, multi-step approvals with caller-is-approver assertion + in-app notifications.

**Configurable workflows** — 7 workflow types ship (Software Delivery, Loan Approval, Customer Onboarding, HR Recruiting, Marketing Campaign, Change Management, Operations); all stages/personas/transitions are CMT-driven.

**Operational** — Quickstart Connection wizard, Ghost Recorder (floating capture form with voice dictation), Voice Notes, CSV Import, 25 pre-built reports, Saved Filters, Email Preview & Scheduled Send.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/GETTING_STARTED.md) | Installation, permset assignment, first work item, optional cross-org sync, document signing, AI |
| [Setup Guide](docs/SETUP.md) | Pre-install checklist, install/upgrade commands, smoke test, common gotchas |
| [Architecture](docs/ARCHITECTURE.md) | Object model, sync engine, API layer, LWC catalogue, enterprise services, permission model |
| [Cockpit Architecture](docs/COCKPIT.md) | 8-layer cockpit: per-layer objects, classes, LWCs, UI pointers |
| [REST API Reference](docs/PUBLIC_API_GUIDE.md) | Public API — endpoints, auth, request/response shapes, rate-limiting, pagination |
| [Sync API Guide](docs/SYNC_API_GUIDE.md) | Org-to-org sync — push/pull flows, echo suppression, HMAC, setup |
| [Bounty API Guide](docs/BOUNTY_API_GUIDE.md) | Bounty marketplace — public discovery, authenticated claim lifecycle |
| [Document Actioning](docs/DOCUMENT_ACTIONING_FEATURE.md) | Multi-party signing — slots, signer tokens, hash chain, certificate of completion |
| [Field Naming](docs/FIELD_NAMING.md) | Type-suffix convention enforced by PMD (`*Txt__c`, `*Number__c`, etc.) |
| [Changelog](docs/CHANGELOG.md) | Version history (pre-0.200 PR-by-PR; later releases tagged in GitHub Releases) |

---

## Development

### Prerequisites

- [CumulusCI](https://cumulusci.readthedocs.io/) (`pip install cumulusci`)
- A Salesforce Dev Hub org with scratch-org allocations available
- Salesforce CLI (`sf` or `sfdx`)
- Git

### Local setup

```bash
git clone https://github.com/Nimba-Solutions/Delivery-Hub
cd Delivery-Hub
cci flow run dev_org --org dev
cci org browser dev
```

### Day-to-day

```bash
# Retrieve changes from your scratch org
cci task run retrieve_changes --org dev

# Push a feature branch — CI spins a fresh namespaced scratch org per PR
git push origin feature/your-feature
```

Every pull request runs feature tests in a namespaced scratch org. PMD static analysis blocks priority 1-4 violations. Apex coverage is enforced at 75% globally, 90% on new enterprise services.

### Releasing

```bash
# Beta — auto-runs on merge to main via beta_create.yml
cci flow run release_unlocked_beta --org packaging

# Production
cci flow run release_unlocked_production --org packaging
```

See [CLAUDE.md](CLAUDE.md) for the full Salesforce/CI/CD/workflow rule reference.

---

## Help & support

- **Bug reports / feature requests**: [open an issue](https://github.com/Nimba-Solutions/Delivery-Hub/issues)
- **Docs**: the [docs/](docs/) folder in this repo
- **Recent changes**: [GitHub Releases](https://github.com/Nimba-Solutions/Delivery-Hub/releases)

---

## Contributing

Delivery Hub is open source under the [BSL 1.1 license](LICENSE.md) (converts to Apache 2.0 four years after each release).

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-idea`)
3. Make your changes
4. Push and open a PR — CI validates everything automatically

---

<p align="center">
  <strong>Built by <a href="https://cloudnimbusllc.com">Cloud Nimbus LLC</a></strong><br>
  We build Salesforce delivery infrastructure so you can focus on your actual product.<br><br>
  <a href="https://cloudnimbusllc.com">Website</a> &middot; <a href="https://cloudnimbusllc.com/docs">Documentation</a> &middot; <a href="https://github.com/Nimba-Solutions/Delivery-Hub/issues">Issues</a>
</p>
