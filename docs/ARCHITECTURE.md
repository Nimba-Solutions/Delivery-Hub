# Delivery Hub Architecture

High-level architecture overview of the Delivery Hub Salesforce managed package.

**Namespace**: `delivery`
**Package type**: Unlocked package (2GP)
**Build system**: CumulusCI

---

## Object Model

### Custom Objects

| Object | Purpose | Key Fields |
|--------|---------|------------|
| **WorkItem\_\_c** | Core work item (ticket, task, deliverable) | BriefDescriptionTxt\_\_c, StageNamePk\_\_c, PriorityPk\_\_c, ClientNetworkEntityId\_\_c, WorkflowTypeTxt\_\_c, EstimatedHoursNumber\_\_c, CalculatedETADate\_\_c |
| **WorkItemComment\_\_c** | Comments/chat on a work item | WorkItemId\_\_c, BodyTxt\_\_c, AuthorTxt\_\_c, SourcePk\_\_c |
| **WorkRequest\_\_c** | Bridge linking a WorkItem to a vendor NetworkEntity for downstream sync | WorkItemId\_\_c, DeliveryEntityId\_\_c, RemoteWorkItemIdTxt\_\_c, StatusPk\_\_c |
| **NetworkEntity\_\_c** | Represents a connected org or external system | EntityTypePk\_\_c (Client/Vendor/Both), IntegrationEndpointUrlTxt\_\_c, ApiKeyTxt\_\_c, ConnectionStatusPk\_\_c, EnableVendorPushBool\_\_c, OrgIdTxt\_\_c |
| **SyncItem\_\_c** | Audit ledger for every sync event (inbound and outbound) | DirectionPk\_\_c, StatusPk\_\_c, ObjectTypePk\_\_c, PayloadTxt\_\_c, GlobalSourceIdTxt\_\_c, RemoteExternalIdTxt\_\_c, LocalRecordIdTxt\_\_c |
| **WorkItemDependency\_\_c** | Blocking relationship between two work items | BlockingWorkItemId\_\_c, DependentWorkItemId\_\_c |
| **WorkLog\_\_c** | Time logging entries | WorkItemId\_\_c, HoursNumber\_\_c, DateDt\_\_c, DescriptionTxt\_\_c |
| **DeliveryHubSettings\_\_c** | Org-level settings (hierarchy custom setting) | Scheduling, polling, AI config |
| **ActivityLog\_\_c** | Audit trail of changes on work items | WorkItemId\_\_c, action, old/new values |

### Custom Metadata Types

| CMT | Purpose | Key Fields |
|-----|---------|------------|
| **WorkflowType\_\_mdt** | Defines a workflow type (e.g., Software Delivery, Loan Approval) | Label, IconName\_\_c, SortOrderNumber\_\_c, IsDefaultBool\_\_c, UseSimplifiedViewBool\_\_c |
| **WorkflowStage\_\_mdt** | Stage definition within a workflow type | ApiValueTxt\_\_c, DisplayNameTxt\_\_c, CardColorTxt\_\_c, HeaderBgColorTxt\_\_c, PhaseTxt\_\_c, IsTerminalBool\_\_c, IsBlockedStateBool\_\_c, IsAttentionStateBool\_\_c, AllowedForwardTransitionsTxt\_\_c, AllowedBacktrackTransitionsTxt\_\_c |
| **WorkflowPersonaView\_\_mdt** | Column grouping for a persona's board view | PersonaNameTxt\_\_c, ColumnNameTxt\_\_c, StageApiValuesTxt\_\_c, SortOrderNumber\_\_c, IsExtendedColumnBool\_\_c |
| **WorkflowEscalationRule\_\_mdt** | Rule-based escalation conditions and actions | Condition fields, notification config |
| **WorkflowStageRequirement\_\_mdt** | Required fields for stage gate enforcement | Stage, required field, validation message |
| **SLARule\_\_mdt** | SLA target definitions | Response/resolution time targets |
| **CloudNimbusGlobalSettings\_\_mdt** | Global configuration defaults | Default vendor settings |
| **OpenAIConfiguration\_\_mdt** | AI integration settings | API key, model, endpoint |

### Platform Events

| Event | Purpose |
|-------|---------|
| **DeliveryWorkItemChange\_\_e** | Published on work item changes to drive real-time UI updates |

### Relationship Diagram

