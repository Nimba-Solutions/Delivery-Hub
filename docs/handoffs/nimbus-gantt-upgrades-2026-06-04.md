# nimbus-gantt — Upgrade Requests (from Delivery Hub usage)

**Date:** 2026-06-04
**Source:** Live Delivery Hub usage of the Timeline tab (`deliveryProFormaTimeline` mounts
`window.NimbusGanttApp` against `WorkItem__c` data). Issues surfaced by Glen while navigating a
real board. **DH integration version baseline:** NG ~0.190.x (engine `window.NimbusGantt`, app shell
`window.NimbusGanttApp`).
**Audience:** nimbus-gantt repo (engine + v10 template shell). Items tagged **[NG]** need engine/shell
changes; **[DH]** can be done in the host LWC; **[NG+DH]** need an engine hook the host then consumes.

The DH integration points referenced below all live in
`force-app/main/default/lwc/deliveryProFormaTimeline/deliveryProFormaTimeline.js`.

---

## 1. Right-click hit-detection is unreliable **[NG]**

**Symptom (Glen):** "When I right-click… sometimes it does, sometimes it doesn't detect that I was
actually over [a bar] when I was."

**Where:** DH installs its own document-level `contextmenu` listener (`handleCanvasContextMenu`)
because NG's `onTaskContextMenu` never fires under Salesforce LWS (the `document` captured inside the
IIFE is sandboxed). DH then calls `handle.taskAt(e.clientX, e.clientY)` (NG 0.185.32) to hit-test
which task the cursor is over. When `taskAt` returns null for a point that is visibly over a bar,
the menu doesn't open.

**Ask:**
- Tighten `taskAt(x, y)` precision. Likely causes to check: row vertical padding/anti-aliasing gaps
  counted as "miss"; scroll-offset or device-pixel-ratio not factored into the hit-rect math;
  the bar's hit-rect being the visual bar width only (no vertical tolerance for the row band).
- Recommend `taskAt` hit-test against the **full row band** (row height), not just the rendered bar
  rectangle, with a few px of tolerance — a user right-clicking anywhere on a task's row clearly
  means that task.
- Expose an optional `taskAt(x, y, { tolerancePx })` so the host can widen the target.

**Acceptance:** right-clicking anywhere on a visible task row opens the task context menu 100% of the
time at 100%/125%/150% browser zoom and when the chart is scrolled.

---

## 2. Right-click zone is ambiguous: "move" vs "create" vs "task menu" **[NG]**

**Symptom (Glen):** "When I'm showing the [drag/handover] thing, it should be right-clicking to
create things… if it's showing the move one, that's the issue there." The menu that appears depends
on a hover affordance (drag/move handle) that the user can't reliably predict.

**Where:** NG 0.189.x zone-aware context menu. DH wires `contextMenu.onContextMenu` (customize),
`onCreateTask` (canvas-empty → new task), `onTaskAction`, `onDateAction`, `onDependencyAction`. When
the cursor is over a drag/move affordance vs the bar body vs empty canvas, NG resolves a different
zone — and the resolution feels nondeterministic to the user.

**Ask:**
- Make zone resolution **deterministic and visible**: the cursor/affordance under the pointer should
  unambiguously signal which right-click menu will appear (bar → task menu; empty canvas → create;
  date header → date menu; dependency line → dependency menu).
- The transient move/drag handle should **not** swallow or change the right-click zone — right-click
  over a bar is always the task menu regardless of whether the move handle is currently shown.
- Expose the resolved zone in the `onContextMenu(hit, pos)` payload (`hit.zone`) so the host can
  confirm/branch, and so DH can log mismatches.

**Acceptance:** the right-click menu is predictable from what's visually under the cursor; the move
handle never causes a "create"/"move" menu when the pointer is over a task bar.

---

## 3. Task identity isn't visible without clicking through **[NG+DH]**

**Symptom (Glen):** "Mouseovers don't make it easy for me to see what the work item [is]. I need the
task ID / some unique identifier in there so I can reference it when I'm navigating around."

**Where:** DH's hover tooltip (`_handleTaskHover` → `_showTooltip`) currently renders only
`"{title} — {truncated 200-char description}"`. There is no stable identifier (WorkItem name/number
or record Id) shown on hover; the user must open the DetailPanel to get it. NG fires
`onTaskHover(taskId|null)` once per row entry/leave.

**Ask:**
- **[DH, immediate]** Add the WorkItem identifier (Name, e.g. `WI-01234`) to the tooltip's top line.
  This is a host-side tooltip change — see §4 for the full redesign.
