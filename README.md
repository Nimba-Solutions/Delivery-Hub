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
    <a href="#install">Install</a> &middot; <a href="https://cloudnimbusllc.com/examples">Examples</a> &middot; <a href="https://cloudnimbusllc.com/docs">Docs</a> &middot; <a href="#contributing">Contributing</a>
  </p>
</p>

---

## Why Delivery Hub?

Most Salesforce teams track work in Jira, Slack threads, or shared spreadsheets. None of those tools know your clients, your pipeline, or your data. Every status update is a manual handoff. Every estimate lives in a comment nobody can find six weeks later.

Meanwhile your CRM &mdash; the system that already knows every account, contact, and deal &mdash; sits right there, completely disconnected from the delivery work you're doing.

**Delivery Hub closes that loop.** Work items, comments, files, stage changes, and estimates all live inside Salesforce, tied to the accounts and contacts they belong to.

| Before | After |
|--------|-------|
| Client emails a change request, gets forwarded 3 times | Client submits directly &mdash; team sees it instantly on the board |
| Small bug fix needs 3 meetings before anyone writes code | Fast Track skips the queue &mdash; developer picks it up same day |
| Vendor work tracked in a separate spreadsheet | Cross-org sync sends it to their Salesforce org automatically |
| VP asks for status &mdash; you open 4 spreadsheets | System Pulse shows everything live, right now |
| Developer guesses hours at end of week | Time Logger captures it on the work item as they go |
| Hours logged but no approval trail | WorkLog approval workflow with Draft &rarr; Approved &rarr; Sync pipeline |
| "We need a portal" = 5 days writing requirements | AI generates description, acceptance criteria, and estimate from one line |
| Blocked item sits for days before anyone notices | Escalation engine auto-alerts when SLA targets are missed |
| Weekly status email takes an hour to write | AI digest compiles and sends it automatically |

---

## Install

