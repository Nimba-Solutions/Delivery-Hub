# Forecast Data-Readiness Query Pack — 2026-06-06

> **READ-ONLY — safe to run against production.** Every statement in this file is a `SELECT` (or a SELECT-only anonymous-Apex snippet). There is **no** `update` / `insert` / `delete` / `upsert` / `merge` anywhere. Nothing here mutates data.

## Purpose

The portfolio forecast number (Pacing & Forecast view, backed by `DeliveryHoursAnalyticsController.getPortfolioPacing`) is only as trustworthy as the WorkItem data feeding it. This pack surfaces the data gaps that make the forecast untrustworthy — unsized items, blown estimates, duplicate items, ownerless items — and diagnoses the **95-vs-99 "active item" count mismatch** between the board's gantt and the Pacing view by returning the actual record IDs on each side.

## How to run

- Run **the same pack on all three orgs** to expose divergence: `MF-Prod` (subscriber prod, invoices cut here is nimba — MF is the canonical work org), `nimba` (sandbox), `dh-prod` (separate dev hub). Counts will differ per org; that divergence is itself a signal.
- **Two forms are given where namespacing matters:**
  - **Plain form** — for a NON-namespaced org / Developer Console where DH is deployed unmanaged (e.g. a scratch org). Fields are bare: `EstimatedHoursNumber__c`.
  - **`delivery__`-prefixed form** — for a SUBSCRIBER org where DH is installed as the managed package (`MF-Prod`, `nimba`, `dh-prod` all have the namespace). Object + every custom field gets the `delivery__` prefix: `delivery__WorkItem__c`, `delivery__EstimatedHoursNumber__c`. Standard fields (`Id`, `Name`, `OwnerId`, `Owner.Name`, `CreatedDate`, `LastModifiedDate`) are **never** prefixed.
- Run via **Developer Console → Query Editor**, **`sf data query`**, or **Workbench**. For `sf data query` on a subscriber org use the `delivery__`-prefixed form, e.g.:
  `sf data query --target-org MF-Prod --query "SELECT ..."`

## Fields used (all confirmed against `docs/FIELD_NAMING.md` + `WorkItem__c` field metadata)

| Concept | Field API name | Confirmed | Notes |
|---|---|---|---|
| Estimate | `EstimatedHoursNumber__c` | ✅ field-meta exists; used in `getPortfolioPacing` | the "sized" field |
| Logged hours (roll-up) | `TotalLoggedHoursSum__c` | ✅ field-meta exists | Roll-Up Summary; gantt reads this. Pacing reads WorkLog directly instead |
| Logged hours (source) | `WorkLog__c.HoursLoggedNumber__c` | ✅ used in controller | summed by Pacing for the headline |
| Activation timestamp | `ActivatedDateTime__c` | ✅ field-meta exists | defines "active" on both board and pacing |
| Archived timestamp | `ArchivedDateTime__c` | ✅ field-meta exists | **Pacing excludes archived; board does NOT** — load-bearing for the count diff |
| Template marker | `TemplateMarkedDateTime__c` | ✅ field-meta exists | both sides exclude templates |
| Stage | `StageNamePk__c` | ✅ field-meta exists | Pacing excludes terminal stages; board default does NOT |
| Parent (root test) | `ParentWorkItemLookup__c` | ✅ field-meta exists | **Pacing scope = roots only (`= NULL`); board includes children** — load-bearing |
| Title / description | `BriefDescriptionTxt__c` | ✅ field-meta exists | the human "title"; gantt uses it as the row title |
| Auto-number name | `Name` | ✅ standard | the `WI-00xxx` style name |
| Assigned developer | `DeveloperLookup__c` / `DeveloperLookup__r.Name` | ✅ field-meta exists | gantt renders this as the row's "owner/developer" |
| Record owner | `OwnerId` / `Owner.Name` | ✅ standard | true Salesforce owner |

### Fields I could NOT confirm — FLAGGED

