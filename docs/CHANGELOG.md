# Changelog

All notable changes to the Delivery Hub package are documented here.

---

## 2026-04-06

### Refactoring

#### PR #574 — Enforce naming conventions on 11 custom fields
- Renamed 11 fields across 6 objects to include type suffix (e.g., `Developer__c` → `DeveloperLookupId__c`, `Epic__c` → `EpicTxt__c`, `Tags__c` → `TagsTxt__c`, `WorkflowType__c` → `WorkflowTypeMdtId__c`, `IconName__c` → `IconNameTxt__c`)
- Platform event fields and `TrackedField__mdt` fields also renamed
- Added 8 enterprise guide sections; fixed demo data script (339 files)

#### PR #572 — Rename Num__c fields to Number__c and fix RequireWorkLogApprovalDate to DateTime
- Renamed 5 `Num__c` fields to `Number__c` suffix per PMD naming convention
- Converted `RequireWorkLogApprovalDate__c` from Date to DateTime (43 files)

#### PR #565 — Rename 10 unprefixed Apex classes with Delivery prefix
- Enforced `Delivery` prefix naming convention on 10 Apex classes

#### PR #564 — Eliminate 40 PMD suppressions
- Final PMD cleanup pass (Phase 8)

### Features

#### PR #566 — Gantt ResizeObserver + enterprise settings UI
- Added responsive ResizeObserver to Gantt chart
- Rate limiting opt-in and enterprise settings exposed in admin UI

### Fixes

#### PR #573 — Guard ResizeObserver for Lightning Locker
- Wrapped ResizeObserver in try/catch for Lightning Locker compatibility
- Gantt initializes without auto-resize on incompatible environments

#### PR #571 — Use window.NimbusGantt in static resource for Lightning Locker compatibility
- Changed IIFE from `var` to `window` assignment for Locker-safe global access

#### PR #570 — Add Gantt info popover registry entry
- Added `deliveryNimbusGantt` to info popover registry

#### PR #568 — Remove platformEventSubscribePermissions from permission sets
- Element not supported in API v52.0; supersedes #567

#### PR #567 — Correct permission set element ordering for platformEventSubscribePermissions
- Attempted ordering fix (superseded by #568)

### Docs

#### PR #569 — Update README, CHANGELOG, and API guides for enterprise readiness
- Updated README, CHANGELOG, PUBLIC_API_GUIDE, SYNC_API_GUIDE, and BOUNTY_API_GUIDE for PRs #549–#566

---

## 2026-04-05 / 2026-04-06

### Architecture

#### PR #549 — Bool field elimination
- Replaced all remaining Boolean/Checkbox custom fields with DateTime stamps across the entire schema (357 files touched)
- Zero Boolean custom fields remain in the codebase
- All Apex, LWC, metadata, and test references updated to use the `DateTime__c` pattern (null = off, non-null = on + when)
- Custom Metadata records updated from `true`/`false` to DateTime values

#### PR #551 — Document controller decomposition
- Decomposed monolithic `DeliveryDocumentController` into five focused services: `DocumentApprovalService`, `DocumentEmailService`, `DocumentGenerationService`, `DocumentPaymentService`, `DocumentQueryService`
- Controller now delegates to services; no behavioral change

#### PR #552 — Escalation service decomposition
- Split `DeliveryEscalationService` into `EscalationRuleEvaluator`, `EscalationActionExecutor`, `EscalationNotificationService`, and `EscalationContext`
- Each class has a single responsibility; no behavioral change

#### PR #554 — WorkItemQueryService extraction
- Extracted shared work item query logic into `WorkItemQueryService`
- Eliminates duplicated SOQL patterns across controllers

### Enterprise Security

#### PR #555 — Rate limiting + audit chain
- New `DeliveryRateLimitService`: opt-in per-entity request throttle for Public API and Sync API
- `PublicApiRateLimitNumber__c` (default 100 req/hr) and `SyncApiRateLimitNumber__c` (default 60 req/hr) on `DeliveryHubSettings__c`
- HTTP 429 response with `Retry-After: 3600` header when limit exceeded
- Disabled by default (null = unlimited)
- New `DeliveryAuditChainService`: SHA-256 hash chain on `ActivityLog__c` records
- Each record stores its hash and parent hash for tamper-evident audit trail
- `LegalHoldEnabledDateTime__c` on settings prevents deletion of chain records

#### PR #564 — Rate limit refinements
- Hardened rate limit enforcement edge cases and added test coverage

#### PR #560 — HMAC signing + data archival
- New `DeliveryCryptoService`: HMAC-SHA256 request signing for outbound sync payloads
- `HmacSecretTxt__c` on `NetworkEntity__c` holds the shared secret
- `X-Signature` header added to outbound callouts when secret is configured
- Receiving org validates signature against request body; backward compatible (no secret = no validation)
- New `DeliveryArchivalService`: automated archival of completed work items and related records
- `ArchivalRetentionDaysNumber__c` (default 365 days) controls retention period
- Archived records excluded from board queries and API responses

#### PR #559 — Approval workflows
- New `DeliveryApprovalChainService`: multi-step approval workflows for stage transitions
- Configurable approvers and approval order via Custom Metadata
- Approval events tracked with timestamps, approver identity, and comments
- Integrates with existing stage gate enforcement

### Enterprise Features

#### PR #557 — SLA business hours + notification preferences
- `DeliverySLAService` now supports business-hours calculations via `BusinessHoursId` on `SLARule__mdt`
- SLA clocks pause outside configured business hours, weekends, and holidays
- New `DeliveryNotificationPreferenceService`: per-event notification channel configuration
- Users configure email, platform event, both, or none per event type
- Preferences respected by escalation engine, digest service, and stage-change alerts

#### PR #556 — Team visibility
- New `DeliveryTeamPermissionService`: record-level board scoping by team membership
- Work items visible only to members of the assigned team (defined on `NetworkEntity__c`)
- Admins retain full visibility
- Opt-in via `TeamVisibilityEnabledDateTime__c` on `DeliveryHubSettings__c`

### Settings UI

#### PR #565 — Enterprise settings surface
- Admin settings page updated with new enterprise feature cards
- Rate limiting, audit chain, HMAC signing, team visibility, archival, and notification preferences all configurable from the Settings tab
- DateTime toggle pattern used consistently for all new feature flags

### Fixes

#### PR #553 — PMD cleanup (document classes)
- PMD compliance for decomposed document service classes

#### PR #558 — PMD cleanup (enterprise services)
- PMD compliance for enterprise security and feature classes

#### PR #561 — PMD cleanup (escalation classes)
- PMD compliance for decomposed escalation service classes

#### PR #562 — PMD cleanup (query service)
- PMD compliance for WorkItemQueryService

#### PR #563 — PMD cleanup (rate limit + crypto)
- PMD compliance for rate limit and crypto service classes

#### PR #566 — Gantt permissions fix
- Fixed Gantt chart permission checks for non-admin users

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

- New `DeliverySavedFilter__c` custom object with Private sharing model (LabelTxt__c, FilterJsonTxt__c, DefaultSetDateTime__c, WorkflowTypeTxt__c)
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
