# Delivery Hub — Timeline & Forecast: Feature Documentation

**What this is:** the "backend-of-the-application" reference for the Delivery Timeline + Pacing/Forecast — every feature, how it works, what you should expect to see, and what actually happens on the live install today. Built from a live click-through of all surfaces on **2026-06-06** after the **0.265.0.1** install (forecast feed) landed on MF prod.

**Audience:** Glen + the NG / DH / CN Claude Code agents. Each finding is tagged with its owner so the right session picks it up.

---

## How to read this doc

| Status | Meaning |
|---|---|
| ✅ **Works** | Verified live, behaves as expected |
| ◑ **Partial** | Works but with a caveat / not fully exercisable |
| 🔴 **Bug** | Verified broken live, expected≠actual |
| ⏳ **Fix in flight** | Broken live, but a fix is already shipped-pending-deploy or being built this session |
| ⚪ **Unverified** | Couldn't be driven (tool limit, or data set too small) — needs a human pass |

**Screenshots:** this testing session can't persist screen captures to disk, so each feature has a **`[SCREENSHOT: …]`** slot describing the exact frame + the real values seen on it. The doc stands on its own from the captions; drop the matching image beside each slot for the published version.

**Surfaces under test**

| Surface | URL | Role | Drivable |
|---|---|---|---|
| cloudnimbus v12 | `cloudnimbusllc.com/mf/delivery-timeline-v12` | Web mount, **git-backed proForma (13 demo items)** — NOT live SF, NOT on the sync rail | ✅ fully (best interaction surface) |
| MF Production | `mobilizationfunding123.lightning.force.com/.../DeliveryTimelineStandalone.app` | The live system of record (95 sched / 138 total) | ✅ renders + readable (SF LWS: DOM read OK, screenshots freeze under load) |
| MF Nimba (sandbox) | `…--nimba.sandbox…` | Staging org (109 sched / 158 total) | ✅ renders + readable |
| Dev org | `orgfarm-…develop…` | Developer sandbox (103 items) | ✅ renders |

**Bundle note:** the live v12 mount tested is bundle **`f99d990`** (NG **0.199.0**). NG's **0.199.1** (core `68953c51` / app `c4122a88`) — which fixes the Month/Quarter + Views-dropdown bugs below — was **NOT yet deployed** to any live surface at test time. Where a bug is marked ⏳, the fix exists but hasn't been re-copied/installed yet.

---

## 1. The Timeline (Gantt board)

**What it is:** the default view — work items as horizontal bars on a date axis, grouped into NOW / NEXT / PLANNED / PROPOSED / HOLD swimlanes, with a "today" line, dependency arrows, and a budget-used % label on each bar.

**How it works:** bars are drawn to a `<canvas>` from each item's `EstimatedStartDevDate__c` → `EstimatedEndDevDate__c`; the lane is its priority group; budget % = logged ÷ estimate.

**Expected:** all in-range items render as bars with correct lane, color, dates, and budget label; today-line at the current date.

**Actual:** ✅ **Works.** MF prod renders 95 scheduled / 1,429h / 8.4 months of real items; v12 renders its 13 demo items. Console clean (only standard SF platform warnings). Budget overruns show correctly (e.g. TX duplicate cleanup 192%, CF Session 183% on prod).

`[SCREENSHOT: MF prod Gantt — 95 scheduled · 1,429h · 8.4 mo; NOW/NEXT/HOLD lanes; today-line ~Jun 6; bars with budget % labels; [sync]-tagged items in HOLD.]`

**Owner:** — (no action)

---

## 2. View modes (the pill bar)

**What it is:** the row of view pills — **Gantt · List · Pacing · Treemap · Bubbles · Views**.

**Expected:** each pill swaps the main panel to that representation of the same data; Calendar/Flow no longer present (removed in 0.198.1).

**Actual:**

