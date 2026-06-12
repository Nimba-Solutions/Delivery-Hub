# DH-MCP Server — Design Doc (2026-06-12)

> Glen, 6/11 call with Mahi: *"we should be building Delivery Hub into the endpoints
> that it needs to access so that it can access its own thing through its own MCP
> server and make the appropriate updates without having to do the Salesforce CLI."*

This is a design doc only — no server code ships with this PR. It grounds the MCP
server in the REST surfaces that **already exist** in the package, names the gaps,
and proposes a crawl/walk/run rollout with PR-sized build chunks.

---

## 1. Architecture (one page)

### What exists today

Delivery Hub already ships three key-authenticated REST surfaces (all under
`/services/apexrest/delivery/`):

| Surface | Class | Base path | Auth | Scoping |
|---|---|---|---|---|
| **Public API** | `DeliveryPublicApiService` | `/deliveryhub/v1/api/*` | `X-Api-Key` (NetworkEntity) | Entity-scoped (most routes) |
| **Task API** | `DeliveryTaskAPI` | `/deliveryhub/v1/tasks/*` | `X-Api-Key` | **Tenant-less** — any active entity key sees all WorkItems |
| **Sync API** | `DeliveryHubSyncService` | `/deliveryhub/v1/sync/*` | `X-Api-Key` + optional HMAC | Org-to-org sync only — **not** an MCP target |

