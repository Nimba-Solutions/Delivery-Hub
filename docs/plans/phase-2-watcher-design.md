# Phase 2 Watcher v1 — Design (2026-05-18)

> **Status:** ✅ SHIPPED at 0.246 (#807/#809/#810) — `DeliveryWatcherService`, the `WatcherDigest__c` object, `DeliveryWatcherDigestFormatter`, the setup LWC, and the top-3 live signals plus 4 stubbed signals all exist in the package. This document is the original design recon, retained for history; it is no longer "design-only / not implemented." (The 4 stub signals remain gated behind their own `Enable…DateTime__c` flags.)

> **Parent plan:** `C:\Users\globa\.claude\plans\wild-roaming-rocket.md` — Phase 2 (Watcher v1 ~14h, top 3 signals implemented + 4 stubs, Slack + WatcherDigest__c audit record, Glen-only via `WatcherDigestRecipientUserIdsTxt__c`).

---

## Goal

The DH org already has a half-dozen sources of operational truth (sync ledger, escalation engine, forecast-alert sweep, weekly digest, NetworkEntity heartbeats, ActivityLog field-change writes, depth-probe audit, Slack outbound). Each addresses a slice of "what's happening?" but **none answer "what does Glen need to look at right now?"**

Watcher v1 is the aggregation layer. It runs once per morning, asks each enabled signal "do you have anything escalation-worthy?", merges the answers into a single Slack DM + `WatcherDigest__c` audit record, and goes silent if nothing fires. The north star (`docs/SUBTRACT_GLEN_ROADMAP_2026-04-24.md`) is **30 min/day of strategic decisions, 0 min of routing/triage.** Watcher is Layer 0 — the primitive that everything else builds on (Phase 3 auto-digest, Phase 4 audit cleanup).

It is explicitly **not** a real-time tail (existing in-context bell notifications + Slack outbound cover that), and it is **not** a stakeholder-facing digest (Phase 3, separate feature).

---

## What's already in place

Surveyed `force-app/main/default/classes` for every observability surface. The Watcher must **aggregate / correlate / route**, never duplicate.

| Surface | What it detects | Current routing | Signal quality |
|---|---|---|---|
| `ActivityLog__c` writes — `DeliveryFieldChangeService` (Field_Change action), `DeliveryWorkItemTriggerHandler`, `DeliverySyncDismissalService`, etc. (23 callsites) | Every tracked field change, every stage move, every sync-dismissal, depth-probe attestation event | LWC timeline + activity-feed components; not pushed anywhere | High volume / low individual signal — perfect aggregation source, terrible for direct alerting |
| `SyncItem__c` ledger | Cross-org outbound/inbound state — `Queued / Staged / Pending / Synced / Failed` | Inspected via dashboards + Activity Tracker LWC | **Failed bucket is the gold-standard sync-health signal.** Self-healing via `DeliveryHubScheduler.requeueFailedItems` + `requeueStagedItemsWithEndpoint` + `requeuePendingItems` + `autoDismissAgedFailedItems` |
| `NetworkEntity__c.LastInboundSyncDateTime__c` / `LastOutboundSyncDateTime__c` | Per-edge heartbeat (PR #786) | Stamped by `DeliverySyncItemProcessor` + `DeliveryHubPoller` | Newest surface. Currently observed by reading the field; no alerting layer yet |
| `WorkItem__c.SLAStatusTxt__c` (formula) | `On Track / At Risk / Breached / Met` derived from `SLATargetDate__c` + current stage | Read by Activity Tracker LWC + reports | **Already calculated** — Watcher just queries it, doesn't re-derive |
| `WorkItem__c.StageEnteredDateTime__c` + `StageNamePk__c` | When current stage was entered (auto-stamp by trigger) | Powers `DeliveryEscalationRuleEvaluator` against `WorkflowEscalationRule__mdt` rows (5 rules deployed: LA_NeedsInfo_2Day_Email, SD_DevBlocked_1Day_Critical, etc.) | Strong — but escalation engine **emails the assignee, not Glen** |
| `DeliveryForecastAlertService.runSweep()` | WIs whose projected final hours > 110% of estimate at current velocity, root-WI only | Bell (per-recipient opt-in) + Email + Slack webhook (`postStageChanges` reused). 7-day cooldown + 10% material-worsening re-alert rule. Caps at 20 WIs/sweep (SOQL governor). Daily 8 GMT via `DeliveryHubScheduler.enqueueForecastAlertsIfDue` | High quality. **Already targets WI owner + DeveloperLookup, never Glen.** Watcher should *aggregate-count* rather than re-fire |
| `DeliveryEscalationService.evaluateRules()` (CMT-driven) | Stalled WIs matching escalation rule criteria | `DeliveryEscalationNotifService.sendEscalationEmails` + `sendBellNotification` + Slack | High quality. Per-rule cooldown via `LastEscalatedDateTime__c`. Same routing pattern as forecast — owner-targeted, not Glen-targeted |
| `DeliveryDepthProbeService` | Cross-org compliance attestation chain | `ActivityLog__c` with `ActionTypePk__c='Depth_Probe'` | Audit-trail only, no alerting layer; off in default org config |
| `DeliveryHubScheduler` (15-min cron 4× hourly) | Orchestrates: sync queue requeue, escalations, recurring items, sync poller, weekly digest enqueue, invoice generation, overdue reminders, forecast alerts, scheduled doc sends, reconciliation, ETA recalc | Per-method routing | The natural mounting point for the new daily Watcher tick. **Add one method `enqueueWatcherDigestIfDue`** mirroring `enqueueForecastAlertsIfDue` |
| `DeliverySlackService.postCommentBatch` (PR #782) + `postStageChanges` + `postApprovalRequest` + `postConnectionApprovalRequest` | Outbound to Slack via incoming-webhook | `@future(callout=true)` posting to `SlackWebhookUrlTxt__c` | **Existing Block Kit / payload-builder pattern to mirror.** Add `postWatcherDigest(Map<String, Object>)` or similar |
| `DeliveryWeeklyDigestService` | Mondays 9am org-local AI summary + metrics email to stakeholders | Email via `Messaging.SingleEmailMessage`, gated by `EnableWeeklyDigestDateTime__c` + `WeeklyDigestDayTxt__c` + idempotent via `LastDigestSentDate__c` | **Different audience + different cadence** — stakeholders weekly, Watcher = Glen daily. Don't merge |
| `DeliveryOverdueReminderService` | DeliveryDocument__c rows in `StatusPk__c='Overdue'` per a `OverdueReminderScheduleTxt__c` schedule (default 1,7,14,30 days) | Email to NetworkEntity contact (client-facing) | Excellent A/R signal source. Watcher's AR-aging signal should **aggregate the count** of overdue invoices not re-fire reminders |
| `DeliverySyncReconciler` | Daily 6 GMT — detects missing outbound SyncItem rows per active downstream connection, inserts Queued repair rows | Self-heals via subsequent processor tick | Watcher's failed-sync-trend stub becomes interesting once we have ~14 days of reconciler-repair counts to baseline against |
| `DeliveryDocEvent__e` / `DeliverySync__e` / `DeliveryWorkItemChange__e` / `DeliveryEscalation__e` / `GanttRemoteEvent__e` Platform Events | Real-time fan-out for LWC subscribers (gantt remote events, escalation banners, sync event toasts) | LWC `subscribe()` patterns | Watcher should **not** subscribe (it's a daily batch, not a tail). But Phase 3 auto-digest may consume `DeliveryWorkItemChange__e` |
| `WorkflowEscalationRule__mdt` (5 rows deployed) | CMT-defined escalation thresholds — stage × days → severity × action | Consumed by `DeliveryEscalationRuleEvaluator` | Mature surface; reuse the same MDT for Watcher stuck-stage thresholds rather than introducing a parallel config |

**Net takeaway:** the org already has rich detection. The gap is *aggregation and Glen-targeted routing*. Watcher v1 is ~80% query-and-merge, ~20% new query (the signals not currently surfaced — e.g. "X WIs have SLA Breached but escalation rule didn't fire because the rule's stage threshold doesn't cover this transition path").

---

## Proposed top 3 signals (implemented in v1)

### 1. `WatcherSLABreachQueryService` — WIs past SLA (or at-risk in <48h)

- **Trigger condition:** `WorkItem__c.SLAStatusTxt__c IN ('Breached','At Risk') AND ParentWorkItemLookup__c = NULL AND StageNamePk__c NOT IN ('Done','Cancelled','Closed','Rejected','Deployed to Prod') AND ActivatedDateTime__c != NULL AND ArchivedDateTime__c = NULL`
- **Detection mechanism:** Single SOQL over `WorkItem__c`. Reuses the existing formula field — no new computation. Cap at 50 results.
- **Severity / routing:** Always Slack DM + `WatcherDigest__c` row. Severity = Breached count + At Risk count. No bell (Glen has his own home pull-surface).
- **False-positive risk + mitigation:**
  - WIs with `SLATargetDate__c=null` are excluded by the formula (returns blank → never matches IN clause).
  - Templates (`TemplateMarkedDateTime__c != null`) excluded.
  - Archived WIs excluded.
- **Why top 3:** SLA Breached is the single most important escalation in the org. Every other signal is downstream of "did we ship by when we said we would." `SLAStatusTxt__c` is already calculated, so cost is sub-1-SOQL.

### 2. `WatcherStuckStageQueryService` — WIs idle in current stage > threshold

- **Trigger condition:** `StageEnteredDateTime__c < (NOW - configurable_days) AND StageNamePk__c IN (set of "should-not-be-stuck-here" stages)`. Per-stage thresholds come from existing `WorkflowEscalationRule__mdt` rows so we don't introduce parallel config.
- **Detection mechanism:** Read all active `WorkflowEscalationRule__mdt` rows once, group by stage + days threshold, build one SOQL per (stage, threshold) cluster. At 5 rules → 3-5 SOQL max.
- **Severity / routing:** Slack + `WatcherDigest__c`. Severity = count × rule.SeverityTxt (Critical-weighted higher).
- **False-positive risk + mitigation:**
  - Same as escalation engine — `LastEscalatedDateTime__c` cooldown still applies. Watcher includes WIs that *would* trigger the rule, regardless of whether escalation emailed the assignee yet. Glen-view is "this list still hasn't moved."
  - SLA Paused WIs (`SLAPausedDateTime__c != null`) excluded — those are deliberately stuck.
- **Why top 3:** Catches the WIs that don't *yet* breach SLA but are heading there. Pairs with signal #1 as an early-warning leading indicator.

### 3. `WatcherARAgingQueryService` — overdue invoices aged into reminder bands

- **Trigger condition:** `DeliveryDocument__c.TemplatePk__c='Invoice' AND StatusPk__c='Overdue' AND DueDateDate__c != NULL`. Aggregate count + sum of `TotalCurrency__c` by aging band (1-7, 8-14, 15-30, 30+ days past due).
- **Detection mechanism:** Two SOQL — count query and a list-of-Top-5-by-`TotalCurrency__c` for the digest body.
- **Severity / routing:** Slack + `WatcherDigest__c`. Severity = total_overdue_amount × age_band_weight.
- **False-positive risk + mitigation:**
  - Disputed invoices (`StatusPk__c='Disputed'`) excluded — that's a different workflow.
  - Superseded versions excluded.
  - Per-doc cooldown does *not* apply to Watcher (reminder schedule is client-facing; Watcher is Glen-facing — they're independent channels).
- **Why top 3:** Cash-collection visibility. Glen has historically been the only person watching the A/R aging report. Surfaces invoices that have aged past the reminder schedule's last band (30+) and need manual escalation.

---

## Proposed 4 stubs (placeholder logic + opt-in flag)

Each stub ships as an empty class with a `query()` method returning an empty result list + a flag-gate. Off by default. Glen flips the flag when the signal definition is ready.

### Stub A. `WatcherUnhappySignalQueryService`

- **Will eventually detect:** WIs whose sentiment trend on `WorkItemComment__c.BodyTxt__c` has tipped negative (frustrated reply patterns, repeated "still broken", customer escalation language). Likely OpenAI-classified.
- **Deferred because:** Requires NLP / signal-design + customer-language baseline. Easy to get wrong (false-positive flags Glen ignores → erodes signal-to-noise). Wait until we've baselined what an "unhappy" comment looks like.
- **v1 shim:** Empty class + `EnableWatcherUnhappySignalDateTime__c` flag. Returns empty list.

### Stub B. `WatcherUpcomingSignoffQueryService`

- **Will eventually detect:** DeliveryDocuments in `Awaiting_Signatures` status whose `RequireSigningDateTime__c` is past + signer hasn't viewed (`ViewedDateTime__c=null`) in N days; OR WIs entering a stage that requires signoff per a CMT-defined gate.
- **Deferred because:** The signoff workflow (`DeliveryAdminSigningController` etc.) is mid-feature — the data shape isn't stable yet.
- **v1 shim:** Empty class + `EnableWatcherSignoffDateTime__c` flag.

### Stub C. `WatcherPaymentOpsQueryService`

- **Will eventually detect:** Edge cases the AR-aging signal doesn't cover — payment-in-progress states (e.g. `DeliveryTransaction__c` for Stripe webhook, dispute reasons surfacing, refund windows opening). Cross-references `DeliveryTransaction__c` (which already exists) with invoice status.
- **Deferred because:** Stripe-style transaction object isn't fully wired across all orgs yet (per memory the CN portal side is mid-build).
- **v1 shim:** Empty class + `EnableWatcherPaymentOpsDateTime__c` flag.

### Stub D. `WatcherFailedSyncTrendQueryService`

- **Will eventually detect:** Rolling 7-day count of `SyncItem__c.StatusPk__c='Failed'` rows that did NOT auto-recover (i.e. survived `FailedSyncAutoDismissDaysNumber__c` window or were dismissed manually) — trended against the prior 7 days. Alerts on **delta**, not on Failed count itself (the existing self-healers handle individual failures fine).
- **Deferred because:** Needs 14-21 days of post-Watcher-install reconciler data to baseline what "normal" failure rate looks like per org. Without a baseline this is a noise generator.
- **v1 shim:** Empty class + `EnableWatcherSyncTrendDateTime__c` flag. **This is the strongest stub** — it pairs with the 14-day Watcher stabilization gate that already gates Phase 3.

---

## Data model

### New custom object — `delivery__WatcherDigest__c`

Audit trail of every Watcher run (successful or failed). Lets us trend "what did Watcher flag over the last 30 days?" and verify Glen-actioned items got addressed.

```xml
<!-- objects/WatcherDigest__c/WatcherDigest__c.object-meta.xml — PHASE 2 SCAFFOLD - not wired yet -->
<deploymentStatus>Deployed</deploymentStatus>
<enableActivities>false</enableActivities>
<enableBulkApi>true</enableBulkApi>
<enableFeeds>false</enableFeeds>
<enableHistory>false</enableHistory>
<enableReports>true</enableReports>
<enableSearch>false</enableSearch>
<enableSharing>true</enableSharing>
<enableStreamingApi>false</enableStreamingApi>
<externalSharingModel>Private</externalSharingModel>
<sharingModel>ReadWrite</sharingModel>
<label>Watcher Digest</label>
<pluralLabel>Watcher Digests</pluralLabel>
<nameField>
    <displayFormat>WD-{0000}</displayFormat>
    <type>AutoNumber</type>
</nameField>
```

**Fields:**

| API name | Type | Purpose | Notes |
|---|---|---|---|
| `RunDateTime__c` | DateTime, required | When the run started | Indexed |
| `RunDurationMsNumber__c` | Number(18,0) | How long the run took in milliseconds | Trend metric — when this climbs, query inefficiency is creeping in |
| `StatusPk__c` | Picklist (GVS-backed) | `Success` / `Partial` / `Failed` | **GVS from day one** per CLAUDE.md GVS rule; create `WatcherDigestStatus__gvs` |
| `DigestTextLong__c` | LongTextArea(32k) | The full markdown/Block Kit body posted to Slack | For audit replay |
| `SignalCountsTxt__c` | Text(255) | Compact summary, e.g. `SLA:3,Stuck:1,AR:2,UnhappyStub:0,SignoffStub:0,PaymentStub:0,SyncTrendStub:0` | For trending / queries |
| `FlaggedWorkItemIdsTxt__c` | LongTextArea(4k) | Comma-separated WI IDs Watcher flagged | Lets us answer "did the WI Glen flagged 7 days ago get resolved?" — join WatcherDigest history to current WI state |
| `FlaggedDocumentIdsTxt__c` | LongTextArea(4k) | Comma-separated DeliveryDocument IDs flagged | A/R aging history |
| `ErrorMessageTxt__c` | LongTextArea(4k) | Filled when `StatusPk__c='Failed'` | Same shape as `SyncItem__c.ErrorLogTxt__c` |
| `RecipientUserIdsTxt__c` | Text(255) | Snapshot of who was on the recipient list at this run | So Glen-to-Mahi-expansion is traceable |
| `RunModePk__c` | Picklist (GVS-backed) | `Scheduled` / `Manual` / `Test` | Distinguish scheduled cron runs from Glen-triggered ad-hoc + test-context runs |

**Retention:** standard. WatcherDigest rows are small and bounded (1/day × 365 days = 365 rows/yr/org). No cleanup job needed in v1. If they grow, add to `DeliveryActivityLogCleanup` follow-on.

**Permset assignment:** `DeliveryHubAdmin_App` gets full CRUD; `DeliveryHubApp` gets read.

### Configuration surface — `DeliveryHubSettings__c` fields

All DateTime per `[[no-booleans]]`. Per-signal toggles default to set-on-install for the top 3 (since they're implemented), null for the 4 stubs.

| Field | Type | Default | Purpose |
|---|---|---|---|
| `EnableWatcherDigestDateTime__c` | DateTime | null | Master opt-in. Null = entire Watcher silent. |
| `EnableWatcherSLABreachDateTime__c` | DateTime | set on install handler | Signal 1 gate |
| `EnableWatcherStuckStageDateTime__c` | DateTime | set on install handler | Signal 2 gate |
| `EnableWatcherARAgingDateTime__c` | DateTime | set on install handler | Signal 3 gate |
| `EnableWatcherUnhappySignalDateTime__c` | DateTime | null | Stub A gate |
| `EnableWatcherSignoffDateTime__c` | DateTime | null | Stub B gate |
| `EnableWatcherPaymentOpsDateTime__c` | DateTime | null | Stub C gate |
| `EnableWatcherSyncTrendDateTime__c` | DateTime | null | Stub D gate |
| `WatcherDigestSlackChannelTxt__c` | Text(255) | null | Optional Slack channel override (Block Kit `channel` field). Defaults to the channel the configured webhook lands in. |
| `WatcherDigestRecipientUserIdsTxt__c` | LongTextArea(1300) | null | Comma-separated User Ids. v1 = Glen's User Id only. v2 = settings-change-only to add Mahi. |
| `WatcherDigestRunHourGmtNumber__c` | Number(2,0) | 12 | GMT hour to fire (default 12 GMT = 8am ET / 5am PT — bracket morning standup) |
| `LastWatcherHeartbeatDateTime__c` | DateTime | null | Stamped on each successful run (mirrors `LastForecastAlertScanDate__c`) |
| `WatcherStuckStageDefaultDaysNumber__c` | Number(3,0) | 5 | Fallback when no `WorkflowEscalationRule__mdt` covers a stage |
| `WatcherARAgingMinDaysOverdueNumber__c` | Number(3,0) | 7 | Don't fire AR signal for invoices < N days overdue (avoid overlap with reminder #1) |

**No-Boolean-rule note:** Following `[[no-booleans]]`. Master-opt-in is `EnableWatcherDigestDateTime__c` (DateTime). All per-signal gates are DateTime. Two numeric "tuning" fields (`WatcherDigestRunHourGmtNumber__c`, `WatcherStuckStageDefaultDaysNumber__c`, `WatcherARAgingMinDaysOverdueNumber__c`) are Number-typed because they're integers, not feature flags.

---

## Slack output format

Mirrors `DeliverySlackService.postCommentBatch` Block Kit shape that just shipped in PR #782. Wraps in a single message; quiet-day produces no message at all (digest of nothing is noise).

### Skeleton

```
:eyes: Watcher Digest — 2026-05-18 08:00 ET
3 items need your eyes today.

*SLA Breach (1)*
• T-0142 — Compliance gate review · 3 days breached · stage: In Review · @owner
  https://nimba.lightning.force.com/.../WorkItem__c/0XX/view

*At Risk in <48h (2)*
• T-0167 — Cashflow report · 1 day to deadline · stage: Testing · @developer
• T-0169 — Risk rating spreadsheet · 2 days to deadline · stage: Awaiting Signoff · @owner

*Stuck Stage (1)*
• T-0151 — Slack inbound handler refactor · 6 days in Code Review (rule: SD_DevBlocked_1Day_Critical)

*A/R Aging*
• $4,300 overdue total · 2 invoices in 30+ band, 1 in 15-30 band
• Top: INV-0042 ACME Inc $2,800 (45d overdue)

Counts: SLA=3, Stuck=1, AR=2 | Run #WD-0042 (847ms)
```

**Implementation:**
- `DeliveryWatcherDigestFormatter` produces a `Map<String,Object>` Block Kit payload (Slack-API shape) AND a plaintext fallback string for the LongTextArea audit field.
- Posts via new `DeliverySlackService.postWatcherDigest(Map<String,Object> payload)` `@future(callout=true)` method — same auth path + URL config as the existing post methods.
- **Webhook reuse strategy:** Use the same `SlackWebhookUrlTxt__c`. If Glen wants a different channel, `WatcherDigestSlackChannelTxt__c` overrides (Block Kit `channel` field). Avoid forcing operators to configure a second webhook.
- **Quiet days:** If all signal queries return empty AND no stubs fire, post **no Slack message** but **still write `WatcherDigest__c` row** with `StatusPk__c='Success'` + empty body. Heartbeat stamp updates regardless. Lets the 14-day-clean gate measure "did the cron actually run every day" separately from "was there anything to say."

---

## Risk register

### 1. Duplication with David's local version of "Nimba Dev" — **UNRESOLVED**

Per `project_mf_standup_0518.md`: David has a "local version of Nimba Dev" — the DH sync-chain visibility surface MF uses to watch cross-org sync activity. Glen acknowledged he doesn't know its current state. **This may overlap with Watcher v1 scope, the cloudnimbusllc portal, or the heartbeat-field surface added in PR #786.** See Open Question 1.

### 2. Governor risk — SOQL fan-out in scheduled context

The 5-signal Watcher could trivially over-query if signals each do per-WI SOQL. Mitigation:
- Bulk SOQL only. One SOQL per signal class (max 2 for AR aging's aggregate + top-5).
- Hard cap at `LIMIT 50` per query.
- Watcher's main method asserts `Limits.getQueries() < 60` before commit + alerts via `WatcherDigest__c.StatusPk__c='Partial'` if a signal couldn't run.
- Same SOQL-cache trick `DeliveryEscalationNotifService.getDeliveryHubAlertTypeId` uses for the CustomNotificationType lookup — cache namespace + recipient user list per-tx.

### 3. Test data hygiene — `TestDataFactory` (Phase 1) now available

`TestDataFactory` shipped in PR #787 per the strategic plan. Watcher tests should consume it:
- `TestDataFactory.makeWorkItemWithSLABreach(daysBreached)` — would belong in the factory
- `TestDataFactory.makeOverdueInvoice(daysOverdue, amount)` — same
- Avoid the Master-Detail + reserved-word + bucket-alignment classes that hit PRs #770/#771/#772/#774. **Phase 2 PR is the second customer of the factory and the first true validation of its design.**

### 4. Subscriber-org rollout — Glen-only via `WatcherDigestRecipientUserIdsTxt__c`

Pattern verified:
- `WatcherDigestRecipientUserIdsTxt__c` defaults to null on install.
- Install handler (mirroring `DeliveryWeeklyDigestService.LastDigestSentDate__c` stamp pattern) populates Glen's User Id ONLY when running in his org (detect via Org Id match against a known-Glen-orgs MDT row; or read from `DeliveryHubSettings__c` if a pre-existing "primary admin user" field can be repurposed).
- Subscriber orgs see Watcher silent until they manually set the field. Same posture as `EnableWeeklyDigestDateTime__c` / `EnableForecastAlertsDateTime__c`.
- **Subscriber org behavior:** if `WatcherDigestRecipientUserIdsTxt__c` is null OR `EnableWatcherDigestDateTime__c` is null, the daily tick is a no-op early-return. No DML, no callout, no `WatcherDigest__c` row.

### 5. Existing-observability surfaces broken that would short-circuit Watcher — **FLAG ONLY, don't fix in this PR**

During recon, no broken surfaces were found that would silently break Watcher signal collection. Two adjacencies worth noting:
- `DeliveryEscalationNotifService.sendBellNotification` already handles managed-package namespace prefix lookup correctly (post PR #777 fix). Watcher doesn't use bells, so unaffected.
- `DeliveryForecastAlertService` SOQL fan-out was fixed in PR #778 (released 0.239). Watcher's stuck-stage signal pulls from the same WorkItem object — verify cap-at-20-WIs pattern doesn't accidentally cap *our* signal at 20 too. Mitigation: separate query, separate LIMIT 50.

### 6. Auto-Schedule modal + Phase 2 sequencing collision

Per memory, the Auto-Schedule modal shipped in PR #779 doesn't have real dependency data yet (Phase 5 in the plan). Watcher v1 doesn't depend on auto-schedule signal. No collision.

### 7. Slack rate limits

Slack incoming-webhook tier: ~1 msg/sec sustained. Watcher posts **at most one** message per run. No risk.

---

## Estimated effort

Reconciling against the 14h Phase 2 ceiling:

| Item | Hours | Notes |
|---|---|---|
| `WatcherDigest__c` object + 9 fields + GVS picklists + permset entries | 1.5 | GVS-backed from day one (CLAUDE.md rule) |
| 14 `DeliveryHubSettings__c` settings fields | 1.0 | Mirror existing field metadata patterns; no permset gates needed |
| `DeliveryWatcherService` orchestrator class | 1.5 | Reads flags, dispatches signals, merges results, persists audit row, posts Slack |
| `WatcherSLABreachQueryService` (signal 1) | 1.5 | Single SOQL + result struct |
| `WatcherStuckStageQueryService` (signal 2) | 2.0 | Reads `WorkflowEscalationRule__mdt`, builds per-stage query, merges |
| `WatcherARAgingQueryService` (signal 3) | 1.5 | Two SOQL (count + top-5), aging-band grouping |
| 4 stub classes (empty `query()` + flag-gate + minimal test) | 1.0 | 15 min each — class + class-test + flag check |
| `DeliveryWatcherDigestFormatter` (markdown + Block Kit + plaintext fallback) | 1.5 | Mirror `postCommentBatch` Block Kit pattern |
| `DeliverySlackService.postWatcherDigest` method (new @future) | 0.5 | Tiny addition to existing class |
| `DeliveryHubScheduler.enqueueWatcherDigestIfDue` + register cron | 0.5 | One method, idempotency stamp gate |
| Tests: orchestrator, each signal (3), each stub flag-gate (4), governor stress, Slack post fail-soft, digest record write | 1.5 | Leverage `TestDataFactory`. ~25 min per signal test |
| **Total** | **14.0** | Right at ceiling |

**Stretch / v2 (out of 14h scope):**
- Cron-trigger-replay UI (re-run yesterday's Watcher on demand) — 2h
- Per-recipient personalized digests (Mahi sees Mahi-relevant signals, Glen sees Glen-relevant) — 4-6h. Wait for v2.
- WatcherDigest reporting (custom report type, dashboard card showing 30-day signal-count trend) — 1-2h. Worth doing once Watcher has 30 days of data.
- Anomaly detection (Stub D properly implemented) — 3-4h once we have a baseline.

---

## Open questions for Glen

### 1. **David's local version of "Nimba Dev"** — clarify before scoping

From `project_mf_standup_0518.md`: David has a "local version of this one" (Nimba Dev sync-visibility surface). Glen acknowledged he doesn't know what happened with it. **Three options:**

a. **Pause Phase 2 until clarified.** Cost: another 24-48h before forward motion on Watcher. Risk: build something David already built or that overlaps.

b. **Build Watcher v1 as-planned and explicitly differentiate.** Watcher = *aggregate digest of escalation-worthy items, daily*. David's local-version = (presumably) *real-time sync-chain visibility tail*. They're orthogonal — Watcher consumes operational state, David's tool exposes operational state. **Recommended: this option.** Watcher is Glen-decision-facing; the local-version is operator-facing. Different audience, different cadence, different layer.

c. **Coordinate with David before scoping.** Cost: a meeting. Benefit: surface overlap early, possibly share signal-query infrastructure. Risk: another async-block on Glen's calendar.

**Recommended: option (b).** Watcher is unique scope (daily digest for Glen, escalation-worthy items only, Slack DM destination). Even if David's tool turns out to overlap operationally, it's almost certainly a different *layer*. Add a follow-up ask in the PR thread: when Glen has 5min he can ping David to confirm and we adjust if needed.

### 2. **`WatcherDigest__c` record vs Slack-only**

Plan-locked decision was "Slack + WatcherDigest__c audit record" — both. Confirming **double-write** is still wanted? Specifically:
- **Yes (recommended):** Audit record gives us trend analysis (30-day signal-count graph), Glen-actioned-followup verification ("the T-0142 I flagged 7d ago — is it still stuck?"), and replay capability. Cost: one DML per run.
- **Slack-only:** Saves the DML + custom object. Loses the trend-analysis capability. Lower-cost; weaker debugging.

**Recommended: stay with the planned double-write.** The DML cost is trivial (one row/day) and the trend analysis pays for itself the first time we wonder "is Watcher helping or just nagging?"

### 3. **Stuck-stage signal — leverage existing `WorkflowEscalationRule__mdt` or define separate Watcher thresholds?**

- **Reuse `WorkflowEscalationRule__mdt` (recommended):** Single source of truth. Glen adjusts one CMT row and both the existing escalation engine + Watcher pick it up. Risk: Watcher fires on the same WIs the escalation engine already emailed about — but that's *by design*, Watcher's job is to surface "still didn't move" regardless of whether assignees got the email.
- **Separate Watcher-only thresholds:** Allows Glen to dial Watcher independently (e.g. "I want to see stuck-stage at 3 days, but escalation rule emails assignee at 5 days"). Cost: parallel config + drift risk.

**Recommended: reuse `WorkflowEscalationRule__mdt`.** Add a fallback default (`WatcherStuckStageDefaultDaysNumber__c=5`) for stages with no rule.

### 4. **Slack post on quiet days?**

When all 3 signals + 4 stubs return zero, should Watcher:

- **Post a quiet-day heartbeat** ("Watcher: 0 items today. All clear.") — reassures Glen the cron is alive. Cost: one Slack message + minor noise.
- **Stay silent + write a quiet-`WatcherDigest__c` row only (recommended):** No Slack message. Audit record still proves the cron ran. `LastWatcherHeartbeatDateTime__c` stamps update. If Glen wants daily reassurance, he checks the Watcher Digest record list-view.

**Recommended: stay silent.** Heartbeat infrastructure (LastWatcherHeartbeatDateTime__c + WatcherDigest__c row) serves the "did the cron run" verification need. Slack is for "needs your eyes" only.

### 5. **Run hour — 12 GMT default OK?**

12 GMT = 8am ET / 5am PT / 1pm UTC+1. Matches forecast-alert's 8 GMT (4am ET — earlier than Glen's morning) and overdue-reminders' 9 GMT. Defaulting to 12 GMT puts Watcher in Glen's morning-window. Configurable via `WatcherDigestRunHourGmtNumber__c` per org. **Recommended: 12 GMT default.**

---

## Implementation order proposal

Recommend the implementation PR cluster as three sub-PRs rather than one 14h megacommit. Each PR is independently shippable + reviewable, behind its own feature flag.

### PR-A — Schema only (~2.5h)

- `WatcherDigest__c` object + 9 fields + GVS picklists + permset entries
- 14 `DeliveryHubSettings__c` settings fields
- No Apex logic. Pure metadata.
- Shippable independently. Subscriber orgs see new (empty) custom object + dormant settings fields. No behavior change.
- **Smoke test:** package upload-beta green + install on dh-prod verified.

### PR-B — Orchestrator + 1 signal, behind master flag (~7h)

- `DeliveryWatcherService` orchestrator (reads master flag, dispatches signals, persists `WatcherDigest__c`, posts Slack)
- `WatcherSLABreachQueryService` (signal 1 — highest-confidence)
- `DeliveryWatcherDigestFormatter` (markdown + Block Kit)
- `DeliverySlackService.postWatcherDigest` method
- `DeliveryHubScheduler.enqueueWatcherDigestIfDue` + 12 GMT gate + idempotency-via-`LastWatcherHeartbeatDateTime__c`
- All 4 stub classes (empty + flag-gated)
- Tests: orchestrator happy path, SLA-breach signal happy path + bulk + cooldown, stub flag-gate, Slack post fail-soft, digest record write
- `EnableWatcherDigestDateTime__c` defaults to null — Glen flips it on his org to activate.

### PR-C — Signals 2 + 3 (~4.5h)

- `WatcherStuckStageQueryService` (signal 2 — reads `WorkflowEscalationRule__mdt`)
- `WatcherARAgingQueryService` (signal 3 — `DeliveryDocument__c` aggregate)
- Each signal flag default = set on install
- Tests for each + governor-stress

### Rationale for splitting

- Each PR is < 8h scope (per `[[default-scope-and-defer-discipline]]` "ship the right thing the first time" lens).
- Three PRs × ~2 scratch orgs each = 6 scratch orgs — vs. a single 14h PR that would still consume 2 scratch orgs but be harder to roll back if one signal turned out to be noisy.
- PR-A is a pure metadata add that can land same-day, unblocks Phase 1 (TestDataFactory) follow-on tests, and gives Glen something to see in the org without committing to behavior.
- PR-B is the "Watcher is alive" milestone — first end-to-end Slack post + audit record. From this point, the 14-day stabilization gate clock can start running on signal-1-only data.
- PR-C adds the remaining two implemented signals once PR-B's orchestrator pattern is proven.

**Total ceiling: 14h across three PRs. No item slips into stretch unless an open-question answer changes scope.**

---

## Critical files (will create in implementation PRs)

### PR-A (Schema)
- `force-app/main/default/objects/WatcherDigest__c/WatcherDigest__c.object-meta.xml`
- `force-app/main/default/objects/WatcherDigest__c/fields/*.field-meta.xml` (9 fields)
- `force-app/main/default/globalValueSets/WatcherDigestStatus.globalValueSet-meta.xml`
- `force-app/main/default/globalValueSets/WatcherDigestRunMode.globalValueSet-meta.xml`
- `force-app/main/default/objects/DeliveryHubSettings__c/fields/*.field-meta.xml` (14 fields)
- `force-app/main/default/permissionsets/DeliveryHubAdmin_App.permissionset-meta.xml` (additions)
- `force-app/main/default/permissionsets/DeliveryHubApp.permissionset-meta.xml` (read-only additions)

### PR-B (Orchestrator + Signal 1 + 4 stubs)
- `force-app/main/default/classes/DeliveryWatcherService.cls` + test
- `force-app/main/default/classes/DeliveryWatcherDigestFormatter.cls` + test
- `force-app/main/default/classes/WatcherSLABreachQueryService.cls` + test
- `force-app/main/default/classes/WatcherUnhappySignalQueryService.cls` + test (stub)
- `force-app/main/default/classes/WatcherUpcomingSignoffQueryService.cls` + test (stub)
- `force-app/main/default/classes/WatcherPaymentOpsQueryService.cls` + test (stub)
- `force-app/main/default/classes/WatcherFailedSyncTrendQueryService.cls` + test (stub)
- `force-app/main/default/classes/DeliverySlackService.cls` (add `postWatcherDigest` method)
- `force-app/main/default/classes/DeliveryHubScheduler.cls` (add `enqueueWatcherDigestIfDue` method)

### PR-C (Signals 2 + 3)
- `force-app/main/default/classes/WatcherStuckStageQueryService.cls` + test
- `force-app/main/default/classes/WatcherARAgingQueryService.cls` + test

---

## Verification (per phase)

Per the strategic plan's Phase 2 verification block:

- Anonymous Apex: `new DeliveryWatcherService().run()` posts a digest to Glen's test channel
- Cron registered: `[SELECT Id, CronJobDetail.Name, NextFireTime FROM CronTrigger WHERE CronJobDetail.Name LIKE '%Watcher%']` returns rows
- `LastWatcherHeartbeatDateTime__c` stamp updates daily for 14 consecutive days
- `WatcherDigest__c` records accumulate, one per day, with `StatusPk__c='Success'` (or `Partial` with clean ErrorMessageTxt)
- Quiet-day behavior: when no signals fire, no Slack message but a `WatcherDigest__c` row IS written

---

## Memory cross-references

- `[[ship-full-cycle-not-just-pr]]` — Implementation PRs land + merged + beta_create + beta_promote + install verified, not just "PR opened."
- `[[no-booleans]]` — All feature toggles use `EnableXDateTime__c` pattern; never Boolean. Numeric tuning fields are Number-typed.
- `[[default-scope-and-defer-discipline]]` — Watcher is the right shape now; v2 features (per-recipient digests, anomaly detection) are explicitly deferred with a written rationale, not for convenience.
- `[[upload-beta-gotchas-consolidated]]` — Validate Master-Detail + reserved-word + bucket-alignment before pushing each PR; Phase 1 TestDataFactory consumed.
- `[[ask-richer-questions]]` — Open Questions are framed with Recommended + Reason + Implication, not menu-picks.
