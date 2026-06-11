# Delivery Hub 0.264 — front-end works vs. needs-work (bot context)

**Date:** 2026-06-06 · **Author:** DH repo session (terminal; no browser — live UI testing is Cowork's lane)
**Purpose:** ground truth for the NG / DH / CN / MF bots on what's wired vs. what still needs work,
so live testing (Cowork) and follow-up builds target the real gaps. Verified against `origin/main`.

## What 0.264 actually ships
- **NG bundle = 0.196.2** — DH static resources on `main`: core `nimbusgantt.resource` md5
  `39df71d7…`, app `nimbusganttapp.resource` md5 `c793a4f8…` (adopted via the overnight bundle PR).
  So the engine includes: 0.193 tooltip+hit-test, 0.195 Pacing subtab, 0.196.0 Team/Auto-Schedule
  modals + `emit`/`on`, 0.196.1 auto-schedule **preview→review→commit**, 0.196.2 **field-generic
  audit buffer**.
- **Checkout Cart** (`deliveryCartBuilder` + `deliveryCartCheckout` + `DeliveryCartService`) — Cart tab + AdminHome card.
- **DH-native forecast** (`deliveryPacingForecast` card + `DeliveryHoursAnalyticsController.getPortfolioPacing`) on Home/AdminHome.

## ✅ WORKS (grounded in code; Cowork to visually confirm under LWS)
- **Gantt renders** via the 0.196.2 bundle (prod console showed it mounting clean, no JS errors — only benign LWS/LDS warnings).
- **Review-before-DML is ON by default.** `deliveryProFormaTimeline` mounts `batchMode: true` +
  `onAuditSubmit` → `commitGanttPatches` (line ~782). Drag/field edits buffer into the pending
  list; nothing hits the org until the operator submits. This *is* the "hypothetical mode" — confirmed
  by Cowork's live console (`batchMode:true, hasOnAuditSubmit:true, hasOnPatch:false`).
- **Field-generic buffer** (NG 0.196.2 Cut A) is in the bundle → the audit/pending list now tracks
  title/status/assignee changes, not just dates (was dates-only before).
- **Checkout Cart** — query/checkout logic verified (activates `Will Do` only); cart is empty until
  items are tagged `ClientIntentionPk__c = Will Do/Sizing Only` (use `deliveryCartBuilder`).
- **DH-native forecast card** — `getPortfolioPacing` returns real all-scope actuals (verified vs MF: 744.5h total).

## 🔲 NEEDS WORK — DH-side wiring of NG capabilities that exist in the bundle but aren't connected
These are the priority "tell the bots" items. The engine shipped them; **DH hasn't wired the host side yet:**

1. **Auto-Schedule → review-before-DML batch is NOT wired.** No `onAutoSchedule` handler in
   `deliveryProFormaTimeline`. NG 0.196.1 emits `onAutoSchedule({changes})` with full
   `{id,name,startDate,endDate,previousStartDate,previousEndDate}` rows — DH must catch that batch
   into its audit/pending list so auto-schedule moves get reviewed/committed like manual edits.
   **Until wired, auto-schedule in DH falls back to in-engine apply (no review gate).**
2. **NG Pacing subtab shows the FALLBACK preview, not DH's authoritative numbers.** No
   `PacingData`/`getPacing` serializer in DH Apex, and no `mountConfig.pacingData` pass-through.
   So the in-gantt Pacing tab computes client-side from task bars — it does NOT have DH's dated
   actuals / $ / client-scope / grading. DH needs `DeliveryHoursAnalyticsController.getPacing()` →
   serialize to NG's `PacingData` (contract in NG `docs/dispatch-pacing-view-0195.md`) → pass at mount.
   (The DH-native `deliveryPacingForecast` Home card is separate and DOES use real numbers.)
3. **No runtime gather/wired toggle.** DH is fixed to `batchMode` (gather) when audit-pass is on,
   `onPatch`-immediate when off — there's no in-UI `setMode('wired'|'gather')` toggle (NG 0.196.2
   exposes it). Decide whether DH surfaces the toggle or stays audit-pass-config-driven.

## 🧩 KNOWN SEAMS (cart) — intentional follow-ups, flagged in code
- **Stripe checkout** — `DeliveryStripePaymentHandler` is an *inbound webhook* handler; `Stripe`
  checkout mode activates lines + leaves a marked TODO (no outbound Checkout-Session callout yet).
- **Approve checkout** — shipped approval rails key on `Feature__c`, not WorkItem baskets; `Approve`
  mode activates + notes the seam.
- **Forecast month-spread in cart checkout** reuses `getPortfolioPacing` (active-scope) for now.

## 🔌 SYNC (operational, not code) — verify before trusting cross-org propagation
- Rail is real + bidirectional (`DeliveryHubSyncService` push receiver + `DeliveryHubPoller`),
  per-org API-key gated, echo-suppressed. **But it's been paused/frozen operationally** (dh-prod→nimba
  paused; MF inbound frozen since ~April per memory). Confirm it's live before expecting prod↔nimba↔dh-prod
  propagation. Page re-render needs a refresh (data hop ≠ page hop).

## Division of labor for this testing push
- **Cowork (browser):** live front-end clicks on the 3 SF timelines + cloudnimbus v12 — the only
  way to verify LWS rendering, the modals, and actual cross-org propagation. (SF now readable after
  the extension host-permission grant.)
- **DH session (me, terminal):** the wiring fixes above (`onAutoSchedule` handler, `getPacing()`
  serializer + pass-through, gather/wired toggle, cart seams) — ideally in the **new scratch org**
  so prod data isn't touched.
- **Scratch org:** an earlier `sf`-native deploy of DH source to a `cowork` scratch org exists but is
  partial (a couple of LWC1503 components + their FlexiPages failed); for clean dev work, recreate via
  cci in an interactive terminal (cci is blocked in this agent env — token redaction) and deploy current `main`.

## Suggested priority order for the bots
1. Wire `onAutoSchedule({changes})` → DH audit list (completes review-before-DML for auto-schedule). **DH.**
2. `getPacing()` serializer + `pacingData` pass-through (NG pacing subtab shows real DH numbers). **DH, then NG re-cut if needed.**
3. Confirm sync rail is live + the prod↔nimba on/off switch behaves. **MF/ops.**
4. Cart seams (Stripe/Approve) + the gather/wired toggle. **DH.**
