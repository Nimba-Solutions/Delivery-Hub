# Delivery Hub — Build Storyline (grounded in merged PRs #259–#928, 2026-02-24 → 2026-06-17)
> Distilled from the actual merged-PR record (600 PRs). Cited PR numbers throughout; "why" arcs are labeled inference. Purpose: give the Cowork campaign a *build-order → test-order* rationale and a fragility map (where to expect the most red). Companion to `00-master-execution-tracker.md`.

## Overall arc
DH was stood up **board-first → spine-first → surface-by-surface**. A late-Feb foundation burst laid the core procurement/delivery object model, a Kanban board, dashboards, and the managed-package skeleton at high velocity. The team almost immediately found the product only matters cross-org, so a **bidirectional sync spine** became the load-bearing subsystem — and it was patched in *every subsequent era*, never "done." On the spine they layered, in order: a public REST API + Experience Cloud portal (early Mar), a Document/Invoice engine (late Mar), an enterprise-hardening + refactor pass (early Apr), document e-signing and a brutal **Gantt/Locker-LWS rendering saga** (mid-Apr), an integration framework + the **GVS picklist reversal saga** (late Apr), live cross-org events + first forecast (early May), a self-configuration "cockpit" with onboarding/approvals/Watcher (mid-May), forecast/pacing + a procurement cart (early Jun), and finally the **work-approval queue + an autonomy "machine"** self-heal layer (mid-Jun). Through-line: every buyer surface depended on a trustworthy spine, and most recurring pain came from (a) the spine, (b) Gantt under Locker/LWS, and (c) the managed-package/namespace/picklist tax that taxed every era.

## Eras
**1 · Foundation burst (Feb 24–28)** — core objects, board, dashboards, package scaffold. #260 pre-prod fixes, #278 Slack+Gantt, #286/#288 multi-workflow platform, **#291 Ticket__c→WorkItem__c rename**, #303 SLA, #311 escalation, #318 portal, #326 PMD cleanup. *Tax:* #269/#279 USER_MODE→SYSTEM_MODE; **#282–#284 strip MD/Lookup FLS from permsets** (first package-boundary fight).

**2 · REST API + portal + push (Mar 8–14)** — #336 public REST API + key auth, #338 real-time vendor→client push, #341 multi-tenant PortalAccess, #352 sync auth + connection approval, #365 WorkLog approval gate. *Tax:* #350/#364 namespace tokens; #360–#362 field-tracking test failures in namespaced beta.

**3 · Document & Invoice engine (Mar 12–31)** — #346 Document Engine, #387 invoices+PDF+A/R+white-label, #389 agreement clauses+onboarding, #438 client invoice approval, #477 invoice automation+overdue, #492 email preview+scheduled send. *Drip:* #399/#482/#489/#500/#506 renderer/PDF/namespace-URL fixes.

**4 · Reconciliation + enterprise hardening + refactors (Mar 23–Apr 6)** — #390 Sync Reconciliation Framework, **#549 Bool__c→DateTime sweep**, #551/#552/#554 god-class decomposition, #555 rate-limit+audit immutability, #559 CMT approval workflows, #560 archival+HMAC. *Reversal:* **#564 rate-limiting walked back to opt-in/off**; #396 revert board filter.

**5 · E-signing + the Gantt/Locker-LWS saga (Apr 7–23)** — signing: #586 multi-party, #589 public portal signing, #592 hash-chain, #593 signature pad. **Gantt (densest pain cluster anywhere):** #531 then a near-continuous run **#603–#665** fighting Locker `prepend`/`insertBefore`, ResizeObserver polyfills, namespace tokens, static-resource dedup, and a sortOrder **snap-back loop** (#660/#662/#663/#665); diagnostic-only bundles (#652/#664) = debugging blind. *Reversal:* **#596 revert all 8 MD renames to unblock prod install.**

**6 · Sync ingestor deepening + integration framework + GVS saga (Apr 21–May 2)** — sync: #673 cross-org file pull, #720 ParentWorkItemLookup translation via ledger, #737 cross-org ID bridge + queue Comments, #744 auto-recover Failed Inbound, #747 predecisional gate. Framework: #700/#702 generic dispatcher. **GVS reversal (net round-trip, scar in CLAUDE.md):** #690→#691→**#692 revert**→#693 allowlist→**#711 deprecate**→#712 remove smoke test. *getNamespace thrash:* #713→#715→**#717 full revert** (misdiagnosis chain).