- **"Owner" is ambiguous.** There is **no** custom field literally named owner on `WorkItem__c`. Two candidates: the standard `OwnerId` (record owner) and the custom `DeveloperLookup__c` (assigned developer, which the gantt displays as the row owner). The "125 no owner" figure most likely means **`DeveloperLookup__c = NULL`** (unassigned work), because that is the field the timeline/board surface as the owner. **Section 4 gives BOTH** — run both and tell us which count is ~125 so we lock the definition.
- **There is no dedicated "scheduled" field.** "Scheduled" on the board is **not** a separate flag — the board's "Active scheduled" set is defined purely by `ActivatedDateTime__c != NULL` (+ not a template). Scheduling dates (`EstimatedStartDevDate__c` / `EstimatedEndDevDate__c`) are used only to *place* the bar, not to gate membership. This is confirmed in `DeliveryGanttController.getGanttData` / `getProFormaTimelineData`. So "Active scheduled" = "Active (activated, non-template)". Section 5 relies on this.

---

## Section 1 — Unsized active WorkItems (the "49 unsized")

**Purpose:** active items carrying no estimate (null or zero `EstimatedHoursNumber__c`). These contribute logged hours but **no target**, so they silently drag the forecast's budget-trajectory math. Healthy = small/zero count; unhealthy = a large pool (e.g. 49) of activated work with no sizing.

> Scope note: this uses the **board's "Active" definition** (`ActivatedDateTime__c != NULL`, non-template) — the broadest "active" set — so it catches every unsized item a human sees on the board. (If you want only Pacing-scope unsized items, add the root + archived + terminal-stage filters from Section 5A.)

**Count — plain:**
```sql
SELECT COUNT(Id)
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND (EstimatedHoursNumber__c = null OR EstimatedHoursNumber__c = 0)
```

**Count — `delivery__` (subscriber orgs):**
```sql
SELECT COUNT(Id)
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND (delivery__EstimatedHoursNumber__c = null OR delivery__EstimatedHoursNumber__c = 0)
```

**List (Id, Name, owner, logged) — plain:**
```sql
SELECT Id, Name, BriefDescriptionTxt__c, Owner.Name, DeveloperLookup__r.Name,
       EstimatedHoursNumber__c, TotalLoggedHoursSum__c, StageNamePk__c
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND (EstimatedHoursNumber__c = null OR EstimatedHoursNumber__c = 0)
ORDER BY TotalLoggedHoursSum__c DESC NULLS LAST
```

**List — `delivery__`:**
```sql
SELECT Id, Name, delivery__BriefDescriptionTxt__c, Owner.Name, delivery__DeveloperLookup__r.Name,
       delivery__EstimatedHoursNumber__c, delivery__TotalLoggedHoursSum__c, delivery__StageNamePk__c
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND (delivery__EstimatedHoursNumber__c = null OR delivery__EstimatedHoursNumber__c = 0)
ORDER BY delivery__TotalLoggedHoursSum__c DESC NULLS LAST
```

**Healthy vs unhealthy:** Healthy = 0–few; every active item should be sized. Unhealthy = a sizeable list (e.g. 49). Items at the top (most logged, still unsized) are the worst — real effort with no budget to compare against.

---

## Section 2 — Variance offenders (logged ≫ estimate)

**Purpose:** active, sized items where logged hours have blown past the estimate. These are the estimates that need truing — until they are re-sized, the forecast's "remaining estimate" cap is wrong (`getPortfolioPacing` caps forecast at `totalEstimatedHours - totalLoggedHours`, flooring negative remaining at 0, so over-budget items quietly stop contributing forward work).

> SOQL cannot compute or order by an arithmetic expression of two fields (`logged - estimate`) directly. There **is** a formula field — `HoursVarianceNumber__c` (confirmed on `WorkItem__c`) — and `BudgetVarianceNumber__c`. **Verify what `HoursVarianceNumber__c` computes** (sign/direction) on a couple of records before trusting its ordering; if its sign convention is the opposite of "overage", use the anonymous-Apex form below which computes overage explicitly.

