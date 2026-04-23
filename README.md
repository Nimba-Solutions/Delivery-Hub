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

**Current version**: `release/0.200` &mdash; see the [Changelog](docs/CHANGELOG.md) for the full history.

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

Drag-and-drop board with 40+ configurable stages from **Backlog** to **Deployed to Production**. Stage gate enforcement blocks bad transitions until required fields are filled. Persona-based views show clients, developers, and managers exactly what they need to see &mdash; nothing more. The slide-out detail panel shows Created By alongside Assignee, Developer, and Epic so you always know who submitted each work item.

### Cross-Org Sync

Bidirectional REST sync between any two Salesforce orgs. Work items created in one org appear in the other within seconds. Stage changes, comments, and files replicate in both directions with echo suppression to prevent loops. Every sync event is logged for full audit visibility.

### AI-Powered Work Management

OpenAI integration that estimates hours, generates descriptions, and drafts acceptance criteria from a one-line summary. ETA engine projects delivery dates from queue depth, developer velocity, and team calendar. Weekly AI digest emails summarize delivery status and send to configurable recipients on a schedule. One click to accept, easy to override.

### Escalation Engine

Rule-based automated escalations defined through Custom Metadata. Configure conditions like "stuck in QA for 3+ days" or "high priority with no assignee" &mdash; the engine evaluates on every scheduler run and fires email notifications automatically. No-response detection flags work items where the submitter hasn't received a reply: set `RequireNoResponseDateTime__c` on any escalation rule and the engine checks whether anyone other than the creator has commented before firing. No manual follow-up needed.

### Board Metrics and Analytics

Burndown chart tracks sprint progress against ideal pace. Developer Workload dashboard shows capacity distribution across the team. Cycle Time analytics measure how long items spend in each stage, identifying bottlenecks before they become blockers.

### Project Timeline (Nimbus Gantt)

