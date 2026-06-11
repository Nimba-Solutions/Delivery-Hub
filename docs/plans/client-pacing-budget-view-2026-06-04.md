# Client Pacing & Budget View — Gap Analysis + Build Plan

**Date:** 2026-06-04
**Trigger:** MF | AtLarge Billing Sync call (6/4). Jose Santiago (Mobilization Funding) wants
to manage spend against a budget with no surprises. Glen: "this is an actual user story…
this should be a canned report/dashboard/ui for Delivery Hub frankly."
**Direction locked by Glen:** View first, emails second. One metadata structure that supports
**both** a retainer envelope *and* fixed-bid scopes (not either/or). Native/canned to DH.

---

## 1. The user story (Jose's words, from the 6/4 call)

1. **No surprises** — "notify myself — hey, this is going to go over your budgeted hours,"
   *before* an estimate lapses, so he can make the business call (approve overage or change course).
2. **Pacing against estimate** — "good visibility on pacing," weekly + month-to-date, ideally
   refreshed before the Wednesday call.
3. **Budget management** — know what everything will cost (because he approved it); see where
   budgets get hit based on estimates.
4. **A budget envelope he can manage to** — the retainer: a set monthly number, draws against it,
   carry surplus/deficit forward, with separate fixed-bid scopes (e.g. QuickBooks) billed 50/50
   running *alongside* the retainer.
5. **Easy** — "an easy way to manage this for all of us." He does not want to hand-track hours.

Commercial wrapper (retainer vs. fixed-bid) is being decided separately with Danny/Jared.
DH's job is to **support both models** and make the numbers self-serve.

### The central artifact: the Spend Timeline (financial twin of the Gantt)

DH already has `deliveryProFormaTimeline` — the nimbus-gantt Timeline tab that plots WorkItems
across a **time axis** using each item's scheduled dates (`EstimatedStartDevDate__c` /
`EstimatedEndDevDate__c`), with an hours column and a `budgetUsedColumn`. "Pro Forma" =
projected financials; the framing is already there.

What Jose wants is the **dollars-on-that-same-time-axis** companion — a month-by-month view with
three series plus the budget line:

| Series | Source | Meaning |
|---|---|---|
| **Estimated spend** | Σ `EstimatedHoursNumber__c × rate`, bucketed into the month each item is *scheduled* to land (Gantt dates) | "What you approved, and when it's planned to hit" |
| **Actual spend** | Σ `WorkLog.HoursLoggedNumber__c × rate` by `WorkDateDate__c` month | "What's been logged/billed" |
| **Forecast spend** | projected remaining hours from `DeliveryForecastService` velocity × rate, spread over upcoming months | "Where we're trending at current pace" |
| **Budget line** | `DeliveryBudget__c` envelope(s) — retainer per month / fixed-bid pots | "The pot, and when cumulative spend crosses it" |

This is the canned view. It reuses the Gantt's scheduling data and the forecast engine — same
inputs, financial lens. The Gantt shows *tasks* over time; the Spend Timeline shows *money* over
the same time, against the budget.

---

## 2. What DH already has (verified in code 2026-06-04 — the engine is real, not dark code)

| Capability | Where | Status |
|---|---|---|
| Hours estimate per item | `WorkItem__c.EstimatedHoursNumber__c`, `ClientPreApprovedHoursNumber__c` | ✅ |
| Logged hours + rollup | `WorkLog__c.HoursLoggedNumber__c` → `WorkRequest__c.TotalLoggedHoursSum__c` → `WorkItem__c.TotalLoggedHoursSum__c` | ✅ |
| **Velocity forecast** | `DeliveryForecastService.calculateProjectForecast()` — walks WI tree, 4-wk rolling velocity ±σ, projects date cumulative hrs cross estimate, returns weekly history+projection, `isOverBudgetTrajectory` | ✅ |
| **"Tell me before we go over"** | `DeliveryForecastAlertService.runSweep()` — fires when `projectedFinalHours > estimate × 110%` (`ForecastAlertThresholdPercentNumber__c`), gated `EnableForecastAlertsDateTime__c`, wired in `DeliveryHubScheduler`, `FeatureDefinition.Forecast_Alerts` toggle | ✅ engine |
| Burn-up chart | `deliveryProjectBurnUpChart` LWC (record-page panel) | ✅ internal |
| On-budget / on-schedule pills | `deliveryHoursPills` LWC | ✅ internal |
| Velocity / burndown | `DeliveryVelocityService`, `DeliveryBurndownController` | ✅ |
| Historical reports | `Monthly_Hours`, `Hours_by_Project_by_Month`, `Budget_Health`, `Budget_Overrun_Heat_Map`, `ETA_vs_Projected` | ✅ |
| Client entity | `NetworkEntity__c` ← `WorkItem__c.ClientNetworkEntityLookup__c` | ✅ |