- **[NG]** Pass the **full task object** (or at least `{id, name, externalId}`) to `onTaskHover`,
  not just the bare `taskId`. Today DH re-looks-up the task in its local array on every hover; a
  richer payload removes the lookup and lets the host render a rich tooltip without a map miss.
- **[NG]** Optionally render the task identifier inline on/beside the bar at sufficient zoom (a
  label slot), so identity is visible without hovering at all.

**Acceptance:** the WorkItem identifier is visible on hover (and ideally on the bar), copyable, and
matches the DetailPanel.

---

## 4. Tooltip review + redesign ideas (Glen: "review the tooltips and think about other ways to improve")

**Current state** (`_handleTaskHover`/`_showTooltip`): a single body-level `<div>` that follows the
cursor, dark theme, shows `title — desc(200)`. Plain text (`textContent`), no structure, no identity,
no metrics, no actions.

**Proposed richer tooltip** — most of this is **[DH]** (host owns tooltip content); a couple need
**[NG]** hooks noted inline:

| Add | Why | Notes |
|---|---|---|
| **WorkItem identifier** (Name + record link) | Glen's core ask — reference/navigate | [DH]; copyable; deep-links via existing `recordUrlTemplate` |
| **Stage** + **priority group** (NOW/NEXT/Proposed) | Triage context at a glance | [DH] from `_tasks` |
| **Hours: logged / estimated + pacing %** | This is the forecasting story — show on hover | [DH]; ties to `BudgetUtilizationPct__c` / pills color (green/amber/red) |
| **Dates** (start → end) + **ETA / overdue** flag | Schedule context | [DH] |
| **Assignee / developer** | "Who's on it" | [DH] from `DeveloperLookup__r.Name` |
| **Blocked indicator** (predecessor count) | Surface blockers without opening | [DH] from `_dependencies` |
| **Structured layout** (title row + key/value grid), not one text blob | Readability | [DH]; switch `textContent` → safe structured DOM (escape values) |
| **Anchor to the bar**, not just cursor; flip near viewport edges | Cursor-follow can occlude the bar/cover content | [DH] for anchor; **[NG]** to expose the hovered bar's screen rect in the hover payload |
| **Hover intent delay** (~150–250ms) + fade | Avoid flicker when sweeping across rows | [DH] |
| **Keyboard / a11y**: dismiss on Escape, `role="tooltip"`, not pointer-only | Accessibility | [DH]; **[NG]** keyboard focus model for bars |
| **Optional quick-actions** on a "pinned" hover (open, copy ID, chat) | Reduce click-throughs | [DH]; or promote to the DetailPanel |

**NG-side enablers that make the above cleaner:**
- Richer `onTaskHover` payload (full task object + bar screen-rect) — see §3.
- A **native tooltip slot** / `tooltipRenderer(task) => HTMLElement|string` hook so hosts can inject
  rich content through the engine instead of maintaining a parallel document-level tooltip div
  (which is what DH does today specifically because the LWS sandbox blocks NG's own handlers).

---

## 5. Other improvements observed in use (lower priority)

- **[NG]** LWS resilience: DH had to install its own `contextmenu` listener + cursor tracker because
  NG's `document`-scoped handlers don't fire under Salesforce Lightning Web Security. A documented
  "host-driven input" mode (engine accepts host-forwarded pointer events / exposes `taskAt`,
  `dateAt`, `dependencyAt` hit-testers) would make every Salesforce integration more robust. DH
  already leans on `taskAt`; rounding out the family would let DH stop reverse-engineering zones.
- **[NG]** Confirm `onTaskHover` fires on **leave** reliably (null payload) so tooltips always
  dismiss — stale tooltips were part of the "hard to navigate" feeling.
- **[NG]** Drag/move affordance visibility: make the move handle appear only on deliberate hover
  intent, so it doesn't flicker and change perceived right-click behavior (ties to §2).

---

## Summary for the NG side
1. **`taskAt` reliability** (full-row hit band + zoom/scroll/DPR correctness) — §1, top priority.
2. **Deterministic, visible right-click zones**; move handle never hijacks the bar's menu — §2.
3. **Richer `onTaskHover` payload** (full task + bar rect) and an optional **tooltip slot** — §3/§4.
4. Host-driven-input mode for LWS; reliable hover-leave — §5.

DH will, in parallel, ship the **tooltip redesign** (§4) host-side — the identifier line is the
immediate win and needs no engine change.
