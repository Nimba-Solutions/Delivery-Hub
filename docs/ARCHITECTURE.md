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
| **DeliveryHubSettings\_\_c** | Org-level settings (hierarchy custom setting) | Scheduling, polling, AI config, ReconciliationHourNumber\_\_c, SyncRetryLimitNumber\_\_c, ActivityLogRetentionDaysNumber\_\_c, EscalationCooldownHoursNumber\_\_c |
| **ActivityLog\_\_c** | Audit trail of changes on work items | WorkItemId\_\_c, ActionTypePk\_\_c, ComponentNameTxt\_\_c, ContextDataTxt\_\_c, PageUrlTxt\_\_c, NetworkEntityId\_\_c, SessionIdTxt\_\_c |
| **DeliveryDocument\_\_c** | Generated documents (invoices, status reports) with versioning | NetworkEntityId\_\_c (MD), TemplatePk\_\_c, StatusPk\_\_c, SnapshotTxt\_\_c (131072 LTA), TotalHoursNumber\_\_c, TotalCurrency\_\_c, AiNarrativeTxt\_\_c, PublicTokenTxt\_\_c (External ID), PeriodStartDate\_\_c, PeriodEndDate\_\_c, TermsTxt\_\_c, DueDateDate\_\_c, VersionNumber\_\_c (default 1), PreviousVersionId\_\_c (self-lookup), DisputeReasonTxt\_\_c (LTA 5000) |
| **DeliveryTransaction\_\_c** | Financial transactions against a document (payments, credits, refunds) | DocumentId\_\_c (MD to DeliveryDocument\_\_c), AmountCurrency\_\_c, TypePk\_\_c (Payment/Credit/Refund/Adjustment/Write-Off), MethodPk\_\_c, TransactionDateDate\_\_c, NoteTxt\_\_c |
| **PortalAccess\_\_c** | Controls portal user access; links email to NetworkEntity with access level | NetworkEntityId\_\_c (MD), EmailTxt\_\_c, RolePk\_\_c |
| **DeliverySavedFilter\_\_c** | User-owned saved board filter presets (Private sharing model) | LabelTxt\_\_c, FilterJsonTxt\_\_c (LTA), IsDefaultBool\_\_c, WorkflowTypeTxt\_\_c |

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
| **DocumentTemplate\_\_mdt** | Registry of document templates (Invoice, Status\_Report) | PortalComponentTxt\_\_c, DataQueryTxt\_\_c, OutputFormatsTxt\_\_c, AiPromptTxt\_\_c, WorkflowTypeTxt\_\_c, DescriptionTxt\_\_c |
| **TrackedField\_\_mdt** | Defines which fields the Activity Tracking system monitors for change logging. Records: WorkItem\_Developer, WorkItem\_Priority, WorkItem\_Stage, WorkItem\_Status | ObjectApiName\_\_c, FieldApiName\_\_c, FieldLabel\_\_c, IsEnabledBool\_\_c, SortOrderNumber\_\_c |

### Platform Events

| Event | Purpose | Key Fields |
|-------|---------|------------|
| **DeliveryWorkItemChange\_\_e** | Published on work item changes to drive real-time UI updates | -- |
| **DeliverySync\_\_e** | Published on sync item completion (success or failure) for external subscribers | RecordIdTxt\_\_c, ObjectTypePk\_\_c, DirectionPk\_\_c, StatusPk\_\_c, ErrorMessageTxt\_\_c |
| **DeliveryEscalation\_\_e** | Published when an escalation rule fires, enabling external alerting integrations | WorkItemIdTxt\_\_c, RuleNameTxt\_\_c, SeverityPk\_\_c, ActionTypePk\_\_c, DaysInStageNum\_\_c |
| **DeliveryDocEvent\_\_e** | Published on document lifecycle events (generated, sent, approved, disputed) | DocumentIdTxt\_\_c, StatusPk\_\_c, TemplatePk\_\_c, EntityNameTxt\_\_c |

