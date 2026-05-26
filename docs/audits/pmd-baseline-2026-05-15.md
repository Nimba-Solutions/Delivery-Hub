# PMD Baseline Audit — 2026-05-15

Read-only recon. Do **not** fix anything in this PR; this report only informs whether to keep refactoring `feat/slack-comment-sync` (PR #782) or to revisit the ruleset later.

## Method

```
sf scanner run --engine pmd --pmdconfig pmd-rules.xml \
  --target "force-app/main/default/classes" --json
```

- **Ruleset**: `pmd-rules.xml` — pulls `category/apex/default.xml` + `category/xml/default.xml` (all default Apex rules at default thresholds; PMD 7.11.0 via `@salesforce/sfdx-scanner`).
- **CI gate**: `.github/workflows/feature_test.yml` uses `mitchspano/sfdx-scan-pull-request@v0.1.16` with `severity-threshold: 4`. That fails the PR on **any** finding of severity 1-4 in the changed files. Every default Apex rule emits at sev 3 → effectively "any new finding fails."
- **Target population**: 277 `.cls` files in `force-app/main/default/classes`.

## Total violation count

- **137 violations** across **62 / 277** files (22% of classes have ≥1 finding).
- 215 / 277 classes (78%) come back **clean** at default thresholds.

## Violations by rule

| Count | Rule | Category |
| ---:  | --- | --- |
| 55 | ApexDoc | Documentation |
| 48 | AvoidGlobalModifier | Best Practices |
| 12 | CyclomaticComplexity | Design |
| 10 | StdCyclomaticComplexity | Design |
|  5 | ApexCRUDViolation | Security |
|  4 | NcssMethodCount | Design |
|  2 | ExcessiveClassLength | Design |
|  1 | NcssTypeCount | Design |

**Most-common rule: `ApexDoc` (55, 40% of all findings).** Almost all of those are concentrated in one file (see Top 10).

## Top 10 noisiest classes

| Violations | Class | Rule breakdown |
| ---: | --- | --- |
| 40 | `DeliveryDocumentController.cls` | ApexDoc:40 |
|  6 | `DeliverySlackInboundHandler.cls` | StdCyc:2, ApexDoc:2, Cyc:1, Ncss:1 |
|  6 | `DeliveryWorkItemController.cls` | ApexCRUDViolation:5, AvoidGlobal:1 |
|  5 | `DeliveryArchivalService.cls` | ApexDoc:5 |
|  5 | `DeliveryDashboardCardController.cls` | StdCyc:2, AvoidGlobal:1, Cyc:1, Ncss:1 |
|  4 | `DeliveryActivityFeedController.cls` | ApexDoc:3, AvoidGlobal:1 |
|  4 | `DeliveryDocActionRestApi.cls` | StdCyc:2, Cyc:2 |
|  4 | `DeliveryGanttController.cls` | StdCyc:2, ExcessiveClassLength:1, NcssTypeCount:1 |
|  4 | `DeliveryHubSyncService.cls` | Cyc:2, NcssMethodCount:2 |
|  3 | `DeliverySlackService.cls` | Cyc:2, AvoidGlobal:1 |

`DeliveryDocumentController.cls` alone (40 findings, all ApexDoc) accounts for **29%** of the entire repo's PMD debt.

## Comparison to PR #782's apex-scan failure

PR #782 added 9 findings against changed files (the gate trips on any sev-3 finding in changed code):

| Count | Rule | Where |
| ---: | --- | --- |
| 4 | ApexDoc | `DeliverySlackInboundHandler.cls:107` (×2), `WebhookSignatureVerifier.cls:91` (×2) |
| 2 | StdCyclomaticComplexity | `DeliverySlackInboundHandler.cls` — class avg=5 highest=12, method `handle` =12 |
| 2 | CyclomaticComplexity | `DeliverySlackInboundHandler.cls` `handle()` =13, `DeliverySlackService.cls` `postCommentBatch()` =11 |
| 1 | NcssMethodCount | `DeliverySlackInboundHandler.cls` `handle()` NCSS=65 |

Same rule mix as the codebase baseline (ApexDoc + Cyclomatic + Ncss). Nothing exotic.

## Is the existing codebase's average complexity above the threshold? (Calibration question)

**No — the threshold is not too tight for this codebase.** Evidence:

- Default per-method `CyclomaticComplexity` threshold is **10**. Across 277 classes, only **6 methods exceeded it** (values: 11, 12, 13, 13, 19, 25). That is a 2% method-level violation rate — well within "normal Apex codebase" range.
- Per-method offenders, in order: `getCardData`=25 (`DeliveryDashboardCardController`), `handleIncomingSync`=19 (`DeliveryHubSyncService`), `parseSignContextFromBody`=13 (`DeliveryDocActionRestApi`), `handle`=13 (`DeliverySlackInboundHandler` — new in #782), `updateWorkItemFields` ≤13 (`DeliveryGanttController`), `postCommentBatch`=11 (`DeliverySlackService` — new in #782).
- A cheap branch-decision proxy (count of `if/for/while/catch/when` per class) gives **median 6, p75=17, p90=29** across all 277 classes. Most classes are well-structured; the long tail is a handful of well-known monoliths (`DeliveryGanttController`=170 branches/1593 LOC, `DeliverySyncItemIngestor`=143/1075 LOC, `DeliveryWorkItemTriggerHandler`=77/681 LOC).

**Conclusion**: PR #782's `handle` and `postCommentBatch` methods genuinely sit in the noisy 2%. The bar is correctly calibrated for the existing codebase. The new code is the outlier, not the threshold.

## Recommendations for a future PMD cleanup sweep (NOT this PR)

Sequenced cheapest-to-richest. Each item is independently shippable.

1. **One-file ApexDoc sweep on `DeliveryDocumentController.cls`** — kills 40/137 findings (29%) in one PR. Pure Javadoc-style headers, zero behavioural risk. ~1h.
2. **`AvoidGlobalModifier` audit (48 findings)** — confirm each `global` is actually needed for a managed-package public surface or `@RestResource`. Where it isn't, downgrade to `public`. Many are likely vestigial. Where it IS needed, add a `@SuppressWarnings('PMD.AvoidGlobalModifier')` with a one-line "// kept global because: <reason>". ~3h. **Note**: per CLAUDE.md, when an Apex class is `global`, all inner return/param types must also be `global` — verify each downgrade doesn't cascade-break.
3. **`ApexCRUDViolation` triage on `DeliveryWorkItemController.cls`** — 5 findings at lines 50/162/224. Either add `Schema.sObjectType.X.isAccessible()` checks or `Security.stripInaccessible(...)` calls, or annotate with `WITH SECURITY_ENFORCED` on the SOQL. Real security finding, not stylistic. ~2h.
4. **Targeted refactor of the 6 over-complex methods** (cyc > 10): extract command-pattern dispatch maps from the long `if/else` ladders. The two highest are `getCardData`=25 (single switch on `cardType`) and `handleIncomingSync`=19. ~6h total.
5. **`ExcessiveClassLength` on `DeliveryGanttController` (1593 LOC, 170 branches)** — already known monolith. Defer to the planned gantt transaction-model refactor; do not crack it open just for PMD. Add `@SuppressWarnings('PMD.ExcessiveClassLength,PMD.NcssTypeCount')` on the class header until then.
6. **`ExcessiveClassLength` on `DeliverySyncItemIngestor` (1075 LOC)** — same call: suppress with a TODO ticket pointing at the depth-charge / sync-engine consolidation roadmap. Cracking it open now is high-risk, low-reward.

**Do not change `pmd-rules.xml` thresholds.** The defaults are well-matched to this codebase's median; relaxing them would mask real regressions in future PRs.

**Do not change `severity-threshold: 4` in `feature_test.yml`.** Lowering it (e.g., to 3) would let new ApexDoc findings slip through silently and the codebase's documentation debt would compound.

## What this means for PR #782

The PR is the right place to fix its own 9 findings — they are real (under-documented public method, two genuinely complex new methods). It is not a "refactor unrelated bystanders to make the new code merge" situation. Cheapest paths:

- `DeliverySlackInboundHandler.handle()` — extract the per-event-type branches into private helpers (`handleUrlVerification`, `handleEventCallback`, `handleMessageEvent`). Drops cyc from 13 → ~4 and NCSS from 65 → ~15.
- `DeliverySlackService.postCommentBatch()` — extract the per-comment Block Kit assembly into a `buildBlocksForComment(comment)` helper. Drops cyc from 11 → ~6.
- ApexDoc on `WebhookSignatureVerifier.verifySlack(...)` and `DeliverySlackInboundHandler.handle(...)` — add `@param` / `@return` headers. ~5 min each.

Estimated total fix time for PR #782: **~45 min**, all in two files. No baseline cleanup needed first.
