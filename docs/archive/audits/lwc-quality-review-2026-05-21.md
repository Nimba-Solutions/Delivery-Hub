# LWC Quality + Accessibility Review — 2026-05-21

## Headline

All 6 LWCs ship with **strong CLAUDE.md compliance** and **complete loading/error states**. Key accessibility gaps exist around aria-labels on icon-only buttons and modal focus management. Subscriber-org degradation is properly implemented in DevLoopGuide but incomplete in DatasetTemplates.

| Component | State Coverage | A11y | CLAUDE.md | Meta-XML | Critical Issues |
|---|---|---|---|---|---|
| `deliveryFeatureCockpit` | ✅ Full | ⚠ Icon labels missing | ✅ | ⚠ description tight | 0 |
| `deliveryFeatureCascadePreview` | ✅ Full | ✅ Dialog ARIA complete | ✅ | ✅ | 0 |
| `deliveryFeatureApprovalInbox` | ✅ Full | ⚠ Modal ESC keyboard | ✅ | ✅ | 0 |
| `deliveryFeatureOnboarding` | ✅ Full | ✅ Tab roles correct | ✅ | ✅ | 0 |
| `deliveryDevLoopGuide` | ✅ Full | ⚠ Icon labels | ✅ Subscriber badge | ✅ | 0 |
| `deliveryDatasetTemplates` | ✅ Full | ✅ | ✅ | ✅ | ⚠ subscriber gap |

All 6 LWCs are production-ready. Gaps below are polish items, not blockers.

---

## Per-LWC Findings

### `deliveryFeatureCockpit`

**State coverage:** loading (implicit via wire) ✅; error (`hasError` getter, `role="alert"` line 16) ✅; empty (`isEmpty` getter + illustration lines 23-29) ✅.

**A11y gaps:** line 40 `<lightning-icon icon-name={feature.icon}>` is missing `alternative-text`. Decorative but should be explicit per WCAG 2.1 AA. Modal close-button pattern at line 113 is correct (`<span class="slds-assistive-text">Close</span>`). Modal structure (lines 106-135) has `role="dialog"`, `aria-modal="true"`, `aria-labelledby`.

**CLAUDE.md compliance:** no template ternaries, `@api` booleans default to false, namespace tokens correct.

**Notable:** `refreshApex(this.wiredResult)` after toggle success; all `.catch()` paths land in toast or state mutation; `for:each` with `key={feature.key}`.

### `deliveryFeatureCascadePreview`

**State coverage:** isLoading spinner, hasError state, null-feature graceful path. All three states covered.

**A11y — exemplary:**
- Line 25: `<ul role="tree">`
- Line 30: `<li role="treeitem" aria-level={row.ariaLevel}>` (hierarchy depth)
- Lines 34-40: icons have `alternative-text={row.iconAlt}` + `title`
- No color-contrast issues (SLDS-native badges)

**CLAUDE.md compliance:** comment on line 11 explicitly notes "No ternaries in the template (LWC v62 limitation per CLAUDE.md)". Line 34: `@api hideFooterButtons = false` — inverted boolean per LWC1503.

**Meta-XML:** `<isExposed>false</isExposed>` correctly hidden (internal-only component).

### `deliveryFeatureApprovalInbox`

**State coverage:** loading, error, empty, plus chain-loading state.

**A11y:** modal at lines 95-158 has `role="dialog"`, `aria-modal="true"`, `aria-labelledby`. Refresh icon-button has `alternative-text="Refresh"`. Close button has icon + assistive text.

**Gap:** keyboard ESC not wired explicitly — relies on SLDS backdrop defaults. SLDS typically handles ESC but explicit `onkeydown` handler is more robust.

**Notable:** toast variants correct (success/error/warning); `refreshApex` after decision; note textareas cleaned on success.

### `deliveryFeatureOnboarding`

**State coverage:** all 4 states (loading, error, empty track, sub-section empty fallbacks via `lwc:elseif`).