### Relationship Diagram

```
WorkflowType__mdt
  |-- WorkflowStage__mdt (many stages per type)
  |-- WorkflowPersonaView__mdt (many persona columns per type)
  |-- WorkflowStageRequirement__mdt (stage gate rules)

NetworkEntity__c
  |-- WorkItem__c.ClientNetworkEntityId__c (client owns work items)
  |-- WorkRequest__c.DeliveryEntityId__c (vendor receives work)
  |-- DeliveryDocument__c.NetworkEntityId__c (generated documents)
  |     |-- DeliveryTransaction__c.DocumentId__c (payments, credits, refunds)
  |-- PortalAccess__c.NetworkEntityId__c (portal user access)

WorkItem__c
  |-- WorkItemComment__c.WorkItemId__c (comments)
  |-- WorkRequest__c.WorkItemId__c (vendor delivery requests)
  |-- WorkItemDependency__c.BlockingWorkItemId__c / DependentWorkItemId__c
  |-- WorkLog__c.WorkItemId__c (time entries)
  |-- SyncItem__c.WorkItemId__c (sync audit trail)
  |-- ActivityLog__c.WorkItemId__c (change history)
  |-- ContentDocumentLink (file attachments)

DeliveryDocument__c
  |-- DeliveryDocument__c.PreviousVersionId__c (version chain, self-lookup)

DeliverySavedFilter__c (owned by User, Private sharing model)
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
| GET | `/api/activity-feed` | Activity feed for an entity |
| GET | `/api/work-logs` | Work log entries for an entity |
| POST | `/api/log-hours` | Submit a new time log entry |
| POST | `/api/approve-worklogs` | Approve pending work log entries |
| POST | `/api/reject-worklogs` | Reject pending work log entries |
| GET | `/api/board-summary` | AI-generated board summary |
| GET | `/api/files` | Files attached to entity work items |
| GET | `/api/documents` | `DeliveryDocumentController.getDocumentsForEntity()` |
| GET | `/api/conversations` | Comment threads for entity work items |
| GET | `/api/pending-approvals` | Work logs awaiting approval |
| GET | `/api/my-entities` | Entities accessible by the authenticated portal user |
| GET | `/api/portal-users` | Portal users for an entity |
| GET | `/api/documents/{token}` | Document detail by public token |
| POST | `/api/document-approve` | Approve a document by public token |
| POST | `/api/document-dispute` | Dispute a document with reason by public token |

See [Public API Guide](PUBLIC_API_GUIDE.md) for full documentation.

### Task API (CI/CD & AI Agents)

**Class**: `DeliveryTaskAPI` (`@RestResource /deliveryhub/v1/tasks/*`)

For CI/CD tools, AI agents, and automation platforms. Endpoints for task management operations.

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
| `deliveryScore` | Attention score indicator, placed on the WorkItem record page sidebar |

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
| `deliverySyncRetryPanel` | Monitor and retry failed sync items. Placed on admin Home page and NetworkEntity record page sidebar. |
| `deliverySyncPollerButton` | Manual sync poll trigger |
| `deliveryActivityTimeline` | Full audit trail of work item changes |
| `deliveryRecurringConfig` | Recurring work item schedule configuration |
| `deliveryReleaseNotes` | Auto-generated release summaries |
| `deliveryCsvImport` | Bulk import from CSV files |
| `deliveryDocumentViewer` | Document preview and management. Placed on Document record page (Preview tab) and admin Home page. |
| `deliveryAiDraftPanel` | AI-generated description and acceptance criteria |
| `deliveryTimelineView` | Gantt-style horizontal timeline with zoom (week/month/quarter), scroll, today marker, stage colors, click-to-navigate. Available as Delivery Timeline tab. |

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

---

## Activity Tracking System

The activity tracking system captures both explicit field changes and implicit navigation patterns for audit and analytics.

### Components

| Class | Responsibility |
|-------|---------------|
| **DeliveryGhostRecorder** (LWC) | Floating UI widget that captures navigation patterns. Logs page visits as `ActivityLog__c` records with page URL, component name, and session context. |
| **DeliveryActivityLogCleanup** | Global schedulable job that purges old navigation/activity logs. Retention period is configurable via `DeliveryHubSettings__c.ActivityLogRetentionDaysNumber__c` (default: 90 days). |
| **TrackedField\_\_mdt** | Custom Metadata Type that defines which fields on which objects generate change log entries. Ships with 4 records: WorkItem\_Developer, WorkItem\_Priority, WorkItem\_Stage, WorkItem\_Status. |

### How It Works

1. **Navigation tracking**: The `deliveryGhostRecorder` LWC listens for page navigation events and writes `ActivityLog__c` records with `ActionTypePk__c`, `PageUrlTxt__c`, `ComponentNameTxt__c`, and session/user context.
2. **Field change tracking**: When a tracked field (defined in `TrackedField__mdt`) changes on a work item, the system logs the old and new values as an `ActivityLog__c` record with the relevant `RecordIdTxt__c`.
3. **Cleanup**: `DeliveryActivityLogCleanup` runs on a schedule to purge stale navigation logs, keeping the `ActivityLog__c` table lean.

### ActivityLog\_\_c Fields

| Field | Purpose |
|-------|---------|
| ActionTypePk\_\_c | Type of action (page\_view, field\_change, etc.) |
| ComponentNameTxt\_\_c | LWC component that generated the log |
| PageUrlTxt\_\_c | URL of the page visited |
| ContextDataTxt\_\_c | Additional context (JSON) |
| RecordIdTxt\_\_c | Related record ID |
| NetworkEntityId\_\_c | Scoping to a network entity |
| SessionIdTxt\_\_c | Browser session identifier |
| UserIdTxt\_\_c | User who performed the action |

---

## Configurable Settings

Operational parameters that were previously hardcoded constants are now read at runtime from `DeliveryHubSettings__c`. Each setting falls back to a sensible default when not configured.

| Setting Field | Default | Consumer | Description |
|---------------|---------|----------|-------------|
| `ReconciliationHourNumber__c` | 6 | `DeliveryHubScheduler` | GMT hour (0-23) for the daily sync reconciliation run |
| `SyncRetryLimitNumber__c` | 3 | `DeliveryHubScheduler` | Max retry attempts before a failed sync item stays in Failed status |
| `ActivityLogRetentionDaysNumber__c` | 90 | `DeliveryActivityLogCleanup` | Days to retain activity/navigation logs before purging |
| `EscalationCooldownHoursNumber__c` | 24 | `DeliveryEscalationService` | Minimum hours between repeated escalations of the same work item |

DateTime activation toggles (e.g., `RequireWorkLogApprovalDate__c`) store the exact timestamp when a feature was enabled, providing an audit trail. The Settings UI in the admin app exposes all of these fields.

### WorkItem Admin Page

The WorkItem Admin record page uses **Dynamic Forms** -- fields are placed directly on the Lightning page layout rather than through a page layout assignment. This allows conditional visibility rules and a more flexible field arrangement per section.

---

## Document Engine

The Document Engine generates structured documents (invoices, status reports) from live Salesforce data, stores them as snapshots, and exposes them through the portal API.

### Components

| Class | Responsibility |
|-------|---------------|
| **DeliveryDocumentController** | Core controller. Generates documents by querying work items, work logs, work requests, and entity data. Builds a JSON snapshot stored on `DeliveryDocument__c.SnapshotTxt__c`. Handles email delivery with configurable CC via `DocumentCcEmailTxt__c`. Supports retrieval by ID or public token. |
| **DeliveryDocumentPdfController** | Visualforce controller for server-side PDF rendering. Parses the frozen JSON snapshot and exposes typed properties (vendor branding, line items, totals, A/R summary, prior balance) that the `DeliveryDocumentPdf.page` consumes. Work item names in the PDF are hyperlinked to their Salesforce records. Runs `without sharing` for guest user / Site access. |
| **DocumentTemplate\_\_mdt** | Registry of document templates. Each record defines a portal component, data query shape, output formats, and an optional AI prompt. Ships with Invoice, Status\_Report, Client\_Agreement, and Contractor\_Agreement records. |

### Rate Hierarchy

When calculating totals for invoices, the engine resolves hourly rates using a three-tier fallback:

1. **WorkRequest** rate (`HourlyRateCurrency__c`) -- highest priority, set per vendor assignment
2. **WorkItem** rate (`BillableRateCurrency__c`) -- item-level override
3. **NetworkEntity** default rate (`DefaultHourlyRateCurrency__c`) -- org-wide fallback

Total is computed as `SUM(hours * resolved_rate)` across all work log entries in the document period.

### Public Token Access

Each generated document receives a unique `PublicTokenTxt__c` (External ID). This token enables unauthenticated access through the portal API, allowing recipients to view invoices and status reports without logging in.

### Generation Flow

```
DeliveryDocumentController.generateDocument(entityId, templateType, periodStart, periodEnd)
  -> Query NetworkEntity, WorkItems, WorkLogs, WorkRequests for the period
  -> Filter out work items with zero logged hours in the period
  -> Build JSON snapshot with entity, items, logs, requests, and computed totals
  -> Create DeliveryDocument__c record with snapshot, totals, and public token
  -> Return document Id for immediate rendering or portal sharing
```

### JSON Snapshot Pattern

Each generated document stores a complete JSON snapshot in `DeliveryDocument__c.SnapshotTxt__c` (131,072-character Long Text Area). The snapshot captures the exact state of all contributing data at generation time: entity details, work items, work logs with resolved rates, work requests, and computed totals. This makes documents **immutable** -- subsequent changes to hours, rates, or descriptions do not alter previously generated documents. The snapshot is parsed at render time by both the LWC document viewer (client-side) and `DeliveryDocumentPdfController` (server-side PDF).

### White-Label Vendor Branding

Documents are issued under the vendor entity's branding, not the Salesforce org's identity. The generation flow resolves the vendor NetworkEntity via `WorkRequest.DeliveryEntityId__c` and pulls:

- **Company name** from `NetworkEntity__c.Name`
- **Address** from `AddressTxt__c` (formatted with line breaks for PDF)
- **Email** from `ContactEmailTxt__c`
- **Phone** from `ContactPhoneTxt__c`

This enables white-label invoicing where the vendor's details appear on the document header regardless of which org generates it.

### Payment Tracking

The `DeliveryTransaction__c` object tracks financial transactions against documents. Each transaction has:

- **TypePk__c**: Payment, Credit, Refund, Adjustment, Write-Off
- **MethodPk__c**: Payment method (check, ACH, wire, etc.)
- **AmountCurrency__c**: Transaction amount
- **TransactionDateDate__c**: When the transaction occurred

Multiple transactions can be recorded per document. The A/R summary on invoices aggregates prior unpaid document balances and transaction totals to show the outstanding amount due.

### Email Delivery

When a document is sent via email, `DeliveryDocumentController` constructs a `Messaging.SingleEmailMessage` with the document PDF attached. The recipient is the client NetworkEntity's contact email. If `DeliveryHubSettings__c.DocumentCcEmailTxt__c` is populated, that address receives a CC copy of every outbound document email.

### Document Versioning

When regenerating a document for the same entity, period, and template combination:

1. The existing document's status is set to **Superseded**
2. A new `DeliveryDocument__c` record is created with an incremented `VersionNumber__c`
3. The new document's `PreviousVersionId__c` links back to the superseded document
4. Superseded documents are excluded from prior balance calculations on new invoices

This preserves full document history while ensuring only the latest version is used for financial calculations.

### Invoice Approval Flow

Documents support client-facing approval and dispute actions via public token authentication:

| Method | Description |
|--------|-------------|
| `approveDocumentByToken(token)` | Validates the document is in an approvable status, transitions to Approved, creates an Approval transaction, and logs the action |
| `disputeDocumentByToken(token, reason)` | Transitions to Disputed, stores the reason in `DisputeReasonTxt__c`, and logs the action |

Both methods are exposed through `DeliveryPublicApiService` as `POST /api/document-approve` and `POST /api/document-dispute`.

---

## Email System

### Inbound Email Handler

| Class | Responsibility |
|-------|---------------|
| **DeliveryInboundEmailHandler** | Implements `Messaging.InboundEmailHandler`. Parses work item numbers from the To address or Subject line using regex (`workitem-T0039`, `T-0039`, `T0039`). Resolves the sender as a Salesforce user, validates the feature gate (`EnableEmailNotificationsDateTime__c`), strips reply quotes, and inserts a `WorkItemComment__c` with `SourcePk__c = 'Email'`. |
| **DeliveryEmailService** | Outbound notification service. Sends comment notification emails to subscribed users (developer + owner) with reply-to address routing back through the inbound handler. Uses `@future` for async email sends. Gated by `EnableEmailNotificationsDateTime__c` org-level setting. |

### Email Flow

```
New comment posted (UI / Sync / Portal)
  -> DeliveryEmailService.notifyCommentSubscribers()
     -> Query work item developer + owner
     -> Build SingleEmailMessage with reply-to = workitem-T{number}@{domain}
     -> Send notification

Recipient replies to email
  -> DeliveryInboundEmailHandler.handleInboundEmail()
     -> Parse T-number from To address or Subject
     -> Resolve sender as Salesforce user
     -> Check EnableEmailNotificationsDateTime__c gate
     -> Strip reply quote text
     -> Insert WorkItemComment__c (Source = 'Email')
     -> Trigger sync engine for comment replication
```

---

## Saved Filters

| Class | Responsibility |
|-------|---------------|
| **DeliverySavedFilterController** | CRUD controller for `DeliverySavedFilter__c`. Methods: `getSavedFilters(workflowType)`, `saveBoardFilter(label, filterJson, isDefault, workflowType)`, `deleteSavedFilter(filterId)`. Uses Private sharing model -- each user can only see their own filters. |

Filters are stored as JSON capturing the complete board filter state and scoped to a workflow type. Default filters auto-apply when the board loads.

---

## Timeline View

| Class | Responsibility |
|-------|---------------|
| **DeliveryTimelineController** | Returns active work items with computed date ranges grouped by NetworkEntity. Uses a fallback chain for start/end dates (CreatedDate, CalculatedETADate__c, estimated hours converted to days). |

The `deliveryTimelineView` LWC renders a CSS Grid-based Gantt chart with configurable zoom levels (week/month/quarter), horizontal scroll, a today-line marker, and stage-based colors pulled from `WorkflowStage__mdt`.

---

## Platform Events

Three HighVolume platform events enable external systems to subscribe to key lifecycle events without polling:

| Event | Publisher | When Fired |
|-------|-----------|------------|
| **DeliverySync\_\_e** | `DeliverySyncItemProcessor` | After every sync item completion (success or failure) |
| **DeliveryEscalation\_\_e** | `DeliveryEscalationService` | When an escalation rule fires against a work item |
| **DeliveryDocEvent\_\_e** | `DeliveryDocumentController` | On document generation, send, approval, or dispute |

These are in addition to `DeliveryWorkItemChange__e` which drives real-time UI updates within the app.

---

## Package Summary

| Category | Count |
|----------|-------|
| Apex classes | 148 (75 production + 73 test) |
| LWC components | 57 |
| Custom Objects | 15 (includes DeliverySavedFilter\_\_c) |
| Custom Metadata Types | 10 |
| Platform Events | 4 (DeliveryWorkItemChange\_\_e, DeliverySync\_\_e, DeliveryEscalation\_\_e, DeliveryDocEvent\_\_e) |
| Permission Sets | 3 |
| Triggers | 5 |
