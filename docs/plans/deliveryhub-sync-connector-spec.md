# `deliveryhub_sync` connector — SPEC ONLY

**Status: specification. DO NOT BUILD YET.** The live connector and anything engine/Phase-0-side are gated on the Bingham call (engine decision: Claude Agent SDK + API key, *not* subscription-headless). This doc exists so the Phase-0 session can start from a defined contract, not a blank page.

## Purpose

`deliveryhub_sync` is the one missing integration point that lets the CaseOps-style pipeline pull **Delivery Hub work items** the same way it already pulls Jira issues. It is a thin **reader**: a parameterized `sf data query` over `WorkItem__c` that emits a manifest in the **exact shape `jira_sync` produces**, so everything downstream in CaseOps (planning, dispatch, the agent loop) consumes DH work with zero new plumbing.

It is **read-only**. It does not write to Salesforce, does not run agents, and does not decide anything. Pull → emit manifest → done.

## Contract

| Aspect | Spec |
|---|---|
| **Invocation** | CLI, mirroring `jira_sync`'s entrypoint (e.g. `deliveryhub_sync --org <alias> --out <manifest.json>`). |
| **Auth** | A Salesforce CLI org connection (`sf`/`sfdx` auth) passed by alias/username. No new auth scheme — reuse whatever the Phase-0 host already has connected (`nimba` sandbox for Phase 0). |
| **Input filter** | `--since <iso8601>` (default: last sync watermark) and an optional `--stage`/`--status` filter, so a run pulls only the actionable slice (e.g. items ready for an agent), not the whole board. |
| **Output** | One manifest file (JSON), shape identical to `jira_sync`'s output. **Confirm the exact top-level envelope + per-item keys against the CaseOps `jira_sync` source before building** — this spec mirrors the intent, not a copy of that file (CaseOps is a separate repo, not present here). |
| **Idempotency** | Deterministic for a given `--since`; safe to re-run. Emits a new watermark the next run reads. |
| **Failure mode** | Non-zero exit + stderr on query/auth failure; never emits a partial manifest silently. |

## The query (DH side)

A single bounded `sf data query` over `WorkItem__c`. Candidate fields (all already exist — zero new metadata):

```
SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, StatusPk__c, PriorityPk__c,
       EstimatedHoursNumber__c, TotalLoggedHoursSum__c, CalculatedETADate__c,
       DeveloperLookup__c, DeveloperLookup__r.Name,
       ParentWorkItemLookup__c, ParentWorkItemLookup__r.Name,
       ClientNetworkEntityLookup__r.Name, ActivatedDateTime__c, LastModifiedDate
FROM WorkItem__c
WHERE LastModifiedDate >= :since
  AND StageNamePk__c NOT IN (<terminal stages>)   -- reuse getAllTerminalStageValues()
  AND TemplateMarkedDateTime__c = null
ORDER BY LastModifiedDate ASC
LIMIT <cap>
```

## Field mapping → `jira_sync` manifest shape

Map DH fields onto the jira_sync per-item keys. **Left column is canonical-jira_sync (confirm names against CaseOps); right is the DH source.**

| jira_sync key (confirm) | DH source |
|---|---|
| `id` / `key` | `WorkItem__c.Id` / `Name` (the `T-####` human key) |
| `title` / `summary` | `BriefDescriptionTxt__c` |
| `description` | `BriefDescriptionTxt__c` (+ latest proposal/criteria comment if the manifest carries a body) |
| `status` | `StageNamePk__c` (workflow stage) — or `StatusPk__c` if jira_sync expects a coarse status |
| `priority` | `PriorityPk__c` |
| `assignee` | `DeveloperLookup__r.Name` |
| `parent`/`epic` | `ParentWorkItemLookup__c` / `ParentWorkItemLookup__r.Name` |
| `estimate` | `EstimatedHoursNumber__c` |
| `updated` | `LastModifiedDate` |
| `url` | constructed record URL (`<instanceUrl>/<Id>`) |

Tenant/account context (`ClientNetworkEntityLookup__r.Name`) maps to whatever jira_sync uses for project/board scoping.

## Sequence (do NOT implement now)

1. **[gated: Bingham call]** Commit the engine (Agent SDK + API key) and stand up the Phase-0 host.
2. Read CaseOps `jira_sync` to lock the **exact** manifest envelope + key names.
3. Implement `deliveryhub_sync` as the thin reader above against the `nimba` sandbox.
4. Push one work item end-to-end through the existing CaseOps pipeline (read prod → fix sandbox → draft) to prove parity.

## Why it's deliberately thin

Everything after the manifest already exists in CaseOps. `deliveryhub_sync` is the single adapter that makes DH a drop-in source — so the smaller and more faithful-to-`jira_sync` it is, the less there is to maintain. No new objects, no new auth, no agent logic. Just: query the board, emit the manifest.
