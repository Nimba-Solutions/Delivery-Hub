# Changelog

All notable changes to the Delivery Hub package are documented here.

---

## 2026-03-24

### PR #443 — Package upload fixes

- Rename DeliveryDocument__e to DeliveryDocEvent__e to avoid name conflict with DeliveryDocument__c custom object
- Set enableStreamingApi=true on DeliverySavedFilter__c
- Fix missing closing brace on testSupersededExcludedFromPriorBalance (broken merge)
- Merge duplicate @SuppressWarnings annotations on DeliveryEmailService and DeliveryInboundEmailHandler

### PR #442 — Inbound email handler for work item comments

- New `DeliveryInboundEmailHandler` (implements `Messaging.InboundEmailHandler`) parses work item numbers from To address or Subject line and creates WorkItemComment__c records
- New `DeliveryEmailService` sends outbound comment notification emails with reply-to routing back through the inbound handler for email-based collaboration
- Supported patterns: `workitem-T0039`, `T-0039`, `T0039`
- Reply quote text automatically stripped for clean comment bodies
- Feature gated by `EnableEmailNotificationsDateTime__c` user-level setting
- New "Email" picklist value on `WorkItemComment__c.SourcePk__c`

### PR #441 — Timeline View LWC

- New `DeliveryTimelineController` returns active work items with date ranges grouped by NetworkEntity
- New `deliveryTimelineView` LWC: CSS Grid-based horizontal Gantt chart with zoom (week/month/quarter), scroll controls, today-line marker, stage colors from workflow config, click-to-navigate
- New **Delivery Timeline** tab added to both Lightning apps
- Tab visibility added to both permission sets
- 7 test methods covering filters, fallback dates, empty states, unassigned entities

### PR #440 — Saved board filters

- New `DeliverySavedFilter__c` custom object with Private sharing model (LabelTxt__c, FilterJsonTxt__c, IsDefaultBool__c, WorkflowTypeTxt__c)
- New `DeliverySavedFilterController` with getSavedFilters, saveBoardFilter, deleteSavedFilter methods
- Dropdown menu in board filter toolbar for loading saved filters
- Save modal for naming and setting default filters
- Default filters auto-apply on board load
- Up to 50 filters per user per workflow type

### PR #439 — Document versioning

- Regenerating a document for the same entity+period+template now creates a new version instead of overwriting
- Old document status set to **Superseded**
- New document gets incremented `VersionNumber__c` and links to old via `PreviousVersionId__c` (self-lookup)
- Superseded documents excluded from A/R prior balance calculations
- 5 new test methods covering version chain, independence, and balance exclusion

### PR #438 — Client-facing invoice approval flow

- New `approveDocumentByToken` and `disputeDocumentByToken` methods on DeliveryDocumentController
- New Public API endpoints: `POST /api/document-approve`, `POST /api/document-dispute`, `GET /api/documents/{token}`
- New field: `DeliveryDocument__c.DisputeReasonTxt__c` (LongTextArea 5000)
- New picklist values: "Approved" on StatusPk__c, "Approval" on TypePk__c, "Document_Action" on ActionTypePk__c
- Permission set updates: DisputeReasonTxt__c on Guest + Admin sets
- 9 new test methods across controller + API service

### PR #437 — Custom app icon + stage gate relaxation

- DeliveryHubLogo SVG static resource (package box with checkmark in Salesforce blue)
- Logo wired to both Delivery Hub and Delivery Hub Admin Lightning apps for App Launcher visibility
- Gate 3 (developer assignment check) relaxed to trigger at In Development only, removing premature block at Ready for Development

### PR #436 — Platform events for sync, escalation, and documents

- New `DeliverySync__e` platform event published by DeliverySyncItemProcessor on every sync completion
- New `DeliveryEscalation__e` platform event published by DeliveryEscalationService when rules fire
- New `DeliveryDocEvent__e` platform event published by DeliveryDocumentController on document lifecycle events
- All three are HighVolume events enabling external systems to subscribe without polling

### PR #435 — Enhanced portal time entry

- `GET /api/work-logs` now accepts optional `workItemId` query parameter for filtering
- `POST /api/log-hours` validates work item belongs to authenticated entity (403 if cross-entity)
- Portal time entries now create ActivityLog__c records for audit
- 3 new test methods: cross-entity blocking, activity log creation, workItemId filter