And, as of 0.276 (PR #904), the work-approval lifecycle is a **`global` Apex
service**: `DeliveryWorkApprovalService` — `submitForApproval(×2)`, `approve`,
`decline`, `requestIncrease`, `getPendingForApprover`, with global DTOs
(`PendingApprovalDTO`, `SubmitResultDTO`). The class comment says it explicitly:
global *"so admin scripting / future MCP automation in subscriber orgs can drive
the approval lifecycle directly."* The Apex half of the MCP story is done; the
missing half is thin REST routes in front of it (§4).

### Proposed shape

A small **TypeScript MCP server over stdio** (`@modelcontextprotocol/sdk`), run
locally by Claude Code / Claude Desktop, that wraps the REST endpoints as typed
tools. No Salesforce CLI in the request path.

```
┌─────────────────────┐   stdio (MCP)   ┌──────────────────────────┐   HTTPS
│ Claude Code /        │ ◄─────────────► │ dh-mcp server (TS, Node) │ ─────────►
│ Claude Desktop       │                 │  - tool registry          │
│ (.mcp.json entry)    │                 │  - REST client            │  Salesforce org
└─────────────────────┘                 │  - auth from env          │  /services/apexrest/delivery/
                                        │  - {success,error} →      │    deliveryhub/v1/api/*
                                        │    MCP result / isError   │    deliveryhub/v1/tasks/*
                                        └──────────────────────────┘
        env: DH_INSTANCE_URL, DH_API_KEY, SF_ACCESS_TOKEN (or OAuth refresh)
```

- **Transport**: stdio. One server per org connection; org/instance URL from env.
- **Namespace-aware**: base path is `/services/apexrest/delivery/...` on
  namespaced installs, `/services/apexrest/...` on scratch orgs — same
  configurable-prefix pattern the delivery-hub-companion `lib/api-client.js`
  already proved out.
- **Error mapping**: every DH endpoint returns the `{success, data}` /
  `{success: false, error}` envelope. The server maps `success:false` and non-2xx
  to MCP tool errors (`isError: true`) with the DH error string passed through —
  no string-parsing heuristics needed.
- **Rate-limit awareness**: Public API returns HTTP 429 + `Retry-After: 3600`
  when `PublicApiRateLimitNumber__c` is breached (default 100/hr when enabled).
  The server surfaces 429 as a retryable error rather than hammering.

### Auth model

Two credentials are involved, and they answer different questions:

1. **`X-Api-Key`** (NetworkEntity key, from `DH_API_KEY` env) — *which tenant
   slice* the call is scoped to. Never hardcoded; never written to disk by the
   server.
2. **Salesforce access token** (`Authorization: Bearer`) — *which user* the
   Apex transaction runs as. `/services/apexrest` on a My Domain host requires a
   session; only the Site-guest path avoids it.

**Per-user vs integration-user trade-off.** An integration user (one stored
refresh token, shared by everyone) is operationally simpler but breaks exactly
the things the approval queue was built on: `approve()`/`decline()` enforce
caller-is-approver via `UserInfo.getUserId()` (`assertCallerMayDecide`), audit
rows (`ActivityLog__c`, SHA-256 hash-chained) stamp the running user, and
unassigned requests stamp the decider as the approver. With an integration user
every decision would attribute to the bot. **Recommendation: per-user OAuth**
(Connected App, PKCE or JWT per user; v0 can bootstrap from `sf org display`'s
access token the way the companion extension does). This matches Glen's stated
preference from the Jose MCP rollout — *"it layers through their user
permissions"* — the MCP server should inherit the human's authority, not mint
its own.

### Where does the server live? (delivery-hub-companion inspected)

`C:\Projects\delivery-hub-companion` is a **Manifest V3 Chrome extension** —
vanilla JS, popup/background/content scripts, and an explicit repo rule: *"Keep
it zero-dependency — no npm, no build step, no bundler."* An MCP server is the
opposite animal: a Node stdio process with npm deps (`@modelcontextprotocol/sdk`,
`zod`) and a TypeScript build. **Verdict: not a viable home.** What IS reusable
from it: `lib/api-client.js`'s namespace-aware REST patterns and its
access-token-from-`sf org display` bootstrap. **Recommendation:** a new
standalone repo `delivery-hub-mcp` (mirrors the nimbus-gantt pattern — a
standalone TS library consumed alongside the Salesforce repo), keeping the DH
repo's CumulusCI packaging tree free of Node tooling.

---

## 2. Proposed v1 tool list (one page)

Names use a `dh_` prefix. "Exists" = the REST endpoint ships in 0.276 today.

### Crawl — read-only (Phase 1)

| Tool | Wraps | Exists? |
|---|---|---|
| `dh_get_dashboard` | `GET /api/dashboard` | ✅ |
| `dh_list_work_items` | `GET /api/work-items?status=` | ✅ |
| `dh_get_work_item` | `GET /api/work-items/{id}` (detail + comments + stages) | ✅ |
| `dh_get_activity_feed` | `GET /api/activity-feed?filterType=&pageOffset=` | ✅ |
| `dh_list_work_logs` | `GET /api/work-logs?workItemId=` | ✅ |
| `dh_get_pending_worklog_approvals` | `GET /api/pending-approvals` | ✅ |
| `dh_list_documents` | `GET /api/documents` (invoices/statements, read-only) | ✅ |
| `dh_get_board_summary` | `GET /api/board-summary` (AI summary; null-safe) | ✅ |
| `dh_get_pending_work_approvals` | work-approval queue feed (`getPendingForApprover`) | ❌ gap G1 |
| `dh_get_billing_preview` | unbilled approved hours × rate hierarchy for a period | ❌ gap G2 |

### Walk — low-risk writes (Phase 2)

| Tool | Wraps | Exists? |
|---|---|---|
| `dh_create_work_item` | `POST /api/work-items` (`title`/`description`/`priority`/`type`) | ✅ |
| `dh_add_comment` | `POST /api/work-items/{id}/comments` | ✅ |
| `dh_log_hours` | `POST /api/log-hours` (lands as Draft → human approval pipeline) | ✅ |
| `dh_update_work_item` | `PATCH /tasks/{id}` (stage + priority only today) | ⚠️ gap G3 |

### Run — decision verbs (Phase 3, after gap G1 ships + per-user OAuth)

| Tool | Wraps | Exists? |
|---|---|---|
| `dh_submit_for_approval` | `DeliveryWorkApprovalService.submitForApproval` | ❌ gap G1 |
| `dh_approve_work_request` | `DeliveryWorkApprovalService.approve` | ❌ gap G1 |
| `dh_decline_work_request` | `DeliveryWorkApprovalService.decline` | ❌ gap G1 |
| `dh_request_budget_increase` | `DeliveryWorkApprovalService.requestIncrease` | ❌ gap G1 |
| `dh_approve_worklogs` / `dh_reject_worklogs` | `POST /api/approve-worklogs` / `/api/reject-worklogs` | ✅ |

Tool descriptions will be prescriptive about *when* to call each tool (decision
verbs say "only when the user explicitly asks to decide"), and the three Phase-3
decision tools should be annotated non-read-only so hosts prompt for
confirmation.

---

## 3. Rollout: crawl / walk / run

Mirrors the MF org-MCP rollout decision — **read-only toolset first**, writes
only after the read layer has been used in anger.

1. **Crawl (read-only)** — ship the 8 existing-endpoint read tools. Zero new
   Apex. Risk ≈ zero; immediately useful for "what's on the board / what's
   pending / what got logged" questions without `sf` CLI.
2. **Walk (additive writes)** — create/comment/log-hours. All three are already
   guarded server-side (blank-create guard, entity-scope 403s, Draft worklog
   status), and none can destroy data.
3. **Run (decisions)** — approval verbs, only after (a) the new REST routes
   (G1) ship and (b) per-user OAuth is in place so `assertCallerMayDecide` and
   the audit chain attribute the human, not a bot.

---

## 4. Gap list — new Apex REST work needed

Verified against `DeliveryPublicApiService` routing (0.276): the Public API has
worklog approve/reject and **feature-toggle** approval verbs (Layer 8), but **no
work-approval (WorkRequest decision) routes at all**.

| # | Gap | What's needed | Notes |
|---|---|---|---|
| **G1** | Work-approval verbs not exposed via REST | New routes wrapping the now-global `DeliveryWorkApprovalService`: `POST /api/work-approvals/submit` (workItemIds + optional quoted hours), `POST /api/work-requests/{id}/approve` (`approvedHours`, `note`), `POST /api/work-requests/{id}/decline` (`reason`), `POST /api/work-items/{id}/request-increase` (`extraHours`, `reason`), `GET /api/work-approvals/pending` | The service is decision-complete (discretionary auto-approve, increase-delta math, backup approver, pings, audit rows). Routes are thin adapters + tests. Follow the PR #842 pattern: add as a NEW router tier to dodge the PMD complexity cap. |
| **G2** | No billing-preview endpoint | `GET /api/billing-preview?entityId=&periodStart=&periodEnd=` — dry-run of `DeliveryDocGenerationService`'s snapshot math (hours × 3-tier rate hierarchy, prior balance) **without inserting** a `DeliveryDocument__c` | The billing-preview PR was **not merged** as of 0.276 — checked the merge log through #905. Until it ships, the MCP tool is blocked (nearest read-only approximations: `/api/documents` + `/api/work-logs`). |
| **G3** | Work-item update is stage+priority only | Task API `PATCH /tasks/{id}` accepts `{stage, priority}` and is tenant-less (any active entity key). Either extend the Public API with an entity-scoped `PATCH /api/work-items/{id}` (estimate, developer, dates) or accept the narrow Task API surface for v1 | v1 can ship with the narrow surface; flag the tenant-less auth in the tool description. |
| **G4** | Per-user attribution | Connected App + per-user OAuth flow for the MCP server (PKCE; v0 bootstrap from `sf org display` token is acceptable for Glen-only use) | Without it, decisions/audit stamp the integration user — conflicts with the "layers through their user permissions" model. |
| **G5** | Idempotency on POSTs | `POST /api/work-items` and `POST /api/log-hours` create duplicates on retry (same known gap as `/scratch-orgs`) | Acceptable for v1 (agent retries are rare); v2 adds an `Idempotency-Key` header. |
| **G6** | Rate-limit headroom | Agent traffic vs `PublicApiRateLimitNumber__c` (100/hr default when enabled) | Operational knob, not code — document in the server README. |

## 5. Build estimate (PR-sized chunks)

**DH repo (Apex):**

| PR | Scope | Est. |
|---|---|---|
| DH-1 | G1: work-approval REST routes + tests (new router tier) | 4–6 h |
| DH-2 | G2: `GET /api/billing-preview` dry-run + tests | ~4 h |
| DH-3 (optional) | G3: entity-scoped `PATCH /api/work-items/{id}` | ~3 h |

**delivery-hub-mcp repo (TypeScript):**

| PR | Scope | Est. |
|---|---|---|
| MCP-1 | Scaffold: stdio server, env auth, namespace-aware REST client, error mapping + the 8 crawl read tools | ~4 h |
| MCP-2 | Walk write tools (create / comment / log-hours / narrow update) | ~2 h |
| MCP-3 | Run tools wired to DH-1 + billing preview wired to DH-2 | ~3 h |
| MCP-4 | `.mcp.json` example, README, smoke harness against a scratch org | ~2 h |

Total ≈ 20–24 h across 6–7 PRs. Crawl is shippable after MCP-1 alone (no Apex
changes required).
