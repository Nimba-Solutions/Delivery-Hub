# Delivery Hub — Page Layout / Field Audit (2026-05-13)

> **Status as of 2026-05-18: RESOLVED.** Headline findings closed by PR #776
> (0.238.0.1 / 0.239.0.1, merged 2026-05-13). Remaining ~55-min backlog closed
> by PR #786 (0.241.0.3, merged 2026-05-16) — 9 admin fields surfaced across
> SyncItem (2), NetworkEntity (5 incl. new Billing section), ActivityLog (1),
> PortalAccess (1). Hidden plumbing fields (HashChainTxt, AccessTokenTxt,
> HmacSecretTxt, UsageAnalyticsJsonTxt, ParentRefTxt) deferred per audit
> recommendation. File preserved as a record.

Scope: 11 user-facing custom objects in `force-app/main/default/objects/`. Method: parsed every `layout-meta.xml` and `flexipage-meta.xml` to extract field references, then diffed against the `fields/` directory. FlexiPage assignment confirmed via `force-app/main/default/applications/DeliveryHub.app-meta.xml` and `DeliveryHubAdmin.app-meta.xml`.

## Executive summary

- **WorkLog__c is a dynamic Lightning page.** Both DeliveryHub and DeliveryHubAdmin apps override the WorkLog `View` action to `DeliveryWorkLogRecordPage` for Large and Small form factors (`applications/DeliveryHub.app-meta.xml:123-138`, `DeliveryHubAdmin.app-meta.xml:123-138`). The FlexiPage uses Dynamic Forms (3 field sections — Time Entry, Description, System — via `flexipage:fieldSection` + `flexipage:column` facets). Not a classic-layout fallback.
- **WorkLog__c FlexiPage is missing 4 real user-relevant fields**: `ResourceTitleTxt__c`, `ApprovalRequestedDateTime__c`, `ApprovalStepNumber__c`, `ApprovedByTxt__c`. The first was shipped 2026-03-28 (PR #484 per `session-march28-state.md:13`) specifically so invoice PDFs could render a RESOURCE column — but it was never surfaced on the record page itself. The other 3 are dormant approval-workflow plumbing that `project_jose_hours_reporting_plan_0508.md:24-29` confirms is unpopulated today (StatusPk__c all NULL on MF-Prod). Both layouts also omit them — gap is on both surfaces, not drift.
- **WorkItemDependency__c has NO FlexiPage at all.** Only object in scope without one (`force-app/main/default/flexipages/` has no DeliveryWorkItemDependencyRecordPage). No override in either app metadata file. Users land on the classic Lightning fallback page. Low-impact since dependency records are typically created via the Gantt UI, not browsed individually, but inconsistent with the rest of the package.
- **Two real layout-vs-FlexiPage drifts**: (a) `WorkItem__c` FlexiPage omits 10 fields that the classic layout includes — Recurrence* cluster, Template* cluster, External* cluster, EventReceivedOnDateTime__c, SourceEventReplayIdTxt__c. Several of these (Recurrence config, Template marking) are user-editable features that admins can no longer reach from the record page in Lightning. (b) `DeliveryTransaction__c` FlexiPage surfaces `MethodPk__c` but the classic layout doesn't — minor reverse drift.
- **Highest-impact non-WorkLog finding: DeliveryDocument__c** is missing 10 fields from both layout and FlexiPage including the entire dunning cluster (`OverdueReminderCountNumber__c`, `OverdueReminderLevelPk__c`, `LastOverdueReminderDateTime__c`), the entire scheduled-send cluster (`ScheduledSendDateTime__c`, `ScheduledRecipientEmailTxt__c`), `DisputeReasonTxt__c`, `RequireSigningDateTime__c`, and `VersionNumber__c`. These are operator-relevant fields supporting features that are shipped in code but invisible in the record UI.

## Past recommendations from memory

I searched 184 files in `C:\Users\globa\.claude\projects\C--Projects-Delivery-Hub\memory\` for "layout", "FlexiPage", "WorkLog", "Glen recommend", "Glen ask", "Glen want", and the specific orphaned field names. **No memory file contains an explicit Glen-authored page-layout recommendation for WorkLog__c.** What I did find that's adjacent:

- `session-march28-state.md:13,24-26,31-32` (46 days old) — PR #484 added `WorkLog__c.ResourceTitleTxt__c` (Text 255) + `DeliveryHubSettings__c.EnableResourceTitleAutoFillDateTime__c`. The use case was "RESOURCE column in time log detail" for invoice rendering, not for the WorkLog record page. So while the field itself was Glen's request, surfacing it on the page was never explicitly logged. **Not implemented on the page.** Likely the source of Glen's "I recommended fields a few months ago" recollection — it was implemented as data/invoice-render only.
- `project_jose_hours_reporting_plan_0508.md:24-29` (4 days old) — flags that `WorkLog__c.StatusPk__c` is a 4-value picklist (Draft/Pending_Approval/Approved/Rejected) but all 52 MF-Prod WLs this month have `StatusPk__c = NULL`. The approval workflow is wired but inert. Approval-* fields are page-invisible AND data-empty — congruent.
- `project_activity_feed_polish_handoff.md` — no WorkLog-page mention.
- `glen-action-items.md` (40 days old) — top-priority list as of 2026-04-02 contains zero page-layout items.

**Conclusion on the "recommendations from a few months ago" thread**: the most likely artifact is the March 28 ResourceTitleTxt__c work, where the field was shipped for invoice rendering but never added to the WorkLog record page. Glen's memory is probably correct that he asked for it; the implementation choice (data-only) is the gap.

## Per-object findings

### WorkLog__c (Glen's headline)

**Fields (10)** — all user-relevant; no sync-engine plumbing on this object. `Name` + `WorkItemLookup__c` (Lookup, required) + `WorkDateDate__c` (Date) + `HoursLoggedNumber__c` (Number) + `WorkDescriptionTxt__c` (Text) + `StatusPk__c` (Picklist) + `RequestId__c` + `ResourceTitleTxt__c` (Text 255) + `ApprovalRequestedDateTime__c` + `ApprovalStepNumber__c` (Number) + `ApprovedByTxt__c` (LongTextArea, JSON of approver IDs).

**Classic layout** `layouts/WorkLog__c-Work Log Layout.layout-meta.xml`:
- "Information" section (`:3-41`): Name, WorkItemLookup__c, WorkDateDate__c, HoursLoggedNumber__c, WorkDescriptionTxt__c, RequestId__c, StatusPk__c. 7 fields.
- "System Information" section (`:42-60`): CreatedById, LastModifiedById.
- Custom Links section (empty, `:61-69`).
- No layoutItem references a missing field.

**FlexiPage** `flexipages/DeliveryWorkLogRecordPage.flexipage-meta.xml`:
- Template `flexipage:recordHomeTemplateDesktop` (`:378-380`), type `RecordPage` (`:381`).
- 3 Dynamic Forms field sections in `detailTabContent` (`:229-287`):
  - "Time Entry" 2-column: Name (readonly), WorkItemLookup__c, WorkDateDate__c | StatusPk__c, HoursLoggedNumber__c, RequestId__c — `:41-108`
  - "Description" 1-column: WorkDescriptionTxt__c — `:111-124`
  - "System" 2-column: CreatedById | LastModifiedById — `:127-156`
- Related Lists tab + tab set otherwise standard.

**FlexiPage assignment**: `applications/DeliveryHub.app-meta.xml:123-138` (Large + Small) and `applications/DeliveryHubAdmin.app-meta.xml:123-138`. **The FlexiPage IS active.**

**Gaps** (fields existing but NOT on either layout OR FlexiPage):
- `ResourceTitleTxt__c` — Text 255, "Your role for this time entry (e.g. 'Sr SFDC Developer'). Auto-filled from your user profile." Shipped 2026-03-28 for invoice rendering, never added to the page.
- `ApprovalRequestedDateTime__c` — "When the approval request was submitted."
- `ApprovalStepNumber__c` — "Which approval step this work log is currently at (1-based)."
- `ApprovedByTxt__c` — LongTextArea, "JSON list of approver IDs."

No layout-vs-FlexiPage drift; the two surfaces agree on what they show (and on what they hide).

**Recommendation**: Add `ResourceTitleTxt__c` to the Time Entry section, second column, between StatusPk__c and HoursLoggedNumber__c — it's auto-populated and editable, exactly the kind of field a logger should be able to confirm at submit time. Defer the 3 approval-* fields until the approval workflow is actually live (`project_jose_hours_reporting_plan_0508.md` Decision D2 outstanding) — surfacing dormant fields creates UX confusion. When approval ships, group those 3 in a new collapsed "Approval" section. Classic layout should be updated in parallel since the package still ships it even if the FlexiPage is the active path, otherwise any subscriber that re-points to the classic layout would lose ResourceTitle.

### WorkItem__c (reference benchmark)

**Fields**: 61. Most complete page in the package.

**Classic layout** (`WorkItem__c-Work Item Layout.layout-meta.xml`): 41 custom fields + Name/Owner/CreatedBy/LastModifiedBy.

**FlexiPage** (`DeliveryWorkItemRecordPage.flexipage-meta.xml`): 32 custom fields. Active per `applications/DeliveryHub.app-meta.xml:57-74`.

**Gaps — fields on classic NOT on FlexiPage** (real drift, users on Lightning don't see these):
- `EventReceivedOnDateTime__c`, `SourceEventReplayIdTxt__c` — sync-context, OK to omit.
- `ExternalRequesterEmail__c`, `ExternalSourceOrgTxt__c` — useful for external-sourced WIs.
- `RecurringEnabledDateTime__c`, `RecurrenceDayTxt__c`, `RecurrenceScheduleTxt__c`, `NextRecurrenceDate__c` — entire recurrence cluster. This is a user-visible feature that admins can no longer configure from the record page.
- `TemplateMarkedDateTime__c`, `TemplateSourceLookup__c` — template marking, user-facing.

**Gaps — fields NOT on either** (excluding pure sync/audit plumbing):
- Bounty cluster (8 fields: BountyAmountCurrency__c, BountyDeadlineDate__c, BountyDifficultyPk__c, BountyEnabledDateTime__c, BountyMaxClaimsNumber__c, BountySkillsTxt__c, BountyStatusPk__c, BountyTokenTxt__c) — bounty marketplace plan (`bounty-marketplace-plan.md`). Hidden on the WI record page is defensible if bounty is gated behind a separate UI; if not, this is a feature-not-visible gap.
- Forecast cluster (`LastForecastAlertDateTime__c`, `LastForecastAlertProjectedHoursNumber__c`) — just shipped per PR #773 (commit `a2b6e242`). Defensible as alert-internal state.
- `MarkedPredecisionalDateTime__c` — predecisional gate (PR #747). Operator-relevant on Nimba; defensible to hide elsewhere.
- `LastEscalatedDateTime__c`, `SLAPausedDateTime__c`, `SLAAccruedPauseDaysNumber__c` — SLA cluster; should be visible to operators tracking SLA.
- `PriorityGroupPk__c` — picklist, user-facing.
- `ArchivalStatusPk__c`, `ArchivedDateTime__c`, `RetentionExpiresDate__c` — retention/archival cluster; admin-facing.
- `AdditionalParentIdsTxt__c` — DAG parenting; visible elsewhere via Gantt.
- `TeamTxt__c` — team label, definitely user-facing.

**FlexiPage adds 1 field classic doesn't have**: `BillableRateCurrency__c`. Small reverse drift; defensible.

**Recommendation**: Add recurrence + template clusters to FlexiPage (closes the classic→FlexiPage drift Glen is most likely to notice next). Add PriorityGroupPk__c and TeamTxt__c — both are user-facing picklist/text. Surface SLA cluster in a collapsed section so SLA operators can see it. Bounty cluster can stay hidden until bounty UI is live.

### WorkRequest__c

**Fields**: 13. **Classic** has 12 custom fields. **FlexiPage** has 12 custom fields. Active per `applications/DeliveryHub.app-meta.xml:21-38`.

**Gaps**: None on either. The two surfaces agree.

**Recommendation**: Good as-is. No action.

### WorkItemComment__c

**Fields**: 5 (all user-relevant). Both surfaces cover all 5. FlexiPage omits CreatedById/LastModifiedById (visible in highlights panel anyway). Active per `applications/DeliveryHub.app-meta.xml:39-56`.

**Recommendation**: Good as-is.

### WorkItemDependency__c

**Fields**: 4 (BlockedWorkItemLookup__c, BlockingWorkItemLookup__c, ExternalIdTxt__c, TypePk__c). Classic layout covers all 4.

**No FlexiPage exists.** No override in either app metadata.

**Recommendation**: Decide: either (a) accept the classic-layout fallback as fine (this object is rarely browsed directly — dependencies are created/edited from the Gantt) and document the choice, or (b) ship a minimal `DeliveryWorkItemDependencyRecordPage.flexipage-meta.xml` for consistency, ~20 min of work. Lean (a) unless Glen wants strict consistency.

### ActivityLog__c

**Fields**: 10. Active FlexiPage per `applications/DeliveryHub.app-meta.xml:107-122`.

**Gaps — not on either layout or FlexiPage**:
- `HashChainTxt__c` — defensible to hide, forensic hash.
- `LegalHoldDateTime__c` — operator-relevant if legal hold is a workflow.

**Recommendation**: Add `LegalHoldDateTime__c` to FlexiPage so admins can see hold state on a record. Keep `HashChainTxt__c` hidden.

### DeliveryDocument__c — second-biggest gap after WorkLog

**Fields**: 26. Active FlexiPage per `applications/DeliveryHub.app-meta.xml:91-106`. Classic layout has 17 custom fields; FlexiPage has 18.

**Gaps — fields not on either surface** (excluding `WorkItemLookup__c` which is on FlexiPage):
- `DisputeReasonTxt__c` (LongTextArea) — user-facing.
- `DocumentHashTxt__c` — defensible to hide.
- `LastOverdueReminderDateTime__c` (DateTime), `OverdueReminderCountNumber__c` (Number), `OverdueReminderLevelPk__c` (Picklist) — dunning. Admin-relevant.
- `PreviousVersionLookup__c` (Lookup), `VersionNumber__c` (Number) — versioning, user-facing.
- `RequireSigningDateTime__c` (DateTime) — signing gate, user-facing.
- `ScheduledRecipientEmailTxt__c`, `ScheduledSendDateTime__c` — scheduled-send cluster, admin-facing.

Plus a small drift: FlexiPage includes `WorkItemLookup__c` (`flexipages/DeliveryDocumentRecordPage.flexipage-meta.xml` field) but classic layout does NOT.

**Recommendation**: Add a "Dunning & Scheduling" FlexiPage section grouping the 5 dunning + 2 scheduled-send fields, and a "Signing & Versioning" section for RequireSigningDateTime__c + VersionNumber__c + PreviousVersionLookup__c + DisputeReasonTxt__c. This is shipped feature-set invisible on the page — concrete user-impact fix.

### DeliveryTransaction__c

**Fields**: 6. Classic has 5 + Name + audit; FlexiPage has 6 + Name + audit. Drift: `MethodPk__c` is on FlexiPage but not classic layout. Active per `applications/DeliveryHub.app-meta.xml:139-154`.

**Recommendation**: Add `MethodPk__c` to classic layout for parity. ~1-line metadata change.

### NetworkEntity__c

**Fields**: 22. Classic has 17 custom; FlexiPage has 15 custom. Active per `applications/DeliveryHub.app-meta.xml:3-20`.

**Gaps — not on either surface**:
- `BillingFrequencyPk__c` — user-facing picklist.
- `EnableBillingDateTime__c` — feature toggle.
- `HmacSecretTxt__c` — defensible to hide (secret).
- `JurisdictionTxt__c` — user-facing.
- `LastOutboundSyncDateTime__c` — admin-relevant (classic has LastInboundSyncDateTime__c but not the outbound twin).
- `RevealFulfillmentDepthPk__c` — depth-charge config, admin-facing.
- `UsageAnalyticsJsonTxt__c` — defensible to hide.

**Recommendation**: Add BillingFrequencyPk__c + JurisdictionTxt__c + LastOutboundSyncDateTime__c + RevealFulfillmentDepthPk__c + EnableBillingDateTime__c to FlexiPage. ApiKeyTxt__c is on the layouts — surprising given it's secret-ish; consider gating behind a permission set or removing.

### PortalAccess__c

**Fields**: 5. Classic has 3 custom; FlexiPage has 3 custom. Active per `applications/DeliveryHub.app-meta.xml:155-170`.

**Gaps**: `AccessTokenTxt__c` (sensitive, defensible) + `PermissionsTxt__c` (user-relevant — what can this portal user do?).

**Recommendation**: Add `PermissionsTxt__c` to FlexiPage. Keep AccessTokenTxt__c hidden.

### SyncItem__c

**Fields**: 17. Classic has 14 custom; FlexiPage has 14 custom. Active per `applications/DeliveryHub.app-meta.xml:75-90`.

**Gaps**: `ChangeTypeTxt__c` (user-facing), `DismissedDateTime__c` (operator-relevant — was this Failed SyncItem dismissed?), `ParentRefTxt__c` (defensible to hide).

**Recommendation**: Add `ChangeTypeTxt__c` and `DismissedDateTime__c` to FlexiPage — operators need both to triage stuck rows.

## Cross-cutting patterns

- **Classic→FlexiPage migration is uneven.** WorkItem__c and DeliveryDocument__c both have FlexiPages that omit fields the classic layout includes. Users on Lightning (the default — every override is registered) lose access to those fields. Pattern: when a new field was added in the past few months and added to the classic layout, the FlexiPage was not always updated in lockstep.
- **No "Dynamic Forms" pattern in 9 of 10 FlexiPages.** Only WorkLog__c uses `flexipage:fieldSection` + `flexipage:column` facets for Dynamic Forms. The other FlexiPages use `flexipage:fieldGroup`-style flat layouts (per spot-check of WorkItem, Document, Network, etc.). Glen's WorkLog complaint is interesting because WorkLog is actually the MOST advanced page in the package structurally — the gap is content, not template.
- **FlexiPage assignment is consistent.** Every FlexiPage that exists is assigned via both `DeliveryHub.app-meta.xml` and `DeliveryHubAdmin.app-meta.xml` for Large+Small form factors. There is no "FlexiPage exists in metadata but isn't actually surfaced" gotcha in this package, with one exception: `WorkItemDependency__c` has no FlexiPage at all and falls through to the SF default Lightning record page.
- **Fields added for one purpose, never surfaced on the page.** `WorkLog__c.ResourceTitleTxt__c` (added for invoice PDF), `WorkItem__c.LastForecastAlertProjectedHoursNumber__c` (added for forecast alert state), `DeliveryDocument__c.OverdueReminder*` cluster (added for the dunning system). Each of these "ship the data, skip the page" choices accumulates as Glen's "missing fields" complaint pile.

## Recommended action items (prioritized)

1. **(30 min) Fix WorkLog__c FlexiPage — Glen's headline complaint.** Add `ResourceTitleTxt__c` to the "Time Entry" right column in `flexipages/DeliveryWorkLogRecordPage.flexipage-meta.xml`. Mirror in `layouts/WorkLog__c-Work Log Layout.layout-meta.xml`. Defer the 3 approval-* fields until the approval workflow is actually populated (Decision D2 in `project_jose_hours_reporting_plan_0508.md`).
2. **(1-2h) Fix DeliveryDocument__c — biggest functional gap.** Add Dunning section (3 OverdueReminder* fields), Scheduled Send section (2 fields), Signing & Versioning section (RequireSigningDateTime__c + VersionNumber__c + PreviousVersionLookup__c + DisputeReasonTxt__c) to `flexipages/DeliveryDocumentRecordPage.flexipage-meta.xml`. Mirror on classic layout.
3. **(1h) Close WorkItem__c classic→FlexiPage drift.** Add Recurrence cluster (4 fields) + Template cluster (2 fields) + External cluster (2 fields) to `flexipages/DeliveryWorkItemRecordPage.flexipage-meta.xml`. Optionally add PriorityGroupPk__c + TeamTxt__c + SLA-paused fields. Defer Bounty cluster until bounty UI is live.
4. **(30 min) NetworkEntity__c hygiene.** Add BillingFrequencyPk__c, JurisdictionTxt__c, LastOutboundSyncDateTime__c, RevealFulfillmentDepthPk__c, EnableBillingDateTime__c to FlexiPage. Consider moving ApiKeyTxt__c behind a permission set.
5. **(15 min) SyncItem__c operator fields.** Add ChangeTypeTxt__c + DismissedDateTime__c to `flexipages/DeliverySyncItemRecordPage.flexipage-meta.xml`.
6. **(15 min) PortalAccess__c.** Add PermissionsTxt__c to FlexiPage.
7. **(15 min) ActivityLog__c.** Add LegalHoldDateTime__c to FlexiPage.
8. **(10 min) DeliveryTransaction__c parity.** Add MethodPk__c to classic layout.
9. **(Decision) WorkItemDependency__c.** Either ship a minimal FlexiPage for consistency (~20 min) or document the classic-fallback as intentional. Recommend the latter — dependencies are typically managed from the Gantt, not browsed.
10. **(Process — biggest leverage)** When a field is added to an object, the PR that adds it should also update the FlexiPage and classic layout in the same commit. The package CI has nothing checking this today. ResourceTitleTxt__c (3/28) and the OverdueReminder cluster are examples of the failure mode. A 30-line bash check in CI that lints "any field added in PR diff must appear in the matching layout or flexipage, or be in an allow-list of sync/audit plumbing" would prevent the next iteration of this audit.