### PR #434 — Hide empty columns toggle + In Flight list view

- New "Hide Empty Columns" toggle in board toolbar
- In Flight list view updated with: Number, Sort Order, ETA, Description, Stage, Budget Variance, Logged Hours, Est Hours, Created Date

### PR #433 — Demo org flow

- New CCI flow: `cci flow run demo_org --org dev`
- Creates scratch org, deploys package, assigns permissions
- Loads realistic sample data: 2 entities, 10 work items across 8 stages, 7 work requests, 21 work logs (108h), 4 comments, 1 draft invoice
- Configures org defaults (activity logging, field tracking, board metrics)
- Schedules all background jobs (poller, cleanup, digest, reconciliation)

### PR #432 — Copy public link LockerService fix

- `navigator.clipboard.writeText()` is blocked by Lightning LockerService
- Switched to hidden textarea + `execCommand('copy')` fallback that works in all contexts

### PR #431 — Task API versioned URL

- Moved DeliveryTaskAPI to `/deliveryhub/v1/tasks/*` (from `/delivery/tasks/*`)
- Aligns with URL convention used by sync, public API, and bounty endpoints
- **Breaking change**: External integrations must update their base URL

### PR #430 — Settings runtime behavior tests

- New test methods verifying configurable settings control runtime behavior:
  - ActivityLogRetentionDaysNumber__c (30 days vs default 90)
  - EscalationCooldownHoursNumber__c (1h and 72h vs default 24h)
  - SyncRetryLimitNumber__c (1 vs default 3)
  - ReconciliationHourNumber__c (non-matching hour suppresses reconciler)

### PR #429 — Documentation update for PRs #424-#428

- README, GETTING_STARTED, ARCHITECTURE, CHANGELOG, PUBLIC_API_GUIDE updated for configurable settings, dynamic forms, PDF hyperlinks, record page assignments, zero-hour filtering, and settings page overhaul

### PR #428 — Configurable settings wired into Apex + admin dynamic forms + PDF hyperlinks

- **Configurable settings**: Four operational parameters previously hardcoded in Apex are now read from `DeliveryHubSettings__c` at runtime:
  - `ReconciliationHourNumber__c` (default 6) — controls the GMT hour for daily sync reconciliation
  - `SyncRetryLimitNumber__c` (default 3) — max retry attempts for failed sync items
  - `ActivityLogRetentionDaysNumber__c` (default 90) — activity log purge threshold
  - `EscalationCooldownHoursNumber__c` (default 24) — minimum hours between re-escalating the same work item
- **Dynamic Forms**: WorkItem Admin record page converted from page layout to Dynamic Forms with field-level conditional visibility
- **PDF hyperlinks**: Work item names in invoice PDFs are now clickable links to their Salesforce records (both work items table and time log detail table)
- **PMD compliance**: Non-final static fields renamed to camelCase

### PR #427 — LWC placements on record pages

- `deliveryScore` placed on WorkItem record page sidebar
- `deliveryDocumentViewer` placed on Document record page (Preview tab)
- `deliverySyncRetryPanel` placed on NetworkEntity record page sidebar

### PR #426 — Settings page overhaul

- DateTime activation toggles replace boolean switches for feature flags (e.g., Work Log Approval records the exact activation timestamp)
- Four new configurable settings exposed in the Settings UI: reconciliation hour, sync retry limit, activity log retention days, escalation cooldown hours
- Settings container redesigned with grouped cards

### PR #425 — Zero-hour invoice filtering

- Work items with zero logged hours in the billing period are automatically excluded from generated invoices

### PR #424 — Record page assignments + VF URL fix + PDF page-break fix

- Record page assignments added for all Lightning apps (Delivery Hub + Delivery Hub Admin)
- Visualforce `DeliveryDocumentPdf.page` uses runtime namespace detection instead of `%%%NAMESPACE_PREFIX%%%` merge tokens
- PDF page-break CSS fix for multi-page documents
- Invoice footer now includes a cloudnimbusllc.com hyperlink

---

## 2026-03-17

### PR #423 — Final PMD compliance

- Zero PMD violations across the entire codebase

### PR #422 — DashboardController PMD + record page guide

- DashboardController PMD compliance
- Record page assignment documentation
