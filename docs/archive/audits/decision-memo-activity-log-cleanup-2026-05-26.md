# Decision Memo — `DeliveryActivityLogCleanup` wire-or-delete

**Status:** awaiting Glen decision.
**Surfaced by:** `docs/audits/dead-code-audit-2026-05-26.md` top dead-code candidate #1.
**Recommendation:** WIRE IT (~1h PR). Not delete.

## The state today

`force-app/main/default/classes/DeliveryActivityLogCleanup.cls` is a fully-implemented `Schedulable, Database.Batchable<SObject>`. It does two things in sequence on every fire:

1. **Aggregate** — Summarizes the last 30 days of `ActivityLog__c` rows per `NetworkEntity__c` into JSON on `NetworkEntity__c.UsageAnalyticsJsonTxt__c`, then queues an outbound `SyncItem__c` so the vendor org receives the analytics.
2. **Purge** — Batch-deletes `ActivityLog__c` rows older than the retention window. Honors `DeliveryHubSettings__c.ActivityLogRetentionDaysNumber__c` (default 90) AND a separate `FieldChangeRetentionDaysNumber__c` so noisy Field_Change rows can age out faster than other action types.

The class has a test (`DeliveryActivityLogCleanupTest`, already in `DH.testSuite-meta.xml`). Its docstring even includes the cron expression example:

```
System.schedule('Delivery Activity Log Cleanup', '0 0 2 * * ?', new DeliveryActivityLogCleanup());
```

**The gap:** `DeliveryHubScheduler.scheduleAll()` (the install-handler-invoked registration point at `DeliveryHubScheduler.cls:403`) registers only the 4 per-15-minute sync ticks. It does NOT register the cleanup job. So in every subscriber install today, the cleanup never fires. `ActivityLog__c` rows accumulate forever, and the per-NetworkEntity usage analytics never get rolled up.

## Option A — WIRE IT (recommended)

**Scope:** Add one block to `scheduleAll()` registering the cleanup nightly at 2 AM. Update the install-handler test to confirm the job is scheduled.

**Concrete diff shape** (~10 LOC):

```apex
// Append to DeliveryHubScheduler.scheduleAll() after the per-tick block:

String cleanupName = 'Delivery Activity Log Cleanup';
String cleanupCron = '0 0 2 * * ?';  // daily 2 AM

for (CronTrigger ct : [
    SELECT Id FROM CronTrigger
    WHERE CronJobDetail.Name = :cleanupName
    WITH SYSTEM_MODE
]) {
    System.abortJob(ct.Id);
}
System.schedule(cleanupName, cleanupCron, new DeliveryActivityLogCleanup());
```

Plus a `DeliveryHubSchedulerTest` assertion that `[SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'Delivery Activity Log Cleanup']` returns 1 after `scheduleAll()`.

**Pros:**
- Class is complete, tested, ApexDoc'd. Real subscriber value: bounded ActivityLog__c storage + automatic usage-analytics rollup.
- Both retention windows (`ActivityLogRetentionDaysNumber__c` + `FieldChangeRetentionDaysNumber__c`) are already shipped as Custom Settings fields — subscribers can tune.
- The cleanup's per-NetworkEntity analytics roll-up makes ActivityLog__c data subscriber-portable (vendor orgs receive the JSON via the existing outbound SyncItem rail).
- Existing test class proves the batch logic is correct; only the registration is missing.

**Cons / risks:**
- Daily batch on `ActivityLog__c` could be heavy at scale. Mitigation: the existing `Database.executeBatch(..., 2000)` chunks it; PMD CRUD-violation suppressions already in place.
- Subscriber org with millions of ActivityLog__c rows could trip batch governor limits the first time it runs. Mitigation: the retention default is 90 days, so first run only deletes existing-over-90-days data — same shape as steady-state.
- New scheduled job appears in subscriber's Setup → Scheduled Jobs. Some admins may flag as "what's this." Mitigation: name it clearly and document in SETUP.md.

**Effort:** ~1 hour. Single PR: scheduler edit + test + SETUP.md note.

## Option B — DELETE IT

**Scope:** Delete `DeliveryActivityLogCleanup.cls` + `DeliveryActivityLogCleanupTest.cls` + remove from `DH.testSuite-meta.xml`. Delete the two Custom Settings fields (`ActivityLogRetentionDaysNumber__c` + `FieldChangeRetentionDaysNumber__c`) via destructiveChanges. Remove `NetworkEntity__c.UsageAnalyticsJsonTxt__c` too (only this class writes it).

**Pros:**
- Less code to maintain. Removes a class that's currently doing nothing.
- One fewer scheduled job (cleaner Setup → Scheduled Jobs list).
- Subscribers who don't want auto-purge of ActivityLog__c don't have to opt out (the field would have to default to a sane "off" value otherwise).

**Cons:**
- Loses real functionality. `ActivityLog__c` will grow unbounded in every install. Today's `deliveryActivityLog` viewer (PR #820) caps at 200 rows shown, but storage cost is real over years.
- Loses the per-NetworkEntity usage rollup — that's a measurable feature that would need rebuilding if we ever wanted it back.
- Destructive deletes ripple: subscribers who upgraded after these fields landed would see them disappear from their settings page. Confusing.

**Effort:** ~2 hours. Single PR + destructiveChanges + post-install handler cleanup (anything that wrote those fields needs to stop writing).

## Recommendation: WIRE IT

The class is complete, tested, has clear subscriber value, and the only missing piece is one block of registration code in `scheduleAll()`. The dead-code audit is correct that it's currently unwired, but the right resolution is the smaller, additive change — not the destructive one.

If you want it dialed down to "only purge, no usage-rollup": split the cleanup's `execute()` so only the `Database.executeBatch(...)` purge fires, and gate the `aggregateUsageAnalytics()` call behind a new `DeliveryHubSettings__c.EnableActivityUsageRollupDateTime__c` flag. That's a slightly larger PR (~2h instead of ~1h) but gives admins control. I'd recommend just shipping the full thing per the existing design unless you want the explicit gate.

## What I'll do next

If you say "wire it," I ship the ~1h PR same-session. If you say "delete it," I ship the destructiveChanges PR. If you want a third option (gate the usage rollup behind a flag), say which flag-name preference.

Until then, I'm leaving it alone — half-state is strictly worse than either pole per the dead-code audit's note.
