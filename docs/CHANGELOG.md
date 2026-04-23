# Changelog

All notable changes to the Delivery Hub package are documented here. Versions match the CumulusCI unlocked package release number (e.g. `release/0.153.0.5`). PR numbers reference https://github.com/Nimba-Solutions/Delivery-Hub/pull/N.

---

## [0.99] — 2026-04-22

Release bundle targeting April invoicing + the two most active production paper cuts.

### Fixes

#### Invoice generator: Client picker on Generate Document form
- `deliveryDocumentViewer` LWC gains a required Client `lightning-combobox` between Template and Period Start. Drives a non-null `entityId` into `DeliveryDocGenerationService.generateDocument`, eliminating the "Please select a client before generating a document." throw when the viewer isn't already scoped to a NetworkEntity record page.
- New `DeliveryDocumentController.getAvailableClients()` → `DeliveryDocQueryService.getAvailableClients()` returns active NetworkEntity rows with `EntityTypePk__c IN ('Client','Both')`, ordered by Name, as `{label, value}` maps.
- Form prefills `genClientId` from the effective entity context when the viewer is embedded on a record page, so one-click invoice generation still works from a NetworkEntity.
- Tests in `DeliveryDocumentControllerTest`: filter contract (Vendor-only excluded, Inactive excluded) + alphabetical ordering.

#### WorkLog sync race condition: Pending queue replaces hard-throw
- `DeliverySyncItemIngestor` no longer throws `SyncException` when a WorkLog payload arrives before its parent WorkItem. Instead it inserts an inbound `SyncItem__c` with `StatusPk__c = 'Pending'`, stashes the raw payload + parent ref, and enqueues a resolver. This cleared the ~165-row stuck-WorkLog backlog on nimba.
- New `SyncItem__c.StatusPk__c` picklist value: `Pending`. New field `SyncItem__c.ParentRefTxt__c` (Text 255) carries the parent's remote identifier for the resolver to query on.
- New `DeliverySyncItemPendingResolver` Queueable: sweeps Pending rows scoped to one parent ref (inline path) or everything (scheduler path). Replays resolved payloads via the new `DeliverySyncItemIngestor.replayPendingPayload` entry point. Rows that can't resolve after `DEFAULT_MAX_RETRIES` (10) flip to `Failed` with a descriptive `ErrorLogTxt__c`.
- `DeliveryHubScheduler.requeuePendingItems()` added to the tick so the backlog self-heals every 15 minutes without manual intervention.
- Tests in new `DeliverySyncItemPendingResolverTest`: parent-arrives-late → Synced + record inserted, parent-never-arrives → Failed at ceiling, idempotent re-delivery, scheduler wiring.

#### Blank WorkItem creates rejected at the REST + sync ingestors
- Defense-in-depth after the cloudnimbus Slack approval handler incident (40 blank WorkItems created via empty `suggestedWorkRequest` POSTs). The client was patched; DH now enforces the rule server-side as the final arbiter.
- `DeliveryPublicApiService.postWorkItem`: HTTP 400 when both `title` and `description` are blank. Clear error message.
- `DeliverySyncItemIngestor.processInboundItem`: inbound WorkItem INSERT payloads without `BriefDescriptionTxt__c` and without `Name` throw `DeliverySyncEngine.SyncException`. Sparse UPDATE payloads (existing record, fewer fields) remain allowed — the guard is insert-only.
- Tests in `DeliveryPublicApiServiceTest` (omitted keys, empty-string values) and `DeliverySyncItemIngestorTest` (blank insert rejected, sparse update still works).

---

## [0.153.0] — 2026-04-07

### Security & Quality