| View | Status | Notes |
|---|---|---|
| Gantt | ✅ | §1 |
| List / Audit | ✅ | §10 — the sizing/data-quality surface |
| Pacing | ✅ | §12 — the forecast |
| Treemap | ✅ | "Area by Hours" — renders, sized by hours |
| Bubbles | ✅ | "Size by Hours" along a today axis |
| Calendar / Flow | ✅ removed | Pills correctly end at Bubbles · Views (were "coming in 0.183" stubs) |

`[SCREENSHOT: pill bar showing Gantt · List · Pacing · Treemap · Bubbles · Views — no Calendar/Flow.]`

**Owner:** — (no action)

---

## 3. Zoom levels (Day / Week / Month / Quarter)

**What it is:** the zoom control that changes the time density of the axis.

**Expected:** every zoom level redraws the same bars at a different pixels-per-day scale; all bars stay visible.

**Actual:**

| Zoom | Status |
|---|---|
| Day | ✅ renders |
| Week | ✅ renders (clean descending distribution) |
| **Month** | 🔴⏳ **blank canvas** — lane headers render, **zero bars + no time axis** |
| **Quarter** | 🔴⏳ **blank canvas** — same as Month |

**Bug detail (Month/Quarter blank canvas):** clicking Month or Quarter paints an empty timeline. Confirmed live on v12 bundle `f99d990`, reproduced cleanly, **no console error**. The canvas is **correctly sized** (1658×845 backing / 1105×563 CSS) — so it is **not** a 0-size race; content is drawn off-screen or not at all. Scrolling does not reveal the bars. Week restores instantly.

- **Root cause (per NG):** on zoom-out the timeline shrinks, but a restored/non-zero `scrollX` from the persisted viewport then exceeds the new max width, so `ctx.translate(-scrollX,0)` pushes every bar off the left edge. Day/Week have enough width to absorb the stale offset; Month/Quarter don't.
- **Fix:** NG **0.199.1** clamps `scrollX/scrollY` to content extent in `render()`. **Shipped, not yet deployed** — the live test was on 0.199.0, so it still repros. **Must be re-verified after the 0.199.1 bundle is re-copied/installed.**

`[SCREENSHOT: v12 Month zoom — lane labels visible at left, entire canvas area blank (no axis, no bars). Week beside it for contrast — full bars.]`

**Owner:** **NG (fix shipped 0.199.1) → CN/DH re-copy bundle → Cowork re-verify.** Highest user-impact item: one click reaches a dead view.

---

## 4. Saved Views (CRUD)

**What it is:** the **Views ▾** dropdown — save the current layout (view+zoom+filters) as a named view, set a default, delete.

**Expected:** dropdown lists saved views with ★ default + ✕ delete; a "Save current view as…" name input + Save button; saving persists and shows in the list; active view name shows in the trigger pill.

**Actual:** ◑🔴⏳ **Feature works, save UI is clipped.** Full CRUD verified (save by name→Enter, persists, ★ default, ✕ delete, active name in pill). **But** the dropdown's **"Save current view as…" input + Save button are clipped** at the bottom edge — only a top sliver shows, with the VIEW filter row bleeding through beneath.

- **Root cause (per NG):** the menu was `position:absolute`, clipped by the titlebar's overflow context.
- **Fix:** NG **0.199.1** → `position:fixed`, anchored to the trigger's measured rect, viewport-clamped. **Shipped, not yet deployed** — still clips on live `f99d990`.

`[SCREENSHOT: v12 Views ▾ open — saved-view list visible, but the Save-view input + purple Save button cut off at the dropdown's bottom edge; filter row showing through.]`

**Owner:** **NG (fix shipped 0.199.1) → re-copy → re-verify.**

---

## 5. Search

**What it is:** the search box that filters the board to matching items.

**Expected:** typing narrows the board; header counts + the COLORS legend update reactively.

**Actual:** ✅ **Works.** Typing "QuickBooks" filtered to the 1 match; counts + legend updated (12 → 1) live.

`[SCREENSHOT: v12 with "QuickBooks" typed — board shows 1 item, header count 1, legend collapsed to the match.]`

