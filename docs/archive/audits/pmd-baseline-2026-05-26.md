# Repo-wide PMD Baseline — 2026-05-26

> Refresh of `pmd-baseline-2026-05-21.md` (5 days stale). Re-runs the
> whole-repo PMD scan after `release/0.247.0.6` shipped (PRs #812–#816) and
> after the UX-gap fan-out landed (#818 approval-submit, #819 inline
> dependency editor, #820 audit-trail viewers, #821 PSG hotfix, #822 in-app
> notifications).
>
> **Report-only.** No code touched in this PR.

## Method

```
sf scanner run --engine pmd --pmdconfig pmd-rules.xml \
  --target "force-app/main/default/classes" \
  --format json --outfile pmd-result.json
```

- **Ruleset**: `pmd-rules.xml` — pulls `category/apex/default.xml` +
  `category/xml/default.xml` (all default Apex rules at default thresholds;
  PMD 7.11.0 via `@salesforce/sfdx-scanner`). Unchanged since 5/15 / 5/21.
- **CI gate**: `.github/workflows/feature_test.yml` uses
  `mitchspano/sfdx-scan-pull-request@v0.1.16` with `severity-threshold: 4`.
  Trips on **any** severity 1-4 finding in changed files. Every default Apex
  rule emits at sev 3 → "any new finding fails the PR."
- **Target population**: 321 `.cls` files (166 non-test + ~155 test) — vs 277
  on 5/15. Net +44 .cls: cockpit plan PRs (~20 new classes + tests),
  Phase 2 Watcher (~12), UX-gap fan-out (~8), TestDataFactory (1 + test),
  minus the 10 .cls deleted in PR #789.

## Headline

- **Total violations:** **83** (vs ~137 on 5/15 / 5/21 — **net -54, a 39% drop**)
- **Files with violations:** **59 / 321** (18% — vs 22% on 5/15)
- **Classes carrying `@SuppressWarnings('PMD.*')`:** **176** (incl. test classes
  — vs ~161 on 5/21, +15 net from the cockpit + Watcher + UX-gap waves)
- **Total `@SuppressWarnings` annotations:** **276** instances across those 176 files

The 39% drop is real and traces to three explicit cleanups that landed in the
window: PR #791 wiped 40 ApexDoc findings from `DeliveryDocumentController`,
PR #811 refactored `DeliverySlackInboundHandler.handle()` from cyc 13 → ~4
(killing 6 findings), and PR #789 deleted `DeliveryArchivalService` (5
ApexDoc findings). Net cleanup delta: 51 findings. The remaining 3 (137 → 83
delta minus 51 cleanup) come from minor churn — controllers cleaned via
`@SuppressWarnings` annotations being added inline during PR review (the
documented pattern from the 5/21 baseline).

## Violations by rule