**7 · Live events + gantt editing + hours/forecast v1 (Apr 28–May 16)** — #722 zero-touch install, #723 DeliveryComment__e (replaces polling), #731–#733 cross-org real-time, #749 gantt drag-stages, #758 dependency cross-org sync, #768 velocity burn-up, #782 bidirectional Slack. *Tax:* **#752 default Status→Active (closes invisible-WI gap)** + #753 backfill; #777 namespace-safe API names.

**8 · The "Cockpit": catalog + onboarding + approvals + Watcher (May 18–31)** — #793/#794 Feature Catalog + dependency graph, #796/#798 onboarding tracks+gates, #799/#802 single→multi-step approvals, #807/#809/#810 Watcher schema+orchestrator+Signals 1–3, #843 zero-noise defaults, #844 consequence-preview. *Tax density:* #797/#800 namespace-safe describe, #805/#806 loosen assertions for packaging, #821 permset-group calc.

**9 · Forecast/pacing credibility + cart (Jun 1–10)** — #866/#869 pacing home view, #874 Checkout Cart (zero new objects), #880 projected-final counts all remaining, #883 cohort stacked forecast, **#885 leaf-only counting (kill double-count)**, #886 adopt NG render bundle, #887 demo-hardening. *Oscillation:* #876 cart system-mode DML → **#877 restore stripInaccessible+runAs** (PMD-vs-packaging tug).

**10 · Approval queue + autonomy "machine" (Jun 11–17)** — #891 approval queue, #892 queue LWC, #900 cap enforcement (flag default), #905 ETA write-back+green cohort, #906 bulk-approve, #908 billing preview, #910 estimate proposals, #916 group-by-epic, **#918 globalize Capture Field Change (SEE keystone)**, **#919 self-heal Move 1 (auto-diagnose, OFF default)**, #921 nameless team-line, #923/#924 durable buyer tabs + slider. *Tail:* #914 relay minting `without sharing`, #925 slider imperative render, #926 terminal-drop, **#928 audit-insert non-fatal + scope retry to Outbound** (sync, the day before this report).

## Fragility ranking (where Cowork should expect the most red)
1. **Sync spine** — patched every era through #928; cross-org FK translation, dedup, Failed-row recovery, sharing context. Broadest blast radius.
2. **Gantt/timeline under Locker/LWS** — ~25 consecutive `fix(gantt)` PRs (#633–#675); environment- and namespace-sensitive.
3. **Namespace / picklist propagation / packaging** — GVS net-zero round-trip (#690→#692→#711), MD-rename reversal (#596), getNamespace misdiagnosis (#717), endless "unblock upload-beta." A cross-cutting tax.
4. **Invoicing / doc rendering** — steady renderer drip + structural frozen-snapshot gap.
5. **Forecast double-count / shape** — recently reworked (#885/#925), still settling.

Smaller real reversal chains: Lightning Path #406→#409→#411; rate-limit on→off #564; cart DML #876→#877.

## Build-order → test-order recommendation
1. **Core objects + board + install/permsets** (Era 1, #752/#753, #722) — gates everything, cheap to check.
2. **Sync spine** (#928/#914/#861/#757/#744/#720) — broadest blast radius, longest fix history. Hunt red here first.
3. **Gantt/timeline** — highest per-feature churn; test specifically in namespaced managed-pkg context (Locker/LWS, sortOrder persistence, terminal-drop #926).
4. **Picklist propagation on UPGRADE** — given the GVS saga, test values land on a subscriber *upgrade*, not just fresh install.
5. **Sync-dependent surfaces last** — forecast (#885/#925), approval queue (#891/#916), invoicing (#859/#908). Test only after the spine is green, or failures get misattributed to the surface.
6. **Autonomy "machine" (#918/#919) ships dark** — verify the gates stay OFF and the keystone invocable is reachable; don't expect a live no-human loop unless flags are flipped.