High-performance canvas-based Gantt chart built from scratch as a standalone MIT library ([nimbus-gantt](https://github.com/glen-bradford-nimba/nimbus-gantt)). **Five visualization modes** for the same data: Gantt timeline, Treemap (effort concentration), Bubble chart (timeline galaxy), Calendar heatmap (daily workload density), and Stage Flow (workflow distribution). Drag-to-reschedule and drag-to-resize with lock/unlock editing. Dependency arrows with critical path highlighting. 27 plugins including undo/redo, keyboard navigation, dark mode, Monte Carlo simulation, risk analysis, and export to PNG/SVG. **Phone remote control** via Platform Events &mdash; tilt your phone to scroll, swipe to zoom, tap to select tasks. QR code connection in the Remote modal. **40-step demo mode** showcases every feature with health-aware sonification that plays the project schedule as music (consonant = on track, dissonant = overdue). 259KB static resource, zero external dependencies.

### Voice Notes

Mobile-first voice-to-work-item creation. Tap the microphone, speak about a customer visit or task, and the transcript becomes a structured work item. Uses the Web Speech API (browser-native, no external APIs). Supports single-item and batch mode (splits by sentence boundaries). Natural language date detection parses "next Monday" or "in two weeks" into `EstimatedStartDevDate__c`. Designed for field reps who need to capture notes hands-free at job sites.

### Real-Time Collaboration

Polling-based chat on every work item. File rollup panel that aggregates every file from the work item, its comments, and related requests into a single view. Ghost Recorder &mdash; a floating form available anywhere in the app for instant issue submission without leaving your current screen, with built-in **voice dictation** via the Web Speech API for hands-free feedback capture. Activity timeline provides a full audit trail of every change on a work item.

### Client Transparency

Home page dashboard showing everything in flight, broken down by phase. Attention Required surfacing calls out anything waiting on the client immediately. System Pulse gives live counts of active work items, hours booked, and sync health at a glance. Public status page provides a shareable Visualforce view without requiring a Salesforce login.

### Operational Automation

Recurring items auto-create work items on configurable schedules &mdash; daily standups, weekly deploys, monthly reviews. Email notifications fire on stage changes. SLA tracking monitors response and resolution times against configurable targets with visual status indicators.

### Bulk Operations

CSV import wizard maps spreadsheet columns to work item fields and creates items in bulk. Dependency graph visualizes blocking relationships so you can see the critical path. Release notes generator compiles completed items into formatted summaries.

### Billing & Approval

WorkLog approval workflow gates logged hours behind a Draft &rarr; Approved &rarr; Synced pipeline. Enable the `RequireWorkLogApprovalDateTime__c` setting and all new hours save as Draft until a manager approves them. Batch approve or reject directly from the Activity Feed. When the setting is null, existing behavior is unchanged &mdash; hours sync immediately. Invoices only include **Approved** work logs &mdash; Draft and unapproved hours are excluded from all generated documents.

The Activity Feed provides a unified, cross-item timeline of comments, hours, and stage/field changes. Date-grouped entries, conversation threads with inline reply, batch WorkLog approval actions, and 30-second polling keep the entire team on the same page without switching between records.

### Invoice Automation

Scheduled invoice generation runs on the DeliveryHubScheduler and produces documents automatically based on each NetworkEntity's billing frequency. Four frequencies are supported: **Daily** (hours summary only), **Weekly**, **Monthly** (full dollar invoice), and **Quarterly**. Enable billing on any entity by setting `EnableBillingDateTime__c` and `BillingFrequencyPk__c` on the NetworkEntity record. The `EnableInvoiceGenerationDateTime__c` setting on DeliveryHubSettings__c activates the scheduler-level invoice generation service.

The engine generates Draft invoices that can be reviewed before sending. Overdue invoice detection automatically marks past-due invoices as Overdue. A pending invoices banner in the Document Viewer alerts users to documents awaiting review. The `LastInvoiceGenerationDate__c` setting tracks when the last generation run completed to prevent duplicate processing.

### Native Document Actioning & Signatures

Multi-party document signing built into the package — no DocuSign integration required. Templates that `RequiresSigningCheckbox__c = true` (Client Agreement, Contractor Agreement, and any custom template you configure) auto-generate one `DocumentAction__c` record per signer slot from `DocumentTemplateSlot__mdt`. Each slot gets a unique signer token, a dedicated public URL (`/portal/documents/<token>`), and captures the signer's IP address (via `X-Forwarded-For` / `X-Salesforce-SIP`), user agent, electronic consent timestamp, and either a text stamp (`Name (digitally signed MMM DD, YYYY)`) or a drawn canvas signature persisted as a ContentVersion. Signatures ride the existing `ActivityLog__c` SHA-256 hash chain for tamper-evident audit — `DocumentAction__c.PriorHashTxt__c` materializes the chain parent at sign time. Documents flow `Draft → Ready → Sent → Awaiting_Signatures → Approved` once every slot is Completed, and a `Certificate_Of_Completion` template can auto-render a full audit trail listing every signer, IP, timestamp, and hash. Admin-side has a "Copy Signer Link" button per slot and `FOR UPDATE` locking so two simultaneous signers cannot double-sign the same slot. Details: [DOCUMENT_ACTIONING_FEATURE.md](docs/DOCUMENT_ACTIONING_FEATURE.md).

### Document Engine

Generate professional invoices, status reports, client agreements, contractor agreements, certificates of completion, and security audit reports directly from Delivery Hub data. Each document captures an immutable JSON snapshot of hours, rates, and work items for the billing period. Zero-hour work items are automatically filtered from invoices so only billable items appear. PDF rendering via Visualforce produces print-ready output with clickable hyperlinks to the source Salesforce records. The VF URL builder detects the namespace at runtime, so PDF and web preview links work correctly in both managed and unmanaged installations. Issuer branding (company name, address, URL) is sourced from the configured vendor `NetworkEntity__c` — no hardcoded strings.

**Email Preview & Scheduled Send:** The "Prepare Email" button opens a full preview modal showing the rendered email body, subject line, recipient (editable), CC addresses, and a clickable PDF attachment link &mdash; all before anything is sent. Send immediately or toggle "Schedule for later" with a datetime picker and a "Next business day at 8 AM" shortcut. The DeliveryHubScheduler checks every 15 minutes for scheduled sends and delivers them automatically. Multiple CC addresses are supported via comma-separated values in `DocumentCcEmailTxt__c`. The email body includes This Invoice, Prior Balance (if outstanding), and Amount Due breakdowns.

Payment tracking through `DeliveryTransaction__c` records supports multiple transaction types (payment, credit, refund, adjustment, write-off) per document. The A/R summary on each invoice shows outstanding prior balances. White-label vendor branding pulls the issuing entity's name, address, email, and phone from the vendor NetworkEntity record. Every invoice footer links to cloudnimbusllc.com. Document versioning preserves history when regenerating &mdash; superseded documents link back via version chain. Client-facing invoice approval flow lets clients approve or dispute invoices from the portal with full audit trail.

### Configurable Workflows

Not just software delivery &mdash; the workflow engine supports any stage-based process. Ships with seven workflow types out of the box: Software Delivery (40+ stages), Loan Approval (8 stages), Customer Onboarding, HR Recruiting, Marketing Campaign, Change Management (12 stages, 3 personas: Requester/CAB/Implementer), and Operations (9 stages, 3 personas: Technician/Supervisor/Customer). Define your own workflow types, stages, personas, and transitions through Custom Metadata. The Workflow Builder admin tab provides a visual editor for creating and modifying workflows without touching metadata files.

### Workspace

A unified tabbed interface combining Board, Timeline, Activity Feed, Documents, Guide, Templates, Analytics, Velocity, Settings, and Workflow Builder. Admin-only tabs are conditionally shown based on user permissions. The workspace replaces the need for multiple app pages and keeps all delivery tools in one screen.

### Activity Dashboard

Tracks user adoption and engagement across the platform. Shows weekly and monthly activity counts, top users, most-used components, and page navigation patterns. All data comes from the Ghost Recorder's background activity logging, providing actionable insights into how the team uses Delivery Hub. The Ghost Recorder now tracks page duration (seconds on each page) and exit method (navigation vs tab close), stored in the existing `ContextDataTxt__c` JSON &mdash; no additional fields required.

### Permission Analyzer

Analyzes 30 days of activity log data to produce permission recommendations based on actual user behavior. The summary view shows active user count, total page views, objects accessed, a per-user activity table (with profile, view count, unique objects, top objects, and risk level), and an object usage table. Click any user row to drill into their detailed breakdown: object frequency, top pages, daily activity bar chart (30-day trend), session count, and average pages per session. Plain-English recommendations flag overprivileged users who have admin access but only touch a small number of objects. Output can be rendered as a Security Audit document via the Document Engine for PDF/email delivery to executives. Available as a dedicated tab in the Delivery Hub Admin app.

### Report Navigation

Dashboard tiles and metrics link directly to pre-deployed Salesforce reports (Attention Items, In-Flight Work Items, Blocked, Recently Completed, Monthly Hours, and per-phase breakdowns). When a report isn't found in the org, navigation falls back gracefully to the corresponding list view.

### Self-Service Onboarding (Phase 3)

Getting Started wizard handles full org setup in 4 steps &mdash; configures scheduled jobs, connection handshake, default settings, and entity registration. No Apex scripts or manual configuration required. Global classes (`DeliveryHubScheduler`, `SyncItemProcessor`, `DeliveryActivityLogCleanup`) ensure subscriber orgs can schedule managed package jobs.

### Velocity and Capacity Planning (Phase 4)

Velocity tracking service calculates team and developer completion rates over configurable time windows. Projected completion dates extrapolate from current velocity and remaining backlog. Capacity utilization reads from `DeveloperCapacity__mdt` configuration to show allocated vs. available hours per developer. What-if analysis lets admins model the impact of adding items to the backlog.

### Enterprise Security & Compliance

A suite of opt-in enterprise features for organizations that need formal governance, compliance controls, and audit-grade data integrity.

**API Rate Limiting:** Configurable per-entity request throttles for both the Public API and the Sync API. Set `PublicApiRateLimitNumber__c` (default: 100 requests/hour) or `SyncApiRateLimitNumber__c` (default: 60 requests/hour) on `DeliveryHubSettings__c` to activate. Excess requests receive HTTP 429 with a `Retry-After: 3600` header. Disabled by default &mdash; leave the fields null to allow unlimited throughput.

**Immutable Audit Chain:** Every auditable event (stage changes, approvals, document lifecycle actions, sync completions) is hashed into a SHA-256 chain via `DeliveryAuditChainService`. Each `ActivityLog__c` record stores its hash and its parent hash, creating a tamper-evident ledger. Legal hold mode (`LegalHoldEnabledDateTime__c` on `DeliveryHubSettings__c`) prevents deletion of any audit chain records. The chain can be verified programmatically at any time.

**HMAC Request Signing:** Outbound sync payloads are signed with an HMAC-SHA256 signature when `HmacSecretTxt__c` is configured on the target `NetworkEntity__c`. The receiving org validates the `X-Signature` header against the request body and shared secret. Backward compatible &mdash; if no secret is set, signature validation is skipped.

**Formal Approval Chains:** Multi-step approval workflows for work item stage transitions via `DeliveryApprovalChainService`. Define required approvers and approval order through Custom Metadata. Approvals are tracked with timestamps, approver identity, and comments. Integrates with the existing stage gate framework.

**Team-Based Visibility:** `DeliveryTeamPermissionService` enforces record-level visibility rules based on team membership. Work items can be scoped so that only members of the assigned team (defined on `NetworkEntity__c`) see them on the board. Admins retain full visibility. Opt-in via `TeamVisibilityEnabledDateTime__c`.

**Data Archival:** `DeliveryArchivalService` moves completed work items and their related records (comments, work logs, sync items) to an archived state after a configurable retention period (`ArchivalRetentionDaysNumber__c`, default 365 days). Archived records are excluded from board queries and API responses but remain queryable for compliance. Restore on demand.

**Business-Hours SLAs:** `DeliverySLAService` now supports business-hours calculations via `BusinessHoursId` on `SLARule__mdt`. SLA clocks pause outside configured business hours, weekends, and holidays. Response and resolution targets are evaluated against business time, not wall-clock time.

**Notification Preferences:** `DeliveryNotificationPreferenceService` lets users configure per-event notification channels (email, platform event, both, or none) through `DeliveryHubSettings__c`. Preferences are respected by the escalation engine, digest service, and stage-change alerts.

### Admin Settings

Central settings page with DateTime activation toggles that record who enabled each feature and when. Four operational settings control runtime behavior across the platform:

| Setting | Field | Default | What It Controls |
|---------|-------|---------|-----------------|
| Reconciliation Hour | `ReconciliationHourNumber__c` | 6 (AM UTC) | Hour when the scheduler runs the daily sync reconciliation |
| Sync Retry Limit | `SyncRetryLimitNumber__c` | 3 | Max retry attempts before a failed sync item stops requeueing |
| Activity Log Retention | `ActivityLogRetentionDaysNumber__c` | 90 days | How long activity log records are kept before batch purge |
| Escalation Cooldown | `EscalationCooldownHoursNumber__c` | 24 hours | Minimum interval before re-escalating the same work item |

All four settings are wired into the Apex runtime &mdash; the DeliveryHubScheduler, DeliveryActivityLogCleanup, and DeliveryEscalationService read from `DeliveryHubSettings__c` on every execution. The admin page uses dynamic forms for field-level layout control.

**DateTime toggles (zero Boolean fields):** The codebase contains **zero Checkbox/Boolean custom fields**. Every toggle uses a DateTime stamp that records **when** the flag was set (e.g., `ActivatedDateTime__c = 2026-03-27T14:30:00Z`). This tells you both **if** and **when**. Examples: `ActivatedDateTime__c`, `BountyEnabledDateTime__c`, `RecurringEnabledDateTime__c`, `TemplateMarkedDateTime__c` (all on WorkItem\_\_c), `EnableVendorPushDateTime__c` (NetworkEntity\_\_c), `DefaultSetDateTime__c` (DeliverySavedFilter\_\_c), and all enterprise feature flags (`LegalHoldEnabledDateTime__c`, `TeamVisibilityEnabledDateTime__c`, etc.). DateTime stamps provide richer audit data at zero extra cost.

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
| **Apex Classes** | 224 (114 production + 110 test) | Core: SyncEngine, SyncItemProcessor, SyncItemIngestor, HubPoller, HubSyncService, HubPoller, InboundEmailHandler, EmailService, InvoiceGenerationService. Controllers: WorkItemController, DocumentController, DocumentPdfController, GuideController, PortalController, AiController, SettingsController, TimelineController, SavedFilterController, WorkflowConfigService, PermissionAnalyzerController, GhostController, GanttController, GanttRemoteController, VoiceNotesController, ExecutiveDashboardController, DashboardCardController. Services (enterprise): RateLimitService, AuditChainService, CryptoService, ApprovalChainService, TeamPermissionService, ArchivalService, NotificationPreferenceService, SLAService, WorkItemQueryService, VelocityService, WeeklyDigestService, WorkItemETAService, EscalationService, EscalationRuleEvaluator, EscalationActionExecutor, EscalationNotifService. Document engine: DocQueryService, DocApprovalService, DocEmailService, DocGenerationService, DocPaymentService, DocActionService, DocActionController, DocActionRestApi, DocCertificateService. |
| **LWC Components** | 68 | deliveryHubBoard, deliveryClientDashboard, deliveryGuide, deliveryDocumentViewer, deliveryDocumentSignatureBlock, deliveryDocumentSignPortal, deliverySignaturePad, deliveryVelocityDashboard, deliveryBurndownChart, deliveryCycleTimeChart, deliveryDeveloperWorkload, deliveryDependencyGraph, deliveryCsvImport, deliveryStatusPage, deliveryActivityTimeline, deliveryActivityFeed, deliveryDataLineage, deliveryGhostRecorder, deliveryScore, deliverySettingsContainer, deliveryNimbusGantt, deliveryVoiceNotes, deliveryPermissionAnalyzer, deliveryHubWorkspace, deliveryWorkflowBuilder, deliveryExecutiveDashboard |
| **Custom Objects** | 16 | WorkItem\_\_c, WorkRequest\_\_c, SyncItem\_\_c, NetworkEntity\_\_c, WorkItemComment\_\_c, WorkItemDependency\_\_c, WorkLog\_\_c, ActivityLog\_\_c, DeliveryDocument\_\_c, DeliveryTransaction\_\_c, DocumentAction\_\_c, PortalAccess\_\_c, DeliveryHubSettings\_\_c, BountyClaim\_\_c, DeliverySavedFilter\_\_c, NotificationPreference\_\_c |
| **Custom Metadata** | 14 | WorkflowType\_\_mdt, WorkflowStage\_\_mdt, WorkflowPersonaView\_\_mdt, WorkflowEscalationRule\_\_mdt, WorkflowStageRequirement\_\_mdt, CloudNimbusGlobalSettings\_\_mdt, DocumentTemplate\_\_mdt, DocumentTemplateSlot\_\_mdt, SLARule\_\_mdt, TrackedField\_\_mdt, DeveloperCapacity\_\_mdt, ApprovalStep\_\_mdt, DashboardCard\_\_mdt, DeliveryTeam\_\_mdt |
| **Platform Events** | 5 | DeliveryWorkItemChange\_\_e, DeliverySync\_\_e, DeliveryEscalation\_\_e, DeliveryDocEvent\_\_e, GanttRemoteEvent\_\_e |
| **Triggers** | 13 | Across WorkItem, WorkItemComment, ContentDocumentLink, WorkLog, BountyClaim, DeliveryDocument, DocumentAction, WorkItemDependency, NetworkEntity, DeliveryTransaction, WorkRequest, plus platform event subscribers |
| **FlexiPages** | 15+ | Record pages, admin home, and workspace pages for all major objects |
| **Reports** | 25 | Attention Items, In-Flight, Blocked, Recently Completed, Monthly Hours, phase breakdowns, activity tracking, budget health |

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

Every pull request automatically spins up a namespaced scratch org, deploys the package, runs 1,000+ Apex tests (90%+ coverage enforced on new services), and runs PMD static analysis (zero violations enforced, priority 1-4 blocking).

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
| GET | `/api/documents/{token}` | Document detail by public token (now includes `signingRequired`, `signingComplete`, `signingSlots[]`, `hashChainVerified`) |
| POST | `/api/document-approve` | Approve a document by public token |
| POST | `/api/document-dispute` | Dispute a document with reason by public token |
| POST | `/sign/{signerToken}` | Public signing endpoint — accepts `signatureType: "Text"` or `"Image"` (base64 PNG via `signatureData`/`drawnSignature`), captures `X-Forwarded-For` IP and User-Agent |
| GET | `/sync/health` | Org-level sync health &mdash; record counts, hours, status breakdown (no auth required) |

All requests require an `X-Api-Key` header matched against a NetworkEntity record. **Rate limiting** is available: set `PublicApiRateLimitNumber__c` on `DeliveryHubSettings__c` to cap requests per entity per hour (default off; returns HTTP 429 when exceeded). See the [Public API Guide](docs/PUBLIC_API_GUIDE.md) for complete documentation.

### Bounty Marketplace API

**Base URL**: `/services/apexrest/delivery/deliveryhub/v1/bounties/`

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/bounties` | Public | List open bounties (filter: `?difficulty=X&skill=Y`) |
| GET | `/bounties/{token}` | Public | Bounty detail with acceptance criteria and active claims |
| POST | `/bounties/{token}/claim` | X-Api-Key | Claim a bounty |
| POST | `/bounties/{token}/submit` | X-Api-Key | Submit completed work with proof URL |
| POST | `/bounties/{token}/withdraw` | X-Api-Key | Withdraw an active claim |

Any WorkItem with `BountyEnabledDateTime__c` set (non-null) is published to the marketplace. Claims are tracked via `BountyClaim__c` and synced to origin orgs automatically. See the [Bounty API Guide](docs/BOUNTY_API_GUIDE.md) for details.

For org-to-org synchronization (with opt-in HMAC request signing and rate limiting), see the [Sync API Guide](docs/SYNC_API_GUIDE.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/GETTING_STARTED.md) | Installation, setup wizard, first work item, and optional sync configuration |
| [Architecture](docs/ARCHITECTURE.md) | Object model, sync engine, API layer, LWC components, enterprise services, and permission model |
| [Changelog](docs/CHANGELOG.md) | Version history grouped by unlocked package release |
| [Field Naming](docs/FIELD_NAMING.md) | Type-suffix convention enforced by PMD (`*Txt__c`, `*Number__c`, etc.) |
| [Document Actioning](docs/DOCUMENT_ACTIONING_FEATURE.md) | Native multi-party signing with hash chain audit |
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
| **Kanban Board** | Drag-and-drop, 40+ stages, persona views, column color coding, Created By in detail panel |
| **Stage Gates** | Block transitions when required fields are missing |
| **Fast Track** | Skip approval queue when estimate fits pre-approved budget |
| **Cross-Org Sync** | Bidirectional REST with retry, echo suppression, audit ledger |
| **Multi-Vendor Routing** | Send to multiple external orgs, each independently tracked |
| **AI Estimation** | Hours estimate, description, acceptance criteria from one line |
| **AI Weekly Digest** | Scheduled email summarizing delivery status across all active work |
| **ETA Engine** | Projected dates from velocity, queue depth, and dependencies |
| **Escalation Engine** | Rule-based auto-escalations with email alerts on SLA breaches, no-response detection for unacknowledged submissions |
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
| **Document Engine** | Generate invoices, status reports, proposals with AI narratives, PDF rendering with hyperlinks to SF records, zero-hour filtering, runtime namespace detection for VF URLs, email delivery with CC, payment tracking, A/R balance, white-label vendor branding (sourced from NetworkEntity, no hardcoded strings), and cloudnimbusllc.com footer. Document versioning tracks regeneration history with version numbers and superseded-document chains. |
| **Native Document Actioning & Signatures** | Multi-party document signing without a DocuSign integration. Auto-generates one `DocumentAction__c` record per signer slot from `DocumentTemplateSlot__mdt`. Each slot has a unique signer token, public `/portal/documents/<token>` URL, captured IP (`X-Forwarded-For` / `X-Salesforce-SIP`), user-agent, electronic consent timestamp, and either text-stamp or drawn-canvas signature (persisted as a ContentVersion). SHA-256 hash chain rides the existing ActivityLog audit chain for tamper evidence. `FOR UPDATE` locking prevents double-sign races. Certificate_Of_Completion template auto-renders the full audit trail. |
| **Invoice Automation** | Scheduled invoice generation via DeliveryInvoiceGenerationService. Supports Daily (hours summary), Weekly, Monthly (full dollar invoice), and Quarterly frequencies per NetworkEntity. Auto-generates Draft invoices on schedule, detects overdue invoices and marks them past-due, and shows a pending invoices banner in the Document Viewer. Invoices only include Approved work logs. |
| **Invoice Approval Flow** | Client-facing approve/dispute workflow via portal. Clients review invoices by public token and either approve or dispute with a reason. Dispute details stored in DisputeReasonTxt__c. All actions logged to ActivityLog for audit trail. |
| **Timeline View** | Gantt-style horizontal timeline showing active work items grouped by NetworkEntity. CSS Grid-based bars with zoom (week/month/quarter), scroll controls, today-line marker, stage-based colors from workflow config, and click-to-navigate to work item records. Available as the Delivery Timeline tab. |
| **Saved Filters** | Save and recall board filter configurations. Per-user filters (Private sharing model) with default filter auto-applied on board load. Stored as JSON in DeliverySavedFilter__c. Accessible from a dropdown in the board toolbar. |
| **Email Preview & Scheduled Send** | Full email preview before sending (subject, HTML body, recipient, CC, PDF link). Schedule sends for a future date/time with "Next business day at 8 AM" shortcut. Multi-CC support via comma-separated addresses. |
| **Permission Analyzer** | Analyzes activity logs to recommend permission sets based on actual user behavior. User heatmaps, object usage, risk flags, drill-down per user with daily activity chart, Security Audit document template. Dedicated admin tab. |
| **Ghost Recorder** | Floating submission form with keyboard shortcut, background navigation tracking, page duration logging (seconds on page, exit method), and **voice dictation** via Web Speech API &mdash; click the mic, speak, and transcribed text auto-appends to the description as `[Voice]` entries |
| **Delivery Guide** | In-app documentation with Ghost Recorder utility bar detection across all Lightning apps |
| **Client Dashboard** | Phase counts, attention items, recent activity |
| **Public Status Page** | Shareable delivery status view &mdash; no Salesforce login required |
| **System Pulse** | Live work items, hours, sync health |
| **Dependency Graph** | Visual blocking relationships between work items |
| **SLA Tracking** | Response and resolution time targets with visual indicators, business-hours support via BusinessHoursId on SLARule__mdt |
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
| **Field Change Tracking** | Automatic audit trail of field changes on all DH objects via triggers. Configured declaratively through TrackedField\_\_mdt &mdash; add a metadata record to track any field. Captures old/new values, delta for numeric fields, and stores as ActivityLog entries. Enabled by default on new installs. |
| **Native Reports** | Full Salesforce reporting on all delivery data &mdash; 25 pre-built reports ship with the package |
| **API Rate Limiting** | Opt-in per-entity throttle for both Public API (default 100 req/hr) and Sync API (default 60 req/hr). HTTP 429 with Retry-After header when exceeded. Disabled by default. |
| **Immutable Audit Chain** | SHA-256 hash chain on ActivityLog records creates a tamper-evident audit trail. Legal hold mode prevents deletion. Chain verifiable programmatically. |
| **HMAC Request Signing** | Outbound sync payloads signed with HMAC-SHA256 via shared secret on NetworkEntity. Receiving org validates X-Signature header. Backward compatible &mdash; no secret means no signature required. |
| **Formal Approval Chains** | Multi-step approval workflows for stage transitions with configurable approvers, approval order, timestamps, and comments. Integrates with stage gates. |
| **Team-Based Visibility** | Record-level board scoping by team membership on NetworkEntity. Admins retain full visibility. Opt-in via TeamVisibilityEnabledDateTime__c. |
| **Data Archival** | Automated archival of completed work items and related records after configurable retention period (default 365 days). Archived records excluded from board/API but queryable for compliance. |
| **Business-Hours SLAs** | SLA clocks pause outside configured business hours, weekends, and holidays. BusinessHoursId on SLARule__mdt controls the calendar. |
| **Notification Preferences** | Per-event notification channel configuration (email, platform event, both, or none). Respected by escalation engine, digest service, and stage-change alerts. |

---

<p align="center">
  <strong>Built by <a href="https://cloudnimbusllc.com">Cloud Nimbus LLC</a></strong><br>
  We build Salesforce delivery infrastructure so you can focus on your actual product.<br><br>
  <a href="https://cloudnimbusllc.com">Website</a> &middot; <a href="https://cloudnimbusllc.com/docs">Documentation</a> &middot; <a href="https://cloudnimbusllc.com/examples">Examples</a> &middot; <a href="https://github.com/Nimba-Solutions/Delivery-Hub/issues">Issues</a>
</p>