**SOQL (uses the formula field for ordering) — plain:**
```sql
SELECT Id, Name, BriefDescriptionTxt__c, Owner.Name, DeveloperLookup__r.Name,
       EstimatedHoursNumber__c, TotalLoggedHoursSum__c, HoursVarianceNumber__c, StageNamePk__c
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND EstimatedHoursNumber__c != null
  AND EstimatedHoursNumber__c > 0
  AND TotalLoggedHoursSum__c > EstimatedHoursNumber__c
ORDER BY HoursVarianceNumber__c DESC NULLS LAST
```

**SOQL — `delivery__`:**
```sql
SELECT Id, Name, delivery__BriefDescriptionTxt__c, Owner.Name, delivery__DeveloperLookup__r.Name,
       delivery__EstimatedHoursNumber__c, delivery__TotalLoggedHoursSum__c,
       delivery__HoursVarianceNumber__c, delivery__StageNamePk__c
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND delivery__EstimatedHoursNumber__c != null
  AND delivery__EstimatedHoursNumber__c > 0
  AND delivery__TotalLoggedHoursSum__c > delivery__EstimatedHoursNumber__c
ORDER BY delivery__HoursVarianceNumber__c DESC NULLS LAST
```

> The `WHERE TotalLoggedHoursSum__c > EstimatedHoursNumber__c` comparison of two fields **is** legal in SOQL (field-to-field comparison is allowed in WHERE; it is only ORDER BY on an *expression* that is not). So the filter is exact; only the ordering leans on the formula field.

**Anonymous Apex (computes overage + ratio explicitly, debug-logs them) — plain:**
> Run in Developer Console → Debug → Open Execute Anonymous Window. SELECT-only; the only output is `System.debug`. On a subscriber org, prefix the object + fields with `delivery__` (see note after the snippet).
```apex
// READ-ONLY. No DML. Computes overage (logged - estimate) and ratio (logged / estimate),
// sorts by overage desc, prints the worst offenders to the debug log.
List<WorkItem__c> items = [
    SELECT Id, Name, BriefDescriptionTxt__c,
           EstimatedHoursNumber__c, TotalLoggedHoursSum__c, StageNamePk__c
    FROM WorkItem__c
    WHERE ActivatedDateTime__c != null
      AND TemplateMarkedDateTime__c = null
      AND EstimatedHoursNumber__c != null
      AND EstimatedHoursNumber__c > 0
      AND TotalLoggedHoursSum__c > EstimatedHoursNumber__c
];
// Build (overage, line) tuples and sort desc by overage.
List<Decimal> overages = new List<Decimal>();
Map<Decimal, List<String>> byOverage = new Map<Decimal, List<String>>();
for (WorkItem__c wi : items) {
    Decimal logged = wi.TotalLoggedHoursSum__c == null ? 0 : wi.TotalLoggedHoursSum__c;
    Decimal est = wi.EstimatedHoursNumber__c;
    Decimal overage = logged - est;
    Decimal ratio = (est == 0) ? null : (logged / est).setScale(2);
    String line = wi.Name + ' | est=' + est + ' logged=' + logged
        + ' overage=' + overage.setScale(2) + ' ratio=' + ratio + 'x'
        + ' | stage=' + wi.StageNamePk__c + ' | ' + wi.Id;
    if (!byOverage.containsKey(overage)) { byOverage.put(overage, new List<String>()); overages.add(overage); }
    byOverage.get(overage).add(line);
}
overages.sort();           // ascending
// print descending
for (Integer i = overages.size() - 1; i >= 0; i--) {
    for (String s : byOverage.get(overages[i])) { System.debug(LoggingLevel.ERROR, s); }
}
System.debug(LoggingLevel.ERROR, '=== variance offenders: ' + items.size() + ' ===');
```
> **Subscriber-org (managed) variant of the snippet:** replace `WorkItem__c` → `delivery__WorkItem__c` and each custom field with its `delivery__`-prefixed name (`delivery__EstimatedHoursNumber__c`, `delivery__TotalLoggedHoursSum__c`, `delivery__ActivatedDateTime__c`, `delivery__TemplateMarkedDateTime__c`, `delivery__BriefDescriptionTxt__c`, `delivery__StageNamePk__c`). Standard `Id`/`Name` stay bare.