**Jose's #1 ask is already built** — `DeliveryForecastAlertService` is almost verbatim "notify
before we exceed budgeted hours." It's just (a) opt-in/off, and (b) routed to internal owners only.

---

## 3. The gaps (3)

**Gap A — The client can't see any of it.** Every surface is internal by design.
`DeliveryForecastAlertService` line 19: *"NEVER ClientNetworkEntityLookup — internal risk
doesn't go to clients."* Pills + burn-up chart mount on the internal WorkItem record page.
Jose only sees DH today via Glen screen-sharing. **This is the #1 gap.**

**Gap B — No budget envelope.** Estimates live per-WorkItem. There is no account-level pot of
approved budget (retainer or fixed-bid) to draw against, no surplus/deficit carry-forward, no
"where does the budget get hit" at the client level.

**Gap C — No monthly *projection* rollup.** Forecasting is per-WI and weekly-bucketed. Reports
do *historical* hours-by-month, but nothing rolls the per-WI projections up to a client-level
forward view ("projected June / July / August draw").

Note: the engine, scheduler, settings gates, and the per-WI math are all done. This is
**surfacing + one new object + an aggregation**, not greenfield.

---

## 4. Metadata: ZERO new objects, ZERO new fields (re-audited 2026-06-04)

Glen pushed: "do we really need a new object? … are you sure?" Re-audited the schema. **Answer: no
new metadata at all.** Every piece already exists:

**`WorkRequest__c` ("requests") already carries the entire budget/pacing field set:**
| Field | Covers |
|---|---|
| `QuotedHoursNumber__c` | the estimate/quote |
| `PreApprovedHoursNumber__c` | approved budget |
| `HourlyRateCurrency__c` | the rate |
| `ProjectedCostCurrency__c` | **forecast cost ($), already computed** |
| `BudgetUtilizationPct__c` | **pacing %, already computed** |
| `RequestedBudgetIncreaseNumber__c` | **the "we're going over — approve it" back-and-forth** |
| `TotalLoggedHoursSum__c` | actuals rollup |

**`WorkItem__c`:** `EstimatedHoursNumber__c`, `ClientPreApprovedHoursNumber__c`,
`TotalLoggedHoursSum__c`, `HoursVarianceNumber__c`, `BudgetVarianceNumber__c`,
`EstimatedStartDevDate__c`/`EstimatedEndDevDate__c`, `ProjectedUATReadyDate__c`.
**`NetworkEntity__c` (client):** `DefaultHourlyRateCurrency__c`, `BillingFrequencyPk__c`,
`EnableBillingDateTime__c`.

A fixed-bid scope = a WorkItem tree with an estimate (already modeled). A retainer target, *if/when*
the commercial decision lands, is at most a number on the client record — deferred, not needed for v1.

### The visualization is also half-built — compose, don't duplicate
| Existing component | Already does | Backed by |
|---|---|---|
| `deliveryBudgetSummary` (HomePage) | the **"running totals at the top"** — hours this/last month, logged, active requests | `DeliveryHubDashboardController.getBudgetMetrics` |
| `deliveryProjectMonthlyHours` | month-by-month bars + **monthly-target overlay** + est/logged summary (per-WI tree, logged-only) | `DeliveryHoursAnalyticsController.getMonthlyHoursForProject` |
| `deliveryProjectBurnUpChart` | forward **forecast** burn-up | `DeliveryForecastService` |
| `deliveryClientDashboard` | This Week / Last Week / This Month toggle | `DeliveryHubDashboardController.getClientDashboard` |

### Units (Glen 2026-06-04)
- **Hours primary**, `$` derived/secondary via `HourlyRateCurrency__c`/`DefaultHourlyRateCurrency__c`.
- **Forecast bucket is user-selectable: weeks / months / quarter / rest-of-year.** The engines already
  produce per-period series; the view re-buckets. *The client picks the lens* — "let them determine
  their pacing off our sizing + the back-and-forth."

### What actually gets built (the whole net-new surface)
1. **One new LWC, `deliveryPacingForecast`**, on the HomePage — composes estimated + actual +
   forecast into one view with the bucket selector. Reuses the existing chart patterns.
2. **One new Apex method** (portfolio-level): `getMonthlyHoursForProject` is per-WI-tree; add a
   sibling that aggregates across **all active root WorkItems** and appends the forward forecast
   series from `DeliveryForecastService`. Same DTO shape (`MonthlyHoursDTO`/`ProjectHoursSummary`),
   plus a `granularity` param and a `projection[]` series.

That's it. No object. No field. One LWC + one aggregation method over data that already exists.

---

## 5. Build sequence

### Phase 0 — Verify the engine live (~1 hr, read-only, do first)
- Confirm `DeliveryForecastService` returns sane numbers against a real WI tree on an org.
- Turn on `EnableForecastAlertsDateTime__c` on a sandbox and watch one alert fire end-to-end.
- Decide internal vs. portal surface for the view (see §6).