```
WorkflowType__mdt
  |-- WorkflowStage__mdt (many stages per type)
  |-- WorkflowPersonaView__mdt (many persona columns per type)
  |-- WorkflowStageRequirement__mdt (stage gate rules)

NetworkEntity__c
  |-- WorkItem__c.ClientNetworkEntityId__c (client owns work items)
  |-- WorkRequest__c.DeliveryEntityId__c (vendor receives work)

WorkItem__c
  |-- WorkItemComment__c.WorkItemId__c (comments)
  |-- WorkRequest__c.WorkItemId__c (vendor delivery requests)
  |-- WorkItemDependency__c.BlockingWorkItemId__c / DependentWorkItemId__c
  |-- WorkLog__c.WorkItemId__c (time entries)
  |-- SyncItem__c.WorkItemId__c (sync audit trail)
  |-- ActivityLog__c.WorkItemId__c (change history)
  |-- ContentDocumentLink (file attachments)
```

---

## Sync Engine

The sync engine handles bidirectional data replication between connected Salesforce orgs.

### Components

| Class | Responsibility |
|-------|---------------|
| **DeliverySyncEngine** | Core engine. Evaluates routing edges (upstream client + downstream vendors), creates outbound SyncItem records, manages echo suppression via blocked origins. |
| **DeliverySyncItemProcessor** | Queueable worker. Resolves endpoints, makes HTTP callouts, updates statuses, closes bridge loops with response IDs, chains for remaining work. |
| **DeliverySyncItemIngestor** | Inbound processing. Resolves local records via bridge/ledger lookup, maps fields, auto-parents upstream clients, registers echo suppression origins. |
| **DeliveryHubSyncService** | REST resource (`@RestResource`). Exposes POST (inbound sync) and GET /changes (pull flow) endpoints. Gateway-level echo suppression via X-Global-Source-Id header. |
| **DeliveryHubPoller** | Schedulable. Polls connected vendor orgs for staged changes on a 15-minute schedule. |

### Push Flow

```
Trigger (WorkItem/Comment/File change)
  -> DeliverySyncEngine.captureChanges()
     -> Evaluate downstream routes (WorkRequest -> Vendor entities)
     -> Evaluate upstream route (WorkItem -> Client entity)
     -> Create SyncItem__c records (StatusPk__c = 'Queued')
     -> Enqueue DeliverySyncItemProcessor
        -> Resolve endpoint URL + API key from NetworkEntity
        -> HTTP POST to /sync/{ObjectType}
        -> Set X-Global-Source-Id header for loop prevention
        -> Set X-Api-Key header for authentication
        -> Parse response, extract processedId
        -> Update WorkRequest.RemoteWorkItemIdTxt__c (bridge loop)
        -> Mark SyncItem as 'Synced' or 'Failed'
        -> Chain if more items remain
```

### Pull Flow

```
DeliveryHubPoller (scheduled or manual)
  -> GET /sync/changes?clientId={id}&since={lastSync}
  -> Remote org returns staged SyncItems, marks them as Synced
  -> For each returned item:
     -> DeliverySyncItemIngestor.processInboundItem()
        -> Resolve local record (bridge -> ledger -> direct ID -> new)
        -> Map fields (namespace-aware)
        -> Auto-parent upstream client entity
        -> Create ledger entry for new records
        -> Register echo suppression origin
```

### Echo Suppression (3 Layers)

1. **Gateway-level**: `X-Global-Source-Id` HTTP header checked against existing outbound SyncItems. Suppresses before any processing.
2. **In-memory origin blocking**: `DeliverySyncEngine.blockedOrigins` Set prevents re-routing to the origin entity within the same transaction.
3. **Kill-switch**: `DeliverySyncEngine.captureChanges()` compares target entity against the GlobalSourceId. If they match, the record originated there -- do not sync back.

---

## API Layer

### Public API (External Clients)

**Class**: `DeliveryPublicApiService` (`@RestResource /deliveryhub/v1/api/*`)

For websites, mobile apps, and external platforms. Authenticated via `X-Api-Key` header matched against NetworkEntity records. Delegates to `DeliveryPortalController` for entity-scoped data access.

