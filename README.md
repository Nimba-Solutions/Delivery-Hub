# Delivery Hub

**Your Salesforce org was built for your business. Now make it run your software delivery too.**

Delivery Hub is a native Salesforce managed package that turns your org into a complete software delivery command center — Kanban boards, cross-org sync, AI-powered estimation, real-time chat, and automated ETA tracking, all living exactly where your team already works. No third-party tools. No context switching. No per-seat subscription on top of Salesforce.

---

## Install

| Environment | Action |
|---|---|
| **Production** | [![Install in Production](https://img.shields.io/badge/Install-Production-0070d2?logo=salesforce)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t) |
| **Sandbox / Test** | [![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-3e8b3e?logo=salesforce)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t) |

> The latest `04t...` package version ID is always in [**GitHub Releases**](https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest). Replace `04t` in the links above with the full version ID from the release notes.

Setup takes about 3 minutes. There is a one-click Quickstart wizard on the home page that configures everything — scheduled jobs, connection handshake, default settings — automatically.

---

## The Problem It Solves

Most Salesforce teams manage software work in Jira, Slack threads, or shared spreadsheets. None of those tools know your clients, your pipeline, your data, or your stage requirements. Every status update is a manual handoff. Every file is in someone's email. Every estimate lives in a comment that no one can find six weeks later.

Meanwhile your CRM — the system your clients already use, the one that knows every account, contact, and deal — sits right there, completely disconnected from the delivery work you're doing for those clients.

**Delivery Hub closes that loop.** Work items, comments, files, stage changes, approvals, estimates, and sync events all live inside Salesforce, tied to the accounts and contacts they belong to, queryable in any report you already know how to build.

---

## What You Get

### A Full Kanban Delivery Pipeline
- 40+ configurable stages from **Backlog** all the way to **Deployed to Production**
- Drag-and-drop board with column grouping, color coding, and stage gate enforcement
- Stage gate requirements that block bad transitions until the right fields are filled — no more work items that skip Client Approval or UAT because someone clicked the wrong button
- **Fast Track** mode that surfaces the direct path to development the moment a work item qualifies based on your configured budget thresholds

### Real-Time Cross-Org Sync
- Bidirectional REST sync between any two Salesforce orgs — your client org and your delivery org
- Work items created in one org appear in the other within seconds, automatically
- Stage changes, comments, file attachments, and field updates replicate in real time, both directions
- **Echo suppression** prevents sync loops when both orgs update the same record simultaneously
- Multi-vendor routing: send work items to multiple external vendors at once, each with its own queue, retry logic, and status ledger
- Every sync event is logged — status, payload, retry count, timestamp — for full audit visibility

### AI-Powered Work Management
- **OpenAI integration** that estimates hours, generates work item descriptions, and drafts acceptance criteria from a one-line summary
- **Automated ETA calculation** based on current queue depth, developer velocity, and team calendar
- AI suggestions are surfaced in-context on the work item record — one click to accept, easy to override

### Native Collaboration Tools
- **Real-time chat** on every work item with polling-based updates and file attachment indicators
- **File rollup panel** that aggregates every file from the work item, its comments, and its related requests into a single scrollable view — no hunting through related lists
- **Ghost Recorder** — a floating form available from anywhere in the app (with keyboard shortcut support) for instant issue or feature submission without leaving your current screen

### Client-Facing Transparency
- A home page **Client Dashboard** showing everything in flight, broken down by phase — clients see exactly where their work is without having to ask
- **Attention Required** surfacing: anything sitting in Client Approval, UAT, or Sign-off waiting on the client is called out immediately on page load
- System Pulse: live counts of active work items, hours booked, and last sync activity — a real-time health check at a glance
- **Time Logger** for quick hour tracking directly on the work item record, creating WorkLog entries with optional notes

### Zero-Friction Setup
- One-click Quickstart Connection wizard handles registration, credential exchange, and scheduler provisioning automatically
- No manual REST endpoint configuration, no custom settings to hunt down, no Apex scripts to run
- Works with managed package namespace translation out of the box — install in any org, production or sandbox

---

## Why It Belongs in Salesforce

| Other Tools | Delivery Hub |
|---|---|
| Another per-seat subscription | Included in your Salesforce license footprint |
| Disconnected from your CRM data | Native objects tied to Accounts, Contacts, and your pipeline |
| Manual status updates via email/Slack | Automated real-time sync, both directions |
| Files in email and shared drives | Every file attached to every related record, in one panel |
| Estimates in spreadsheets | AI-generated in-context with one click |
| Reports in a different tool | Native Salesforce reports and dashboards on your delivery data |
| Admin overhead to maintain | Self-configuring setup wizard, scheduled jobs managed automatically |

Your Salesforce admin can install this in an afternoon. Your team can be running a full delivery operation by end of day.

---

## How It Works

```
Your Org (Client)                        Delivery Team's Org (Vendor)
─────────────────                        ────────────────────────────
Work item created        ──── sync ────► Request ingested
  └─ Stage updated       ◄─── sync ────   └─ Developer assigned
  └─ Comment posted      ──── sync ────►  └─ Comment synced back
  └─ File attached       ──── sync ────►  └─ Status progressed
  └─ Client approval     ──── sync ────►  └─ Deployed to Prod
```

1. **A work item is created** on the Kanban board. A sync record queues automatically.
2. **The sync engine** picks up the queue and POSTs to the vendor's REST endpoint — in real time or on the 15-minute scheduler cycle, whichever fires first.
3. **The vendor's org ingests** the payload, creates or updates the matching work item, and syncs back any response fields.
4. **Both orgs stay in lock-step** — every stage change, comment, and file attachment triggers the next sync automatically.
5. **Echo suppression** on both sides ensures a change from Org A doesn't bounce back from Org B as a new sync event.

The sync engine is headless, retry-aware (up to 3 attempts with automatic re-queue on failure), and handles namespace translation for managed package deployments.

---

## Feature Summary

| Feature | Details |
|---|---|
| Kanban Board | Drag-and-drop, 40+ stages, configurable column order and color |
| Stage Gate Enforcement | Block moves when required fields are missing; warns before invalid transitions |
| Fast Track | Highlights the approval-free path to dev when estimate fits pre-approved budget |
| Cross-Org Sync | Bidirectional REST sync with retry, echo suppression, and full audit ledger |
| Multi-Vendor Routing | Send to multiple external orgs simultaneously, each independently tracked |
| AI Estimation | OpenAI-powered hours estimate, description generation, acceptance criteria drafting |
| ETA Engine | Projected UAT-ready date from developer velocity and current queue depth |
| Real-Time Chat | Polling-based work item chat with file attachment indicators |
| File Rollup | All files from work item + comments + requests in one sidebar panel |
| Time Logger | Quick hour logging directly on the work item, creates WorkLog entries |
| Ghost Recorder | Floating issue/feature submission form with keyboard shortcut, available anywhere |
| Client Dashboard | Home page phase counts, attention items, and recent activity |
| System Pulse | Live active work items, hours booked, sync health, and last entry time |
| Dependency Tracking | Mark work items as blocking each other; board surfaces blocked work items visually |
| Setup Wizard | One-click connection to vendor org with automatic scheduler provisioning |
| Native Reports | Full Salesforce report and dashboard support on all delivery data |

---

## Getting Started

### Install in 3 Minutes

1. Click the **Install in Production** or **Install in Sandbox** button above (use the latest `04t...` ID from [Releases](https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest))
2. Open the **Delivery Hub** Lightning App
3. On the Home tab, click **Quickstart Connection** — this registers your org, configures default settings, and schedules sync jobs automatically
4. Create your first work item on the **Work Item Board** tab
5. Invite your delivery team or connect to an external vendor org

### For Development Teams Running Their Own Instance

```bash
git clone https://github.com/Nimba-Solutions/Delivery-Hub
cci flow run dev_org --org dev
cci org browser dev
```

Configure your `CloudNimbusGlobalSettings__mdt` custom metadata with your org's endpoint URL and client orgs can connect via Quickstart immediately.

---

## Architecture

```
force-app/main/default/
├── classes/
│   ├── DeliverySyncEngine.cls          # Core fan-out engine (outbound + inbound routing)
│   ├── DeliverySyncItemProcessor.cls   # Queueable: processes outbound sync queue
│   ├── DeliveryHubScheduler.cls        # Schedulable: re-queues failures + triggers sync
│   ├── DeliveryHubPoller.cls           # Polls all active vendors for inbound items
│   ├── DeliverySyncItemIngestor.cls    # Maps inbound payloads to sObject fields
│   ├── DeliveryHubSyncService.cls      # REST endpoint (/delivery/sync)
│   ├── DeliveryWorkItemETAService.cls    # ETA calculation engine
│   ├── DeliveryHubDashboardController  # Home page metrics + client dashboard
│   ├── DeliveryHubFilesController      # Rolled-up file queries
│   ├── DeliveryHubCommentController    # Chat: get/post comments + file indicators
│   ├── DeliveryTimeLoggerController    # Time logging against work items (WorkLog__c)
│   └── DeliveryHubSetupController      # Quickstart wizard + handshake
├── lwc/
│   ├── deliveryHubBoard/               # Main Kanban board (drag-drop, column config)
│   ├── deliveryWorkItemActionCenter/     # Stage transition buttons with gate logic
│   ├── deliveryWorkItemChat/             # Real-time polling chat with file indicators
│   ├── deliveryWorkItemFiles/            # Rolled-up files sidebar panel
│   ├── deliveryTimeLogger/             # Quick time logging with WorkLog__c creation
│   ├── deliveryClientDashboard/        # Client home: attention / in-flight / recent
│   ├── deliveryBudgetSummary/          # System pulse: active work items, hours, sync health
│   ├── deliveryHubSetup/               # Quickstart connection wizard
│   ├── deliveryGhostRecorder/          # Issue / feature request submission form
│   └── deliveryWorkItemRefiner/          # AI description and sizing assistant
├── objects/
│   ├── WorkItem__c/                      # Core work item
│   ├── WorkRequest__c/                     # Sync bridge (client ↔ vendor)
│   ├── SyncItem__c/                   # Outbound sync ledger
│   ├── NetworkEntity__c/              # Connected org registry
│   ├── WorkItemComment__c/              # Chat messages
│   ├── WorkItemDependency__c/           # Blocking relationships
│   └── WorkLog__c/                     # Time tracking entries
└── triggers/
    ├── DeliveryWorkItemTrigger           # Stage changes → sync engine
    ├── DeliveryWorkItemCommentTrigger    # Comments → sync engine
    └── DeliveryContentDocumentLinkTrigger  # File attachments → sync engine
```

---

## CI/CD

This project uses [CumulusCI](https://cumulusci.readthedocs.io/) with GitHub Actions for a fully automated release pipeline.

Every pull request:
1. Spins up a namespaced scratch org
2. Deploys the full package
3. Runs all Apex tests (74+ tests, 75%+ coverage enforced)
4. Runs PMD static analysis
5. Tears down the scratch org

### Developer Workflow

```bash
cci flow run dev_org --org dev
cci org browser dev
cci task run retrieve_changes --org dev
git push origin feature/your-feature
```

### Releasing

```bash
cci flow run release_unlocked_beta --org dev
cci flow run release_unlocked_production --org dev
```

After promoting, copy the `04t...` package version ID from the CumulusCI output and update the install links in the [latest GitHub Release](https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest).

---

## Built By

**Cloud Nimbus LLC** — We build Salesforce delivery infrastructure so you can focus on your actual product.

Questions, partnership inquiries, or enterprise licensing: open an issue or reach out at [cloudnimbusllc.com](https://cloudnimbusllc.com).
