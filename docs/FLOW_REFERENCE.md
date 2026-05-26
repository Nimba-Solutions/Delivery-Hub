# Delivery Hub — Flow Reference

> End-to-end user flows through the Delivery Hub cockpit + Watcher v1 + onboarding-track + REST surfaces. Living document — superseded the point-in-time `docs/audits/e2e-walkthrough-2026-05-21.md` audit by capturing the post-Wave-1 state (PRs #818 / #819 / #820 / #821 merged to `main`).

Each flow declares its current status:
- **OK** — end-to-end working for the happy-path user.
- **PARTIAL** — works for some paths; one or more known gaps remain. Gap rows cite the audit they trace to.
- **NOT END-TO-END** — code shipped but a load-bearing UI / wiring component is missing.

---

## Flow 1 — Feature Catalog browse — OK

**Persona.** Any user with `DeliveryHubAdmin` or `DeliveryHubApp` PSG.

**Path.**
1. User navigates to `Feature Cockpit` App Page (FlexiPage `DeliveryFeatureCockpit`).
2. `deliveryFeatureCockpit` LWC calls `DeliveryFeatureCatalogController.getCatalog()`.
3. Controller joins `FeatureDefinition__mdt` (package catalog) ⨯ `Feature__c` (per-tenant runtime row) and returns a list of `FeatureCatalogRowDTO`.
4. LWC renders one card per row with status badge + admin-only Enable / Disable / Show Dependencies buttons (gated by `DeliveryHubDashboardController.isAdminUser()`).

**Status.** OK. The catalog browse path is the foundation of every other cockpit flow.

---

## Flow 2 — Admin toggles a feature — OK

**Persona.** Admin (`DeliveryHubAdmin` PSG holder).

**Path.**
1. Admin clicks Enable / Disable on a Feature Cockpit card.
2. LWC calls `DeliveryFeatureCatalogController.toggleFeature(featureId, action)`.
3. Controller calls `enforceCascadeOrThrow(featureId, action)`:
   - `DeliveryFeatureGraphService.computeCascade()` walks the dependency graph (BFS, depth cap 10).
   - If any Hard edge is violated, `AuraHandledException` is raised and the LWC auto-opens the cascade-preview modal.
4. If cascade is clean, controller flips `Feature__c.EnabledDateTime__c` (set or null).
5. `FeatureTrigger` fires `DeliveryFeatureTriggerHandler.onAfterUpdate()`.
6. Handler calls `DeliveryFeatureSyncService.syncFeaturesToSettings()` — mirrors the toggle into the legacy `DeliveryHubSettings__c.Enable*DateTime__c` field.
7. Handler calls `DeliveryFeatureSyncService.writeAuditRow()` — inserts an `ActivityLog__c` row with action `Feature_Toggle`.
8. `ActivityLogTrigger` fires `DeliveryAuditChainService.setHashOnInsert()` — computes the SHA-256 chain hash.

**Status.** OK end-to-end. Audit-trail viewer (Flow Cross-1) closed the only standing gap from the 5/21 audit.

---

## Flow 3 — Non-admin onboarding gate — PARTIAL

**Persona.** Non-admin user (`DeliveryHubApp` PSG).

**Path.**
1. Non-admin opens the Feature record page; `deliveryFeatureOnboarding` LWC renders.
2. LWC calls `DeliveryOnboardingService.getProgress(featureId)` — joins `OnboardingTrack__mdt` + `OnboardingLesson__mdt` + `OnboardingQuiz__mdt` + `OnboardingChecklistItem__mdt` with the user's `OnboardingProgress__c` row.
3. User progresses through lessons, takes the quiz (graded by `DeliveryOnboardingService.gradeQuiz()`), completes Manual checklist items via attestation.
4. When `CompletedDateTime__c` is populated on `OnboardingProgress__c`, the Feature Cockpit's non-admin Enable refusal lifts.
5. Non-admin can then toggle the feature (Flow 2 path).

**Status.** PARTIAL. End-to-end happy path works (Lessons → Manual checklist → toggle). Known gaps:
- **External checklist evaluators are PR 4 stubs.** `SoqlQuery` / `RestCall` / `WebhookReceived` verification methods always fall back to Manual attestation in the current build. Tracked in `docs/audits/e2e-walkthrough-2026-05-21.md` Flow 3 row 3.
- **No completion notification.** User navigates back to the cockpit manually to discover the gate has lifted. Closed in flight by PR #822 (notification layer), not yet merged to `main`.
- **Quiz retry gate.** Verified honored per `e2e-walkthrough-2026-05-21.md` Flow 3 row 2 correction (`deliveryFeatureOnboarding.js:169` reads `quizAllowsRetry`). Polish opportunity (button label "Retry Quiz" vs "Submit Quiz") tracked separately.
- **Error toast doesn't link to the feature record page.** User navigates manually. Cosmetic.

---

## Flow 4 — Approval workflow — PARTIAL (was NOT END-TO-END)

**Persona.** Requester (admin or non-admin); separate Approver.

**Path.**
1. Requester opens a Feature record page; `deliveryFeatureApprovalSubmit` LWC renders (added in PR #818).
2. Requester selects action (Enable / Disable), adds a reason, clicks Submit.
3. LWC calls `DeliveryFeatureApprovalService.submit(featureId, action, reason)`.
4. Service creates `FeatureToggleRequest__c` with Status=Pending + a frozen `CascadeSnapshotJsonTxt__c` (so the approver sees what they're approving even if dependencies change later).
5. Service walks the cascade graph (BFS) and inserts one `FeatureToggleApproval__c` row per non-Optional cascade node + a root-level row for the originally-requested feature.
6. Approver opens the `deliveryFeatureApprovalInbox` LWC (mounted on `DeliveryHubAdminHome` FlexiPage).
7. Inbox calls `DeliveryFeatureApprovalService.listPending()` and renders each pending row.
8. Approver clicks Grant or Reject, optionally adds a note.
9. Service stamps the approval row + calls `applyIfFullyGranted()` — when every required approval row resolves, flips the underlying `Feature__c`, auto-marks Soft / non-required rows Status='Auto', stamps the request Applied + AppliedDateTime, and writes an `ActivityLog__c` row.
10. Same trigger path as Flow 2 fires (sync + audit chain).

**Status.** PARTIAL. End-to-end now works (submission UI shipped in PR #818, caller-is-approver security guard shipped in PR #815). Known gaps:
- **No approver auto-assign in current `main`.** `ApproverUserLookup__c` is null at create; admin must open each `FeatureToggleApproval__c` row to assign. Closed in flight by PR-E `feat/approval-routing-auto-assign` branch (visible in `git log --all`), not yet merged.
- **No notification to requester on grant.** Closed in flight by PR #822, not yet merged.

---

## Flow 5 — Dependency cascade preview + edit — OK (was PARTIAL)

**Persona.** Admin.

**Path.**
1. Admin opens the Feature record page.
2. `deliveryFeatureDependencyEditor` LWC renders (added in PR #819 — closes the "no UI to create FeatureDependency__c records" gap from the 5/21 audit).
3. Admin adds / removes dependencies inline; LWC calls `DeliveryFeatureDepEditorController` methods.
4. Cascade preview pane (`deliveryFeatureCascadePreview` modal) renders the BFS expansion via `DeliveryFeatureGraphService.computeCascade()`.
5. Admin commits dependency changes; controller writes `FeatureDependency__c` rows.

**Status.** OK end-to-end as of PR #819. The audit's "no UI to create FeatureDependency__c records" gap is closed.

---

## Flow 6 — Dev-loop mirror — PARTIAL

**Persona.** Developer (external).

**Path.**
1. CI (GitHub Actions) provisions a scratch org via CumulusCI.
2. CI calls `POST /services/apexrest/delivery/deliveryhub/v1/api/scratch-orgs` with `{branch, orgId, loginUrl, cciFlow, workItemName, expiresAt}`.
3. `DeliveryPublicApiService.postScratchOrg()` authenticates via `X-Api-Key`, resolves the WorkItem by `Name` if provided, inserts `ScratchOrgInstance__c` with Status=Active.
4. During teardown, CI calls `PATCH /scratch-orgs/{id}` with `{state, lastSyncAt}`. `DeliveryPublicApiService.patchScratchOrg()` validates against the `ScratchOrgState` GVS and updates the row.
5. `deliveryDevLoopGuide` LWC on `ScratchOrgInstance__c` record pages renders the matching `DevLoopGuide__mdt` content.

**Status.** PARTIAL. REST routes + LWC ship; missing wiring:
- **No example GitHub Action workflow** in `.github/workflows/` that actually calls the endpoint. Subscriber devs roll their own.
- **No auto-create of `WorkItem__c`** when a branch name doesn't match an existing WI. Tracked in `docs/audits/e2e-walkthrough-2026-05-21.md` Flow 6 row 2.

---

## Flow 7 — Dataset loading — PARTIAL

**Persona.** Developer.

**Path.**
1. Developer opens the Feature record page; `deliveryDatasetTemplates` LWC renders.
2. LWC reads `DatasetTemplate__c` rows matching the feature, displays each with a "Copy command" button.
3. Developer copies the CLI command and runs it locally: `cci task run execute_anon --path scripts/feature-data/<feature>.apex --org <alias>`.
4. Apex script seeds sample data (idempotent, placeholder values only).

**Status.** PARTIAL. Code + CLI path ship; missing:
- **`DatasetTemplateAssignment__c` rows are not auto-inserted** after a successful load. The audit-trail object ships empty.
- **`load_feature_data` CCI task is a debug-stub wrapper.** Direct anonymous-apex invocation is the canonical path (per `scripts/feature-data/README.md`).
- **Only `invoice_generation.apex` ships.** Other features have no script.

---

## Flow 8 — Watcher daily digest — PARTIAL

**Persona.** Admin (recipient of the digest).

**Path.**
1. Subscriber admin enables Watcher: sets `DeliveryHubSettings__c.EnableWatcherDigestDateTime__c` to a non-null DateTime and populates `WatcherDigestRecipientUserIdsTxt__c` with comma-separated User Ids.
2. Scheduled job (`DeliveryWatcherScheduler.execute()`) runs daily at the configured cron.
3. `DeliveryWatcherService.runDailySweep()` reads the master flag, walks the enabled per-signal flags, and invokes each `Watcher*QueryService.query()` method.
4. Signal services (`WatcherSLABreachQueryService` / `WatcherStuckStageQueryService` / `WatcherARAgingQueryService` shipping; `WatcherFailedSyncTrendQueryService` / `WatcherPaymentOpsQueryService` / `WatcherUnhappySignalQueryService` / `WatcherUpcomingSignoffQueryService` are PR-B stubs returning empty) return their entries.
5. Service merges into a `WatcherRunResultDTO`, persists a `WatcherDigest__c` row (always — even on quiet days, for the 14-day stabilization gate), and posts a multi-section Slack message when there's something to say.
6. `deliveryWatcherDigestHistory` LWC (added in PR #820) renders the run history.

**Status.** PARTIAL. Signal pipeline works; missing:
- **No admin setup UI for the master flag + recipient list.** Subscribers must open Setup → Custom Settings → DeliveryHubSettings → edit to flip the flag and populate recipients. No user picker, no friendly form. `deliveryHubSetup` LWC could be extended.
- **Slack post is fire-and-forget.** No fallback if the webhook 4xx / 5xx's; the `WatcherDigest__c` row records `StatusPk__c='Success'` regardless.
- **4 of 7 signal services are stubs.** Functional, returning empty results, with full implementations queued for Phase 2.5+.

---

## Cross-flow — Audit-trail viewers — OK (NEW since PR #820)

**Persona.** Admin.

**Path.** Three read-only LWCs surface `ActivityLog__c`, `WatcherDigest__c`, and `OnboardingProgress__c` history:

| LWC | Mounts on | Data |
|---|---|---|
| `deliveryActivityLog` | App Page or any record page | `ActivityLog__c` rows scoped to org or to a specific record via `recordId` |
| `deliveryWatcherDigestHistory` | App Page | `WatcherDigest__c` rows, one per Watcher run |
| `deliveryOnboardingHistory` | App Page (org-wide view) or User record page (user-scoped) | `OnboardingProgress__c` rows |

**Status.** OK. Audit-chain hash readout supported via `deliveryAuditChainViewer` (existed pre-cycle).

---

## Cross-flow — In-app notifications — NOT IN `main` YET

Closed in flight by PR #822 (`feat(notify): in-app notifications on toggle/approval/onboarding events`). The branch exists; the PR is open but not merged to `main` as of 2026-05-26. When merged, the notification matrix becomes:

| Event | In-app bell | Slack | Email |
|---|---|---|---|
| Feature toggle (admin direct flip) | Y | (existing weekly digest) | N |
| Approval grant / reject (notifies requester) | Y | N | N |
| Onboarding completion (notifies user) | Y | N | N |
| Watcher daily digest | N | Y | N |

Until PR #822 merges, all four event rows are silent in-platform; subscribers polled the cockpit / inbox manually.

---

## Cross-flow — REST surface map

The full REST surface as of `release/0.248.0.3`:

| Method | Path | Purpose | Auth | Audit |
|---|---|---|---|---|
| `GET`  | `/services/apexrest/delivery/deliveryhub/v1/api/dashboard` | Portal home | `X-Api-Key` | N |
| `GET`  | `/work-items` | List WIs scoped to entity | `X-Api-Key` | N |
| `GET`  | `/work-items/{id}` | Single WI detail | `X-Api-Key` | N |
| `GET`  | `/activity-feed` | Org activity stream | `X-Api-Key` | N |
| `GET`  | `/conversations` | Comment threads | `X-Api-Key` | N |
| `GET`  | `/pending-approvals` | Approvals awaiting | `X-Api-Key` | N |
| `GET`  | `/work-logs` | Time-log rows | `X-Api-Key` | N |
| `GET`  | `/files` | Linked content | `X-Api-Key` | N |
| `GET`  | `/board-summary` | AI-summarized board state | `X-Api-Key` | N |
| `GET`  | `/documents` | Document list | `X-Api-Key` | N |
| `GET`  | `/documents/{token}` | Single document detail | Public token | N |
| `GET`  | `/feature-toggle-requests` | Audit list of requests (paginated, post PR #813) | `X-Api-Key` | N |
| `POST` | `/features/{name}/toggle` | Submit a toggle request (idempotency key, post PR #813) | `X-Api-Key` | Y |
| `POST` | `/feature-toggle-approvals/{id}/grant` | Approver grants | `X-Api-Key` + caller-is-approver guard (PR #815) | Y |
| `POST` | `/feature-toggle-approvals/{id}/reject` | Approver rejects | `X-Api-Key` + caller-is-approver guard (PR #815) | Y |
| `POST` | `/scratch-orgs` | CI provisioning hook | `X-Api-Key` | Y |
| `PATCH`| `/scratch-orgs/{id}` | CI state update (rate-limited, post PR #813) | `X-Api-Key` | Y |

Public-facing per-route documentation lives in `docs/PUBLIC_API_GUIDE.md` (refresh owned by a parallel agent).

---

## Status summary

| Flow | Status | Closed-since-5/21 deltas |
|---|---|---|
| 1. Feature catalog browse | OK | — |
| 2. Admin toggle | OK | Audit-trail viewer (Flow Cross-1) closed via PR #820 |
| 3. Non-admin onboarding | PARTIAL | Quiz retry gate confirmed honored (was wrong in 5/21 audit) |
| 4. Approval workflow | PARTIAL (was NOT END-TO-END) | Submission UI shipped (PR #818); caller-is-approver guard shipped (PR #815) |
| 5. Dependency cascade | OK (was PARTIAL) | Inline editor shipped (PR #819) |
| 6. Dev-loop mirror | PARTIAL | — |
| 7. Dataset loading | PARTIAL | — |
| 8. Watcher digest | PARTIAL | Digest history viewer shipped (PR #820) |
| X. Audit-trail viewers | OK (NEW) | Shipped via PR #820 |
| X. In-app notifications | NOT IN MAIN | PR #822 in flight |

---

## Related reading

- `docs/audits/e2e-walkthrough-2026-05-21.md` — point-in-time audit that originally surfaced the Flow 4 / Flow 5 / Cross-flow gaps that this doc now reports closed.
- `docs/audits/documentation-gap-audit-2026-05-26.md` — companion audit that registers documentation surfaces (this doc closes the "no flow-reference document" gap).
- `docs/DESIGN_PRINCIPLES.md` — the patterns each flow assumes (ActivityLog on every side effect, PSG admin check, GVS picklists, etc.).
- `docs/ARCHITECTURE.md` — the object model the flows traverse.
