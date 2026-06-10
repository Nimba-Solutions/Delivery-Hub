# Documentation Gap Audit — 2026-05-26 (Differential)

> Five-day follow-up to `documentation-gap-audit-2026-05-21.md`. Same scope (architecture / design docs / inline docstrings / object descriptions / REST endpoint docs / Custom Setting flag help). README + setup + REST API guide are owned by a parallel agent and explicitly out of scope here.

## Headline

Inline documentation coverage on **Apex services, REST endpoints, LWCs, Custom Objects, Custom Setting fields** is at or near 100%. The remaining gaps are concentrated on:
- **7 `__mdt` types** ship without object-level `<description>` (admin-readable in Setup → Custom Metadata).
- **23 of 80 LWCs** still lack a top-of-file `@description` ApexDoc block.
- **No design-principles document** existed (`docs/DESIGN_PRINCIPLES.md`).
- **No contributor guide** existed (`docs/CONTRIBUTING.md`).
- **No flow-reference document** existed; the only end-to-end flow narrative lived in `docs/audits/e2e-walkthrough-2026-05-21.md` (an audit, not a guide).

This PR closes the three missing top-priority architecture docs and registers the inline-doc gaps for future cleanup.

---

## Differential from 2026-05-21

### Closed since 2026-05-21

| Audit row | Closed by | Notes |
|---|---|---|
| §1 README still pinned at 0.239 | parallel README-refresh agent | Out of scope here; flagged for the parallel agent. |
| §2 `Feature__c` / `FeatureDependency__c` / `WatcherDigest__c` / `FeatureToggleRequest__c` / `FeatureToggleApproval__c` / `OnboardingProgress__c` / `ScratchOrgInstance__c` / `DatasetTemplate__c` / `DatasetTemplateAssignment__c` object-level `<description>` | PRs #793 / #794 / #796 / #799 / #802 / #803 / #804 / #807 | All 9 new `__c` objects now ship with multi-sentence `<description>` in their `.object-meta.xml`. Verified in this scan. |
| §3 4 new REST routes "no docs" | PRs #802 / #804 (inline ApexDoc above each route method) | `postFeatureToggle` / `postFeatureApprovalDecision` / `postScratchOrg` / `patchScratchOrg` all carry `@description` blocks with body shape + verb + status codes. Public-facing guide (`docs/PUBLIC_API_GUIDE.md`) refresh is owned by the parallel REST-API-doc agent. |
| §4 `load_feature_data` CCI task missing description | PR #803 | `cumulusci.yml:104` ships a one-line description plus a pointer to `scripts/feature-data/`. `scripts/feature-data/README.md` exists. |
| §6 No upgrade guide for 0.243–0.247 release notes | Out of scope | Parallel README-refresh agent owns CHANGELOG roll-up. |
| §7 No architecture diagrams | Partially closed by this PR | `docs/FLOW_REFERENCE.md` introduces ASCII flow tables for every flow + the cross-flow notification matrix. Mermaid render is a follow-on. |

### Still open

| Gap | Severity | Owner |
|---|---|---|
| **7 `__mdt` types missing `<description>`** (see §3) | Medium | This PR flags; metadata-only fix queued. |
| **23 of 80 LWCs missing top-of-file `@description`** (see §4) | Low | This PR flags; pattern is established (57 of 80 already comply). |
| **No `docs/DESIGN_PRINCIPLES.md`** (codifies the 8 patterns that recur across every PR) | High | **CLOSED by this PR.** |
| **No `docs/CONTRIBUTING.md`** (CLAUDE.md is internal-tooling-flavoured, not a contributor guide) | High | **CLOSED by this PR.** |
| **No `docs/FLOW_REFERENCE.md`** (`e2e-walkthrough` is point-in-time audit, not living doc) | High | **CLOSED by this PR.** |
| **No Mermaid diagrams** for Feature state machine / Watcher signal flow / Onboarding track content | Medium | Deferred — ASCII tables in `docs/FLOW_REFERENCE.md` close the readability gap. |
| **No public `docs/REST_API_GUIDE.md` refresh** for the 4 new cockpit routes | High | Parallel REST-API-doc agent. |