**Healthy vs unhealthy:** Healthy = few items, low ratios (≤1.2x). Unhealthy = items at 2x–10x+ — those estimates are fiction and must be re-sized before the forecast means anything.

---

## Section 3 — Exact-name duplicate candidates

**Purpose:** WorkItems whose title collides — the same work entered twice (or thrice), inflating both the active count and any hours roll-up. Cowork confirmed live dupes (`QBAG-PARENT` ×2, `"Can't Save Page Layout Edits"` ×3) the audit missed.

### 3A — Exact-`Name` collisions (SOQL `GROUP BY ... HAVING`)
> `Name` is the auto-number, which is normally unique — so collisions here are unusual. The more useful collision is on the **title** (`BriefDescriptionTxt__c`). SOQL `GROUP BY` works on a text field; the catch is SOQL cannot `LOWER()`/`TRIM()` inside `GROUP BY`, so this only catches **byte-exact** title duplicates. Case/whitespace variants need 3B.

**By title, exact — plain:**
```sql
SELECT BriefDescriptionTxt__c, COUNT(Id) dupes
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND BriefDescriptionTxt__c != null
GROUP BY BriefDescriptionTxt__c
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

**By title, exact — `delivery__`:**
```sql
SELECT delivery__BriefDescriptionTxt__c, COUNT(Id) dupes
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND delivery__BriefDescriptionTxt__c != null
GROUP BY delivery__BriefDescriptionTxt__c
HAVING COUNT(Id) > 1
ORDER BY COUNT(Id) DESC
```

> **Note on `BriefDescriptionTxt__c` field type:** `GROUP BY` is only allowed on fields that are *groupable*. If `BriefDescriptionTxt__c` is a long-text/rich-text area, SOQL will reject `GROUP BY` on it (`field 'X' can not be grouped in a query call`). If that happens, **skip 3A and use 3B** (the anonymous-Apex grouper), which works regardless of field type. Run 3A first; if it errors with a "can not be grouped" message, that confirms you need 3B.

### 3B — Case/whitespace-insensitive title collisions (anonymous Apex)
> SOQL can't `LOWER()`/`TRIM()` in `GROUP BY`, so normalize in Apex. READ-ONLY; output is the debug log only. This is also the fallback when `BriefDescriptionTxt__c` is not groupable.

**Plain:**
```apex
// READ-ONLY. No DML. Groups active WorkItems by normalized title
// (trimmed, collapsed internal whitespace, lowercased) and prints groups with >1 member.
Map<String, List<WorkItem__c>> byNorm = new Map<String, List<WorkItem__c>>();
for (WorkItem__c wi : [
    SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
           ActivatedDateTime__c, DeveloperLookup__r.Name
    FROM WorkItem__c
    WHERE ActivatedDateTime__c != null
      AND TemplateMarkedDateTime__c = null
      AND BriefDescriptionTxt__c != null
    LIMIT 5000
]) {
    String norm = wi.BriefDescriptionTxt__c.trim().toLowerCase();
    norm = norm.replaceAll('\\s+', ' ');     // collapse runs of whitespace
    if (!byNorm.containsKey(norm)) { byNorm.put(norm, new List<WorkItem__c>()); }
    byNorm.get(norm).add(wi);
}
Integer dupGroups = 0;
for (String norm : byNorm.keySet()) {
    List<WorkItem__c> grp = byNorm.get(norm);
    if (grp.size() > 1) {
        dupGroups++;
        System.debug(LoggingLevel.ERROR, '--- DUP x' + grp.size() + ' : "' + norm + '"');
        for (WorkItem__c wi : grp) {
            System.debug(LoggingLevel.ERROR, '      ' + wi.Name + ' | ' + wi.Id
                + ' | stage=' + wi.StageNamePk__c
                + ' | dev=' + (wi.DeveloperLookup__r != null ? wi.DeveloperLookup__r.Name : '(none)'));
        }
    }
}
System.debug(LoggingLevel.ERROR, '=== ' + dupGroups + ' duplicate title groups ===');
```
> **Subscriber variant:** `WorkItem__c` → `delivery__WorkItem__c`; `BriefDescriptionTxt__c` → `delivery__BriefDescriptionTxt__c`; `StageNamePk__c` → `delivery__StageNamePk__c`; `ActivatedDateTime__c` → `delivery__ActivatedDateTime__c`; `TemplateMarkedDateTime__c` → `delivery__TemplateMarkedDateTime__c`; `DeveloperLookup__r` → `delivery__DeveloperLookup__r`. `Id`/`Name` stay bare.

**Healthy vs unhealthy:** Healthy = 0 dup groups. Unhealthy = any group with size>1. Expect to see `QBAG-PARENT` (x2) and `Can't Save Page Layout Edits` (x3) in the 3B output if those normalize-collide; if 3A misses them but 3B catches them, the difference is case/whitespace — which is exactly why 3B exists.

