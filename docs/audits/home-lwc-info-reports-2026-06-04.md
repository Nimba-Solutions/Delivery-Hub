# Home-Page LWC Sweep — Info Popover Coverage + Report/Dashboard Deep-Links

**Date:** 2026-06-04
**Branch:** `feat/home-lwc-info-coverage`
**Scope:** Every LWC mounted on the two Home FlexiPages —
`DeliveryHubHome.flexipage-meta.xml` and `DeliveryHubAdminHome.flexipage-meta.xml`.

This audit (1) confirms the `deliveryInfoPopover` self-documenting icon is present on
every home-page card, and (2) maps which home cards deep-link to the pre-built reports
under `force-app/main/default/reports/DeliveryHubVendor/`, flagging gaps + recommendations.

---

## Working set — home-page LWCs

Derived directly from the two Home FlexiPages (`<componentName>` entries, deduplicated):

| LWC | DeliveryHubHome | DeliveryHubAdminHome |
|---|:---:|:---:|
| deliveryGettingStarted | ✅ | |
| deliveryHubSetup | ✅ | ✅ |
| deliveryClientDashboard | ✅ | ✅ |
| deliveryExecutiveDashboard | ✅ | |
| deliveryFeatureCockpit | ✅ | |
| deliveryFeatureApprovalInbox | ✅ | |
| deliveryBudgetSummary | ✅ | ✅ |
| deliveryGhostRecorder | ✅ | ✅ |
| deliveryClientOnboarding | | ✅ |
| deliveryDocumentViewer | | ✅ |
| deliveryProFormaTimeline | | ✅ |
| deliveryReleaseNotes | | ✅ |
| deliveryActivityDashboard | | ✅ |
| deliveryDataLineage | | ✅ |
| deliverySyncRetryPanel | | ✅ |
| deliveryHubHealthDashboard | | ✅ |
| deliveryWatcherSetup | | ✅ |

---

## Coverage table

Legend:
- **Info popover** — `<c-delivery-info-popover>` present in `.html` **and** an `INFO_REGISTRY` entry in `deliveryInfoPopover.js`.
- **Report deep-links** — does the card navigate to a `DeliveryHubVendor` report (via `getReportIds` + `NavigationMixin`)?

| LWC | Info popover | Report / dashboard deep-links | Gaps / notes |
|---|:---:|---|---|
| deliveryGettingStarted | ✅ (pre-existing) | — | Setup wizard; no reportable data. No gap. |
| deliveryHubSetup | ✅ (pre-existing) | — | Connection status card. No report surface. No gap. |
| deliveryClientDashboard | ✅ (pre-existing) | ✅ `Recently_Completed`, `In_Flight_Work_Items`, `Blocked_Work_Items`, `Monthly_Hours`, plus per-stage `WorkItems_*` + `Attention_Items` (list-view fallback if absent) | Reference implementation. No gap. |
| deliveryExecutiveDashboard | ✅ **(added)** | Per-card click-through via `DashboardCard__mdt.ClickThroughUrlTxt__c` | Click-through is CMT-authored, not report-bound. Optionally seed cards with report URLs (see recs). |
| deliveryFeatureCockpit | ✅ **(added)** | — | Feature catalog; no report surface. No gap. |
| deliveryFeatureApprovalInbox | ✅ **(added)** | — | Approval inbox; no report surface. No gap. |
| deliveryBudgetSummary | ✅ (pre-existing) | ✅ `Monthly_Hours`, `Monthly_Hours_By_Entry_Date`, `In_Flight_Work_Items`, `Synced_Items`, `Failed_Items` | Reference implementation. No gap. |
| deliveryGhostRecorder | ✅ (pre-existing) | ✅ `Attention_Items` (list-view fallback) | Quick-submit + attention banner. No gap. |
| deliveryClientOnboarding | ✅ (pre-existing) | — | Intake form; creates records, no report surface. No gap. |
| deliveryDocumentViewer | ✅ (pre-existing) | — | Per-entity document list; record-scoped, not report-scoped. No gap. |
| deliveryProFormaTimeline | ⚠️ registry-only (no icon) | — | Gantt canvas has **no SLDS card/header slot** — see note below. |
| deliveryReleaseNotes | ✅ (pre-existing) | ❌ none | **Recommend** a `Recently_Completed` deep-link (see recs); needs NavigationMixin wiring — deferred as non-trivial. |
| deliveryActivityDashboard | ✅ (pre-existing) | ✅ `Activity_By_Day`, `User_Activity_Summary` | No gap. Could optionally add `Component_Usage` / `Page_Navigation`. |
| deliveryDataLineage | ✅ (pre-existing) | — | Sync-chain map; status is live, not report-backed. No gap. |
| deliverySyncRetryPanel | ✅ (pre-existing) | — | Failed-sync count + retry. Could optionally deep-link `Failed_Items` (recs). |
| deliveryHubHealthDashboard | ✅ **(added)** | — | Self-assessment checks; no report surface. No gap. |
| deliveryWatcherSetup | ✅ **(added)** | — | Admin form; no report surface. No gap. |

### deliveryProFormaTimeline — why no popover icon was injected