### Phase 1 — The VIEW (client pacing & budget dashboard) — *ship first*
- `DeliveryBudget__c` object + fields + GVS picklists + `WorkItem__c.BudgetLookup__c`.
- `DeliveryBudgetService` — draw-down recalc + per-client projection fan-in (reuses ForecastService).
- `DeliveryClientPacingController` — **tenant-safe** (filter to one `NetworkEntity__c`), returns:
  current period envelope, drawn MTD, remaining, projected EOM draw, carry-in surplus/deficit,
  active fixed-bids, and the per-WI estimate/logged/projected table.
- `deliveryClientPacing` LWC — the canned dashboard: month-to-date number, projection, pacing
  bar (green/yellow/red against envelope), budget list, per-project burn-up (reuse
  `deliveryProjectBurnUpChart`). Mounts on a DH Lightning page now; exposable via the public-API
  tier later (same controller) for a client portal.
- Reports/list views on `DeliveryBudget__c` for the Wed-call cadence.

### Phase 2 — The EMAILS — *ship second, DEFAULT OFF*
- New `DeliveryBudgetDigestService` sends a **client-safe** weekly digest to the
  `NetworkEntity__c` contact: envelope, drawn MTD, projected EOM, "you're tracking to N% of
  budget," next-month estimated spend. Reuse the OWEA/DKIM sender path (now verified — see
  invoice-email work). Keep the internal forecast-risk alert (`DeliveryForecastAlertService`)
  exactly as-is; the client digest is a separate, sanitized payload.
- **Default OFF.** Gated by its own `EnableClientBudgetDigestDateTime__c` (null = off), per the
  DateTime-opt-in pattern. We *propose* turning it on for Jose once the view is solid and the
  numbers have been validated against an actual invoice — not before. The view is the product;
  the email is an opt-in push on top.
- Cadence: weekly before the Wednesday call (Watcher scheduler already runs daily).

### Phase 3 — Monthly projection rollup (polish)
- Account-level forward view: projected draw by calendar month across all the client's active budgets.

---

## 6. Architecture: both surfaces, one synced spine (NOT A-then-B)

**Product thesis (Glen, 2026-06-04):**
- **Delivery Hub = procurement, Salesforce-native.** The client's own surface. Jose does it all
  himself — sees work, approves it, sees budget + spend timeline — natively in his own Salesforce org.
- **cloudnimbusllc.com portal = fulfillment, white-label.** The delivery/agency operation, the
  white-label face of the work.
- **Bidirectional sync is the spine.** The two surfaces are the *same data seen from two doors*,
  kept in lockstep across the existing sync rail (MF ↔ nimba ↔ dh-prod ↔ portal). Not two versions
  — one truth, two surfaces.

So both Option A (native DH view) and Option B (portal) are first-class. The implementation
consequence:

**`DeliveryBudget__c` is a first-class *synced* entity** — it rides the `DeliverySyncItem` rail
alongside `WorkItem__c` / `WorkLog__c`, not just a record read over REST. That's what makes the
budget/pacing genuinely bidirectional:
- Budget envelope set on the fulfillment side → syncs down to the client's DH.
- WorkLogs (actuals) already flow up the chain → draw-down recomputes on both sides.
- Client approval of an overage entered in DH procurement → syncs back up to fulfillment.

The Spend Timeline lives **natively in DH** (procurement, self-serve) AND the **portal renders the
synced data** (white-label fulfillment) — same numbers, both live, because they're on the rail.
The tenant-safe `DeliveryClientPacingController` (filtered to one `NetworkEntity__c`) is the
portal's read path; the *object itself* is syncable so it round-trips.

### Dependency + clean build order
The bidirectional portal mirror leans on the **sync rail being healthy** — currently it isn't
(dh-prod→nimba dead: null endpoint + paused, 750 stuck; MF inbound frozen since April — see the
Phase 1-5 sync-chain wiring runbook). The *native DH view reads local data and ships standalone*,
so this is a build order, not a blocker:
1. **`DeliveryBudget__c` as a synced object** + **native DH Spend Timeline** → ships now, works
   standalone on the procurement side.
2. **Portal mirror** lights up as the sync rail is repaired (parallel workstream).
3. **Email digest** (default off) on top.

---

## 7. CLAUDE.md compliance notes
- `BudgetTypePk__c` / `StatusPk__c` use **GlobalValueSet** references from day one (not inline).
- `DeliveryBudget__c`: `enableReports=true`; align enableSharing/enableBulkApi/enableStreamingApi.
- Controller is namespace-safe (typed `DeliveryBudget__c.SObjectType.getDescribe()`, no
  `getGlobalDescribe`), tenant-filtered to the caller's `NetworkEntity__c` slice.
- Keep Apex class names ≤36 chars (+`Test` suffix budget).
- New picklist seed values must be present across orgs (no runtime allowlist trigger — pass known
  values directly).