#### PR #597 — Phase A P0 fixes + portal HIGH gaps
- **Clickjacking** — `Delivery_Hub.site-meta.xml` `AllowAllFraming` changed to `SameOriginOnly`
- **FLS leak** — removed `DocumentAction__c.SignerTokenTxt__c` from `DeliveryHubGuestUser` permission set (service layer still reads it via `SYSTEM_MODE`)
- **Hardcoded issuer branding** — document renderer now sources issuer name/url/address from the configured vendor `NetworkEntity__c` instead of the hardcoded Cloud Nimbus literal
- **Escalation test fixes (16)** — `DeliveryEscalationServiceTest` + `DeliveryEscalationJobTest` now set `ActivatedDateTime__c`/`StageEnteredDateTime__c` explicitly in `@TestSetup` to work around the namespaced-packaging trigger-mutation gotcha (same pattern as #595)
- **`loadPendingAction` race** — added `FOR UPDATE` so two concurrent signers cannot double-sign the same slot
- **classAccesses gap** — `DeliveryGanttController` and `DeliveryDocActionController` added to both `DeliveryHubAdmin_App` and `DeliveryHubApp` permission sets (both are `public`, not `global`, so they need explicit class access)
- **Canvas signature persistence in REST API** — `DeliveryDocActionRestApi` POST now reads `signatureType`/`signatureData`/`drawnSignature` from the body and routes canvas PNG bytes through the existing image-handling path instead of silently dropping them. Also picks up `X-Forwarded-For` for end-to-end client IP capture and `portalSessionEmail` for tamper-evident portal-session attribution.
- **`signingRequired`/`signingComplete`/`signingSlots` on `getDocumentByToken`** — new `buildSigningStatusBlock` helper in `DeliveryDocQueryService` returns signing slot metadata and a `hashChainVerified` flag. Automatically surfaced on `GET /api/documents/<token>`.

#### PR #596 — Revert all 8 Master-Detail field renames (unblock prod install)
- Reverted PR #590's Master-Detail renames. Salesforce does not permit Master-Detail field rename via package upgrade (the platform refuses to delete the old MD field while child records reference it and refuses to create the new MD field while the old one still exists).
- All 8 MD fields stay on the legacy `*Id__c` suffix forever: `BountyClaim__c.WorkItemId__c`, `DeliveryDocument__c.NetworkEntityId__c`, `DeliveryTransaction__c.DocumentId__c`, `DocumentAction__c.DocumentId__c`, `PortalAccess__c.NetworkEntityId__c`, `WorkItemComment__c.WorkItemId__c`, `WorkLog__c.RequestId__c`, `WorkRequest__c.WorkItemId__c`.
- `MasterDetailFieldNamingConvention` PMD rule disabled in `category/xml/default.xml`; `LookupFieldNamingConvention` still enforced.
- See [FIELD_NAMING.md](FIELD_NAMING.md) for the full exception rationale.

### Features — Document Actioning + Signatures

#### PR #593 — Phase 5: drawn signature pad (canvas)
- New `deliverySignaturePad` LWC — HTML5 canvas pad with mouse + touch + Apple Pencil support, ported from mobilization-funding repo with Flow code stripped
- DocuSign-parity drawn signatures: signer drags in the box, preview renders, signature persists as a ContentVersion attached to the `DocumentAction__c` row
- `DeliveryDocActionService` accepts `signatureType = 'Image'` with the base64 PNG in `drawnSignature`; normalizes legacy `Drawn` spelling to `Image`
- Public portal signing LWC wires the pad into the signing modal alongside the existing text-stamp mode

#### PR #592 — Phase 4: hash chain materialization + Certificate of Completion
- `DeliveryDocActionService.applySignatureToAction` now materializes the SHA-256 chain parent hash from the latest `ActivityLog__c.HashChainTxt__c` at sign time, stamping `DocumentAction__c.PriorHashTxt__c` for tamper evidence
- Re-queries `ActivityLog__c` after insert so the trigger-computed `PriorHashTxt__c` materializes (see #595 for the follow-up fix)
- `Certificate_Of_Completion` DocumentTemplate and `DeliveryDocCertificateService` — auto-generates an ESIGN/UETA-compliant audit certificate listing every signer, IP, user-agent, consent timestamp, and hash chain entry
- `scripts/backfill-document-hashes.apex` — one-shot script to populate hashes on pre-existing signed documents

#### PR #591 — Admin Copy Signer Link button + token rotation
- `deliveryDocumentViewer` admin view gains a "Copy Signer Link" button per signer slot — one click copies the public `/portal/documents/<token>` URL with the signer token pre-filled
- Tokens rotate to null on sign completion (defense in depth); non-null tokens indicate the slot is still pending
- Admins can force a token rotation to invalidate a previously-sent signer link
- See [DOCUMENT_ACTIONING_FEATURE.md](DOCUMENT_ACTIONING_FEATURE.md) for the full phase map

#### PR #590 — Enforce strict field naming convention across all custom fields
- **NOTE**: Fully reverted by PR #596 for the 8 Master-Detail fields. Lookup renames stayed.
- Original intent: rename 44 fields to enforce type-suffix conventions package-wide

#### PR #589 — Phase 3: public portal signing (Coleman demo)
- New `deliveryDocumentSignPortal` LWC — guest-context signing UX that loads a document by signer token, shows a consent checkbox, and writes a signature via the text-stamp mode
- `DeliveryDocActionRestApi` exposes `POST /services/apexrest/sign/<token>` for the portal LWC to post the signature (captures `X-Salesforce-SIP` / `X-Forwarded-For` IP and `User-Agent`)
- `DeliveryDocApprovalService` auto-transitions `Sent → Awaiting_Signatures` when the document is signed and signing is still incomplete
- `DeliveryHubGuestUser` permission set widened for the new flow (read on `DocumentAction__c` fields required by the portal, explicit class access for the REST resource)
- **Coleman demo is fully demoable at the end of this PR** — full lease-signing flow works end-to-end

#### PR #586 — Native multi-party document actioning + signatures (Phase 1 + 2)
- New `DocumentAction__c` object (master-detail child of `DeliveryDocument__c`) holds one record per signer slot with signer name/email, status, signature type, signature data, signer token, prior hash, IP address, user agent, and electronic consent timestamp
- New `DocumentTemplateSlot__mdt` CMT defines signer slots per template (4 records ship: Client_Agreement × Consultant/Client, Contractor_Agreement × Company/Contractor)
- New `DeliveryDocActionService` with `createSlotsForTemplate`, `signActionByToken`, `getDocumentBundleForSignerToken`, `templateRequiresSigning`, `formatTextSignatureStamp`, `generateSignerToken`
- New `DeliveryDocActionController` and `DeliveryDocActionControllerTest`
- New `deliveryDocumentSignatureBlock` child LWC shared by admin viewer and public portal
- New `DeliveryHubSettings__c.EnableAdminSigningDateTime__c` feature flag gates admin-side signing UI
- `DeliveryDocument__c` gains `DocumentHashTxt__c` and `RequiresSigningCheckbox__c`; `StatusPk__c` gains `Awaiting_Signatures` value
- `DocumentTemplate__mdt` gains `RequiresSigningCheckbox__c` and `ElectronicConsentTextTxt__c`
- `Client_Agreement` and `Contractor_Agreement` CMT records set to require signing
- Phase 1 (data model + slot creation) and Phase 2 (text-stamp admin signing) ship in this PR

### Features

#### PR #585 — Introduce Delivery Hub design system for hero components
- New `deliveryDesignTokens` static resource — CSS variables for color, spacing, typography, shadow
- `deliveryHubBoard`, `deliveryClientDashboard`, and `deliveryDocumentViewer` updated to consume design tokens
- Consistent look across hero components

#### PR #581 — Add CMT-driven Executive Dashboard framework
- New `DashboardCard__mdt` CMT defines card configuration (title, metric query, size, target app)
- New `DeliveryExecutiveDashboardController` resolves card metrics at runtime
- Admin-only `deliveryExecutiveDashboard` LWC placed on the admin home flexipage
- First-cut cards: active work items, hours this period, open invoices, rate-limit breaches

#### PR #580 — Add coverage for 11 untested service classes (91 methods)
- Closes the coverage gap on `DeliveryApprovalChainService`, `DeliveryArchivalService`, `DeliveryAuditChainService`, `DeliveryCryptoService`, `DeliveryNotificationPreferenceService`, `DeliveryRateLimitService`, `DeliverySLAService`, `DeliveryTeamPermissionService`, `DeliveryWorkItemQueryService`, and the decomposed document/escalation services

#### PR #579 — Operations workflow type (9 stages, 3 personas)
- New `Operations` workflow type via CMT: 9 stages (Backlog → Scheduled → In Progress → Waiting on Parts → Work Complete → Documentation → Quality Check → Signed Off → Closed) and 3 personas (Technician, Supervisor, Customer)

#### PR #578 — Change Management workflow type (12 stages, 3 personas)
- New `Change_Management` workflow type via CMT: 12 stages covering Request → Approve → Implement → Post-Implementation Review lifecycle; 3 personas (Requester, CAB, Implementer)

#### PR #577 — Wire Permission Analyzer to Security Report document generation
- `deliveryPermissionAnalyzer` LWC gains a "Generate Security Report" button
- Renders as a `Security_Audit` DocumentTemplate — PDF + email delivery via the Document Engine
- Executives get a plain-English permission audit without running SOQL

#### PR #576 — Expose Gantt/timeline fields in portal work-items API
- `GET /api/work-items` and `GET /api/work-items/{id}` now include `estimatedStartDate`, `estimatedEndDate`, `calculatedETADate`, and `stageEnteredDateTime`
- Portal Gantt at cloudnimbusllc.com/portal can render the Nimbus Gantt directly from the REST payload

### Fixes

#### PR #595 — Re-query ActivityLog after insert so PriorHashTxt__c materializes
- Trigger-computed `PriorHashTxt__c` was not visible to the same transaction without a re-query
- `DeliveryDocActionService.applySignatureToAction` now re-queries the inserted `ActivityLog__c` row before stamping the parent hash onto the `DocumentAction__c`

#### PR #594 — Unbreak beta_create: fix CustomSite Apex page reference
- `CustomSite` metadata was referencing a renamed Apex page using the `%%%NAMESPACED_ORG%%%` token, which does not resolve in subscriber orgs
- Swapped to `%%%NAMESPACE%%%` so the reference resolves correctly in both scratch and subscriber contexts
- Unblocks the `beta_create` job

#### PR #588 — Skip unsized work items in ETA simulation
- `DeliveryWorkItemETAService` was including work items with null `EstimatedHoursNumber__c` in the Monte Carlo ETA projection, producing NaN dates
- Now skipped with a debug log

#### PR #587 — Run scratch-org tests on all PRs, not just feature/* branches
- `.github/workflows/feature_test.yml` trigger changed from `branches: ['feature/**']` to `branches: ['**']`
- Closes the gap where PRs not prefixed with `feature/` were skipping the scratch-org feature-test job
- Deserves its own PR so every downstream PR gets real CI coverage

#### PR #584 — Resolve beta build #503 errors
- Triaged the beta build #503 failures: permission set XML ordering, CMT references to deleted fields, and a missing field path in `DeliveryRateLimitService`

#### PR #583 — Make DashboardCardController global for package visibility
- `@AuraEnabled` methods on a `public` controller are invisible to subscriber-org LWCs in an unlocked package — had to be `global`

#### PR #582 — Add Executive Dashboard to home page flexipage
- `deliveryExecutiveDashboard` LWC placed on the admin home flexipage region

### Chore

#### Debug-statement hygiene sweep
- Removed leftover `System.debug` / `console.log` dev tracing from `DeliveryContentDocLinkTriggerHandler`, `DeliveryWorkItemController`, and `deliveryHubBoard` ahead of the marketing push. Error-path logging retained.

---

## [0.152.0] — 2026-04-06

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

## [0.151.0] — 2026-04-05

### Architecture — Enterprise Readiness (Phases 0-8)

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

## [0.150.0] — 2026-03-24

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

## [0.149.0] — 2026-03-17

### PR #423 — Final PMD compliance

- Zero PMD violations across the entire codebase

### PR #422 — DashboardController PMD + record page guide

- DashboardController PMD compliance
- Record page assignment documentation
