# getName() vs getLocalName() Per-Callsite Discretion Audit — 2026-05-26

> Closes finding #3 from `docs/audits/code-quality-audit-2026-05-26.md`
> ("Apex `getDescribe().getName()` where `getLocalName()` is cleaner — 9
> across 7 files — P2 cosmetic").
>
> Reference memory:
> `~/.claude/projects/C--Projects-Delivery-Hub/memory/feedback_get_local_name_vs_get_name_nuance.md`
>
> CLAUDE.md says "`getLocalName()` not `getName()` for field/object API
> names in managed package context." That rule is correct as a default
> but overstates the case. Per the memory, two patterns LEGITIMATELY
> require `getName()`:
>
> 1. **Dynamic SOQL string-building** — `Database.query('SELECT Id FROM '
>    + Foo__c.SObjectType.getDescribe().getName())` needs the
>    namespace-prefixed form. `getLocalName()` here breaks subscriber-org
>    SOQL.
> 2. **Lightning record URL construction** — `/lightning/r/' +
>    sobj.getName() + '/' + recordId + '/view` needs the prefixed form
>    to navigate correctly in subscriber installs.
>
> This audit walks each of the 9 (actually 13 — the 5/26 code-quality
> audit table consolidated multiple lines per file) callsites and applies
> per-callsite discretion: migrate to `getLocalName()` where the call
> context only needs the bare form; KEEP `getName()` with an inline
> justification comment where the call is load-bearing.

## Executive summary

| Bucket | Count |
|---|---|
| Production `.getName()` callsites on `SObjectType` / `DescribeFieldResult` | **13** |
| Migrated to `getLocalName()` | **10** |
| Kept on `getName()` (load-bearing) | **3** |
| Ambiguous (flagged for follow-up) | **0** |

`UserInfo.getName()` callsites (7) are out of scope — they return the
running user's display name, not an API name, so the
`getName()`/`getLocalName()` discretion doesn't apply.

One test-file callsite (`DeliveryWorkItemTriggerHandlerTest.cls:465`)
compares against the literal `'User'` (standard object — no namespace
either way), so the migration is moot. Left unchanged.

## Per-callsite table

### KEPT on `getName()` (load-bearing — do NOT migrate)

| File:line | Pattern | Reason |
|---|---|---|
| `DeliverySyncItemIngestor.cls:694` | `'SELECT Id FROM ' + type.getDescribe().getName() + ' WHERE Id = :candidateId LIMIT 1'` | **Dynamic SOQL** — the namespaced object name is required for the query to resolve in the packaging org and in subscriber installs. `getLocalName()` here would break subscriber-side validation. |
| `DeliverySyncItemIngestor.cls:985` | `'/lightning/r/' + entity.getSObjectType().getDescribe().getName() + '/' + entity.Id + '/view'` | **Lightning record URL** — `/lightning/r/delivery__NetworkEntity__c/<id>/view` resolves in subscriber installs; the bare form 404s. |
| `DeliveryGanttController.cls:859` | `byAnyName.put(dfr.getName().toLowerCase(), sf)` | **INTENTIONAL 3-form index** — adjacent to `byAnyName.put(mapKey.toLowerCase(), sf)` and `byAnyName.put(dfr.getLocalName().toLowerCase(), sf)`. The whole point is to accept all 3 input forms (map-key, bare, namespaced) from LWC callers. Removing `getName()` narrows the accepted-input set. |

Each KEPT callsite was annotated with an inline comment in this PR
documenting the discretion, so future mechanical-replace passes don't
silently regress them.

### MIGRATED `getName()` → `getLocalName()` (safe — bare form works equally well)

| File:line | Context | Reason migration is safe |
|---|---|---|
| `DeliveryContentDocLinkTriggerHandler.cls:69` | `cdl.LinkedEntityId.getSObjectType().getDescribe().getLocalName()` (was `:65`) | Result is consumed by `sObjName.endsWithIgnoreCase('WorkItem__c')`. Both forms (`WorkItem__c` and `delivery__WorkItem__c`) satisfy the predicate. |
| `DeliveryCsvImportController.cls:179` | `entry.put('apiName', dfr.getLocalName())` (was `:175`) | LWC consumer (`deliveryCsvImport.js`) displays this in dropdown labels (`${f.label} (${f.apiName})`) and uses it as an internal lookup key in `apiToApi` (consistent round-trip). The downstream `resolveField()` is namespace-tolerant. Migration cleans up `delivery__` prefix leaking to admins. |
| `DeliveryCsvImportController.cls:244` | `wi.put(dfr.getLocalName(), coerceValue(dfr, val))` (was `:240`) | `SObject.put()` accepts both bare and namespaced forms identically. |
| `DeliveryCsvImportController.cls:248` | `'" for field ' + dfr.getLocalName() + ': '` (was `:244`) | Debug log; bare form is cleaner. |
| `DeliveryHubCommentController.cls:120` | `... + type.getDescribe().getLocalName()` (was `:117`) | User-facing `AuraHandledException` message; bare name reads cleaner than `delivery__WorkItem__c` to subscriber admins. |
| `DeliverySyncEngine.cls:359` | `String name = rec.getSObjectType().getDescribe().getLocalName()` (was `:357`) | `name` is used in `endsWithIgnoreCase('WorkItem__c')` checks below. Both forms satisfy the predicate. |
| `DeliverySyncEngine.cls:400` | Debug log inside `WARN` (was `:396`) | Diagnostic log; bare form is cleaner. |
| `DeliverySyncEngine.cls:413` | `String fullApiName = rec.getSObjectType().getDescribe().getLocalName()` (was `:408`) | Result is passed through `.replace('delivery__', '')` to derive `cleanName`. Migration makes the `.replace()` a no-op safety net (kept for defense in depth). `ObjectTypePk__c` stores the bare form. |
| `DeliverySyncItemIngestor.cls:217` | `castId.getSobjectType().getDescribe().getLocalName().endsWithIgnoreCase('WorkItem__c')` (was `:215`) | `endsWithIgnoreCase` works either way. |
| `DeliverySyncItemIngestor.cls:570` | `stripNamespace(type.getDescribe().getLocalName())` (was `:565`) | `stripNamespace` becomes a no-op safety net (kept for defense in depth). |
| `DeliverySyncItemIngestor.cls:648` | `stripNamespace(type.getDescribe().getLocalName())` (was `:644`) | Same as :570 (sibling function). |
| `DeliverySyncItemIngestor.cls:796` | `endsWithIgnoreCase('WorkItem__c')` paired (was `:784`) | `endsWithIgnoreCase` works either way. |
| `DeliverySyncItemIngestor.cls:820` | `endsWithIgnoreCase('WorkItem__c')` paired (was `:807`) | `endsWithIgnoreCase` works either way. |
| `DeliverySyncItemPendingResolver.cls:278` | `endsWithIgnoreCase('WorkItem__c')` paired (was `:276`) | `endsWithIgnoreCase` works either way. |

(Line numbers post-migration. Original audit-2026-05-26 line numbers
were pre-migration.)

### AMBIGUOUS (flagged for follow-up)

**None.** Every callsite was unambiguously classifiable as either
load-bearing-keep or safe-to-migrate after manual context inspection.

## Verification

- All 10 migrated callsites use the result either in `endsWithIgnoreCase`,
  `SObject.put()` (which accepts both forms), debug logs, user-facing
  error messages, or as the input to `stripNamespace()`/`.replace()`
  (which become defense-in-depth no-ops after migration).
- The 3 KEPT callsites each have an inline annotation comment explaining
  why `getName()` is required, citing the
  `[[get-local-name-vs-get-name-nuance]]` memory by name for future
  maintainers.
- Existing test suite (`DeliveryCsvImportControllerTest`,
  `DeliverySyncEngineTest`, `DeliverySyncItemIngestorTest`,
  `DeliverySyncItemPendingResolverTest`,
  `DeliveryContentDocLinkTriggerHandlerTest`,
  `DeliveryHubCommentControllerTest`, `DeliveryGanttControllerTest`)
  exercises the migrated paths. The CSV test (`DeliveryCsvImportControllerTest`)
  uses `endsWith('BriefDescriptionTxt__c')` against `apiName` values, which
  is satisfied by both forms.

## Test-file callsite (informational)

`DeliveryWorkItemTriggerHandlerTest.cls:465` calls
`ref.getDescribe().getName()` and compares it to the literal string
`'User'`. Standard objects have no namespace prefix in either form, so
both methods return `'User'` and the assertion is identical. Left
unchanged — no behavior or hygiene difference.

## Lessons / CLAUDE.md amendment recommendation

The 5/26 code-quality audit's recommendation #4 already proposes amending
CLAUDE.md to:

> "Prefer `getLocalName()` for comparison and DTO emission; use
> `getName()` when building dynamic SOQL or Lightning URLs that need
> the runtime-resolved object name."

This audit confirms the recommendation is correct. Three production
callsites genuinely need `getName()`; the other 10 were latent
mechanical-replace risk that's now annotated and reduced.

## Out of scope

- `UserInfo.getName()` (7 callsites) — running-user display name, not an
  API name. Different signature, different semantics.
- The 53 `global` classes missing `AvoidGlobalModifier` suppressions —
  separate backlog item (5/21 PMD baseline recommendation #3).
