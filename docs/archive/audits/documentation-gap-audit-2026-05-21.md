# Documentation Gap Audit — 2026-05-21

## Headline

The 21+ PRs shipped **functional systems** (cockpit feature lifecycle, Watcher v1, onboarding tracks with structured content, REST API surface) but **documentation is fragmented across audit files + design memos, not user-facing guides**. Subscribers lack setup instructions for 5 major new sObjects, can't find REST API definitions for 4 new routes, and have no template guide for the onboarding-track content pattern.

---

## 1. README / Top-Level — High severity

**Missing from `README.md`:**
- Feature Catalog (`Feature__c`, `FeatureDefinition__mdt`, `FeatureToggleRequest__c`, `FeatureToggleApproval__c`) — cockpit UI + toggle/approval workflow absent.
- Watcher v1 (`WatcherDigest__c`, signal queries, daily digest). README still mentions only the weekly digest.
- Onboarding Tracks (5 new `__mdt` types + `OnboardingProgress__c`).
- Version pinned at `release/0.239`; 0.243-0.246 (and pending 0.247) shipped in 36 hours.

## 2. Object-Level User-Facing Docs — High severity

| Object | User-facing doc? | Recommendation |
|---|---|---|
| `Feature__c` | No | Add "Feature Catalog Setup" section to GETTING_STARTED.md |
| `FeatureDefinition__mdt` | No | Part of Feature__c section (metadata registry) |
| `FeatureDependency__c` | No | Part of Feature__c section (dependency rules) |
| `FeatureToggleRequest__c` | No | REST API guide + admin UI workaround if any |
| `FeatureToggleApproval__c` | No | Approval workflow section |
| `WatcherDigest__c` | No | "Watcher Digest — Daily Operations Summary" — signals, Slack config, recipient setup |
| `OnboardingTrack__mdt` + Lesson/Quiz/ChecklistItem | No | "Onboarding Tracks — Self-Service Training" — show Invoice_Generation_Track sample + cloning steps |
| `OnboardingProgress__c` | No | Part of Onboarding Tracks docs |
| `ScratchOrgInstance__c` | No | REST API + Developer Setup |
| `DevLoopGuide__mdt` | No | Developer Guide |
| `DatasetTemplate__c` / `DatasetTemplateAssignment__c` | No | Clarify dev-vs-subscriber scope |

## 3. REST API Documentation — High severity

Four new routes shipped with **zero public docs**:
- `POST /features/{name}/toggle`
- `GET /feature-toggle-requests`
- `POST /feature-toggle-approvals/{id}/grant|reject`
- `POST /scratch-orgs` + `PATCH /scratch-orgs/{id}`

The 3 hardening fixes from `rest-api-surface-review-2026-05-21.md` (rate-limit PATCH, idempotency on toggle POST, pagination metadata) should ship together with the public docs.

## 4. CCI Task Docs — Medium severity

`load_feature_data` task exists in `cumulusci.yml` but no description/docstring; not mentioned in `GETTING_STARTED.md` or README.

## 5. Onboarding-Track Template Guide — High severity

`Invoice_Generation_Track` sample ships (3 lessons + 1 quiz + 3 checklist items) but no docs explaining:
- How to view the sample in an org
- How to clone it for a custom feature
- What the `__mdt` field names mean
- How `OnboardingProgress__c` tracks completion

Without this, subscribers can't reuse the pattern even though all four `__mdt` types are designed for it.

## 6. Migration / Upgrade Guide — Medium severity

No `docs/UPGRADE_GUIDE.md` covering:
- v0.243-0.247 release notes (feature summary, deprecations)
- Opt-in feature flags (Watcher master `EnableWatcherDigestDateTime__c` is null on install; subscribers must enable)
- New permission set assignments
- REST API stability notice (3 routes have known issues being fixed)

## 7. Architecture Diagrams — Medium severity

No Mermaid/flow diagrams for:
- Feature Catalog state machine (definition → request → approval → enabled/disabled, with dependency blocking)
- Watcher signal aggregation (cron → 7 signals → merge → Slack + WatcherDigest__c row)
- Onboarding track content structure (Track → Lesson/Quiz/Checklist → Progress)

Complex state machines without visuals are harder to grok for a new admin or contributor.

## 8. Stale Docs — none critical

`docs/SUBTRACT_GLEN_ROADMAP_2026-04-24.md` is still useful context; no contradictions with current state. No `*-RESOLVED.md` markers needed.

---

## Recommended doc-PR bundle

### PR-D1: REST API Completeness (~3h)
- Fix 3 issues in 4 new routes (rate-limit PATCH, idempotency guard on toggle POST, pagination metadata on list GET)
- Document all 4 routes in `PUBLIC_API_GUIDE.md` (or create the file) with request/response examples + error codes
- 1.5h code + 1.5h docs

### PR-D2: Feature Catalog + Watcher Setup Guide (~2h)
- Add "Feature Catalog — Toggle Management" and "Watcher Digest — Daily Operations Summary" sections to `GETTING_STARTED.md`
- Cover: how to find the cockpit, how to toggle, how to enable Watcher's master flag + recipient list

### PR-D3: Onboarding Tracks Template + Architecture (~2.5h)
- "Onboarding Tracks — Self-Service Learning Paths" section in `GETTING_STARTED.md`
- Create `docs/COCKPIT_ARCHITECTURE.md` with 3 Mermaid diagrams (Feature state machine, Watcher signal flow, Onboarding track content)

**Total: ~7.5h** across 3 PRs.

---

## Verdict

What ships now is **functional but undiscoverable**. Subscribers who install 0.247 will get:
- A working Feature Catalog with no UI/API guidance
- A daily Watcher digest that they don't know how to enable
- An onboarding-track sample they can't clone without reverse-engineering metadata field names
- Four REST routes with documented bugs (per `rest-api-surface-review`) and no public reference

**Recommendation:** ship the 3 doc PRs as a single "Documentation Completeness" release before declaring General Availability. Code can ship today; docs can ship tomorrow as `0.247.1` (docs-only) or bundled into `0.248`.