**A11y — strong:** stepper tabs with `role="tablist" / role="presentation" / role="tab"`; radio quiz items use standard `<label class="slds-radio">`; checklist buttons have clear text labels. No icon-only elements without labels.

**CLAUDE.md compliance:** no template ternaries (all in getters lines 77-295), `@api trackDeveloperName = ''` defaults to empty string not boolean, namespace tokens.

**Notable:** `completedLessonNames` JSON parsing wrapped in try-catch; quiz answer tracking via immutable object spread; CSS uses `var(--lwc-colorBackgroundAlt, #fafaf9)` (SLDS-aware).

### `deliveryDevLoopGuide`

**State coverage:** loading, error, empty, **subscriber-org degraded** (badge lines 23-29 when `isSubscriberOrg === true`). Exemplary pattern.

**A11y gaps:** line 40 header icon missing `alternative-text` (decorative but should be explicit). Copy icon-buttons at lines 56 + 73 correctly labeled (`alternative-text="Copy command"` / `"Copy step command"`).

**Notable:** `navigator.clipboard.writeText()` with fallback toasts; subscriber detection via Apex return flag.

### `deliveryDatasetTemplates`

**State coverage:** loading, error, empty.

**Subscriber-org gap:** unlike DevLoopGuide, this component has **no Apex-level `isSubscriberOrg` flag** — relies on empty-state message fallback only. Users on a subscriber org see the full template list before reading "for package developers." UX friction, not functional.

**A11y:** copy button has full text label ("Copy Load Command") + icon, not icon-only. All interactive elements labeled.

**Notable:** elegant dual-wire pattern (lines 45-61) — conditional `featureIdForWire`/`workItemIdForWire` return null until parent object matches, leaving the wire inert.

---

## Cross-Cutting Issues

### 1. Icon labels on decorative/utility icons

**Affected:** `deliveryFeatureCockpit:40`, `deliveryDevLoopGuide:40`.

`<lightning-icon>` lacks `alternative-text`. Per SLDS, decorative icons can omit but explicit labels are WCAG 2.1 AA best practice.

**Severity:** Low.

### 2. Subscriber-org degradation inconsistency

**Affected:** `deliveryDatasetTemplates` vs `deliveryDevLoopGuide`.

DevLoopGuide returns `isSubscriberOrg` flag from Apex and renders a clear badge. DatasetTemplates relies on empty-state message fallback.

**Severity:** Low (UX friction, not functional).

### 3. Modal keyboard escape

**Affected:** `deliveryFeatureApprovalInbox` lines 95-158.

Approval chain modal wires close via button onclick but not keyboard `Escape`. SLDS often handles ESC via backdrop interaction; explicit handler is more robust.

**Severity:** Low.

---

## Top 3 Fixes

### Fix 1: Add `alternative-text` to decorative icons
- Scope: `deliveryFeatureCockpit.html:40`, `deliveryDevLoopGuide.html:40`
- Effort: 5 min (2 one-line edits)
- Severity: Low

### Fix 2: Align DatasetTemplates subscriber-org UX with DevLoopGuide
- Scope: `deliveryDatasetTemplates.js` + `DeliveryDatasetController.cls`
- Effort: 30 min (Apex returns `isSubscriberOrg`, JS getter, conditional render)
- Severity: Low (UX consistency)

### Fix 3: Wire ESC handler on the approval-chain modal
- Scope: `deliveryFeatureApprovalInbox.js` — add `onkeydown` on the modal container
- Effort: 5 min
- Severity: Low

---

## Summary

**Strengths:** complete state coverage across all 6 LWCs; strong CLAUDE.md compliance (no ternaries, namespace tokens, boolean handling); robust error handling on imperative Apex calls; exemplary modal ARIA (cockpit + cascade); subscriber-org awareness established in DevLoopGuide.

**Gaps:** decorative-icon labels (WCAG AA polish); DatasetTemplates subscriber-org consistency; explicit modal ESC handlers.

**Bottom line:** all 6 LWCs are production-ready. The three Top Fixes total ~40 minutes and can ship as a single polish PR when convenient — not blocking.