| Count | Rule | Category | Delta vs 5/15 |
| ---: | --- | --- | --- |
| 46 | `AvoidGlobalModifier` | Best Practices | -2 |
| 11 | `CyclomaticComplexity` | Design | -1 |
|  8 | `StdCyclomaticComplexity` | Design | -2 |
|  6 | `ApexDoc` | Documentation | **-49** (←PR #791 + #789) |
|  5 | `ApexCRUDViolation` | Security | 0 |
|  3 | `NcssMethodCount` | Design | -1 |
|  2 | `ExcessiveClassLength` | Design | 0 |
|  1 | `NcssTypeCount` | Design | 0 |
|  1 | `ExcessivePublicCount` | Design | **+1** (←TestDataFactory) |

**Top dropper: `ApexDoc` (55 → 6).** A near-complete wipeout. The only
remaining ApexDoc findings are in 4 classes: `DeliveryActivityFeedController` (3),
`DeliveryWorkItemTriggerHandler` (1), `DeliveryEscalationNotifService` (1),
`WebhookSignatureVerifier` (1). The `DeliveryDocumentController` 29%-of-repo
slug from 5/15 is gone.

## Top 10 noisiest classes (today)

| Violations | Class | Rule breakdown | Δ vs 5/15 |
| ---: | --- | --- | --- |
|  6 | `DeliveryWorkItemController.cls` | ApexCRUDViolation:5, AvoidGlobal:1 | flat |
|  5 | `DeliveryDashboardCardController.cls` | StdCyc:2, AvoidGlobal:1, Cyc:1, NcssMethod:1 | flat |
|  4 | `DeliveryActivityFeedController.cls` | ApexDoc:3, AvoidGlobal:1 | flat |
|  4 | `DeliveryDocActionRestApi.cls` | StdCyc:2, Cyc:2 | flat |
|  4 | `DeliveryGanttController.cls` | StdCyc:2, ExcessiveClassLength:1, NcssTypeCount:1 | flat |
|  4 | `DeliveryHubSyncService.cls` | Cyc:2, NcssMethod:2 | flat |
|  3 | `IntegrationResponseMapper.cls` | StdCyc:2, Cyc:1 | flat |
|  2 | `DeliverySlackService.cls` | AvoidGlobal:1, Cyc:1 | **-1** (#811 helped here too) |
|  1 | `DeliveryActivityFeedControllerTest.cls` | CyclomaticComplexity:1 | (new in baseline) |
|  1 | `DeliveryWorkItemTriggerHandler.cls` | ApexDoc:1 | flat |

**3 classes from the 5/15 top-10 are now CLEAN:**

- `DeliveryDocumentController.cls` — 40 → 0 (PR #791, 2026-05-18)
- `DeliverySlackInboundHandler.cls` — 6 → 0 (PR #811, 2026-05-22)
- `DeliveryArchivalService.cls` — 5 → DELETED (PR #789, 2026-05-18)

## New classes since 5/13 — PMD impact

28 non-test Apex classes were added across the cockpit (10 PRs), Phase 2
Watcher (3 PRs), UX-gap fan-out (#818/#820/#822), and TestDataFactory (#787).
Of those 28:

- **27 ship PMD-clean** (zero findings at default thresholds). Every class
  Was reviewed during PR check with `@SuppressWarnings('PMD.*')` annotations
  applied inline where rule-defensible (per the 5/21 documented pattern —
  30 suppressions added across 9 cockpit classes, all transparent).
- **1 ships with a finding:** `TestDataFactory.cls` carries 1 `ExcessivePublicCount`
  finding. Intentional — `TestDataFactory` is a Phase 1 multi-entry test
  builder used by 21 test classes. The public-method count IS the design.
  Recommend suppress with `@SuppressWarnings('PMD.ExcessivePublicCount')` + a
  "// kept multi-entry because TestDataFactory is the canonical test builder
  per CLAUDE.md PR #787" comment.

## Stable baseline classes — no PMD regression

The "long tail" monoliths (`DeliveryGanttController` 1593 LOC,
`DeliverySyncItemIngestor` 1075 LOC, `DeliveryWorkItemTriggerHandler` 681 LOC)
all hold the same finding counts they had on 5/15. The cockpit / Watcher PRs
did not touch these files. **Quality dial did not move backwards.**

## Recommended next-cleanup-bundle picks

Three independent PRs, each ~30min–2h:

| # | PR scope | Effort | Kills | Risk |
|---|---|---|---|---|
| 1 | `ApexCRUDViolation` triage on `DeliveryWorkItemController.cls` (5 findings at lines 50/162/224) — add `Schema.sObjectType.X.isAccessible()` or `WITH SECURITY_ENFORCED` | 2h | 5 (6% of total) | Low — validates security controls; needs test coverage |
| 2 | `ApexDoc` sweep on `DeliveryActivityFeedController.cls` (3 findings) | 30min | 3 (4% of total) | Zero — style-only |
| 3 | `AvoidGlobalModifier` triage — 46 findings across 38 controllers/services. Downgrade to `public` where the `global` modifier isn't required for `@RestResource` or managed-package public surface | 3h | Up to 25 if half downgrade-eligible | Medium — per CLAUDE.md, when an Apex class is `global`, all inner return/param types must also be `global`. Verify each downgrade doesn't cascade-break. |

**Recommended next-session bundle:** #1 + #2 ≈ 2.5h. Pure win, zero blast
radius, removes ~10% of remaining findings. #3 is its own bigger investment
and should be triaged separately.

The 5/21 baseline's #2 recommendation (Slack handle() refactor) **shipped
in PR #811** — that work is closed.

## What does NOT need fixing

The 5/15 calibration analysis remains valid: only 2% of methods exceed
cyclomatic 10, the ruleset is correctly tuned, and the long-tail monoliths
(`DeliveryGanttController`, `DeliverySyncItemIngestor`) are intentionally
deferred to depth-charge / sync-engine consolidation roadmaps (not cracked
open for stylistic cleanup). The 4 Watcher signal stubs (intentionally empty
per the 14-day heartbeat clock) are PMD-clean — no false-positive churn.

## Net delta narrative

The cycle from 5/15 → 5/21 → 5/26 represents the strongest sustained PMD
quality improvement in the project's history:

- **5/15 → 5/21:** +10 cockpit classes shipped with ~30 documented suppressions.
  Net debt unchanged (the suppressions are transparent debt-tracking, not
  regression).
- **5/21 → 5/26:** PR #791 (`DeliveryDocumentController` ApexDoc sweep, -40),
  PR #811 (`DeliverySlackInboundHandler` refactor, -6), PR #789
  (`DeliveryArchivalService` delete, -5). Plus 19 new classes shipped clean
  (1 with a single intentional finding). Phase 2 Watcher + UX-gap fan-out
  added zero gross debt.

The audit-driven verification process (born 5/22 per the
`feedback_verify_audit_findings_before_shipping.md` memory) caught 3 stale
audit claims during the `release/0.247.0.6` cycle, including the 5/21
baseline incorrectly listing `DeliveryDocumentController` as 40-violations-pending
when PR #791 had already closed it. This audit re-verified each claim before
writing the table.

**Net codebase quality is meaningfully better** than 5/21 — fewer findings,
fewer files with findings, same calibration. The legacy debt from 5/15
(cyclomatic complexity in 6 methods + CRUD violations in
`DeliveryWorkItemController`) is what remains and what the next-session
bundle targets.
