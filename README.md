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
| "We need a portal" = 5 days writing requirements | AI generates description, acceptance criteria, and estimate from one line |
| Blocked item sits for days before anyone notices | Escalation engine auto-alerts when SLA targets are missed |
| Weekly status email takes an hour to write | AI digest compiles and sends it automatically |

---

## Install

| Environment | Link |
|---|---|
| **Production** | [![Install in Production](https://img.shields.io/badge/Install-Production-0070d2?logo=salesforce&style=for-the-badge)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t) |
| **Sandbox** | [![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-3e8b3e?logo=salesforce&style=for-the-badge)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t) |

> Replace `04t` in the links above with the full package version ID from [the latest release](https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest).

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

### Configurable Workflows

Not just software delivery &mdash; the workflow engine supports any stage-based process. Ships with Software Delivery (40+ stages) and Loan Approval (8 stages) out of the box. Define your own workflow types, stages, personas, and transitions through Custom Metadata.

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

The engine is retry-aware (up to 3 attempts), handles namespace translation for managed packages, and supports multi-vendor routing to multiple external orgs simultaneously.

---

## Architecture

| Layer | Count | Key Components |
|-------|-------|----------------|
| **Apex Classes** | 73 (47 production + 26 test) | SyncEngine, SyncItemProcessor, SyncItemIngestor, HubPoller, WorkItemController, EscalationService, WeeklyDigestService, ETAService, AiController, WorkflowConfigService |
| **LWC Components** | 40 | deliveryHubBoard, deliveryClientDashboard, deliveryBurndownChart, deliveryCycleTimeChart, deliveryDeveloperWorkload, deliveryDependencyGraph, deliveryCsvImport, deliveryStatusPage, deliveryActivityTimeline, deliveryGhostRecorder |
| **Custom Objects** | 8 | WorkItem\_\_c, WorkRequest\_\_c, SyncItem\_\_c, NetworkEntity\_\_c, WorkItemComment\_\_c, WorkItemDependency\_\_c, WorkLog\_\_c, DeliveryHubSettings\_\_c |
| **Custom Metadata** | 6 | WorkflowType\_\_mdt, WorkflowStage\_\_mdt, WorkflowPersonaView\_\_mdt, WorkflowEscalationRule\_\_mdt, SyncRoutingConfig\_\_mdt, CloudNimbusGlobalSettings\_\_mdt |
| **Triggers** | 4 | WorkItemTrigger, WorkItemCommentTrigger, ContentDocumentLinkTrigger, WorkLogTrigger |

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

Every pull request automatically spins up a namespaced scratch org, deploys the package, runs 300+ Apex tests (75%+ coverage enforced), runs PMD static analysis (zero violations enforced), and tears everything down.

### Releasing

```bash
cci flow run release_unlocked_beta --org dev
cci flow run release_unlocked_production --org dev
```

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
| **Time Logger** | Quick hour logging, creates WorkLog entries |
| **Ghost Recorder** | Floating submission form with keyboard shortcut |
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
| **Setup Wizard** | One-click connection with automatic scheduler provisioning |
| **Native Reports** | Full Salesforce reporting on all delivery data |

---

<p align="center">
  <strong>Built by <a href="https://cloudnimbusllc.com">Cloud Nimbus LLC</a></strong><br>
  We build Salesforce delivery infrastructure so you can focus on your actual product.<br><br>
  <a href="https://cloudnimbusllc.com">Website</a> &middot; <a href="https://cloudnimbusllc.com/docs">Documentation</a> &middot; <a href="https://cloudnimbusllc.com/examples">Examples</a> &middot; <a href="https://github.com/Nimba-Solutions/Delivery-Hub/issues">Issues</a>
</p>