---

## Section 4 — No-owner active items (the "125 no owner")

**Purpose:** active items with no assignee. Ambiguous which "owner" — so run BOTH and tell us which lands near 125. (See the flagged note above: `DeveloperLookup__c` is the more likely "owner" because the board/timeline display it as such.)

### 4A — No assigned developer (`DeveloperLookup__c = NULL`) — most likely the "125"

**Count — plain:**
```sql
SELECT COUNT(Id)
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND DeveloperLookup__c = null
```
**Count — `delivery__`:**
```sql
SELECT COUNT(Id)
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND delivery__DeveloperLookup__c = null
```
**List — plain:**
```sql
SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, Owner.Name,
       EstimatedHoursNumber__c, TotalLoggedHoursSum__c
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND DeveloperLookup__c = null
ORDER BY CreatedDate DESC
```
**List — `delivery__`:**
```sql
SELECT Id, Name, delivery__BriefDescriptionTxt__c, delivery__StageNamePk__c, Owner.Name,
       delivery__EstimatedHoursNumber__c, delivery__TotalLoggedHoursSum__c
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND delivery__DeveloperLookup__c = null
ORDER BY CreatedDate DESC
```

### 4B — Record owner is an inactive/automation user (sanity cross-check)
> `OwnerId` is never null in Salesforce (every record always has an owner), so a literal "no `OwnerId`" query returns nothing. Instead check whether the **record owner is an inactive user** (orphaned ownership), which sometimes reads as "no owner" in a UI.

**Plain:**
```sql
SELECT Id, Name, Owner.Name, Owner.IsActive, StageNamePk__c
FROM WorkItem__c
WHERE ActivatedDateTime__c != null
  AND TemplateMarkedDateTime__c = null
  AND Owner.IsActive = false
ORDER BY Owner.Name
```
**`delivery__`:**
```sql
SELECT Id, Name, Owner.Name, Owner.IsActive, delivery__StageNamePk__c
FROM delivery__WorkItem__c
WHERE delivery__ActivatedDateTime__c != null
  AND delivery__TemplateMarkedDateTime__c = null
  AND Owner.IsActive = false
ORDER BY Owner.Name
```

**Healthy vs unhealthy:** Healthy = near-zero unassigned. Unhealthy = a large pool (e.g. 125) of active work with no developer — nobody is accountable, and the forecast attributes their hours to no one. **Tell us which of 4A/4B is ~125 so we lock the "owner" definition.**

---

## Section 5 — The 95-vs-99 count diagnosis (THE important one)

