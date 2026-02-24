# Delivery Hub

**The fastest way to run a real software delivery operation — entirely inside Salesforce.**

Delivery Hub turns your Salesforce org into a fully operational dev shop command center. Whether you're managing an internal development team or sending work out to an external vendor like [Cloud Nimbus LLC](https://cloudnimbusllc.com), every ticket, comment, file, and status update lives in one place, syncs in real-time between orgs, and requires zero manual coordination overhead.

---

## Install

| Environment | Action |
|---|---|
| **Production** | [![Install in Production](https://img.shields.io/badge/Install-Production-0070d2?logo=salesforce)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t) |
| **Sandbox / Test** | [![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-3e8b3e?logo=salesforce)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t) |

> The latest `04t...` package version ID is always listed in the [**GitHub Releases**](https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest) page. Replace `04t` in the links above with the full version ID from the release notes to install.

---

## Why Delivery Hub Exists

Most Salesforce teams manage development work in Jira, Slack, email, or a spreadsheet no one trusts. None of those tools know anything about your Salesforce data. Delivery Hub fixes that — it lives where your business already lives, speaks Salesforce natively, and keeps your clients, your developers, and your delivery pipeline in permanent sync without any manual handoffs.

If you're a client sending work to an external dev team, you click a button and the ticket appears on their board. If you're a dev team, incoming requests auto-create tickets, stage changes sync back to the client, and nothing falls through the cracks. It is the delivery loop that closes itself.

---

## What It Does

### For Clients
- **See your tickets** — a live Kanban view of every item in flight, broken down by stage
- **Know what needs your attention** — the home page surfaces anything sitting in Client Approval, Client UAT, or UAT Sign-off waiting on you specifically
- **Chat directly with the dev team** — real-time messaging on every ticket, with file attachments rolling up automatically so nothing gets buried
- **Report issues and request features** — one-click Ghost Recorder form from anywhere in the app
- **Self-service onboarding** — a one-click Quickstart Connection wizard on the home page that sets up the entire integration without admin involvement

### For Development Teams
- **Manage a full delivery pipeline** — 40+ stages from Backlog to Deployed to Prod, with configurable stage gate requirements that prevent bad transitions
- **Multi-vendor routing** — sync outbound to multiple external vendors simultaneously; each vendor gets its own queue, retries on failure, and independent status tracking
- **AI-assisted sizing** — optional OpenAI integration that estimates hours, generates ticket descriptions, and drafts acceptance criteria from a brief summary
- **Automated ETA calculation** — based on dev velocity, team calendar, and current queue depth
- **Full file rollup** — every file attached to a ticket, its comments, or its related requests visible in one panel on the ticket record

### For Everyone
- **Cross-org real-time sync** — bidirectional sync via REST between any two Salesforce orgs. Comments, stage changes, file attachments, and field updates replicate within seconds
- **Echo suppression** — smart deduplication prevents sync loops when both orgs update the same record
- **Audit trail** — every sync item tracked in a ledger with status, retry count, and payload
- **Dependency tracking** — mark tickets as blocking each other; the board surfaces blocked tickets and warns before invalid transitions

---

## How It Works

```
Your Org (Client)                        Cloud Nimbus's Org (Vendor)
─────────────────                        ───────────────────────────
Ticket created           ──── sync ────► Request ingested
  └─ Stage updated       ◄─── sync ────   └─ Developer assigned
  └─ Comment posted      ──── sync ────►  └─ Comment synced back
  └─ File attached       ──── sync ────►  └─ Status progressed
  └─ Stage updated       ◄─── sync ────   └─ Deployed to Prod
```

1. **You create a ticket** in your org's Kanban board. A `Request__c` sync record is queued.
2. **Delivery Hub's scheduler** (runs every 15 minutes, or on-demand) picks up the queue and POSTs to the vendor's REST endpoint.
3. **The vendor's org ingests** the payload, creates or updates their matching ticket, and syncs back any response fields.
4. **Both orgs stay in lock-step** — every stage change, comment, and file attachment triggers another sync cycle automatically.
5. **Echo suppression** on both sides ensures a change originating from Org A doesn't bounce back from Org B as a new sync event.

The sync engine is headless, retry-aware (up to 3 attempts with automatic re-queue), and handles namespace translation for managed package deployments.

---

## Key Features at a Glance

| Feature | Details |
|---|---|
| Kanban Board | Drag-and-drop, 40+ stages, configurable column order |
| Stage Gate Warnings | Block moves when required fields (developer, criteria, estimate) are missing |
| Fast Track | Highlights the path to dev when estimate fits within pre-approved budget |
| Cross-Org Sync | Bidirectional REST sync with retry, echo suppression, and ledger |
| Multi-Vendor | Route to multiple vendors simultaneously |
| Chat | Real-time polling chat on every ticket, with file attachment indicators |
| File Rollup | Aggregates files from ticket + comments + requests into one panel |
| Time Logger | Quick-log hours against a ticket; creates WorkLog entries with optional notes |
| Ghost Recorder | Floating or card-mode issue/feature submission form with keyboard shortcut |
| AI Estimation | OpenAI-powered hours estimate and description generation |
| ETA Engine | Calculates projected UAT-ready date from velocity and queue depth |
| Client Dashboard | Home page shows attention items, in-flight phase counts, recent activity |
| Setup Wizard | One-click connection to vendor org with automatic scheduler provisioning |

---

## Getting Started in 3 Minutes

### As a Client Org

1. Install the Delivery Hub package (see **Install** section above)
2. Open the **Delivery Hub** Lightning App
3. On the Home tab, click **Quickstart Connection** — this registers your org, configures default settings, and schedules the sync jobs automatically
4. Create your first ticket on the **Ticket Board** tab
5. Watch it appear on your vendor's board within seconds

### As a Vendor Org (Self-Hosted)

1. Clone this repository
2. Run `cci flow run dev_org --org dev` to spin up a scratch org
3. Run `cci org browser dev` to open it
4. Configure your `Cloud_Nimbus_LLC_Marketing__mdt` custom metadata with your org's endpoint URL
5. Client orgs can now connect to you via Quickstart

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
│   ├── DeliveryTicketETAService.cls    # ETA calculation engine
│   ├── DeliveryHubDashboardController  # Home page metrics + client dashboard
│   ├── DeliveryHubFilesController      # Rolled-up file queries
│   ├── DeliveryHubCommentController    # Chat: get/post comments + file indicators
│   ├── DeliveryTimeLoggerController    # Time logging against tickets (WorkLog__c)
│   └── DeliveryHubSetupController      # Quickstart wizard + handshake
├── lwc/
│   ├── deliveryHubBoard/               # Main Kanban board (drag-drop, column config)
│   ├── deliveryTicketActionCenter/     # Stage transition buttons with gate logic
│   ├── deliveryTicketChat/             # Real-time polling chat with file indicators
│   ├── deliveryTicketFiles/            # Rolled-up files sidebar panel
│   ├── deliveryTimeLogger/             # Quick time logging with WorkLog__c creation
│   ├── deliveryClientDashboard/        # Client home: attention / in-flight / recent
│   ├── deliveryHubSetup/               # Quickstart connection wizard
│   ├── deliveryGhostRecorder/          # Issue / feature request submission form
│   └── deliveryTicketRefiner/          # AI description and sizing assistant
├── objects/
│   ├── Ticket__c/                      # Core work item
│   ├── Request__c/                     # Sync bridge (client ↔ vendor)
│   ├── Sync_Item__c/                   # Outbound sync ledger
│   ├── Network_Entity__c/              # Connected org registry
│   ├── Ticket_Comment__c/              # Chat messages
│   ├── Ticket_Dependency__c/           # Blocking relationships
│   └── WorkLog__c/                     # Time tracking entries
└── triggers/
    ├── DeliveryTicketTrigger           # Stage changes → sync engine
    ├── DeliveryTicketCommentTrigger    # Comments → sync engine
    └── DeliveryContentDocumentLinkTrigger  # File attachments → sync engine
```

---

## CI/CD

This project uses [CumulusCI](https://cumulusci.readthedocs.io/) with GitHub Actions for a fully automated release pipeline.

Every pull request:
1. Spins up a namespaced scratch org
2. Deploys the full package
3. Runs all Apex tests (74+ tests, 75%+ coverage enforced)
4. Runs PMD static analysis with custom rules
5. Tears down the scratch org

### Developer Workflow

```bash
# Set up CumulusCI
cci flow run dev_org --org dev

# Open your scratch org
cci org browser dev

# Retrieve your changes
cci task run retrieve_changes --org dev

# Push a feature branch and open a PR
git push origin feature/your-feature
```

### Releasing

```bash
# Beta package
cci flow run release_unlocked_beta --org dev

# Production package
cci flow run release_unlocked_production --org dev
```

After promoting, copy the `04t...` package version ID from the CumulusCI output and update the install links in the [latest GitHub Release](https://github.com/Nimba-Solutions/Delivery-Hub/releases/latest).

---

## Built By

**Cloud Nimbus LLC** — We build Salesforce delivery infrastructure so you can focus on your actual product.

Questions, issues, or partnership inquiries: open an issue or reach out at [cloudnimbusllc.com](https://cloudnimbusllc.com).
