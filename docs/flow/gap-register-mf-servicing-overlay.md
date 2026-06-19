# Gap Register — the MF client-servicing overlay
> **Provenance:** distilled from a grounded 4-agent code audit run from the *seat of actually servicing MF* (Mobilization Funding), cross-checked against MF-Prod with DH `0.288.0.1` installed, 2026-06-18. Source artifact: `Mobilization-Funding-Claude/handoffs/dh-end-to-end-client-servicing-map-0618.md`.
>
> **Why this doc exists:** phases A–H were written from the package code. This overlay is the *lived-experience* check — it grades each capability by **whether MF could actually use it, and why not**, and flags where the phase docs have **no coverage or under-state a gap**. Several findings below are explicitly undocumented in A–H; this register is where they land until folded into each phase.
>
> **Honesty rules:** every claim is attributed to the audit. Items the audit itself marked **NEEDS-VERIFY** are labeled — do not treat them as confirmed. MF-Prod state claims reflect what the audit observed on 0.288.0.1, not a fresh query.

---

## 0. The one-picture thesis (from the audit)
The DH "machine" is a pipeline — `SEE → DIAGNOSE → INTAKE → ESTIMATE → APPROVE → SCHEDULE → DELIVER/TRACK → INVOICE → PAY`. The problem is **not missing capability** — it's that the stages ship **OFF, un-wired, or fighting each other at exactly the seams a delivery operator hits.** That is why so much MF work happened by hand or via cloudnimbus stand-in pages. Turn each red/yellow green → a Cowork can verify it → it runs unattended.

## 0.5 The adoption ceiling (non-code, but the most important context)
The instruction-engine / "subtract-Glen" thesis (Phase G/H) assumes the operator *wants* the machine. The MF engagement surfaced the opposite: **the people running the client's business do not want to automate or systematize their work** — a maintainer relationship, not a transformation partner. This is a real ceiling on the autonomy vision and belongs in any honest read of "the machine": the buyer who would be automated may resist the automation that removes them. DH's value to such a client is reliable *delivery + billing hygiene*, not autonomy. The autonomy layer pays off only where the buyer is bought-in to being subtracted.

---

## Ranked blockers (the audit's priority order — fix these first, they gate the most)
1. **🔴 No UI to create an estimate / submit work for approval.** `DeliveryWorkApprovalService.submitForApproval` has **zero LWC callers** (grep-confirmed); the only in-package caller is the dark auto-diagnose engine. The approval queue can DECIDE but never INTAKE. **This is the single reason the approval flow never stood up for MF.** → *Phase E §4(5) names it; this register elevates it to THE gating blocker.*
2. **🔴 SEE / DML field-capture is OFF** (`EnableFieldTrackingDateTime__c = null` on MF-Prod). The eyes of the interpretation engine are dark — nothing to diagnose or route. → *Phase G §2/§4 (documented as "ships dark").*
3. **🔴 Intake auto-activates with no gate.** → see §INTAKE below. **Undocumented in A–H.**
4. **🔴 Invoice is a frozen day-1 snapshot** that drops late billables; no completeness detector. → *Phase F §4 / Phase H — well covered; this is the recurring monthly manual-regen pain.*
5. **🔴 Date-guard vs ETA-job collision ships green, CI blind.** → see §SUBSTRATE below. **Undocumented in A–H — the audit's single most important new finding.**
6. **🟡 Auto-diagnose ships with zero rules · 🟡 approval cap built but OFF · 🟡 forecast estimate-based not velocity · 🟡 admin pacing card still flat bars.** → *Phase G/H — covered.*

---

## NEW / under-stated findings to fold into the phase docs

### SUBSTRATE — Date-guard vs ETA nightly job COLLISION  ·  **undocumented in A–H · audit's #1 finding**
Two date-scar fixes fight each other. `DeliveryWorkItemETAService` (nightly) nulls out stale `EstimatedStart/EndDevDate__c` on unsized items; the new gantt guard `protectGanttCriticalFieldsFromNull` `addError`s exactly that non-null→null transition. The ETA job's `Database.update(records, false)` swallows the error to a debug log, **and the guard is disabled in test context, so CI is green while prod silently stops clearing stale dates.**
- **Cowork test (TS.1):** after a nightly ETA run, `SELECT COUNT() FROM delivery__WorkItem__c WHERE DeveloperDaysSizeNumber__c=null AND EstimatedHoursNumber__c=null AND (EstimatedStartDevDate__c!=null OR EstimatedEndDevDate__c!=null) AND StageNamePk__c NOT IN ('Done','Cancelled','Deployed to Prod')` → **>0 means the guard is blocking ETA cleanup (collision live).**
- **Fix direction:** the ETA queueable should set `triggerDisabled=true` around its null-out DML (audited bypass), so the guard protects user-driven edits without blocking the system job.
- **Belongs in:** phase-c (sync/data-integrity) §4.