**Owner:** — (no action)

---

## 6. VIEW filters & Group

**What it is:** the **VIEW** filter set (Active / Proposal / Done / Everything) and **Group** (Priority / Epics).

**Expected:** filters change which items show; grouping changes the lane organization.

**Actual:** ⚪ **Unverified on v12** — the controls are clickable but produce no visible change because v12's curated 13-item set is uniform (all active, all one group). **Needs the real 138-item SF orgs to exercise** — re-test on MF prod/nimba where filter/group count-changes are observable.

`[SCREENSHOT: v12 VIEW filter row (Active/Proposal/Done/Everything) + Group (Priority/Epics) — clickable, no count delta on the uniform demo set.]`

**Owner:** **Cowork — re-test on a real SF org.**

---

## 7. Hover tooltip

**What it is:** the mouseover card on a bar.

**Expected:** work-item ID + Status/Assignee/Dates + an Estimate / Logged / Used sizing block.

**Actual:** ✅ **Works.** Tooltip shows the ID, status, assignee, dates, and the sizing block.

`[SCREENSHOT: hover tooltip — ID line, Status/Assignee/Dates, Estimate/Logged/Used % block.]`

**Owner:** — (no action)

---

## 8. Right-click context menu

**What it is:** right-click on a bar → bar menu (Edit task / Change parent / Change bucket / Mark complete / Delete); right-click empty canvas → "Add new task at end".

**Expected:** menu renders on the correct target; selecting an action performs it.

**Actual:** ◑ **Menu renders correctly; actions machine-unverified.** The bar menu and empty-canvas "Create" both appear on the right target (hit-test is correct). The menu **actions** (Change bucket/parent, Mark complete) did **not execute** via browser automation — this is a **synthetic-event vs. canvas-pointer limitation of the test tool**, not proof the features are broken. Needs a **real mouse click-through** to confirm persistence.

`[SCREENSHOT: bar right-click menu — Edit task / Change parent / Change bucket / Mark complete / Delete.]`

**Owner:** **Human/Cowork — real-mouse click-through to confirm the actions commit.**

---

## 9. Sidebar — Priority Groups / reprioritize

**What it is:** the Sidebar panel ("Priority Groups", with a Capacity input + Auto-Schedule button) exposing NOW / NEXT / PLANNED / PROPOSED / HOLD as drag-to-move drop zones.

**Expected:** dragging an item between buckets re-prioritizes it and reflects in the main timeline lanes.

**Actual:** ✅ **Works.** Dragged CF 2.0 NEXT → PROPOSED → PLANNED → back to NEXT; each move reflected live in the timeline lanes and reverted cleanly. **This is the reliable reprioritize path** (DOM drag-drop, not canvas pointer).

`[SCREENSHOT: Sidebar "Priority Groups" with NOW/NEXT/PLANNED/PROPOSED/HOLD drop zones + Capacity input + Auto-Schedule button.]`

**Owner:** — (no action)

---

## 10. Canvas drag-to-reschedule

**What it is:** grabbing a bar on the canvas and dragging it to change its dates.

**Expected:** bar moves, dates update.

**Actual:** ◑ **Config-disabled on v12 + automation-resistant.** The v12 mount logs `enableDragReparent=false` and `enableDragBarToReprioritize=false` — so canvas drag-edit is **turned off by configuration** on this mount (not just resisting automation). Where enabled, synthetic drags pan/tooltip instead of moving the bar, so it remains machine-unverified. Decision needed: do we want canvas drag-reschedule enabled in the DH/MF mount? (Reprioritize already works via the Sidebar — §9.)

**Owner:** **DH/CN mount config (enable flags) + human click-through.**

---

## 11. List / Audit view (the data-quality surface)

**What it is:** the tabular view with budget-used %, hours logged/estimate, date range, owner, and filter chips (Needs attention / Not sized / No owner / No dates / Dupe candidates).

**Expected:** every item with its sizing + a clean dupe count.

