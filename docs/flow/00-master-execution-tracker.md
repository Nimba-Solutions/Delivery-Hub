# Delivery Hub — Master Execution Tracker
> **Created:** 2026-06-19 · **Owner lanes:** DH-Claude (package code) · MF-Claude (MF data/config) · Cowork (live verification). **This is the single entry point** on top of the phase docs (A–H), the MF client-servicing overlay, and the build storyline. It exists to let Cowork run **async**: pick a row, verify it on a sandbox/MF-Prod, stamp the result, move on.
>
> **How to use:** each row is a capability or test-group that expands to detailed Pre→Action→Expected→Verify scenarios in the linked phase §6. Work **top to bottom** (rows are ordered by the build-history fragility ranking — test the spine before the surfaces that ride it). On each row: run it → set **Status** → fill **Confirmed (UTC)** with the datetime you verified → drop an **Evidence** link (screenshot/SOQL/PR) → route any failure to the right lane.
>
> **Status legend:** ⬜ not yet run · ✅ verified working · 🟡 partial / built-but-off / works-with-caveat · 🔴 broken or missing · ⚫ N/A to DH package
>
> **Honesty rule (hard):** the "Believed" column is the *audit's current read*, NOT a confirmation. Nothing is ✅ until a Cowork run stamps **Confirmed**. Do not pre-fill datestamps. Items the audits couldn't confirm are marked NEEDS-VERIFY in the source docs.

---

## Part 1 — The build storyline (why the test order is what it is)
DH was built **board-first → spine-first → surface-by-surface**. A foundation burst (late Feb) laid the object model + Kanban + package skeleton; the team immediately found the product only matters cross-org, so a **bidirectional sync spine** became load-bearing — and was patched in *every* era after, right up to #928 the day before this tracker. On the spine they layered, in order: REST API + portal (early Mar), document/invoice engine (late Mar), an enterprise-hardening/refactor pass (early Apr), e-signing + the **Gantt/Locker-LWS rendering saga** (mid-Apr), an integration framework + the **GVS picklist reversal saga** (late Apr), live cross-org events + first forecast (early May), a self-configuration "cockpit" with onboarding/approvals/Watcher (mid-May), forecast/pacing + procurement cart (early Jun), and finally the **approval queue + the autonomy "machine"** self-heal layer (mid-Jun). Through-line: every buyer surface depends on a trustworthy spine, and most recurring pain came from (a) the spine, (b) Gantt under Locker/LWS, and (c) the managed-package/namespace/picklist tax that taxed every era.