### SUBSTRATE — Dateless-from-creation WIs render invisibly, no warning  ·  **under-stated**
The gantt guard only catches non-null→null. A WorkItem created with no Estimated dates (the 4/29 RR/MKT failure class) is invisible on the timeline with **no health card or toast flagging it.**
- **Cowork test (TS.2):** create an active WI with null Estimated dates → confirm absent from timeline AND nothing flags it.
- **Belongs in:** phase-c §4 / phase-h forecast gaps (pairs with the date-guard collision).

### INTAKE — `deliveryQuickRequest` auto-activates with no approval gate  ·  **undocumented in A–H**
`DeliveryQuickRequestController` stamps `ActivatedDateTime__c = now()` at creation and **never calls `submitForApproval`** → the request goes straight into the live pipeline with no estimate, no approval. This inverts the "estimate-before-every-item" rule Danny asked for. (Phase H documented the *cart-checkout* activation seam but missed this second, more common front door.)
- **Cowork test (T2.1):** submit one QuickRequest → new WorkItem has `ActivatedDateTime__c` non-null and no `WorkRequest__c` in "Offer Sent" → proves no gate.
- **Belongs in:** phase-d §1E / phase-e §7.

### SCHEDULE — auto-schedule modal exists but is data-starved  ·  **not named in A–H**
`deliveryGanttAutoScheduleModal` → NG `AutoSchedulePlugin` → audited `commitGanttPatches` is a real two-stage auto-scheduler that writes engineered dates. But `WorkItemDependency__c` holds **~7 edges org-wide (0 on CF 2.0)** — the mechanism works, there's nothing to sequence against. The gap is **data, not code.**
- **Cowork tests (T5.1/T5.2):** run the modal → confirms it writes dates via `commitGanttPatches`; `SELECT COUNT() FROM delivery__WorkItemDependency__c` ≈ 7 → empty dependency graph.
- **Belongs in:** phase-e §1.D / phase-h schedule lane.

### DELIVER — closed/historical rear-view is controller-ready but has no UI  ·  **gap**
`getGanttData(showCompleted)` + `LAST_N_DAYS:90` are supported server-side, but the buyer LWC always calls `showCompleted:false` and there's **no toggle in the UI.** Small lift, controller-ready.
- **Cowork test (T6.4):** buyer timeline → confirm no "show closed/completed" toggle.
- **Belongs in:** phase-h forecast / phase-e §1.G.

### DELIVER — admin pacing card still draws flat bars  ·  **sharpening of a known gap**
The buyer capacity slider got the cohort-segment fix, but `deliveryPacingForecast` (admin card) still **ignores `segments` and draws a single value per period** — the original 6/7 "1 bar" scar lives on here specifically. (Phase H noted the card lacks segments; the audit pins it as the surviving home of the flat-bar bug.)
- **Cowork test (T6.1):** buyer slider shows 4 stacked colors; admin pacing card still flat single bars.

### PAY — Stripe webhook non-idempotent + DueDate/aging holes  ·  **covered in Phase F, re-confirmed live**
Stripe handler keys on `metadata.document_id` with no chargeId idempotency (duplicate webhook double-credits); `DueDateDate__c` is set only at send, so generated-but-unsent and portal-Approved invoices **never age into AR / never get reminded.** Audit re-confirms Phase F §4.

### QuickBooks defect — **⚫ NOT in the DH package**
Lives in MF-Prod `QuickBooksJEService.handleTransactionUpdate` (no dirty-field gate). Correctly out of scope for the DH docs; noted so it isn't mistaken for a package gap. **(Also: MF has put QB on hold — do not treat as active work.)**

---

## Items the audit marked NEEDS-VERIFY (do NOT assert as fact)
- **Bulk archive/regroup admin action** — `PriorityGroupPk__c` is in the sync set and `ArchivedDateTime__c`/soft-delete/terminal-drop exist, but whether a **one-click bulk** archive/regroup admin action ships is **unconfirmed** (TS.4). If absent, regroup/archive is still hand DML.
- **Stub watcher signals** — audit reports `WatcherFailedSyncTrend` + `WatcherPaymentOps` (and 2 others) return empty stubs (T1.3); confirm against current main before citing as the missing missing-billable detector.

---

## How this converges with the phase docs
Each finding above carries its **"belongs in"** phase. Folding them into the named phase docs (with the audit's `Tn.x` test cases added to that phase's §6) closes the comprehensiveness gap Glen flagged. Priority order = the ranked-blockers list: estimate-UI (Phase E/3), SEE (Phase G/0), intake gate (Phase D/2), invoice completeness (Phase F/7), and the date-guard collision (Phase C/substrate) gate the most downstream value. The audit's full `Tn.x` catalog (~25 cited test steps across Phases 0–8 + substrate) is a ready Cowork campaign that runs against MF-Prod/sandbox and records pass/fail with evidence.