| Environment | Link |
|---|---|
| **Production** | [![Install in Production](https://img.shields.io/badge/Install-Production-0070d2?logo=salesforce&style=for-the-badge)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000T0SrIAK) |
| **Sandbox** | [![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-3e8b3e?logo=salesforce&style=for-the-badge)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000T0SrIAK) |

**Setup takes about 3 minutes:**

1. Install the package
2. Open the **Delivery Hub** app
3. Click **Quickstart Connection** on the Home tab &mdash; it configures scheduled jobs, connection handshake, and default settings automatically
4. Create your first work item on the board

No consultants. No manual REST endpoint configuration. No Apex scripts to run.

---

## What You Get

### Kanban Board

Drag-and-drop board with 40+ configurable stages from **Backlog** to **Deployed to Production**. Stage gate enforcement blocks bad transitions until required fields are filled. Persona-based views show clients, developers, and managers exactly what they need to see &mdash; nothing more.

### Cross-Org Sync

Bidirectional REST sync between any two Salesforce orgs. Work items created in one org appear in the other within seconds. Stage changes, comments, and files replicate in both directions with echo suppression to prevent loops. Every sync event is logged for full audit visibility.

### AI-Powered Work Management

OpenAI integration that estimates hours, generates descriptions, and drafts acceptance criteria from a one-line summary. ETA engine projects delivery dates from queue depth, developer velocity, and team calendar. Weekly AI digest emails summarize delivery status and send to configurable recipients on a schedule. One click to accept, easy to override.

### Escalation Engine

Rule-based automated escalations defined through Custom Metadata. Configure conditions like "stuck in QA for 3+ days" or "high priority with no assignee" &mdash; the engine evaluates on every scheduler run and fires email notifications automatically. No manual follow-up needed.

### Board Metrics and Analytics

Burndown chart tracks sprint progress against ideal pace. Developer Workload dashboard shows capacity distribution across the team. Cycle Time analytics measure how long items spend in each stage, identifying bottlenecks before they become blockers.

### Real-Time Collaboration

Polling-based chat on every work item. File rollup panel that aggregates every file from the work item, its comments, and related requests into a single view. Ghost Recorder &mdash; a floating form available anywhere in the app for instant issue submission without leaving your current screen. Activity timeline provides a full audit trail of every change on a work item.

### Client Transparency

Home page dashboard showing everything in flight, broken down by phase. Attention Required surfacing calls out anything waiting on the client immediately. System Pulse gives live counts of active work items, hours booked, and sync health at a glance. Public status page provides a shareable Visualforce view without requiring a Salesforce login.

### Operational Automation

Recurring items auto-create work items on configurable schedules &mdash; daily standups, weekly deploys, monthly reviews. Email notifications fire on stage changes. SLA tracking monitors response and resolution times against configurable targets with visual status indicators.

### Bulk Operations

CSV import wizard maps spreadsheet columns to work item fields and creates items in bulk. Dependency graph visualizes blocking relationships so you can see the critical path. Release notes generator compiles completed items into formatted summaries.

### Billing & Approval

WorkLog approval workflow gates logged hours behind a Draft &rarr; Approved &rarr; Synced pipeline. Enable the `RequireWorkLogApprovalDate__c` setting and all new hours save as Draft until a manager approves them. Batch approve or reject directly from the Activity Feed. When the setting is null, existing behavior is unchanged &mdash; hours sync immediately.

The Activity Feed provides a unified, cross-item timeline of comments, hours, and stage/field changes. Date-grouped entries, conversation threads with inline reply, batch WorkLog approval actions, and 30-second polling keep the entire team on the same page without switching between records.

### Document Engine

Generate professional invoices, status reports, client agreements, and contractor agreements directly from Delivery Hub data. Each document captures an immutable JSON snapshot of hours, rates, and work items for the billing period. Zero-hour work items are automatically filtered from invoices so only billable items appear. PDF rendering via Visualforce produces print-ready output with clickable hyperlinks to the source Salesforce records. The VF URL builder detects the namespace at runtime, so PDF and web preview links work correctly in both managed and unmanaged installations. Email delivery sends the document to the client contact with an optional CC address (configurable via `DocumentCcEmailTxt__c`). Payment tracking through `DeliveryTransaction__c` records supports multiple transaction types (payment, credit, refund, adjustment, write-off) per document. The A/R summary on each invoice shows outstanding prior balances. White-label vendor branding pulls the issuing entity's name, address, email, and phone from the vendor NetworkEntity record. Every invoice footer links to cloudnimbusllc.com. Document versioning preserves history when regenerating &mdash; superseded documents link back via version chain. Client-facing invoice approval flow lets clients approve or dispute invoices from the portal with full audit trail.

### Configurable Workflows

Not just software delivery &mdash; the workflow engine supports any stage-based process. Ships with Software Delivery (40+ stages) and Loan Approval (8 stages) out of the box. Define your own workflow types, stages, personas, and transitions through Custom Metadata.

### Admin Settings

Central settings page with DateTime activation toggles that record who enabled each feature and when. Four operational settings control runtime behavior across the platform:

| Setting | Field | Default | What It Controls |
|---------|-------|---------|-----------------|
| Reconciliation Hour | `ReconciliationHourNumber__c` | 6 (AM UTC) | Hour when the scheduler runs the daily sync reconciliation |
| Sync Retry Limit | `SyncRetryLimitNumber__c` | 3 | Max retry attempts before a failed sync item stops requeueing |
| Activity Log Retention | `ActivityLogRetentionDaysNumber__c` | 90 days | How long activity log records are kept before batch purge |
| Escalation Cooldown | `EscalationCooldownHoursNumber__c` | 24 hours | Minimum interval before re-escalating the same work item |

All four settings are wired into the Apex runtime &mdash; the DeliveryHubScheduler, DeliveryActivityLogCleanup, and DeliveryEscalationService read from `DeliveryHubSettings__c` on every execution. The admin page uses dynamic forms for field-level layout control.

---

## How It Works

```text
Your Org (Client)                        Delivery Team's Org (Vendor)

Work item created        ---- sync ---->  Request ingested
  Stage updated          <--- sync ----   Developer assigned
  Comment posted         ---- sync ---->  Comment synced back
  File attached          ---- sync ---->  Status progressed
  Client approval        ---- sync ---->  Deployed to Prod
```

1. A work item is created on the board. A sync record queues automatically.
2. The sync engine POSTs to the vendor's REST endpoint &mdash; in real time or on the 15-minute scheduler, whichever fires first.
3. The vendor org ingests the payload, creates or updates the matching work item, and syncs back.
4. Both orgs stay in lock-step. Echo suppression ensures changes don't bounce back as duplicates.

The engine is retry-aware (configurable limit, default 3 attempts), handles namespace translation for managed packages, and supports multi-vendor routing to multiple external orgs simultaneously.

---

## Architecture

| Layer | Count | Key Components |
|-------|-------|----------------|
| **Apex Classes** | 148 (75 production + 73 test) | SyncEngine, SyncItemProcessor, SyncItemIngestor, HubPoller, WorkItemController, DocumentController, DocumentPdfController, GuideController, EscalationService, WeeklyDigestService, ETAService, AiController, WorkflowConfigService, DeliverySyncReconciler, SettingsController, TimelineController, SavedFilterController, InboundEmailHandler, EmailService |
| **LWC Components** | 57 | deliveryHubBoard, deliveryClientDashboard, deliveryGuide, deliveryDocumentViewer, deliveryBurndownChart, deliveryCycleTimeChart, deliveryDeveloperWorkload, deliveryDependencyGraph, deliveryCsvImport, deliveryStatusPage, deliveryActivityTimeline, deliveryActivityFeed, deliveryDataLineage, deliveryGhostRecorder, deliveryScore, deliverySettingsContainer, deliveryTimelineView |
| **Custom Objects** | 15 | WorkItem\_\_c, WorkRequest\_\_c, SyncItem\_\_c, NetworkEntity\_\_c, WorkItemComment\_\_c, WorkItemDependency\_\_c, WorkLog\_\_c, ActivityLog\_\_c, DeliveryDocument\_\_c, DeliveryTransaction\_\_c, PortalAccess\_\_c, DeliveryHubSettings\_\_c, BountyClaim\_\_c, DeliverySavedFilter\_\_c |
| **Custom Metadata** | 10 | WorkflowType\_\_mdt, WorkflowStage\_\_mdt, WorkflowPersonaView\_\_mdt, WorkflowEscalationRule\_\_mdt, WorkflowStageRequirement\_\_mdt, CloudNimbusGlobalSettings\_\_mdt, DocumentTemplate\_\_mdt, OpenAIConfiguration\_\_mdt, SLARule\_\_mdt, TrackedField\_\_mdt |
| **Platform Events** | 4 | DeliveryWorkItemChange\_\_e, DeliverySync\_\_e, DeliveryEscalation\_\_e, DeliveryDocEvent\_\_e |
| **Triggers** | 5 | WorkItemTrigger, WorkItemCommentTrigger, ContentDocumentLinkTrigger, WorkLogTrigger, BountyClaimTrigger |

---

## Development

### Prerequisites

- [CumulusCI](https://cumulusci.readthedocs.io/)
- A Salesforce Dev Hub org
- Git

### Local Setup

```bash
git clone https://github.com/Nimba-Solutions/Delivery-Hub
cd Delivery-Hub
cci flow run dev_org --org dev
cci org browser dev
```

### Day-to-Day

```bash
# Retrieve changes from scratch org
cci task run retrieve_changes --org dev

# Push your branch
git push origin feature/your-feature
```

Every pull request automatically spins up a namespaced scratch org, deploys the package, runs 600+ Apex tests (75%+ coverage enforced), runs PMD static analysis (zero violations enforced), and tears everything down.

### Reconciliation

Run a full sync reconciliation to detect and repair drift:

```bash
# In subscriber org Dev Console:
delivery.DeliverySyncReconciler.reconcileAll();
```

### Billing Entity Setup

Configure the default billing entity for invoice generation:

```apex
delivery__DeliveryHubSettings__c s = delivery__DeliveryHubSettings__c.getOrgDefaults();
s.delivery__DefaultBillingEntityIdTxt__c = '<NetworkEntity ID>';
upsert s;
```

### Releasing

```bash
cci flow run release_unlocked_beta --org dev
cci flow run release_unlocked_production --org dev
```

---

## Public API

Delivery Hub exposes a REST API for non-Salesforce clients (websites, mobile apps, external platforms) to read and write delivery data.

**Base URL**: `/services/apexrest/delivery/deliveryhub/v1/api/`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard` | Dashboard with active counts, phase distribution, recent activity |
| GET | `/api/work-items` | List work items (filter: `?status=active`, `completed`, `attention`) |
| GET | `/api/work-items/{id}` | Full work item detail with comments and file count |
| POST | `/api/work-items` | Submit a new work item request |
| POST | `/api/work-items/{id}/comments` | Add a comment to a work item |
| GET | `/api/activity-feed` | Unified timeline of comments, hours, and changes |
| GET | `/api/work-logs` | List work logs for the authenticated entity |
| POST | `/api/log-hours` | Create a new work log entry |
| POST | `/api/approve-worklogs` | Batch approve draft work logs |
| POST | `/api/reject-worklogs` | Batch reject draft work logs |
| GET | `/api/board-summary` | AI-generated board summary |
| GET | `/api/files` | Files attached to entity work items |
| GET | `/api/documents` | Documents generated for the entity |
| GET | `/api/documents/{token}` | Document detail by public token |
| POST | `/api/document-approve` | Approve a document by public token |
| POST | `/api/document-dispute` | Dispute a document with reason by public token |
| GET | `/sync/health` | Org-level sync health &mdash; record counts, hours, status breakdown (no auth required) |

All requests require an `X-Api-Key` header matched against a NetworkEntity record. See the [Public API Guide](docs/PUBLIC_API_GUIDE.md) for complete documentation.

### Bounty Marketplace API

**Base URL**: `/services/apexrest/delivery/deliveryhub/v1/bounties/`

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/bounties` | Public | List open bounties (filter: `?difficulty=X&skill=Y`) |
| GET | `/bounties/{token}` | Public | Bounty detail with acceptance criteria and active claims |
| POST | `/bounties/{token}/claim` | X-Api-Key | Claim a bounty |
| POST | `/bounties/{token}/submit` | X-Api-Key | Submit completed work with proof URL |
| POST | `/bounties/{token}/withdraw` | X-Api-Key | Withdraw an active claim |

Any WorkItem with `IsBountyBool__c = true` is published to the marketplace. Claims are tracked via `BountyClaim__c` and synced to origin orgs automatically. See the [Bounty API Guide](docs/BOUNTY_API_GUIDE.md) for details.

For org-to-org synchronization, see the [Sync API Guide](docs/SYNC_API_GUIDE.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/GETTING_STARTED.md) | Installation, setup wizard, first work item, and optional sync configuration |
| [Architecture](docs/ARCHITECTURE.md) | Object model, sync engine, API layer, LWC components, and permission model |
| [Public API Guide](docs/PUBLIC_API_GUIDE.md) | REST API for websites and external apps &mdash; endpoints, auth, response schemas |
| [Sync API Guide](docs/SYNC_API_GUIDE.md) | Org-to-org synchronization &mdash; push/pull flows, echo suppression, setup steps |
| [Bounty API Guide](docs/BOUNTY_API_GUIDE.md) | Bounty marketplace &mdash; publishing bounties, claim lifecycle, sync to origin orgs |

---

## Contributing

Delivery Hub is open source under the [BSL 1.1 license](LICENSE.md) (converts to Apache 2.0 after 4 years per release).

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-idea`)
3. Make your changes
4. Push and open a PR &mdash; CI will validate everything automatically

If you're not sure where to start, check [open issues](https://github.com/Nimba-Solutions/Delivery-Hub/issues) or reach out.

---

## Feature Summary

| Feature | What It Does |
|---|---|
| **Kanban Board** | Drag-and-drop, 40+ stages, persona views, column color coding |
| **Stage Gates** | Block transitions when required fields are missing |
| **Fast Track** | Skip approval queue when estimate fits pre-approved budget |
| **Cross-Org Sync** | Bidirectional REST with retry, echo suppression, audit ledger |
| **Multi-Vendor Routing** | Send to multiple external orgs, each independently tracked |
| **AI Estimation** | Hours estimate, description, acceptance criteria from one line |
| **AI Weekly Digest** | Scheduled email summarizing delivery status across all active work |
| **ETA Engine** | Projected dates from velocity, queue depth, and dependencies |
| **Escalation Engine** | Rule-based auto-escalations with email alerts on SLA breaches |
| **Burndown Chart** | Sprint progress tracking against ideal pace |
| **Developer Workload** | Team capacity distribution dashboard |
| **Cycle Time Analytics** | Stage duration measurement to identify bottlenecks |
| **Real-Time Chat** | Polling-based comments with file attachment indicators |
| **File Rollup** | All files from work item + comments + requests in one panel |
| **Activity Timeline** | Full audit trail of every change on a work item |
| **Time Logger** | Quick hour logging with date picker, creates WorkLog entries |
| **WorkLog Approval** | Draft &rarr; Approved &rarr; Synced pipeline, gated by org setting |
| **Activity Feed** | Cross-item unified timeline of comments, hours, and changes with inline reply |
| **Data Lineage** | Visual sync chain with per-entity health metrics on admin home |
| **Document Engine** | Generate invoices, status reports, proposals with AI narratives, PDF rendering with hyperlinks to SF records, zero-hour filtering, runtime namespace detection for VF URLs, email delivery with CC, payment tracking, A/R balance, white-label vendor branding, and cloudnimbusllc.com footer. Document versioning tracks regeneration history with version numbers and superseded-document chains. |
| **Invoice Approval Flow** | Client-facing approve/dispute workflow via portal. Clients review invoices by public token and either approve or dispute with a reason. Dispute details stored in DisputeReasonTxt__c. All actions logged to ActivityLog for audit trail. |
| **Timeline View** | Gantt-style horizontal timeline showing active work items grouped by NetworkEntity. CSS Grid-based bars with zoom (week/month/quarter), scroll controls, today-line marker, stage-based colors from workflow config, and click-to-navigate to work item records. Available as the Delivery Timeline tab. |
| **Saved Filters** | Save and recall board filter configurations. Per-user filters (Private sharing model) with default filter auto-applied on board load. Stored as JSON in DeliverySavedFilter__c. Accessible from a dropdown in the board toolbar. |
| **Ghost Recorder** | Floating submission form with keyboard shortcut + background navigation tracking |
| **Delivery Guide** | In-app documentation with Ghost Recorder utility bar detection across all Lightning apps |
| **Client Dashboard** | Phase counts, attention items, recent activity |
| **Public Status Page** | Shareable delivery status view &mdash; no Salesforce login required |
| **System Pulse** | Live work items, hours, sync health |
| **Dependency Graph** | Visual blocking relationships between work items |
| **SLA Tracking** | Response and resolution time targets with visual indicators |
| **Recurring Items** | Auto-create work items on configurable schedules |
| **Email Notifications** | Stage-change alerts to keep stakeholders informed |
| **CSV Import** | Bulk import work items from spreadsheets |
| **Release Notes** | Auto-generate formatted release summaries from completed items |
| **Configurable Workflows** | Custom stages, personas, and transitions via metadata |
| **Setup Wizard** | One-click connection with automatic scheduler provisioning and real-time prerequisites checklist |
| **Bounty Marketplace** | Publish work items as bounties with fixed payouts, skill tags, difficulty ratings, and deadlines. Developers claim, submit work, and get approved through a structured lifecycle. Public API for marketplace browsing, authenticated API for claims. Claims auto-sync to origin orgs. |
| **Sync Reconciler** | Self-healing sync engine that detects drift between orgs and auto-repairs missing records. Runs daily at a configurable hour (default 6 AM UTC) or on-demand. Health endpoint for monitoring. |
| **Dynamic Record Pages** | Every object has a production-quality record page with dynamic forms, smart field sections, readonly enforcement on rollup fields, and compact layouts for lookup previews. LWC placements put the right component on the right page: deliveryScore on WorkItem, deliveryDocumentViewer on Document and NetworkEntity, deliverySyncRetryPanel on NetworkEntity. All 10 record pages are assigned as app defaults for both Delivery Hub apps. |
| **Default Billing Entity** | Configurable billing entity override for pass-through invoicing patterns (e.g., Cloud Nimbus &rarr; At Large &rarr; MF). |
| **Configurable Settings** | Admin settings page with DateTime activation toggles (shows who enabled what and when) and 4 operational knobs: reconciliation hour (default 6 AM UTC), sync retry limit (default 3), activity log retention days (default 90), and escalation cooldown hours (default 24). All settings are wired into the Apex runtime &mdash; the scheduler, cleanup job, and escalation service read from `DeliveryHubSettings__c` on every run. |
| **Document Versioning** | Regenerating a document for the same entity, period, and template creates a new version. The old document is marked Superseded, the new one gets an incremented VersionNumber__c and links back via PreviousVersionId__c. Superseded documents are excluded from A/R prior balance calculations. |
| **Inbound Email Handler** | Reply to work item notification emails to create comments directly. DeliveryInboundEmailHandler parses work item numbers (T-0039, WI-0039) from the To address or Subject, strips reply quotes, and inserts a WorkItemComment__c. Gated by EnableEmailNotificationsDateTime__c. DeliveryEmailService sends outbound comment notifications with reply-to routing for seamless email-based collaboration. |
| **Platform Events** | Three HighVolume platform events (DeliverySync__e, DeliveryEscalation__e, DeliveryDocEvent__e) enable external systems to subscribe to sync completions, escalation firings, and document lifecycle changes without polling. |
| **Portal Time Entry** | Enhanced portal time logging with entity scoping, workItemId filtering on GET /work-logs, cross-entity validation on POST /log-hours (403 if work item belongs to another entity), and activity log auditing for portal hour submissions. |
| **Demo Org Flow** | One-command demo org setup via `cci flow run demo_org --org dev`. Creates a scratch org, deploys the package, loads realistic sample data (2 entities, 10 work items, 21 work logs, comments, a draft invoice), configures org defaults, and schedules all background jobs. |
| **Task API (Versioned)** | CI/CD and AI agent endpoints moved to `/deliveryhub/v1/tasks/*` to match the URL convention used by all other REST endpoints. |
| **Native Reports** | Full Salesforce reporting on all delivery data |

---

<p align="center">
  <strong>Built by <a href="https://cloudnimbusllc.com">Cloud Nimbus LLC</a></strong><br>
  We build Salesforce delivery infrastructure so you can focus on your actual product.<br><br>
  <a href="https://cloudnimbusllc.com">Website</a> &middot; <a href="https://cloudnimbusllc.com/docs">Documentation</a> &middot; <a href="https://cloudnimbusllc.com/examples">Examples</a> &middot; <a href="https://github.com/Nimba-Solutions/Delivery-Hub/issues">Issues</a>
</p>