**The mismatch:** the board's gantt shows ~95 "Active scheduled" while the Pacing view shows ~99 "active items." These are two DIFFERENT filters over `WorkItem__c`. Below are the exact filters (read straight from source), queries returning **both sets**, and the **symmetric difference** so the gap is explained by real record IDs, not a guess.

### The two filters, exactly

**Pacing-active** — `DeliveryHoursAnalyticsController.getPortfolioPacing` → `queryActiveRootIds()` (the `rootCount` the Pacing headline shows):
- `ParentWorkItemLookup__c = NULL`  ← **roots only**
- `ActivatedDateTime__c != NULL`
- `ArchivedDateTime__c = NULL`  ← **excludes archived**
- `TemplateMarkedDateTime__c = NULL`
- `StageNamePk__c NOT IN ('Done','Cancelled','Closed','Rejected')`  ← **excludes terminal stages**
- `LIMIT 500` (cap; unlikely to bind here)

**Board-active** — `DeliveryGanttController.getGanttData(false)` / `getProFormaTimelineData(false)` (the bars the gantt renders when "show completed" is OFF):
- `TemplateMarkedDateTime__c = NULL`
- `ActivatedDateTime__c != NULL`
- *(NO root filter — children count too)*
- *(NO archived filter)*
- *(NO terminal-stage filter — a Done item still renders if it's activated & non-template)*

> **So the two are NOT the same "active."** Pacing counts only **root** items, archived-excluded, terminal-excluded. The board counts **every activated non-template item** including children, archived, and terminal-stage ones. The reason the numbers are *close* (95 vs 99) rather than wildly apart is that on this data most active items happen to be roots in non-terminal stages — but the deltas (archived roots, terminal-stage roots, child items, etc.) net out to the 4-item gap. The queries below pin down exactly which records.
>
> ⚠️ **Direction caveat:** by these filters you'd expect the **board** set (looser — adds children/archived/terminal) to be the *larger* one, yet the report says board≈95 < pacing≈99. That inversion is itself a finding — most likely the board number a human is reading is a **post-load client-side count** (e.g. NG hides terminal/decorated bars, or counts only one bucket) rather than the raw Apex row count. The queries return the **raw Apex-filter sets**; compare those to what each surface *displays* to see whether the discrepancy is in the data (these queries explain it) or in client-side rendering (then it's an LWC count, not a data gap). Either way the symmetric-difference IDs below localize it.

### 5A — Pacing-active set (root IDs the Pacing headline counts)
**Plain:**
```sql
SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, ActivatedDateTime__c,
       ArchivedDateTime__c, ParentWorkItemLookup__c
FROM WorkItem__c
WHERE ParentWorkItemLookup__c = null
  AND ActivatedDateTime__c != null
  AND ArchivedDateTime__c = null
  AND TemplateMarkedDateTime__c = null
  AND StageNamePk__c NOT IN ('Done','Cancelled','Closed','Rejected')
ORDER BY Name
```
**`delivery__`:**
```sql
SELECT Id, Name, delivery__BriefDescriptionTxt__c, delivery__StageNamePk__c, delivery__ActivatedDateTime__c,
       delivery__ArchivedDateTime__c, delivery__ParentWorkItemLookup__c
FROM delivery__WorkItem__c
WHERE delivery__ParentWorkItemLookup__c = null
  AND delivery__ActivatedDateTime__c != null
  AND delivery__ArchivedDateTime__c = null
  AND delivery__TemplateMarkedDateTime__c = null
  AND delivery__StageNamePk__c NOT IN ('Done','Cancelled','Closed','Rejected')
ORDER BY Name
```

### 5B — Board-active set (rows the gantt renders, show-completed OFF)
**Plain:**
```sql
SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, ActivatedDateTime__c,
       ArchivedDateTime__c, ParentWorkItemLookup__c
FROM WorkItem__c
WHERE TemplateMarkedDateTime__c = null
  AND ActivatedDateTime__c != null
ORDER BY Name
```
**`delivery__`:**
```sql
SELECT Id, Name, delivery__BriefDescriptionTxt__c, delivery__StageNamePk__c, delivery__ActivatedDateTime__c,
       delivery__ArchivedDateTime__c, delivery__ParentWorkItemLookup__c
FROM delivery__WorkItem__c
WHERE delivery__TemplateMarkedDateTime__c = null
  AND delivery__ActivatedDateTime__c != null
ORDER BY Name
```

