# Staged Changes — preview pending DML before commit

**Date:** 2026-06-05
**Constraint (Glen):** minimize new metadata — **zero new objects/fields**; LWCs/Apex fine.
**Shape:** a git-style staging area for records — edits accumulate with no DML, a modal shows
the whole diff, Commit applies them in one bulk transaction, Discard throws them away.

> Origin: 2026-06-05. "Do changes made on schedule and change without DML so we can preview what
> it's doing before committing — a whole list of DML updates on a modal." Same stage-then-commit
> shape as the checkout cart.

## Why zero metadata
The entire feature is **behavior over existing records** — a client-side buffer, a review modal,
and Apex that `update`s records that already exist. Nothing persists a "change set"; the buffer
lives in LWC memory until Commit. The dry-run uses `Database.Savepoint`/`rollback` (runtime, no
schema). **No new objects or fields.**

## Two preview depths (build both)
- **(a) Raw diff** — list the field changes themselves (per record: field, old → new). Always on.
  All client-side until Commit. This is "the list of DML updates on a modal."
- **(b) Effects dry-run** — preview *downstream consequences* before committing. Apex wraps the
  proposed updates in a `Database.Savepoint`, applies them, reads back derived state (forecast
  months, budget/rollup deltas, validation pass/fail), then `Database.rollback(sp)` — persists
  nothing. Scope the headline to the **forecast/budget shift** ("commits move +X h / $Y across
  these months"). Commit = the same path minus the rollback.

## Architecture
### Now — DH-side (zero metadata)
- **`DeliveryStagedChangeService`** (Apex, ≤36-char name so `...Test` ≤40):
  - `dryRun(List<SObject> proposed)` → savepoint → apply → capture derived summary (reuse
    `DeliveryHoursAnalyticsController` forecast for the months/$ delta) → `rollback` → return a
    `StagedChangePreviewDTO` (per-record diff + effects headline). All `WITH SYSTEM_MODE`.
  - `commit(List<SObject> proposed)` → single bulk `update` in one transaction; return result.
  - Global DTOs if returned to LWC; typed describe only; never assert AuraHandledException msg.
- **`deliveryPendingChanges`** LWC — generic review modal: takes a pending-change array, renders
  the diff table + the effects headline, Commit / Discard. No template ternaries (getters); info
  popover registered; `.js-meta.xml` description < 255 chars; placed where hosts invoke it.

### Long-term — NG substrate (don't fork)
The gantt-canvas "review pending changes" modal **extends NG's #28 modal primitive + the existing
`pendingBuffer`** (gantt edits/auto-schedule already stage as PATCHes with no DML). NG renders the
modal; **DH supplies the commit handler** (the #28 convention: in-app surface = NG-rendered,
persistence = host). DH adopts via bundle re-copy and wires `DeliveryStagedChangeService.commit`
as the handler. We do **not** copy the gantt buffer into DH.

## Build order (one PR, after the cart lands)
1. `DeliveryStagedChangeService` (dryRun + commit) + tests — zero metadata.
2. `deliveryPendingChanges` review-modal LWC + Jest — the reusable surface.
3. Wire DH-native edit surfaces to stage→preview→commit through it.
4. NG-side brief: extend #28 modal into "Review N pending changes" reading `pendingBuffer`;
   DH adopts the bundle and passes the commit handler. (Separate NG PR.)

## Sequencing
Build immediately **after** the checkout-cart PR lands — NOT in parallel: both touch the
info-popover registry + AdminHome FlexiPage, and concurrent agents would collide there and double
scratch-org burn. Ship staged-changes + cart + #28's re-copied bundles in **one release**.

## Reuses (nothing rebuilt)
Gantt `pendingBuffer` + PATCH dispatch · NG #28 modal primitive + `emit`/`on` · forecast engine
(the dry-run effects headline) · existing records (no new schema). The cart and this are the same
stage-then-commit pattern — one mental model.