`deliveryProFormaTimeline.html` is **not** a `lightning-card`. Its entire body is a
`<div class="timeline-root">` whose toolbar/header is rendered by the
`@nimbus-gantt/app` framework into a `lwc:dom="manual"` container (with its own
context menu + a fullscreen toggle that escapes the Salesforce chrome). There is no
SLDS `slot="actions"` or header region to host `<c-delivery-info-popover>` in the
neighboring-card style, and a floating absolutely-positioned icon would risk
overlapping the framework's own controls. The `INFO_REGISTRY` entry already exists
(added in a prior change), so the description is queryable; wiring a visible icon is
left as a recommendation pending a deliberate placement decision (see recs).

---

## What this PR changed

**Info popover — registry entries added (5):**
`deliveryExecutiveDashboard`, `deliveryFeatureCockpit`, `deliveryFeatureApprovalInbox`,
`deliveryHubHealthDashboard`, `deliveryWatcherSetup`. Each entry's `dataSource` /
`keyFields` were derived from the component's actual Apex imports and field references
(not invented).

**Info popover — icon added to card actions area (5):**
the same 5 components' `.html` files now render
`<c-delivery-info-popover component-name="...">` in the card's `slot="actions"`,
matching the flex-row placement used by `deliveryBudgetSummary` /
`deliveryActivityDashboard`.

**Report deep-links wired:** none added in this PR. The four components that warrant
report deep-links already have them (`deliveryClientDashboard`, `deliveryBudgetSummary`,
`deliveryActivityDashboard`, `deliveryGhostRecorder`). The remaining candidates require
non-trivial NavigationMixin wiring and are listed as recommendations below rather than
forced in, per the "low-risk and obvious only" rule.

---

## Recommendations

### R1 — deliveryReleaseNotes → `Recently_Completed` report (low/medium effort)
The card lists completed Work Items for a date range; a "View as report" affordance to
the existing `Recently_Completed` report (passing the start/end dates as `fv0`/`fv1`) is
a natural fit. Requires adding `NavigationMixin`, the `getReportIds` import, a wired
fetch, and a handler/button — same shape as `deliveryBudgetSummary.openHoursReport`.
Deferred here to keep the PR focused and because the component currently has no
`NavigationMixin` and no jest test guarding it.

### R2 — deliverySyncRetryPanel → `Failed_Items` report (low effort)
The panel already centers on failed `SyncItem__c` records. A secondary "View failed
items report" link to `Failed_Items` would let admins drill into error detail beyond the
inline preview. `deliveryBudgetSummary.handleFailedClick` already demonstrates the exact
pattern (report-if-present, `SyncItem__c` list-view fallback).

### R3 — deliveryProFormaTimeline info icon placement (design decision)
Registry entry exists; decide whether to (a) add a small SLDS info button into the
gantt's own framework toolbar, or (b) wrap the timeline in a thin `lightning-card`
header strictly to host the popover + a title. Option (b) is the lower-risk, in-pattern
choice but changes the component's chrome — worth a quick confirm before implementing.

### R4 — deliveryExecutiveDashboard card seeds
This is CMT-driven; its click-throughs come from `DashboardCard__mdt.ClickThroughUrlTxt__c`.
Recommend shipping a few seed `DashboardCard__mdt` rows whose click-through points at
existing reports (e.g. `Budget_Health`, `Velocity_by_Week`, `Work_Item_Pipeline`) so the
home dashboard is non-empty out of the box. Data/seed work, not a code change to the LWC.

---

## Recommendation for the new pacing card (`deliveryPacingForecast`) — NOT implemented here

`deliveryPacingForecast` is owned by a concurrent PR (#869); its file is intentionally
untouched in this PR. The `INFO_REGISTRY` entry for it already exists on `main`. For its
report/dashboard deep-links, recommend:

- **`Monthly_Hours`** — its actual-hours bars are WorkLog hours bucketed by `WorkDateDate__c`; `Monthly_Hours` is the matching report (already date-parameterized in `deliveryBudgetSummary`). **Strong fit.**
- **`Hours_By_Project_By_Month`** — the portfolio pacing view rolls up hours across all active project trees; this report gives the per-project breakdown behind the aggregate line. **Strong fit.** (Note exact DeveloperName casing: `Hours_By_Project_By_Month`.)
- **`Budget_Health`** — when a single blended rate is configured the card surfaces dollars; `Budget_Health` is the natural drill-down for the $ view. **Good fit, conditional on rate config.**
- **`ETA_vs_Projected`** / **`Budget_Overrun_Heat_Map`** — relevant to the forecast/run-rate line; optional secondary links if the card grows a "forecast detail" affordance.

**New "forecast" report/dashboard — is one warranted?**
Not strictly. The pacing card already computes its target + run-rate lines in Apex
(`DeliveryHoursAnalyticsController.getPortfolioPacing`); the existing
`Monthly_Hours` + `Hours_By_Project_By_Month` + `Budget_Health` reports cover the
drill-down surfaces a user would want from it. A dedicated *forecast* report would
duplicate the amortization/run-rate math in report formulas (fragile) without adding a
view the trio above doesn't already give. **Recommendation: wire the three existing
reports as deep-links from the pacing card (in PR #869); defer any net-new forecast
report until there's a concrete drill-down the existing reports can't satisfy.**