| Method | Route | Handler |
|--------|-------|---------|
| GET | `/api/dashboard` | `DeliveryPortalController.getPortalDashboard()` |
| GET | `/api/work-items` | `DeliveryPortalController.getPortalWorkItems()` |
| GET | `/api/work-items/{id}` | `DeliveryPortalController.getPortalWorkItemDetail()` |
| POST | `/api/work-items` | `DeliveryPortalController.submitPortalRequest()` |
| POST | `/api/work-items/{id}/comments` | `DeliveryPortalController.addPortalComment()` |

See [Public API Guide](PUBLIC_API_GUIDE.md) for full documentation.

### Sync API (Org-to-Org)

**Class**: `DeliveryHubSyncService` (`@RestResource /deliveryhub/v1/sync/*`)

For Salesforce-to-Salesforce synchronization. Opt-in API key validation.

| Method | Route | Handler |
|--------|-------|---------|
| POST | `/sync/{ObjectType}` | `DeliverySyncItemIngestor.processInboundItem()` |
| GET | `/sync/changes` | Query staged SyncItems, return and mark as Synced |

See [Sync API Guide](SYNC_API_GUIDE.md) for full documentation.

---

## LWC Component Hierarchy

### Board and Core UI

| Component | Description |
|-----------|-------------|
| `deliveryHubBoard` | Main Kanban board. Wire-loads workflow config, renders persona-based columns, drag-and-drop stage transitions. |
| `deliveryWorkItemActionCenter` | Side panel for work item actions (stage change, assign, etc.) |
| `deliveryWorkItemChat` | Polling-based comment thread on work items |
| `deliveryWorkItemFiles` | File rollup panel (files from work item + comments + requests) |
| `deliveryWorkItemProgress` | Stage progress bar visualization |
| `deliveryWorkItemStageGateWarning` | Stage gate enforcement warnings |
| `deliveryWorkItemRefiner` | Filtering and search controls for the board |
| `deliveryManageRequest` | Work request management (link to vendor entities) |
| `deliveryWorkItemDependencies` | Dependency management UI |
| `deliveryWorkItemQuotes` | Quote/estimate management |
| `deliveryWorkItemTemplates` | Work item template picker |
| `deliverySwipeCard` | Mobile swipe interaction for stage transitions |

### Dashboard and Analytics

| Component | Description |
|-----------|-------------|
| `deliveryClientDashboard` | Home page dashboard: in-flight items, attention section, recent activity |
| `deliveryBudgetSummary` | Budget and hours summary with connection health indicator |
| `deliveryBurndownChart` | Sprint burndown tracking |
| `deliveryCycleTimeChart` | Stage duration analytics |
| `deliveryDeveloperWorkload` | Team capacity distribution |
| `deliveryDependencyGraph` | Visual dependency graph between work items |
| `deliveryGanttChart` | Gantt chart view of work items |
| `deliverySLASummary` | SLA status dashboard |

### Portal Components

| Component | Description |
|-----------|-------------|
| `deliveryPortalDashboard` | Portal-facing dashboard for external users |
| `deliveryPortalWorkItemList` | Portal work item list view |
| `deliveryPortalWorkItemDetail` | Portal work item detail view |
| `deliveryPortalRequestForm` | Portal request submission form |
| `deliveryStatusPage` | Public status page (no login required) |

### Setup and Configuration

| Component | Description |
|-----------|-------------|
| `deliveryGettingStarted` | 4-step onboarding wizard |
| `deliveryHubSetup` | Hub configuration panel |
| `deliverySettingsContainer` | Settings container (tabs for different setting areas) |
| `deliveryGeneralSettingsCard` | General settings |
| `deliveryAiSettingsCard` | AI configuration |
| `deliveryOpenAiSettingsCard` | OpenAI API key and model settings |
| `deliveryKanbanOpenAiSettings` | Board-specific AI settings |
| `deliveryKanbanSettingsContainer` | Board settings container |
| `deliveryPartnerSettingsCard` | Partner/vendor settings |
| `deliveryWorkflowTemplatePicker` | Workflow type selection UI |

### Operational Tools

| Component | Description |
|-----------|-------------|
| `deliveryGhostRecorder` | Floating work item submission form (available anywhere in the app) |
| `deliveryTimeLogger` | Quick hour logging |
| `deliverySyncRetryPanel` | Monitor and retry failed sync items |
| `deliverySyncPollerButton` | Manual sync poll trigger |
| `deliveryActivityTimeline` | Full audit trail of work item changes |
| `deliveryRecurringConfig` | Recurring work item schedule configuration |
| `deliveryReleaseNotes` | Auto-generated release summaries |
| `deliveryCsvImport` | Bulk import from CSV files |
| `deliveryAiDraftPanel` | AI-generated description and acceptance criteria |