### 5C — The four breakdown buckets that explain the gap (SOQL counts)
Run these counts; they enumerate exactly the records that are in one set but not the other.

**(i) In BOARD but NOT in PACING because they are CHILDREN** (board includes children, pacing is roots-only):
```sql
-- plain
SELECT COUNT(Id) FROM WorkItem__c
WHERE TemplateMarkedDateTime__c = null
  AND ActivatedDateTime__c != null
  AND ParentWorkItemLookup__c != null
```
```sql
-- delivery__
SELECT COUNT(Id) FROM delivery__WorkItem__c
WHERE delivery__TemplateMarkedDateTime__c = null
  AND delivery__ActivatedDateTime__c != null
  AND delivery__ParentWorkItemLookup__c != null
```

**(ii) In BOARD but NOT in PACING because they are ARCHIVED roots** (board keeps archived, pacing drops them):
```sql
-- plain
SELECT Id, Name, StageNamePk__c FROM WorkItem__c
WHERE TemplateMarkedDateTime__c = null
  AND ActivatedDateTime__c != null
  AND ParentWorkItemLookup__c = null
  AND ArchivedDateTime__c != null
```
```sql
-- delivery__
SELECT Id, Name, delivery__StageNamePk__c FROM delivery__WorkItem__c
WHERE delivery__TemplateMarkedDateTime__c = null
  AND delivery__ActivatedDateTime__c != null
  AND delivery__ParentWorkItemLookup__c = null
  AND delivery__ArchivedDateTime__c != null
```

**(iii) In BOARD but NOT in PACING because they are TERMINAL-stage roots** (board keeps Done/Cancelled/Closed/Rejected, pacing drops them):
```sql
-- plain
SELECT Id, Name, StageNamePk__c FROM WorkItem__c
WHERE TemplateMarkedDateTime__c = null
  AND ActivatedDateTime__c != null
  AND ParentWorkItemLookup__c = null
  AND ArchivedDateTime__c = null
  AND StageNamePk__c IN ('Done','Cancelled','Closed','Rejected')
```
```sql
-- delivery__
SELECT Id, Name, delivery__StageNamePk__c FROM delivery__WorkItem__c
WHERE delivery__TemplateMarkedDateTime__c = null
  AND delivery__ActivatedDateTime__c != null
  AND delivery__ParentWorkItemLookup__c = null
  AND delivery__ArchivedDateTime__c = null
  AND delivery__StageNamePk__c IN ('Done','Cancelled','Closed','Rejected')
```

> Every record in the PACING set (5A) is, by construction, also in the BOARD set (5B) — pacing's filters are strictly a superset of board's filters PLUS the root/archived/terminal restrictions. So there should be **no** record that is "pacing-active but not board-active." If 5D finds any such record, that is an anomaly worth flagging (e.g. a field value changed between the two reads, or one surface is reading a stale cache).

### 5D — Symmetric difference, computed exactly (anonymous Apex)
> READ-ONLY. Runs both filters in one transaction (no cache skew) and prints: count of each set, records ONLY in board, records ONLY in pacing. This is the definitive, ID-level explanation of the 95-vs-99 gap.

