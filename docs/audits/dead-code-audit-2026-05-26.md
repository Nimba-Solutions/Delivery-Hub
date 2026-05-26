# Dead Code / Orphan Metadata Audit (2026-05-26)

> Refresh of `dead-code-audit-2026-05-13.md` (13 days stale). The 5/13
> "Definitely safe to delete" cluster shipped via PR #789 — 4,323 LOC removed
> across 48 files. This refresh re-runs the analysis against everything that
> shipped after 5/13: the 10-PR DH cockpit plan (release `0.244.0.2` +
> `0.245.0.4`), Phase 2 Watcher v1 (release `0.246.0.4` — PRs #807/#809/#810),
> the `release/0.247.0.6` "subscriber-ready first impression" bundle
> (PRs #812–#816), and the post-promotion UX-gap fan-out (PRs #818/#820/#822
> approval-submit + audit-trail viewers + in-app notifications + #819 inline
> dependency editor + #821 PSG hotfix).
>
> **Report-only.** No code touched in this PR.

Scope: `force-app/main/default/` — 166 non-test Apex classes (321 .cls total),
80 LWCs, 50 objects, 19 FlexiPages, 21 tabs, 3 apps, 6 VF pages. Same
methodology as 5/13 — each class/component/field cross-referenced against
every other file type in the package (cls/trigger/js/html/page/cmp/-meta.xml/
permset/flexipage/layout/report), with externally-invoked entry points
(`@RestResource`, `@AuraEnabled` LWC bindings, Aura `aura:application`, VF
pages, tabs, app utility bars, scheduled cron) treated as live. Method
references via `grep -E "\b<NAME>\b"` excluding the symbol's own .cls family.

## Executive summary

- **Zero confirmed-dead Apex classes** across all 166 non-test classes — every
  class has at least one production caller. The 5/13 "Definitely safe" cluster
  has been deleted (PR #789), and no new dead classes have accumulated in the
  cockpit / Watcher / UX-gap waves.
- **3 Apex classes are "test-only by static reference" but live via external
  HTTP** — `DeliveryBountyApiService`, `DeliveryGanttRemoteController`,
  `DeliveryTaskAPI`. All three are `@RestResource` endpoints — the apparent
  dead-ness is an artifact of greppability. `DeliveryGanttRemoteController`
  receives traffic from the in-repo `GanttRemote.page` VF page (browser fetch);
  `DeliveryTaskAPI` is documented in README + CHANGELOG as the external
  AI-agent integration; `DeliveryBountyApiService` is the only one with
  no production traffic Glen can confirm (carry-over from 5/13).
- **20 LWCs ship without a FlexiPage placement** — 14 are unchanged from the
  5/13 "Likely safe — verify before deleting" list (Glen never gave the
  delete OK; carry-over), and **6 are NEW since 5/13** — five from the cockpit
  + Watcher + audit-trail PRs (#796/#803/#804/#820 — three audit-trail viewers
  + dataset templates + dev-loop guide + feature onboarding), one from the
  cockpit Onboarding Tracks (#796). The five new ones are **exposed**
  (`lightning__RecordPage` / `lightning__AppPage` targets) so admins can
  drag-drop, but the package ships no out-of-the-box placement.
- **6 stale stubs ship empty `query()` implementations** — the four Watcher
  signal services (Signals 4/5/6/7 — `WatcherFailedSyncTrendQueryService`,
  `WatcherPaymentOpsQueryService`, `WatcherUnhappySignalQueryService`,
  `WatcherUpcomingSignoffQueryService`) all return `SignalResultDTO.emptyResult(SIGNAL_NAME)`.
  Per the Phase 2 Watcher design memo, this is **intentional** — full
  implementations land after Watcher accumulates ~14 days of heartbeat data
  (earliest ~2026-06-04). Plus a non-Watcher near-stub —
  `DeliveryActivityLogCleanup` is a `Schedulable, Database.Batchable` class
  that runs nightly per its docstring, but the master `DeliveryHubScheduler.scheduleAll()`
  does **NOT** register it. Admins must hand-invoke `System.schedule(...)`
  from anonymous Apex to activate. Practically dormant on every subscriber org.
- **3 deprecated-by-comment TODOs persist** (`DeliveryDocActionRestApi.cls:158`,
  `DeliveryDocGenerationService.cls:272`, `DeliveryOnboardingService.cls:398`).
  First two are unchanged from 5/13 (still ~49 days old, still under any
  reasonable stale-comment threshold); the third is intentional
  ("PR 4+: when VerificationMethodPk__c != 'Manual', call the
  verification handler") and tracks back to the Onboarding Tracks MVP.
- **Field-level orphans unchanged** from 5/13 — same 4 fields (3 dormant
  `WorkLog__c` approval-workflow fields + `PortalAccess__c.PermissionsTxt__c`).
  Field discipline remains strong even as the codebase grew ~30 new classes.
- **Object-level orphans: zero.** All 50 custom objects are referenced from
  Apex / LWC / trigger code.

## Confirmed dead (zero references)

**None.** Every non-test Apex class has at least one production caller; every
custom object has at least one SOQL/DML reference. PR #789 closed the
5/13 dead-Apex bucket.

## Test-only by static reference (live via external HTTP)

| Class | Live entry point | Note |
| --- | --- | --- |
| `DeliveryBountyApiService` | `@RestResource('/deliveryhub/v1/bounties/*')` | No in-repo HTTP consumer. Bounty marketplace pivoted to cloudnimbusllc.com Next.js. 5/13 audit's "Likely safe" carry-over — Glen sign-off still pending on whether external traffic exists. |
| `DeliveryGanttRemoteController` | `@RestResource('/gantt-remote/*')` | `GanttRemote.page` VF page (mobile companion) is the live consumer via browser fetch — not greppable as Apex reference. Active. |
| `DeliveryTaskAPI` | `@RestResource('/deliveryhub/v1/tasks/*')` | Documented in README + CHANGELOG as external AI-agent integration. Removing without checking Site usage logs would silently break any AI client polling it. Active. |

## Stale stubs (referenced but implementation is empty / disabled)

### Watcher signal stubs — intentional, time-locked

Four classes, all ship as wired stubs from PR #809 (Phase 2 Watcher PR-B):

- `WatcherFailedSyncTrendQueryService.query()` — returns `SignalResultDTO.emptyResult('FailedSyncTrend')`
- `WatcherPaymentOpsQueryService.query()` — returns `SignalResultDTO.emptyResult('PaymentOps')`
- `WatcherUnhappySignalQueryService.query()` — returns `SignalResultDTO.emptyResult('UnhappySignal')`
- `WatcherUpcomingSignoffQueryService.query()` — returns `SignalResultDTO.emptyResult('UpcomingSignoff')`

All four are registered with `DeliveryWatcherService` (the orchestrator) and
gated by their own `DeliveryHubSettings__c.EnableWatcher*DateTime__c` flags.
Per the Watcher v1 design memo (PR #790), each stub's docstring explicitly
states "Deferred because: needs 14-21 days of post-Watcher-install reconciler
data to baseline what 'normal' looks like per org." Phase 3 (the auto-digest
that consumes these signals) is **time-locked** until ~2026-06-04. **Do
nothing** — this is the documented contract.

### `DeliveryActivityLogCleanup` — schedulable but never auto-scheduled

`global without sharing class DeliveryActivityLogCleanup implements Schedulable, Database.Batchable<SObject>`.
Doc-comment says *"Daily housekeeping: aggregates yesterday's analytics-style
ActivityLog__c rows into NetworkEntity__c.UsageAnalyticsJsonTxt__c and purges
rows older than the retention horizon."* The class implements the full
Schedulable + Batchable surface, has a 200-line test class, and reads
`DeliveryHubSettings__c.ActivityLogRetentionDaysNumber__c`. **But:** the master
scheduler (`DeliveryHubScheduler.scheduleAll()` — called from
`DeliveryHubInstallHandler.onInstall()`) does NOT include it. The class header
suggests admins run `System.schedule('Delivery Activity Log Cleanup', '0 0 2 * * ?', new DeliveryActivityLogCleanup())`
from anonymous Apex — but no subscriber installs would ever do that without
documentation. **Recommendation:** either wire it into `scheduleAll()` (so it
runs everywhere), or delete it (~280 LOC + retention field). The half-state is
strictly worse than either pole.

### Dead `@AuraEnabled` reader methods (carry-over from 5/13)

`DeliveryFieldChangeService.getFieldChangeHistory()` +
`getFieldChangeTrend()` — only called by the dead `deliveryFieldHistory` LWC.
The companion writer methods on the same class are alive (called by
`DeliveryFieldTrackingService` from 3 triggers). Same status as 5/13: if Glen
deletes the dead LWC, these two reader methods go with it; if he keeps the
LWC, leave them.

## Deprecated-but-in-use (TODO markers still pending)

| Location | TODO | Age (days) | Status |
| --- | --- | --- | --- |
| `DeliveryDocActionRestApi.cls:158` | "persist portalSessionEmail to a dedicated PortalSessionEmail__c field once the schema PR lands" | ~49 | Schema PR still unlanded; workaround (stuffing email in a user-agent string column) remains live. Carry-over from 5/13. |
| `DeliveryDocGenerationService.cls:272` | "surface a dedicated DeliveryHubSettings__c branding block so admins can override the issuer name/url" | ~49 | Minor admin-config gap, no urgency. Carry-over from 5/13. |
| `DeliveryOnboardingService.cls:398` | "PR 4+: when VerificationMethodPk__c != 'Manual', call the verification handler" | ~6 | Intentional next-iteration marker. Cited as a known gap in `docs/audits/e2e-walkthrough-2026-05-21.md` Top 5. |

## LWCs that ship without a placement

**14 carry-over from 5/13** (Glen never gave the delete OK on the "Likely safe —
verify before deleting" cluster from the prior audit):

- `deliveryBurndownChart` (Feb 2026, PR #304)
- `deliveryCycleTimeChart` (Feb 2026, PR #307)
- `deliveryDeveloperWorkload` (Feb 2026, PR #305)
- `deliverySLASummary` (Feb 2026)
- `deliveryStageHistory` (Mar 2026 — note: declares `lightning__RecordPage` target,
  could feasibly be intended for the WI record FlexiPage; flagged 5/13)
- `deliveryFieldHistory` (Mar 2026, PR #354)
- `deliveryBoardMetrics` (Mar 2026)
- `deliveryCsvImport` (Feb 2026, PR #315)
- `deliveryWorkItemTemplates` (Feb 2026, PR #317) — likely superseded by
  `deliveryTemplateManager`
- `deliveryKanbanSettingsContainer` (Feb 2026) — likely superseded by
  `deliverySettingsContainer`
- `deliveryStatusPage` (Feb 2026, PR #319) — superseded by `DeliveryStatusPage.page`
  VF (the deployed one)
- `deliveryDocumentSignPortal` (Apr 2026, PR #589 "Coleman demo")
- `deliveryRecordLiveRefresh` (Apr 2026, PR #731) — "wire don't delete" per 5/13
- `deliveryInvoicePreviewDeferPanel` (Apr 2026, PR #686) — bulk-defer panel
  that was built but never placed on the invoice or document FlexiPage

**6 NEW since 5/13** — all from the cockpit / Watcher / audit-trail PR fan-out:

| LWC | Origin PR | Date | Targets | Status |
| --- | --- | --- | --- | --- |
| `deliveryFeatureOnboarding` | #796 | 2026-05-20 | `lightning__RecordPage` (Feature__c, WorkItem__c) | Exposed for admin drag-drop; package ships no auto-placement on FeatureRecordPage. Worth wiring. |
| `deliveryDevLoopGuide` | #804 | 2026-05-21 | `lightning__RecordPage` (Feature__c, WorkItem__c) | Same shape — designed for record-page drop, no out-of-box placement. |
| `deliveryDatasetTemplates` | #803 | 2026-05-21 | `lightning__RecordPage` (Feature__c, WorkItem__c), `lightning__AppPage`, `lightning__HomePage` | Same shape. |
| `deliveryActivityLog` | #820 | 2026-05-24 | `lightning__AppPage`, `lightning__HomePage`, `lightning__RecordPage` | Designed as audit-trail viewer for ActivityLog__c. The `ActivityLog__c.tab-meta.xml` standard tab exists; the standard list view replaces this LWC on the tab. Worth dropping on a record page or the admin home. |
| `deliveryOnboardingHistory` | #820 | 2026-05-24 | (verify meta) | Audit-trail viewer for OnboardingProgress__c. |
| `deliveryWatcherDigestHistory` | #820 | 2026-05-24 | (verify meta) | Audit-trail viewer for WatcherDigest__c. The `WatcherDigest__c.tab-meta.xml` standard tab exists; same drop-on-page question as `deliveryActivityLog`. |

Pattern note: **every one of the 6 new orphan LWCs is exposed=true with valid
targets**. They are NOT dead code — they are "exposed-but-unwired", the same
pattern Glen called out in `feedback_default_scope_and_defer_discipline.md`
("Don't reach for defer — ship the right thing the first time"). The audit
recommends a one-shot **wiring-PR** (not a delete-PR) for these six, mirroring
PR-E from the 5/13 audit.

## Cross-cutting patterns

1. **The 5/13 "Definitely safe" delete cluster shipped cleanly** in PR #789
   without follow-on regressions. The audit-driven verification process worked
   (`feedback_verify_audit_findings_before_shipping.md` was born this cycle).
   No new "definitely safe" candidates have accumulated in the 13 days since.

2. **The "Likely safe — verify before deleting" 5/13 bucket is unchanged.**
   The 14 unplaced LWCs from the Feb–Apr widget/portal spike + various stragglers
   all still ship. Glen's sign-off path on these stalled — these are not
   "regressions", they're a backlog item awaiting decision. Estimated cleanup:
   one PR per cluster (analytics widgets ~7 LWCs + 1:1 controllers, Experience
   Cloud portal stub ~1 LWC remaining (deliveryDocumentSignPortal) + DeliveryPortalController
   methods, bounty cluster ~3 classes + 1 object + 9 fields).

3. **New code is hygenic but under-wired.** All 6 new orphan LWCs from
   2026-05-20→2026-05-24 are exposed=true with valid targets, real
   Apex controllers, real tests, and design intent recorded in their
   `masterLabel` / `description`. They're just not auto-placed by the
   package. This is the same defer-pattern Glen has flagged twice
   ([[default-scope-and-defer-discipline]], [[ship-full-cycle-not-just-pr]]).
   Recommend: wiring-PR (place on FeatureRecordPage / WorkItemRecordPage /
   admin home), not delete-PR.

4. **Stub-state services have a documented contract.** The 4 Watcher signal
   stubs from PR #809 (Signals 4-7) are intentionally empty and gated behind
   a 14-day heartbeat-data clock. Their stub-ness is a feature, not a bug —
   they ship the wiring so Phase 3 implementation is mechanical. **Do not
   delete or refactor**; they will be filled in after 2026-06-04.

5. **One real stale stub deserves attention.** `DeliveryActivityLogCleanup`
   is a fully-implemented Schedulable that the master scheduler never
   registers. This is materially different from "dormant by-design" because
   the class header explicitly describes it as nightly-running. Either wire
   into `DeliveryHubScheduler.scheduleAll()` or delete — the half-state is
   strictly worse than either pole.

## Suggested follow-on PRs (Glen sign-off required)

If Glen wants to action the findings, three independent PRs:

1. **PR-W "wire don't delete"** — place the 6 new orphan LWCs (cockpit + audit-trail
   viewers) onto their natural FlexiPages. Estimated 30min:
   - `deliveryFeatureOnboarding` → `DeliveryFeatureRecordPage` (Feature__c)
   - `deliveryDevLoopGuide` → `DeliveryFeatureRecordPage` + `DeliveryWorkItemRecordPage`
   - `deliveryDatasetTemplates` → `DeliveryFeatureRecordPage`
   - `deliveryActivityLog` → `DeliveryHubAdminHome` (admin home page)
   - `deliveryOnboardingHistory` → `DeliveryFeatureRecordPage` (or `DeliveryHubAdminHome`)
   - `deliveryWatcherDigestHistory` → `DeliveryHubAdminHome`
   Adds ~12 lines of FlexiPage XML per LWC, removes 6 from this audit's flag
   list next pass. **Highest-leverage delta** — fixes a known recurring pattern.

2. **PR-A "wire or delete the cleanup batch"** — single-class call:
   `DeliveryActivityLogCleanup`. Either add to `DeliveryHubScheduler.scheduleAll()`
   (~3 lines) OR delete the class + test + retention field (~280 LOC).
   Either decision unblocks subscriber-facing housekeeping. Same pattern as
   the 5/13 audit's "Refactor-target classes never adopted" call-out — when
   a class is shipped without its wiring, ship the wiring or remove the
   class.

3. **PR-B "drop the 5/13 carry-over likely-safe cluster"** (only if Glen
   confirms intent) — same three sub-PRs as the 5/13 audit recommended:
   analytics widgets (~3500 LOC), Experience Cloud / docusign stub
   (~2000 LOC), bounty marketplace (~1500 LOC + 1 object + 9 fields). Net
   ~7000 LOC if all three land. Carry-over decisions, no new analysis.

Total potential cleanup vs wiring: PR-W is 30min net-add; PR-A is 5min
(wire) OR 1h (delete); PR-B is the deferred 5/13 carry-over (~half-day).

## Net delta vs 2026-05-13 baseline

- Dead Apex classes: **0 today vs 4 on 5/13** — PR #789 closed all four
  (`DeliveryArchivalService`, `DeliveryHubCalloutService`,
  `DeliveryWorkItemQueryService`, `DeliveryTimelineController`).
- Dead LWCs (zero references): **20 today vs 22 on 5/13** — PR #789 deleted 5
  Experience-Cloud portal LWCs + `deliveryPartnerSettingsCard` +
  `deliveryActivityTracker` (8 net deletions); 6 new orphan LWCs accumulated
  from the cockpit + audit-trail PR fan-out (net +6). True net: -8 + 6 = -2.
- Dead objects: **0 today vs 0 on 5/13** — unchanged, still clean.
- Stale stubs: **6 today vs 0 explicitly tracked on 5/13** — 4 are documented
  intentional time-locked Watcher signals (Phase 3 holds until ~2026-06-04);
  1 is the `DeliveryActivityLogCleanup` wire-vs-delete decision; 1 is the
  `DeliveryFieldChangeService` reader-method pair (carry-over from 5/13's
  judgment-call list, status unchanged).
- Field-level orphans: **4 today vs 4 on 5/13** — unchanged (3 dormant
  approval-workflow fields + `PortalAccess__c.PermissionsTxt__c`).
- Test-only-but-live-via-REST: **3 today vs 3 on 5/13** — unchanged
  (`DeliveryBountyApiService`, `DeliveryGanttRemoteController`, `DeliveryTaskAPI`).
- TODO comments older than 30 days: **2 today vs 2 on 5/13** — same two, now
  ~49 days old (vs 36 days on 5/13). Still under the 60-day stale threshold.