**Actual:** ✅ renders; 🔴 **the data behind it is not forecast-ready, and dupe-detection misses exact dupes.**

- **MF prod:** 138 items · 1,977h sized · **129 needs attention · 39 not sized · 125 no owner** · several over budget (TX cleanup logged 11.5h on a 6h estimate; QuickBooks parent unsized; MF-732 logged 161h vs 12h estimate).
- **Dupe-detection:** reports **"0 dupes"** while `QBAG-PARENT ×2` and `"Can't Save Page Layout Edits" ×3` are visibly present. The detector misses exact/near name matches (inflates the sized-hours total).
- Stray record `__SCHEMA_PROBE_DELETE_ME__` sitting in prod PROPOSED.

`[SCREENSHOT: MF prod Audit — 138 items · 1,977h · 129 needs attention · 39 not sized · 125 no owner; rows with over-budget reds.]`

**Owner:** **MF/DH data cleanup** (size the 39, assign the 125 owners, true up over-budget estimates, delete the probe record); **NG** for the dupe-detector (0.198.1 claims a fix → confirm on prod once deployed).

---

## 12. Pacing / Forecast (the headline for the retainer conversation)

**What it is:** the forecast view — per-period and cumulative charts of Logged / Forecast / Target hours, with summary cards and bucket drill-down.

**How it works:** **DH computes** the numbers server-side (`getPacing()` → `getPortfolioPacing` → `toPacingData`, marked `authoritative:true`) and **passes them to NG to draw** via `config.pacing.data` / `setPacingData`. When DH doesn't feed data, NG falls back to a task-derived **"Forecast preview."**

### 12a. Controls

**Expected:** Range (Next 3 / Next 6 / Rest of yr / This Qtr / YTD / All / Custom) · Bucket (Week/Month/Quarter) · Mode (Per period / Cumulative) · Series (Actual/Forecast/Target) · EARLIER/LATER edge steppers.

**Actual:** ✅ **All present and functional.** Default = **week + ±6** (the old "one giant Month bar" default is fixed).

### 12b. Authoritative vs preview

**Expected:** on the live SF timeline, subtitle reads **"Actuals · forecast · target"** with DH's real numbers (not "Forecast preview").

**Actual:** ✅ **LIVE on MF Production** (0.265.0.1). Reads **LOGGED 405h · ESTIMATED 1,360h · REMAINING 956h · PACING 30% · 32 active**, subtitle **"Actuals · forecast · target"** — confirmed authoritative, not fallback.
- ⚠️ The "preview" seen on **cloudnimbus v12** is **expected** — v12 has no DH feed (its own 13-item static data). Not a bug; just the wrong surface to judge the forecast on.

### 12c. Cumulative burn-up

**Actual:** ✅ renders the climbing actuals→projected curve — the "are we tracking to budget / will we go over" view. ⚠️ The budget/target **line** isn't drawn until DH feeds `target`.

### 12d. 🔴 Projected Final is wrong (the number Jose sees)

**Expected:** Projected-final-at-completion ≈ Logged + Remaining ≈ **1,361h** (= Estimated), and can **never** be below Remaining alone.

**Actual:** 🔴⏳ **PROJECTED FINAL = 543h** on MF prod — **less than Remaining (956h) alone**, which is impossible. Logged (405) + Remaining (956) = 1,361 ✓ internally consistent, but Projected Final is broken.

- **Root cause:** `applyPortfolioForecast` computes Projected Final as `totalLogged + cumulativeForecast`, where `cumulativeForecast` only sums the **windowed** (±6) periods — so ~818h of out-of-window remaining is dropped. The projection is scoped to the visible horizon instead of total remaining.
- **Fix:** being built **this session** in the batched-release agent → `totalLogged + total remaining across all in-flight items` (≈ Estimated when on-budget).

`[SCREENSHOT: MF prod Pacing — cards LOGGED 405 / ESTIMATED 1,360 / REMAINING 956 / PROJECTED FINAL 543 / PACING 30% / 32 active; subtitle "Actuals · forecast · target". Projected Final 543 < Remaining 956 = the bug.]`