**Plain:**
```apex
// READ-ONLY. No DML. Computes the symmetric difference between the
// Pacing-active set and the Board-active set, by record Id.

// --- Pacing-active (mirrors queryActiveRootIds) ---
Map<Id, WorkItem__c> pacing = new Map<Id, WorkItem__c>([
    SELECT Id, Name, StageNamePk__c, ParentWorkItemLookup__c, ArchivedDateTime__c
    FROM WorkItem__c
    WHERE ParentWorkItemLookup__c = null
      AND ActivatedDateTime__c != null
      AND ArchivedDateTime__c = null
      AND TemplateMarkedDateTime__c = null
      AND StageNamePk__c NOT IN ('Done','Cancelled','Closed','Rejected')
    LIMIT 5000
]);

// --- Board-active (mirrors getGanttData(false)) ---
Map<Id, WorkItem__c> board = new Map<Id, WorkItem__c>([
    SELECT Id, Name, StageNamePk__c, ParentWorkItemLookup__c, ArchivedDateTime__c
    FROM WorkItem__c
    WHERE TemplateMarkedDateTime__c = null
      AND ActivatedDateTime__c != null
    LIMIT 5000
]);

System.debug(LoggingLevel.ERROR, '=== PACING count = ' + pacing.size()
    + ' | BOARD count = ' + board.size() + ' ===');

// In BOARD but NOT in PACING — explains why board is bigger (children/archived/terminal)
Integer onlyBoard = 0;
for (Id k : board.keySet()) {
    if (!pacing.containsKey(k)) {
        onlyBoard++;
        WorkItem__c w = board.get(k);
        String why = (w.ParentWorkItemLookup__c != null) ? 'CHILD'
            : (w.ArchivedDateTime__c != null) ? 'ARCHIVED'
            : 'TERMINAL-STAGE(' + w.StageNamePk__c + ')';
        System.debug(LoggingLevel.ERROR, 'ONLY-BOARD ' + w.Name + ' | ' + k + ' | reason=' + why);
    }
}
// In PACING but NOT in BOARD — should be empty; any hit is an anomaly
Integer onlyPacing = 0;
for (Id k : pacing.keySet()) {
    if (!board.containsKey(k)) {
        onlyPacing++;
        WorkItem__c w = pacing.get(k);
        System.debug(LoggingLevel.ERROR, 'ONLY-PACING(ANOMALY) ' + w.Name + ' | ' + k);
    }
}
System.debug(LoggingLevel.ERROR, '=== ONLY-BOARD = ' + onlyBoard
    + ' | ONLY-PACING(anomaly) = ' + onlyPacing + ' ===');
System.debug(LoggingLevel.ERROR, '=== symmetric difference = ' + (onlyBoard + onlyPacing) + ' ===');
```
> **Subscriber variant:** prefix the object + every custom field with `delivery__` (`delivery__WorkItem__c`, `delivery__StageNamePk__c`, `delivery__ParentWorkItemLookup__c`, `delivery__ArchivedDateTime__c`, `delivery__ActivatedDateTime__c`, `delivery__TemplateMarkedDateTime__c`). `Id`/`Name` stay bare.

**How to read the output:** `PACING count` should be ≈99 and `BOARD count` should be ≈95 (or whatever the surfaces show). The `ONLY-BOARD` lines, tagged with `reason=CHILD|ARCHIVED|TERMINAL-STAGE`, are the records that make the board set differ from pacing. `ONLY-PACING(ANOMALY)` should be 0 — pacing's filter is a subset of board's by construction, so any non-zero count means a record satisfied pacing's stricter filter but not board's looser one, which can only happen via cache skew or a field changing between reads (flag it). The `symmetric difference` line is the precise size of the disagreement; reconcile it against `|95 − 99| = 4` and the per-reason tally explains every record in that gap.

---

## Cross-org rollup

After running on all three orgs, the divergence table to fill in:

| Section | MF-Prod | nimba | dh-prod |
|---|---|---|---|
| 1. Unsized active | | | |
| 2. Variance offenders | | | |
| 3. Duplicate title groups | | | |
| 4A. No developer | | | |
| 4B. Inactive owner | | | |
| 5. Pacing count | | | |
| 5. Board count | | | |
| 5. Symmetric diff | | | |

Large per-org divergence in any row points at sync drift between the orgs (the hub-and-spoke return path) rather than a single-org data-entry gap.
