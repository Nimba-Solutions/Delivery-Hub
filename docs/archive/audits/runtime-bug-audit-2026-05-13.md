# Production Runtime Bug Audit (2026-05-13)

> **Status as of 2026-05-15: RESOLVED.** All 7 confirmed bugs (findings #1–#7) were
> shipped in PR #778 (commit `6fc31726`, merged 2026-05-14, released as
> `0.239.0.1`, installed on dh-prod / nimba / MF-Prod). The 6 "likely" findings
> (#8–#13) and lower-priority sweep items are retained below for future triage.
> File preserved for historical record.

Scope: Apex + LWC under `force-app/main/default`, read-only. ~290 production Apex
classes scanned for the 13 bug categories listed in the audit brief. Test
classes excluded except where the test itself enables a runtime trap.

## Executive summary

1. **Forecast Alert sweep will hit the 100-SOQL governor limit at scale.**
   `DeliveryForecastAlertService.runSweep` evaluates up to 200 root WIs in one
   transaction. Each WI triggers ~12 SOQL via `walkDescendants` (loop SOQL),
   `calculateProjectForecast`, plus per-recipient `shouldNotifyChannel` and
   per-call `CustomNotificationType` lookups in `sendBellNotification`. The
   ceiling is reached at roughly the 8th WI. Tests pass with 1–3 candidate
   WIs and never expose this.
2. **DeliveryHubPoller.handleSuccess loops record-by-record through
   `DeliverySyncItemIngestor.processInboundItem`**, and the ingestor itself
   issues 6 SOQL via `getNamespacePrefix()` + several ledger / bridge /
   validate / parent-resolution queries per call. A vendor returning ≥ 8
   inbound items will exceed governor limits on the poll.
3. **`DeliveryDepthProbeService.buildRootSegment` issues synchronous HTTP
   callouts inside a SOQL for-loop**, recursing across peer orgs at up to
   30 s timeout each. The class suppresses `PMD.OperationWithLimitsInLoop`
   but real-world fan-out can blow the 600 s Apex CPU/wall budget on a single
   probe even when callout count stays under 80.
4. **`DeliveryHubScheduler` has two silent-swallow catch blocks** at lines
   293-297 and 322-325 disguised as PMD compliance (`msg.length();`). The
   forecast-alert / overdue-reminder enqueue failure produces zero log
   evidence — only the missing daily alert.
5. **`DeliveryWorkItemBackfillService.backfillStatusDefaults` ignores
   `Database.SaveResult` failures** while counting successes — runs on every
   install (`DeliveryHubInstallHandler.backfillWorkItemStatusDefaults`) and
   under partial DML failure (e.g. a custom validation rule) the install log
   reports "succeeded: N" without surfacing any of the failures.
6. **`DeliveryWorkItemTriggerHandler.handleNetworkEntitySync` auto-attaches
   new WorkItems to the first Active Vendor entity (`LIMIT 1` with no
   `ORDER BY`)** — non-deterministic on orgs with multiple Vendor records.
   The peer fix in `DeliverySyncItemIngestor` (line 397: `ORDER BY
   CreatedDate ASC LIMIT 1`) was not back-ported to the trigger handler.
7. **Forecast-alert scheduler mixes GMT and local-TZ semantics**:
   `DateTime.now().hourGmt()` compared to a settings hour, but
   `Date.today()` is user-TZ. On a non-GMT scheduling user the daily
   idempotency guard (`LastForecastAlertScanDate__c == today`) can flip a
   day early or late.

## Confirmed bugs (will misbehave under realistic load)

### 1. Forecast alert sweep — N×SOQL fan-out exceeds governor limit

**Files:**
- `force-app/main/default/classes/DeliveryForecastAlertService.cls:92-108, 179-217`
- `force-app/main/default/classes/DeliveryForecastService.cls:144-164, 171-186` (loop-SOQL in `walkDescendants` and per-call tree query)
- `force-app/main/default/classes/DeliveryEscalationNotifService.cls:184-188`
- `force-app/main/default/classes/DeliveryNotificationPreferenceService.cls:23-31`

**What goes wrong.** `runSweep` (DeliveryForecastAlertService.cls:58-108)
queries up to 200 root WIs (`MAX_WORKITEMS_PER_SWEEP = 200`, line 46), then:

```apex
for (WorkItem__c wi : candidates) {
    AlertCandidate ac = evaluate(wi, thresholdRatio);  // → calculateProjectForecast → walkDescendants
    ...
}
```

Per candidate, `evaluate` → `DeliveryForecastService.calculateProjectForecast`
fires:
- 1 SOQL per `walkDescendants` iteration (up to `MAX_TREE_DEPTH = 10`, see
  DeliveryForecastService.cls:147-160 — SOQL inside for-loop body)
- 1 SOQL for the tree pull (line 73-80)
- 1 SOQL for the weekly history (line 175-186)

That is up to ~12 SOQL per candidate. Then `dispatchAlerts` (line 167) loops
candidates × recipients × channels and calls `sendBellNotification`, which
re-queries `CustomNotificationType` *every* call (DeliveryEscalationNotifService.cls:184-188),
plus `shouldNotifyChannel` per (recipient, channel) re-queries
`NotificationPreference__c` (DeliveryNotificationPreferenceService.cls:23-31).

At realistic scale (50 WIs that fire an alert, 2 recipients each, 2 channels):
- Evaluation: 50 × 12 = 600 SOQL
- Dispatch: 50 × 2 × 2 = 200 SOQL (shouldNotify) + 50 × 2 = 100 SOQL (CNT)

Apex hard cap is 100 SOQL per transaction. The sweep will catastrophically
fail well before reaching the 200-WI ceiling.

**Tests pass** because `DeliveryForecastAlertServiceTest` exercises 1–3
candidate WIs in `runSweep` paths.

**Recommended fix:**
- Hoist the `CustomNotificationType` lookup out of `sendBellNotification`
  (mirror the pattern already used in
  `DeliveryWorkItemCommentTriggerHandler.notifyWorkItemOwners:71-77`).
- Bulk-load `NotificationPreference__c` for all (recipient, channel,
  eventType) tuples once before the dispatch loop in
  `DeliveryForecastAlertService.dispatchAlerts`.
- Cache `Organization.NamespacePrefix` in a static (see finding #2).
- Cap effective sweep size (e.g. drop `MAX_WORKITEMS_PER_SWEEP` to 25 OR
  chain via Queueable batches) until the evaluation SOQL count is bounded.

---

### 2. Poller per-item ingestion runs ≥6 SOQL inside a for-loop

**File:** `force-app/main/default/classes/DeliveryHubPoller.cls:83-122` and
`force-app/main/default/classes/DeliverySyncItemIngestor.cls:12-15, 32-533`.

**What goes wrong.** `DeliveryHubPoller.handleSuccess` iterates `events`
(line 91-113) and calls `processInboundItem` per record. Inside
`processInboundItem`:

```apex
// line 12-15
private static String getNamespacePrefix() {
    String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
    return String.isBlank(ns) ? '' : ns + '__';
}
```

`getNamespacePrefix()` is uncached and is called up to 6 times in a single
`processInboundItem` invocation (lines 399, 400-403, 408, 436, 514-516, 521,
920). Additionally each invocation can fire `findLocalId` (1 SOQL),
`findLocalIdByGlobalSource` (1), bridge lookup (1), parent-ledger lookup
(1-2), `validateLocalIdExists` (1), `tryAsLocalWorkItemId` (1), the
auto-parent NetworkEntity query at line 406 (1), and the echo-suppression
query at line 519 (1). Easily ≥ 10 SOQL per inbound item.

Polling a vendor with 10–15 items per cycle exceeds 100 SOQL.

**Tests pass** because per-test ingestion is single-record; the polling
loop is exercised with stubbed mocks that don't replay 10+ ingestions in
one tx.

**Recommended fix:**
- Cache `Organization.NamespacePrefix` in a transaction-scoped static (e.g.
  initialize once in a static initializer or memoize in `getNamespacePrefix`).
- Move `processInboundItem` from per-record to a bulk
  `processInboundBatch(List<Map<String,Object>>)` shape — pre-fetch ledger
  rows, bridges, and parent ledger entries once per batch.

---

### 3. Depth-probe service makes synchronous HTTP callouts in a SOQL loop

**File:** `force-app/main/default/classes/DeliveryDepthProbeService.cls:136-198, 205-250`.

**What goes wrong.** `buildRootSegment` (line 145-164) iterates
`WorkRequest__c` records and calls `buildPeerNode` → `invokePeerProbe` →
synchronous `new Http().send(httpReq)` (line 230) with `PEER_TIMEOUT_MS =
30000` (30 s). The probe is server-to-server **recursive** — each peer can
in turn fan out.

```apex
for (WorkRequest__c req : [SELECT ... FROM WorkRequest__c WHERE ...]) {
    DepthChainNode peer = buildPeerNode(req, remainingDepth, requestId);  // calls Http.send
    ...
}
```

`MAX_CALLOUTS_PER_PROBE = 80` (line 56) protects against the 100-callout
governor, but **does nothing for wall time**. 8 slow peers × 30 s = 240 s
just on this org's segment; the recursive form can multiply that by
`MAX_DEPTH = 5`. Apex sync invocation cap is 60 s for `@AuraEnabled` calls
and ~600 s overall — easily exceeded.

The class suppresses `PMD.OperationWithLimitsInLoop` at line 40, so static
analysis won't catch this.

**Tests pass** because integration tests use mock HttpCalloutMocks that
return immediately.

**Recommended fix:**
- Convert the recursive probe to an async Queueable chain that posts
  partial results to a per-probe ledger; the LWC polls the ledger.
- Add a per-peer wall-clock budget (e.g. `System.currentTimeMillis() -
  start > BUDGET_MS` short-circuit) in addition to the callout count cap.
- Reduce `PEER_TIMEOUT_MS` to 10 s (most healthy peers respond <2 s).

---

### 4. Scheduler swallows enqueue failures behind a no-op PMD shim

**File:** `force-app/main/default/classes/DeliveryHubScheduler.cls:274-277, 294-297, 322-325`.

**What goes wrong.** Three catch blocks in `DeliveryHubScheduler`
(`enqueueInvoiceGenerationIfDue`, `enqueueOverdueRemindersIfEnabled`,
`enqueueForecastAlertsIfDue`) discard the exception and only fake a "use":

```apex
} catch (Exception ex) {
    String msg = ex.getMessage();
    msg.length(); // satisfy PMD empty-catch rule
}
```

If `System.enqueueJob` throws (queueable-limit exceeded, async-job-id
collision, etc.) the daily forecast alert / overdue reminder / invoice
generation silently no-ops. No `System.debug`, no `ActivityLog__c`, no
DeliveryHubSettings stamp left behind. The next day's tick will look
identical to the failed tick.

**Recommended fix:** Mirror the pattern used at lines 68-71 (`requeuePendingItems`):
```apex
} catch (Exception ex) {
    System.debug(LoggingLevel.ERROR,
        '[DeliveryHubScheduler] enqueueForecastAlertsIfDue failed: '
        + ex.getMessage());
}
```

---

### 5. Partial-success DML failures silently ignored on install backfill

**File:** `force-app/main/default/classes/DeliveryWorkItemBackfillService.cls:42-66`.

**What goes wrong.**

```apex
Database.SaveResult[] results = Database.update(stale, false);
Integer succeeded = 0;
for (Database.SaveResult r : results) {
    if (r.isSuccess()) {
        succeeded++;
    }
}
return succeeded;
```

Failures are dropped on the floor. The caller (`DeliveryHubInstallHandler.
backfillWorkItemStatusDefaults`) only logs via `System.debug`. If a
subscriber's validation rule, FLS restriction, or trigger rejects the
Status flip, the install will silently report "X succeeded" and the
remaining stale WIs stay stuck at `Status = New` — invisible on the gantt
because of the existing `ActivatedDateTime__c IS NULL` filter chain that
recent memory entries call out repeatedly.

By contrast, `DeliveryWorkItemETAService.cls:316-320` does the correct
thing and `System.debug`s each `!sr.isSuccess()` row.

**Recommended fix:** Add the failure-iteration loop in
`backfillStatusDefaults` and return a (succeeded, failed) tuple; surface
both into the install-handler log.

---

### 6. Auto-Vendor attachment is non-deterministic with multiple Vendors

**File:** `force-app/main/default/classes/DeliveryWorkItemTriggerHandler.cls:155-193`.

**What goes wrong.** When `EntityTypePk__c = 'Vendor'` is the chosen path
(line 157), the SOQL is:

```apex
List<NetworkEntity__c> vendors = [
    SELECT Id FROM NetworkEntity__c
    WHERE StatusPk__c = 'Active' AND EntityTypePk__c = 'Vendor'
    WITH SYSTEM_MODE
    LIMIT 1
];
```

No `ORDER BY`. SF's default ordering is undefined — on orgs with multiple
Vendor entities the chosen one is whatever SF returns first. The very
similar pattern in `DeliverySyncItemIngestor.cls:393-398` was fixed (added
`ORDER BY CreatedDate ASC LIMIT 1` and a `IN ('Client', 'Both')` filter)
but this trigger-handler version wasn't back-ported.

**Recommended fix:** Add `ORDER BY CreatedDate ASC LIMIT 1` and document
the auto-attach semantics in the field-tracking metadata.

---

### 7. Forecast scheduler date/time TZ mismatch

**File:** `force-app/main/default/classes/DeliveryHubScheduler.cls:307-326`.

**What goes wrong.**

```apex
Integer currentHour = DateTime.now().hourGmt();   // GMT
if (currentHour != 8) { return; }
...
Date today = Date.today();                         // user TZ
if (settings.LastForecastAlertScanDate__c == today) { return; }
```

`Date.today()` is the running user's TZ; `hourGmt()` is GMT. The
scheduled-Apex user typically runs in the org TZ, not GMT. On a server in
US/Eastern, when GMT hour rolls to 8 AM, `Date.today()` reads "yesterday"
between roughly 04:00–08:00 Eastern. The idempotency stamp
`LastForecastAlertScanDate__c = Date.today()` (set in
`DeliveryForecastAlertService.stampScanComplete` at line 355) can be the
previous calendar day, causing either:
- a missed daily alert (stamp says today, but today is tomorrow in GMT), or
- a duplicate alert across a TZ-boundary day.

**Recommended fix:** Use `Date.newInstance(DateTime.now().yearGmt(),
DateTime.now().monthGmt(), DateTime.now().dayGmt())` everywhere the
8-AM-GMT cadence is being gated, or switch all comparisons to user-TZ
hour. Pick one and use it consistently.

---

## Likely bugs (high suspicion, needs context to confirm)

### 8. Bell-notification SOQL inside a per-comment trigger loop

**File:** `force-app/main/default/classes/DeliveryWorkItemCommentTriggerHandler.cls:48-121`.

**Concern.** `notifyWorkItemOwners` correctly hoists the
`CustomNotificationType` SOQL outside the loop (lines 71-77), but it still
calls `Messaging.CustomNotification.send()` synchronously **per comment**
inside the `for (WorkItemComment__c c : comments)` loop at line 79. SF's
CustomNotification limit is 10,000/day org-wide and there is no documented
per-tx bulkification (the `send()` API accepts a `Set<String>` of user IDs
but is otherwise single-message).

`DeliveryHubSettings__c.getInstance(wi.OwnerId)` inside the same loop
(line 97) is hierarchical custom-settings — SF caches that one, no SOQL —
so the per-call cost is just the `.send()` call itself.

If a bulk comment import (or a `Database.insert(comments)` with 100+ rows)
hits this trigger, 100+ `notification.send()` calls execute synchronously
on the same tx, each making a platform-events bus round-trip.

**Additional info needed to confirm:** Production volume of multi-comment
inserts. If comments only arrive 1-by-1 from the chat LWC, this is fine in
practice.

**Recommended fix if confirmed:** Batch `Set<String>` per (title, body) key
and call `send()` once per unique (title, body) tuple, or move the dispatch
to a queueable to absorb large per-tx fan-out.

---

### 9. `processInboundItem` swallow of cast/SOQL failures leaves no breadcrumb

**File:** `force-app/main/default/classes/DeliverySyncItemIngestor.cls:122-124, 350-353, 381-383, 414-417, 525-528, 605-607`.

**Concern.** Multiple `catch (Exception e) { System.debug(LoggingLevel.FINE, ...) }`
blocks downgrade hard failures (Id-cast exceptions, FLS rejection on auto-
parenting writes) to debug-level traces. `FINE` is below the default
LoggingLevel for many production org debug-log filters — these traces
won't show up unless someone explicitly turns on a `FINE` filter for the
namespace before reproducing.

Specifically lines 414-417 catch a failed `putSafe(... ClientNetworkEntityLookup__c ...)`
during auto-parenting and discard. The receiver-side fix in PR #757
depends on this auto-parent succeeding — silent failure here is exactly
the "permanent no-op" failure mode the codebase has been hunting for the
past 4 weeks (per MEMORY.md).

**Additional info needed:** Confirm whether production debug-log filters
on subscriber orgs include `FINE` for `delivery`-namespaced classes. If
not, raise the level to `WARN` for these specific catches and add a
`recordSyncFailure(...)` helper that stamps an `ActivityLog__c` row so
admins can see the trail.

---

### 10. `DeliveryForecastService.calculateProjectForecast` flagged `cacheable=true` over a tree of records

**File:** `force-app/main/default/classes/DeliveryForecastService.cls:65-121`.

**Concern.** The method is `@AuraEnabled(cacheable=true)` but its result
depends on:
- WorkLog__c rows logged for the entire descendant tree of `workItemId`,
- velocity stats computed from those logs.

LDS caches the result per (controller, workItemId) tuple. If the user
logs hours to a child WI, the cache won't invalidate — the parent's
forecast LWC will keep showing stale velocity until a manual refresh.

**Additional info needed:** Confirm whether the LWC consumers
(`deliveryProjectBurnUpChart`, `deliveryHoursPills`) refresh on
`@wire(getRecord, { fields: ['WorkLog__c.HoursLoggedNumber__c'] })` or
some other invalidation trigger. If not, the `cacheable=true` is wrong
for the project-level aggregation.

**Recommended fix:** Drop `cacheable=true` for this aggregation (forecast
inputs change too frequently) — or have callers force-refresh via
`refreshApex`.

---

### 11. `DeliverySyncEngine.hasSignificantChange` uses `!=` on boxed `Object`

**File:** `force-app/main/default/classes/DeliverySyncEngine.cls:324-334`.

**Concern.**

```apex
for (String field : allowedFields) {
    if (getSafeValue(rec, field) != getSafeValue(oldRec, field)) {
        return true;
    }
}
```

For primitive boxed types (Decimal, Date, String) Apex `!=` does call
`.equals()` semantically. For nullable Decimal fields, `null != 0` is
`true`, which is the intended outcome. But for two `Decimal` instances
representing the same value but constructed differently (e.g.
`Decimal.valueOf('1.0')` vs `Decimal.valueOf(1)` after JSON round-trip),
the comparison can return `true` even when business-semantically equal —
producing spurious outbound SyncItems. Combined with the existing
reconciler / dedup machinery this is benign, but it does cost SyncItem
table volume.

**Additional info needed:** Audit a day of `SyncItem__c` rows that have
`PayloadTxt__c` identical to the previous row's payload — that count is
the false-positive rate.

**Recommended fix:** Use `String.valueOf(a) == String.valueOf(b)` for the
comparison (with null normalization to `''`), or `(a == null ? b == null
: a.equals(b))`.

---

### 12. `DeliveryWorkItemTriggerHandler.slaProcessed` static flag never reset between transactions

**File:** `force-app/main/default/classes/DeliveryWorkItemTriggerHandler.cls:26, 325-348`.

**Concern.** `slaProcessed` is a `private static Boolean` that flips true
on first call to `autoSetSLATargets` and never resets. Apex statics are
**scoped to a single transaction**, so this is technically correct as a
recursion guard within one tx. But the comment ("Guard flag to prevent
recursive SLA target setting", line 25-26) implies cross-call safety. If a
future refactor caches the handler instance across transactions (e.g.
moving to a Queueable that processes multiple WIs), the flag becomes
permanently stuck.

**Additional info needed:** Confirm there's no plan to reuse the handler
class state across asynchronous boundaries. If not — add a
`@TestVisible static void reset()` and a comment clarifying transaction
scope to prevent regression.

---

### 13. JS `result.data.X` chains without an enclosing `result.data` check

**File scan summary:** `force-app/main/default/lwc/deliveryActivityDashboard/deliveryActivityDashboard.js:44-51`
shows the correct pattern (`if (result.data) { ... }`). Most LWCs follow.

**Concern.** `force-app/main/default/lwc/deliveryWorkItemChat/deliveryWorkItemChat.js:107` uses
`this.comments.data.length` in `renderedCallback()`. `comments` is
initialized to `{ data: [] }` in the field declaration (line 30), so this
is safe — but if a future refactor swaps the wire-result object directly
into `this.comments` (e.g. `this.comments = result`), `data` could become
`undefined`. Worth a defensive `(this.comments?.data?.length ?? 0)`
rewrite as cheap insurance.

Similarly `force-app/main/default/lwc/deliveryWorkItemChat/deliveryWorkItemChat.js:132`
uses `this.comments.data.length` after the wire result has populated —
safe today, same defensive concern.

**Recommended fix (cheap):** Convert dotted access to optional chaining
across the LWC layer in the existing PR #777 namespace pass.

---

## Lower-priority findings (worth a sweep later)

- **`DeliveryHubPoller.cls:78-81` catches the entire poll loop and returns a
  string** — caller (`DeliveryHubScheduler.runSyncAsync` line 421-428) only
  logs to `System.debug(LoggingLevel.ERROR)` if the string doesn't contain
  "Success". Errors that contain the word "Success" anywhere (substring
  match) bypass the log. Make the success-check exact.
- **`DeliveryDocumentPdfController.cls:486-487`** catches a date-parse
  failure and falls back to the raw string — that string then renders into
  a PDF that PMs send to clients. The fall-back surface is the customer.
  Worth converting to an explicit "Invalid date" placeholder so the
  artifact looks like a bug rather than a typo.
- **`DeliveryGanttController.cls:337-339, 349-351`** swallow integer/decimal
  parse errors silently in `copyClampedBorderWidth` / `copyClampedFillOpacity`.
  Each is invoked per saved gantt patch — a malformed admin save quietly
  drops the field instead of surfacing the typo to the admin.
- **`DeliveryPortalController.cls:465-467`** returns an empty list on any
  Exception. Portal callers can't distinguish "no records" from "internal
  error" — clients may show a "no work assigned" screen during a real
  outage.
- **`DeliveryDepthProbeService.cls:295-297, 363-365`** silently return null /
  0 from `tryAsLocalWorkItemId` and `toInteger`. The first is fine; the
  second can mask a payload-type mismatch from a peer (e.g. peer sends
  `remainingDepth` as a `String`).
- **`DeliveryActivityDashboardController.cls:75-81`** swallows Id-cast
  failures inside a `for (Object uid : userIds)` loop. If the calling LWC
  feeds it a payload with mixed-type ids the user sees the dashboard
  silently render with the wrong cohort.
- **`DeliveryFieldChangeService.cls:201-203`** catches an Exception while
  parsing `req.extraContext` and falls through. The resulting
  `ActivityLog__c.ContextDataTxt__c` then contains the raw req.extraContext
  string instead of the structured payload — `DeliveryActivityFeedController.
  isSuppressedFieldChange` then parses that as JSON, returns `false`
  (line 547-549, JSONException swallow), and the noisy event surfaces in
  the feed. Two swallows compound to "noisy feed under malformed input".
- **`DeliveryAiController.cls:42, 72, 86, 149`** wraps `DeliveryHubException
  → AuraHandledException(e.getMessage())` — per CLAUDE.md rule
  "`AuraHandledException.getMessage()` returns generic in managed package",
  this means subscriber-org users get a generic error, never the original
  message. Apply the `.setMessage()` pattern used in
  `DeliveryGanttController.cls:517-518` consistently.
- **`DeliveryHubInstallHandler.cls:106-108`** skips `enqueueInitialReconciliation`
  in test context. The skip is wider than necessary — the test mode could
  install a `HttpCalloutMock` and still let the reconciler run. Today no
  test installs a callout-mock for the reconciler path, but it's a
  gold-plate gap when test coverage of the reconciler grows.
- **`DeliveryWorkItemTriggerHandler.cls:155-160` Vendor LIMIT 1 query**
  (see finding #6) also has no `EntityTypePk__c IN ('Vendor', 'Both')`
  branch — an entity flagged `'Both'` won't auto-attach. Confirm whether
  that's intended.
- **`DeliveryActivityDashboardController.cls:76-81`** uses `Id ignored`
  catch idiom but never re-throws — coupled with `Test.isRunningTest()`
  branches elsewhere, could let test-only Id payload contamination slip
  past in production.
- **`DeliveryHubPoller.cls:117-119`** does `update as system vendor;` —
  fine for single-record, but if the caller batches `handleSuccess` across
  multiple vendors in one tx, each becomes its own update. Not a bug
  today; gold-plate when poll multi-vendor.
- **`DeliveryFieldBytesResource.cls:185-187`** returns false on Exception —
  combined with the caller pattern at lines 56-59 (writes JSON error 500),
  the actual exception message is preserved. OK.
- **Hardcoded NetworkEntity OrgId tokens** appear only in test fixtures
  (`DeliveryDepthProbeServiceTest.cls`, `DeliveryHubSyncServiceTest.cls`,
  `DeliverySyncEngineTest.cls`). No production-side hard-coded IDs found.
- **`System.schedule` cron strings** in `DeliveryHubScheduler.cls:355-385`
  use unique slot names per `:00 / :15 / :30 / :45` and pre-abort existing
  jobs by name. No collision risk on reinstall.
- **`Test.isRunningTest()` branches** in `DeliverySyncReconciler.cls:127,
  132`, `DeliveryContentDocLinkTriggerHandler.cls:169`,
  `DeliverySyncItemProcessor.cls:277`, `DeliveryWorkLogTriggerHandler.cls:256`,
  `DeliveryHubInstallHandler.cls:106` all suppress async-job chaining in
  test context. Each is justified individually (avoid scratch-org queueable
  storms in CI); collectively they mean **multi-hop async chains have
  zero production-equivalent test coverage**. Worth one rope-and-pulley
  Test class that explicitly runs the chains end-to-end with mocked HTTP.
- **`DeliverySyncEngine.cls:300`** uses `Database.update(toUpdate, false,
  AccessLevel.SYSTEM_MODE)` for the dedup-merge — failures are intentionally
  swallowed per the comment. Same partial-success-without-iteration smell
  as finding #5 but the comment explicitly justifies it (Staged rows stay
  Staged with old payload). Defensible — leaving as a known-pattern.

---

## What I would prioritize fixing first (severity × likelihood)

1. **Finding #1 (forecast alert SOQL fan-out)** — already shipped, will fire
   the first day any subscriber has ≥10 alertable WIs. Cost ~3h to hoist
   the two SOQLs + bulk-load NotificationPreference__c.
2. **Finding #2 (poller per-item SOQL fan-out)** — same shape, harder fix
   because of the cross-namespace string-replace pattern; cache the
   namespace as a starting wedge (~1h).
3. **Finding #4 (scheduler swallow)** — 5 minutes, lights up the next
   failure with a real log line.
4. **Finding #6 (Vendor ORDER BY)** — 1 line of SOQL.
5. **Finding #7 (TZ inconsistency)** — picks 1 of 2 conventions and applies
   consistently. ~30 min including writing the regression test.
6. **Finding #3 (depth-probe sync callouts)** — needs a redesign so save
   for a planned PR rather than in-line patch.
7. **Finding #5 (install backfill partial DML)** — 15 minutes; matters
   only on install/upgrade so blast radius is bounded.