**Owner:** **DH (fix in flight this session).**

### 12e. Count parity

**Expected:** Pacing "active" count == board scheduled count.

**Actual:** 🔴⏳ historically 99 (Pacing) vs 95 (board); PR **#879** fixes the scope. With the live feed it now reads **32 active** — re-confirm board parity after #879 + the feed settle.

**Owner:** **DH (PR #879).**

### 12f. Bucket drill-down

**Expected:** click a bucket bar → list of the work items composing it with per-item hours.

**Actual:** ✅ drill-down opens with the contributing items (verified on the demo earlier this cycle).

---

## 13. Auto-Schedule (review-before-DML)

**What it is:** computes a proposed reschedule and shows the **old→new date diff** for review **before** anything is written.

**Expected:** modal "Auto-Schedule — review changes" lists N proposed changes (Work item · Start old→new · End old→new); footer "Apply N changes"; Apply hands the batch to the host (no silent write).

**Actual:**
- ✅ **On the SF build (0.196.1+):** the review-before-DML modal works — verified earlier: 47-change diff, "Apply N changes", nothing written on Apply (host-handoff path). This is the gate that lets you review proposed DMLs before committing.
- 🔴⏳ **On cloudnimbus v12:** **blocked** — modal says *"Auto-schedule needs the core engine 0.196.1+… re-copy the core bundle, then reload."* CN's core reports `version:"0.187.0"` (stale baked string) while the guard requires ≥0.196.1. DH avoids it (server-side `onAutoSchedule` override); CN trips it (in-bundle scheduler).
- **Fix:** NG bump the core's reported version string → CN re-copy.

`[SCREENSHOT: v12 Auto-Schedule modal showing the "needs core engine 0.196.1+" block message.]`

**Owner:** **NG (version-string bump) → CN re-copy.**

---

## 14. Team capacity / runway · Stats · Audit Pass

**Expected:** Team modal shows capacity (per-person hours) + a runway projection; Stats panel; Audit Pass commit-gate.

**Actual:** ✅ all three render and compute. Team modal recomputes runway live on edit (verified earlier: 170 h/mo capacity → 43.2 months runway; bumping a value recomputed correctly). Audit Pass shows the clean/dirty gate with Submit.

`[SCREENSHOT: Team capacity modal — per-person hours, total capacity, runway projection; honest note "feeding capacity into the scheduler is the next step."]`

**Owner:** — (resource-leveling, i.e. capacity actually driving the schedule, is NG's parked later-step).

---

## 15. Per-client configuration (dollars hidden for MF)

**What it is:** `config.pacing` lets each host tailor the Pacing controls + initial state.

**Expected for MF:** `controls.dollars:false` → no $ measure anywhere.

**Actual:** ✅ **Confirmed live** — MF prod Pacing shows hours only, no dollar figures. Per-client config works end-to-end.

**Owner:** — (no action)

---

## 16. Native Salesforce record experience

**What it is:** the work items are real `delivery__WorkItem__c` Lightning records, not just timeline rows.

**Actual:** ✅ solid native experience (reviewed on nimba):
- Standard Work Items tab + list views; New / Import / Change Owner / Assign Label; Maximus-branded MF org alongside full CRM.
- Record page: Details + Related tabs, inline-edit on every field, sections for Details / Acceptance Criteria / Steps to Reproduce / Budget & Estimates (Fast Track).
- Related lists: Work Item Comments, Files.

**Data-model notes (matter for the forecast):**
- **Stage Name** and **Status** are **separate fields** (e.g. Stage "Ready for Development" while Status "New").
- **Calculated ETA is blank** → the ETA field isn't populated (part of why early forecasts ran in preview).
- **Developer field blank** → matches the 125-no-owner data gap.
- 🟡 **LWC debug mode is ON** ("Salesforce is slower in debug mode") — **confirm it's disabled in prod** (perf hit).

**Owner:** **DH/MF — disable debug mode in prod; populate ETA/Developer as part of data cleanup.**

---

## 17. Cross-org sync status

**What it is:** bidirectional HTTP push/poll sync between MF prod ↔ nimba ↔ dh-prod (DeliverySyncItem rail).

**Expected:** new items propagate across orgs (with the predecisional gate holding prod-bound items).

**Actual:** 🔴 **Prod is the isolated/frozen node.** Triangulated across all 3 orgs: the smoke items (NORMAL, PREDECISIONAL, TEST·Bug 2) are present in **both nimba AND dev**, but **absent from prod** — including the NORMAL control that *should* cross. So nimba↔dev sync is moving items, while **prod isn't receiving anything new** (counts: prod 95 < dev 103 < nimba 109). The PREDECISIONAL gate correctly holds for prod.

⚠️ **Important architecture correction:** **cloudnimbus v12 is NOT on the sync rail.** It's a git-backed proForma editor (13 static items); editing it commits to `proFormaPatches.ts` via `/api/pro-forma/submit`, **not** a Salesforce DML. "Create on CN → syncs to MF prod" does not exist. The sync rail is **Salesforce↔Salesforce only.**

**Owner:** **DH — investigate prod inbound (the frozen node).**

---

## 18. Known-bugs summary (one table for the agents)

| # | Bug | Surface | Owner | Status |
|---|---|---|---|---|
| 1 | Month/Quarter zoom → blank canvas | timeline (all) | NG → CN/DH re-copy | ⏳ fixed in 0.199.1, **not deployed** |
| 2 | Views dropdown clips Save UI | timeline (all) | NG → re-copy | ⏳ fixed in 0.199.1, **not deployed** |
| 3 | Auto-Schedule blocked on v12 (stale core version string) | v12 | NG version bump → CN | 🔴 open |
| 4 | Projected Final = 543h (< Remaining) | Pacing (prod) | DH | ⏳ fix in flight this session |
| 5 | Pacing count vs board (95 vs 99) | Pacing | DH (PR #879) | ⏳ PR open |
| 6 | Dupe-detection misses exact dupes | Audit | NG (0.198.1) | ⏳ confirm on prod |
| 7 | Prod sync node frozen (not receiving) | sync rail | DH | 🔴 open |
| 8 | Data not forecast-ready (39 unsized / 125 no-owner / over-budget / probe record) | data | MF/DH | 🔴 open |
| 9 | LWC debug mode ON in prod | prod config | DH/MF | 🔴 open |
| 10 | Canvas drag-edit config-disabled | v12 mount | DH/CN config decision | ⚪ by design? |

---

## 19. Environment notes (for the next tester)

- **SF LWS screenshot/CDP channel freezes under load** — `get_page_text` DOM read still works; use it on the SF tabs.
- **cloudnimbus v12 = git-backed proForma (13 items), not live SF, not on the sync rail** — best *interaction* surface, but never judge the forecast or sync on it.
- **Extension host-permission resets** after disconnects/reloads on the SF tabs — re-grant "On all sites" + hard-refresh if reads start failing.
- **Window resize mid-session shifts pill coordinates** — re-screenshot before coordinate clicks; prefer element-ref (find) for menu items.
- **Live bundle at test time = `f99d990` (0.199.0)** — 0.199.1 fixes (#1, #2) require a re-copy before they can be re-verified.

---

## 20. The forecast bottom line (for Jose / the retainer conversation)

The forecast **screen is ready and the feed is live** on MF prod (authoritative "Actuals · forecast · target", 405h logged / 1,360h estimated). Two things still make the **number** soft:

1. **Projected Final is miscalculated** (543h, impossibly low) — fix in flight this session.
2. **Source data is incomplete** — 39 unsized items + estimates below actuals understate the true total until trued up.

**Sequence to a defensible number:** land the Projected-Final fix → true up the 39 unsized + over-budget estimates → set the budget/target line → then the cumulative burn-up becomes the clean "on track / will we go over" view for the client.