**Fragility ranking (from reversal chains + fix density — where Cowork should expect the most red):**
1. **Sync spine** — patched in every era (#380s→#390s reconciler→#737–#747→#928). Cross-org FK translation, dedup/idempotency, Failed-row recovery, sharing context. Broadest blast radius. *Test first, deepest.*
2. **Gantt/timeline under Locker/LWS** — the single densest fix cluster (~25 consecutive `fix(gantt)` PRs #633–#675). Environment- and namespace-sensitive rendering.
3. **Namespace / picklist propagation / packaging** — the GVS saga is a net-zero round-trip (#690→#691→#692 revert→#711 deprecate); Master-Detail rename reversal (#596 reverts all 8); endless "unblock upload-beta" PRs. *A cross-cutting tax, not one feature.*
4. **Invoicing / doc rendering** — steady drip of renderer fixes + the structural frozen-snapshot gap.
5. **Forecast double-count / shape** — recently reworked (#885 leaf-only, #925 render), still settling.

---

## Part 2 — Execution checklist (capability rows, ordered by test priority)

> Detailed scenarios live in the linked phase doc §6. Counts in parentheses = scenarios behind that row.

### TIER 0 — Foundation (gates everything; cheap to check)
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 0.1 | Install + permset auto-assign (zero-touch) | C §1 | 🟡 | ⬜ | | | DH |
| 0.2 | Status defaults to Active (no invisible WIs) | C/D | ✅? | ⬜ | | | DH |
| 0.3 | Cron scheduled (`scheduleAll` → 4 triggers) | H/CW-8c #1-2 | 🟡 must-run-per-org | ⬜ | | | MF-config |
| 0.4 | Board renders / regroup-archive (bulk action?) | overlay TS.4 | 🟡 NEEDS-VERIFY | ⬜ | | | DH+data |

### TIER 1 — Sync spine (highest residual risk — test deepest)
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 1.1 | Outbound dispatch (push + hub modes) | C §1, overlay TS.3 | 🟡 | ⬜ | | | DH |
| 1.2 | Inbound ingest + cross-org FK translation | C §1 | ✅? | ⬜ | | | DH |
| 1.3 | Dedup / idempotency (no double-write) | C §1 | 🟡 | ⬜ | | | DH |
| 1.4 | Failed-row recovery + Staged-with-endpoint heal | C, #928 | 🟡 post-#928 | ⬜ | | | DH |
| 1.5 | Audit-insert non-fatal (#928) — full org doesn't roll back write | C/F | ✅? per #928 | ⬜ | | | DH |
| 1.6 | ContentVersion/file sync dispatch | C §4 | 🔴 stuck Queued | ⬜ | | | DH |
| 1.7 | Reconciler heals drift (Hub-mode blind spot?) | F overlay | 🟡 | ⬜ | | | DH |

### TIER 2 — Gantt / timeline (densest historical churn)
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 2.1 | Board/Gantt renders under managed-pkg Locker/LWS | E/H | 🟡 env-sensitive | ⬜ | | | DH |
| 2.2 | Drag-reorder / dependency edit persists (no snap-back) | E §1.D | ✅? | ⬜ | | | DH |
| 2.3 | Terminal-stage items dropped from default timeline (#926) | E/H | ✅? | ⬜ | | | DH |
| 2.4 | Auto-schedule modal writes dates (data-starved: ~7 deps) | overlay T5.1-2 | 🟡 mechanism-ok/no-data | ⬜ | | | data |
| 2.5 | **Date-guard vs nightly ETA-job collision** | overlay TS.1 | 🔴 ships green, CI-blind | ⬜ | | | DH-FIX |
| 2.6 | Dateless-from-creation WIs invisible, no warning | overlay TS.2 | 🔴 | ⬜ | | | DH |

### TIER 3 — Intake → Estimate → Approve (the loop that never stood up for MF)
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 3.1 | **No UI to create estimate / submit for approval** | E §4(5), overlay #1 | 🔴 RANKED BLOCKER #1 | ⬜ | | | DH-BUILD |
| 3.2 | `deliveryQuickRequest` auto-activates, no gate | overlay INTAKE | 🔴 | ⬜ | | | DH |
| 3.3 | Cart checkout activates → Stripe/Approve modes stubbed | H/CW-8a #40-41 | 🟡 stubs | ⬜ | | | DH |
| 3.4 | Cart admin-only (no buyer self-serve surface) | H/CW-8a #49-51 | 🟡 selfServe inert | ⬜ | | | DH |
| 3.5 | Approval queue decide/approve/decline/bulk | E/CW-8c | 🟡 decide-only | ⬜ | | | DH |
| 3.6 | Auto-approve ≤ threshold within cap | E/CW-8c #17 | 🟡 works-when-fed | ⬜ | | | DH |
| 3.7 | Approval-cap **enforcement** (flag vs hard-block) | E/CW-8c #48-49 | 🟡 built, OFF | ⬜ | | | MF-config |

### TIER 4 — Deliver / Forecast / Pacing
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 4.1 | Buyer capacity slider (4 bands; 2 synthetic) | H/CW-8b #1-28 | 🟡 | ⬜ | | | DH |
| 4.2 | `TeamPoolTxt__c` does NOT feed slider (misroute) | H/CW-8b #63 | 🔴 wrong-surface | ⬜ | | | DH |
| 4.3 | Admin pacing card still flat bars (ignores segments) | overlay T6.1 | 🔴 | ⬜ | | | DH |
| 4.4 | Forecast estimate-based, not velocity | overlay T6.3 | 🔴 | ⬜ | | | DH |
| 4.5 | Approval re-tiers but does NOT re-scope forecast | H/CW-8c #20 | 🟡 by-design-confusing | ⬜ | | | DH |
| 4.6 | Closed/historical rear-view (controller-ready, no UI) | overlay T6.4 | 🟡 | ⬜ | | | DH |
| 4.7 | Forecast-alert sweep (20-WI cap) | H/CW-8b #66-75 | 🟡 OFF/capped | ⬜ | | | MF-config |

### TIER 5 — Invoice / Pay (the #1 money pain)
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 5.1 | **Invoice = frozen day-1 snapshot, drops late billables** | F §4, overlay T7.1 | 🔴 structural | ⬜ | | | DH-BUILD |
| 5.2 | Missing-billable completeness detector | F §5 | 🔴 doesn't exist | ⬜ | | | DH-BUILD |
| 5.3 | AR/prior-balance excludes Superseded | F, overlay T7.2 | ✅? FIXED at gen | ⬜ | | | DH |
| 5.4 | Stripe webhook idempotency (chargeId) | F, overlay T8.1 | 🔴 non-idempotent | ⬜ | | | DH |
| 5.5 | DueDate/aging (unsent + portal-Approved never age) | F, overlay T8.2 | 🔴 holes | ⬜ | | | DH |
| 5.6 | QuickBooks JE dirty-field gate | overlay T8.3 | ⚫ MF-Prod, not DH pkg · ON HOLD | ⬜ | | | MF-Prod |

### TIER 6 — Inbound channels / onboarding / process / the machine
| # | Capability | Phase ref | Believed | Status | Confirmed (UTC) | Evidence | Lane |
|---|---|---|---|---|---|---|---|
| 6.1 | Slack two-way (ships OFF) | D | 🟡 OFF | ⬜ | | | MF-config |
| 6.2 | Inbound email (no Email Service in metadata) | D | 🟡 manual setup | ⬜ | | | MF-config |
| 6.3 | Public submit / portal API intake | D | 🟡 no estimate gate | ⬜ | | | DH |
| 6.4 | Onboarding → contract → e-sign | A | 🟡 | ⬜ | | | DH |
| 6.5 | Hash-chain tamper validator | A §4 | 🔴 can't reconcile | ⬜ | | | DH |
| 6.6 | Non-dev process can RUN (not just display) | B §4 | 🔴 picklist-coupled | ⬜ | | | DH |
| 6.7 | SEE field-capture ON | G/overlay #2 | 🔴 OFF | ⬜ | | | MF-config |
| 6.8 | Auto-diagnose drafts into queue (ships ruleless) | G/overlay | 🔴 0 rules | ⬜ | | | DH+config |

---

## Part 3 — Environment / Install DIMENSIONS (the real "what's left" — mostly UNTESTED)
**This is the gap class Glen flagged.** All ~700 functional cases above test **one** environment: namespaced (`delivery__`), fresh-ish install, the 3 known orgs (MF/nimba/dh-prod), admin profile. The same functionality can behave differently across these **axes** — and almost none are covered today. Each axis multiplies risk, not test count: you re-run the *high-risk* functional rows under each axis, not all 700.

| Axis | Variants | Covered today? | Why it matters / known signal |
|---|---|---|---|
| **D1 Namespace** | managed/`delivery__` · unlocked/no-namespace · **mixed mesh** | 🔴 only namespaced | Framework built for it (tokenized imports, dual-key ingest, dynamic describes) BUT ~60 hardcoded `delivery__` literals + 14 `getGlobalDescribe/USER_MODE` sites are residual landmines. **Cross-namespace sync (ns↔bare both ways) = ~4 directional combos, untested.** |
| **D2 Install type** | fresh install · **subscriber upgrade** | 🔴 mostly fresh | The GVS saga proves upgrade ≠ fresh: picklist values don't reliably propagate on upgrade (SF known issue, scarred into CLAUDE.md). Must test values land on *upgrade*. |
| **D3 Org topology** | 2-org · 3-org hub-spoke · mixed-namespace mesh · client-installs-own-DH | 🔴 only the 3 known orgs | "However they want to set up their pipeline" — the sync matrix changes per topology. |
| **D4 Profile / perms** | admin · buyer · guest/portal · minimal-perms | 🔴 admin only | `selfServe`/portal/guest paths (e.g. relay minting needed `without sharing`, #914) behave differently; FLS strips silently. |
| **D5 Data volume** | small · large portfolio · big sync backlog | 🔴 small only | Forecast-alert 20-WI cap; sync backlog; governor limits at scale. |
| **D6 Edition / limits** | storage-full · API-limited | 🔴 untested | Storage-full was the #928 root cause (rolled back billable writes). |
| **D7 Locale / TZ / currency** | non-USD · non-GMT · non-US locale | 🔴 untested | Scheduler gates are GMT-hour; invoice dates; currency on rates. |
| **D8 Sandbox vs prod** | prod · sandbox · **post-refresh** | 🟡 partial | Sandbox refresh wipes cron + NetworkEntity config (audit flag) — re-init not turnkey. |

**Scoping takeaway:** the functional catalog (~700) answers "does each feature work in the happy environment." These 8 axes answer "does it work the way a *real future client* will install and run it." **That second question is where most of the unknown-unknown work hides** — and it's the honest answer to "what's left after Cowork goes green on the ~700": a focused re-run of the high-risk rows under D1–D8, plus the fixes each axis surfaces.

---

## Part 4 — Open gaps / domain-input invitation (Glen + MF-Claude add here)
The catalog is only as comprehensive as the gaps we've named. Glen's namespace point already added axis D1. **Add candidate gaps below — they become tracker rows or new dimensions:**
- _(open)_ white-label / branding per-client (Tier-2 thesis enabler) — is it a dimension or a feature?
- _(open)_ multi-currency / international clients?
- _(open)_ data residency / compliance per client?
- _(open)_ … _(Glen / MF-Claude: append here)_

---

## Part 5 — How Cowork runs this async
1. **Claim a row** (top-down by tier). Run its scenarios from the linked phase §6 on a **sandbox** (or read-only on MF-Prod).
2. **Stamp it:** Status + Confirmed (UTC datetime) + Evidence link. A row designed to *prove a gap* (e.g. 3.2 auto-activation) is ✅-confirmed when you've reproduced the gap with evidence — that's a successful test, not a pass of the feature.
3. **On 🔴/🟡 → route:** DH-code → DH-Claude (PR) · MF-config/data → MF-Claude · DH-BUILD/DH-FIX rows are net-new work, not just verification.
4. **Re-run under dimensions:** once a high-risk row is ✅ in the happy env, re-run it under the relevant D1–D8 axis and stamp separately.
5. **"Done" = ** all Tier rows ✅ in happy env **+** high-risk rows ✅ under D1–D8 **+** the DH-BUILD/DH-FIX rows shipped. Only then does "confirming it works" fully simplify the operator's life — and even then, the autonomy payoff is client-dependent (see overlay §0.5, the adoption ceiling).

**Source docs:** `phase-a..h-*.md` (functional scenarios) · `gap-register-mf-servicing-overlay.md` (client-servicing gaps + Tn.x) · this tracker (order + status). Render target: these become DH docs as native web pages (replacing cloudnimbus/mf stand-ins) — an interactive, checkable runbook with live status per row.