### Newly surfaced

None. The post-5/21 ship cycle (#812 - #821) was code only, no new sObjects or REST routes that could create new doc-surface gaps. PR #822 (in-app notifications) is in flight on a feature branch but not merged to main; its docs land when the PR lands.

---

## 1. Apex Service Class Headers — PASS

All 56 `*Service.cls` files under `force-app/main/default/classes/` start with a `/**` ApexDoc block. Sample sweep on 8 of the highest-leverage services (`DeliveryFeatureApprovalService`, `DeliveryWatcherService`, `DeliveryOnboardingService`, `DeliveryPublicApiService`, `DeliveryRateLimitService`, `DeliveryFeatureSyncService`, `DeliveryFeatureGraphService`, `DeliveryUserAutoAssignService`) confirmed:

- Purpose stated (1-3 sentences)
- Layer in the cockpit architecture noted where relevant
- Sharing model implicit in the class declaration (`global with sharing` / `public without sharing`)
- Side effects called out (audit-log rows, settings mirror, Slack post, etc.)
- Re-entry / recursion guards documented inline

**No service-class header gaps surfaced.**

## 2. REST Endpoints — PASS

Surveyed: `DeliveryPublicApiService`, `DeliveryBountyApiService`, `DeliveryDocActionRestApi`, `DeliveryFileBytesResource`, `DeliveryTaskAPI`, `DeliveryWebhookReceiverApi`, `DeliveryPublicSubmissionService`, `DeliveryHubSyncService`, `DeliveryGanttRemoteController`.

All `@HttpGet / @HttpPost / @HttpPatch / @HttpPut / @HttpDelete` methods carry an ApexDoc block describing:

- URL pattern
- Method + body shape (where applicable)
- Auth requirement
- Return shape / status codes

`DeliveryPublicApiService` uses single `@HttpGet` / `@HttpPost` / `@HttpPatch` entry points that route internally; per-resource methods (`postFeatureToggle`, `postFeatureApprovalDecision`, `postScratchOrg`, `patchScratchOrg`, `getFeatureToggleRequests`) all carry per-route ApexDoc.

**No endpoint-level inline-doc gaps surfaced.** The public-facing `docs/PUBLIC_API_GUIDE.md` refresh is owned by a parallel agent.

## 3. Custom Metadata Type Object Descriptions — 7 GAPS

The following `__mdt` objects ship a `<label>` + `<pluralLabel>` but no `<description>`. Setup → Custom Metadata Types displays a blank description column for these, which means admins clicking through have no context for what the type is for.

| `__mdt` | Status | Recommendation |
|---|---|---|
| `DashboardCard__mdt` | Missing | "Executive Dashboard card configuration (CMT-driven). One record per displayed card. Click-drill + info-popover supported." |
| `DevLoopGuide__mdt` | Missing | "Per-feature dev-loop guide content. Surfaced by `deliveryDevLoopGuide` LWC on `ScratchOrgInstance__c` record pages. Markdown-friendly." |
| `FeatureDefinition__mdt` | Missing | "Package-shipped registry of subscribable Delivery Hub features. Joined to per-tenant `Feature__c` at runtime by `DeliveryFeatureCatalogController`." |
| `OnboardingChecklistItem__mdt` | Missing | "One row per gated checklist item inside an `OnboardingTrack__mdt`. Verification methods: Manual (PR 3) / SoqlQuery / RestCall / WebhookReceived (PR 4 stubs)." |
| `OnboardingLesson__mdt` | Missing | "Lesson card content inside an `OnboardingTrack__mdt`. Markdown body + completion stamp on `OnboardingProgress__c`." |
| `OnboardingQuiz__mdt` | Missing | "Multiple-choice quiz block inside an `OnboardingTrack__mdt`. `AllowRetryDateTime__c` populated = retries allowed (read by `deliveryFeatureOnboarding.js`)." |
| `OnboardingTrack__mdt` | Missing | "Top-level onboarding track. Linked to a `FeatureDefinition__mdt` to enforce the gated-toggle pattern (non-admin must complete the track before flipping the feature)." |

All seven are Public-visibility `__mdt`. The fix is pure metadata (one `<description>` insert per file). Bundle into a 30-min PR — not in scope for this audit PR.

## 4. LWC Top-of-File `@description` — 23 GAPS (of 80)

The 23 LWCs below are missing a top-of-file `/** @description ... */` ApexDoc block. The 57 that comply use the canonical four-line shape (`@name` / `@license` / `@description` / `@author`).

Older / less-recently-touched LWCs are over-represented in the gap list. New LWCs since PR #793 all comply.

```
deliveryActivityDashboard       deliveryGuide
deliveryAiDraftPanel            deliveryHoursPills
deliveryAiSettingsCard          deliveryHubBoard
deliveryAuditChainViewer        deliveryHubSetup
deliveryBudgetSummary           deliveryHubWorkspace
deliveryBurndownChart           deliveryKanbanOpenAiSettings
deliveryClientDashboard         deliveryKanbanSettingsContainer
deliveryExecutiveDashboard      deliveryManageRequest
deliveryGeneralSettingsCard     deliveryOpenAiSettingsCard
deliveryGhostRecorder           deliveryPermissionAnalyzer
                                deliveryProjectBurnUpChart
                                deliveryProjectMonthlyHours
                                deliverySettingsContainer
```

`deliveryHubSetup` is the most user-facing miss — it's the admin entry point for `DeliveryHubSettings__c`. Worth prioritising.

Recommended fix: one PR that drops the canonical 4-line block onto each of the 23 (~30 min metadata-only).

## 5. Custom Object Descriptions — PASS

Verified: all 25 `__c` objects under `force-app/main/default/objects/*__c/` carry `<description>` blocks. The 9 new cockpit objects (`Feature__c`, `FeatureDependency__c`, `FeatureToggleRequest__c`, `FeatureToggleApproval__c`, `OnboardingProgress__c`, `ScratchOrgInstance__c`, `DatasetTemplate__c`, `DatasetTemplateAssignment__c`, `WatcherDigest__c`) all ship multi-sentence descriptions with layer-of-architecture notes.

**No gaps.**

## 6. DeliveryHubSettings__c Fields — PASS

All 66 fields under `force-app/main/default/objects/DeliveryHubSettings__c/fields/` carry at least one of `<description>` / `<inlineHelpText>`. 14 new Watcher fields shipped in PR #807 all comply. **No gaps.**

## 7. Architecture Bundle Status — CLOSED

The three "missing architecture-level docs" the 5/21 audit recommended now exist:

| Doc | Path | Status |
|---|---|---|
| Design principles | `docs/DESIGN_PRINCIPLES.md` | **NEW in this PR** |
| Contributor guide | `docs/CONTRIBUTING.md` | **NEW in this PR** |
| End-to-end flow reference | `docs/FLOW_REFERENCE.md` | **NEW in this PR** |

`docs/ARCHITECTURE.md` (object model + Apex layers) already existed and is current.

---

## Top-3 still-open gaps

1. **7 `__mdt` types missing `<description>`** — high admin-confusion potential; the cockpit and onboarding admin journey both pass through Setup → Custom Metadata Types. Bundle as a single 30-min metadata PR.
2. **23 LWCs missing top-of-file `@description`** — established convention (57 of 80 comply); cleanup is mechanical. The `deliveryHubSetup` LWC is the highest-priority miss because it's the admin entry point for `DeliveryHubSettings__c`.
3. **No public `docs/REST_API_GUIDE.md` refresh** for the four new cockpit REST routes — inline ApexDoc is complete, but external-facing guide lags. Parallel REST-API-doc agent owns.

---

## Verdict

What ships now is **functionally documented at the implementation layer** (ApexDoc, object descriptions, field help text) and now also **conceptually documented at the architecture layer** (`docs/DESIGN_PRINCIPLES.md` + `docs/CONTRIBUTING.md` + `docs/FLOW_REFERENCE.md`). The remaining gaps are cleanup-class items (Mermaid diagrams, `__mdt` descriptions, 23 LWC headers) that don't block subscriber adoption.

**Recommendation:** ship the three architecture docs in this PR. Bundle the `__mdt` description + LWC `@description` cleanups into a single follow-on metadata-only PR (~45 min total).