---

## Triggers

| Trigger | Object | Purpose |
|---------|--------|---------|
| `DeliveryWorkItemTrigger` | WorkItem\_\_c | Fires sync engine on insert/update. Publishes platform events for real-time UI. |
| `DeliveryWorkItemCommentTrigger` | WorkItemComment\_\_c | Fires sync engine for comment replication. |
| `DeliveryContentDocumentLinkTrigger` | ContentDocumentLink | Fires sync engine when files are attached to work items. |
| `DeliveryWorkLogTrigger` | WorkLog\_\_c | Fires sync engine for time entry replication. |

All triggers delegate to `DeliverySyncEngine.captureChanges()` with a curated set of allowed fields. The sync engine checks `isSyncContext` to prevent recursive firing during inbound sync processing.

---

## Permission Model

### Permission Sets

| Permission Set | Audience | Access |
|----------------|----------|--------|
| **DeliveryHubApp** | Standard users | Read/write on all custom objects, access to all LWC components, field-level access for day-to-day work |
| **DeliveryHubAdmin\_App** | Administrators | Everything in DeliveryHubApp plus access to setup components, settings objects, and admin-only flexipages |
| **DeliveryHubGuestUser** | Salesforce Site guest users | Minimal access for the Public API: read on NetworkEntity (for auth), read/write on WorkItem and WorkItemComment (for portal operations). Applied to the Site guest user profile. |

### How Access Works

- **Internal users**: Assigned `DeliveryHubApp` or `DeliveryHubAdmin_App` via permission set assignment
- **Public API**: Site guest user with `DeliveryHubGuestUser` permission set. API key auth in `DeliveryPublicApiService` provides entity-level scoping on top of the permission set.
- **Sync API**: Uses `WITHOUT SHARING` and `SYSTEM_MODE` because sync operations are system-level. The opt-in API key provides caller identity verification.
- **Portal controllers**: Use `WITHOUT SHARING` intentionally because portal/guest users lack org-wide access. Entity-level access validation is done in code.

### Apex Sharing Model

Most Apex classes that handle sync or portal operations use `without sharing` combined with `WITH SYSTEM_MODE` queries. This is intentional:

- Sync operations are system-level and must access all records regardless of the running user's sharing rules
- Portal operations validate access through NetworkEntity relationship checks rather than sharing rules
- All write operations go through `Database.insert/update(records, AccessLevel.SYSTEM_MODE)`

---

## CI/CD Pipeline

### Build System

- **CumulusCI** manages scratch org lifecycle, package builds, and deployments
- **GitHub Actions** runs CI on every pull request

### CI Pipeline (Per PR)

1. Spin up a namespaced scratch org
2. Deploy the package source
3. Deploy `unpackaged/post/` (reports, test suites, etc.)
4. Run 300+ Apex tests (75%+ coverage enforced)
5. Run PMD static analysis (zero violations enforced)
6. Tear down scratch org

### Release Process

```bash
# Beta release
cci flow run release_unlocked_beta --org dev

# Production release
cci flow run release_unlocked_production --org dev
```

---

## Configurable Workflow Engine

The board UI is entirely data-driven. No stage names, colors, transitions, or persona views are hardcoded in JavaScript.

### How It Works

1. `DeliveryWorkflowConfigService.getWorkflowConfig(typeName)` queries all three CMT objects
2. Returns a structured config with stages, transitions, colors, and persona column groupings
3. `deliveryHubBoard` LWC wires to this method and renders everything dynamically
4. `WorkItem__c.WorkflowTypeTxt__c` determines which workflow applies to each item

### Adding a New Workflow Type

1. Create a `WorkflowType__mdt` record
2. Create `WorkflowStage__mdt` records for each stage (with colors, transitions, phase)
3. Create `WorkflowPersonaView__mdt` records to define column groupings per persona
4. Set `WorkflowTypeTxt__c` on work items to route them to the new workflow

### Shipped Workflow Types

| Type | Stages | Personas | Use Case |
|------|--------|----------|----------|
| Software_Delivery | 40+ | Client, Consultant, Developer, QA | Full software delivery lifecycle |
| Loan_Approval | 8 | Borrower, Processor, Admin | Simplified loan processing |
