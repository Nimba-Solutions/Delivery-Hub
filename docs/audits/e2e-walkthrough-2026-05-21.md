# E2E Business-Logic Walkthrough — 2026-05-21

> Three factual corrections to the original walkthrough are inline below:
> 1. **Watcher v1 IS merged to main** (PRs #807 / #809 / #810). The agent claimed it was on unmerged feature branches; it's in `release/0.246.0.4` LIVE.
> 2. **`POST /scratch-orgs` and `PATCH /scratch-orgs/{id}` REST routes DO exist** (PR #804). The agent claimed they were unshipped. Verified in `DeliveryPublicApiService.cls`.
> 3. **Flow 3 #2 quiz-retry-gate claim is wrong** (verified 2026-05-22 during follow-on UX-gap fan-out). `AllowRetryDateTime__c` lives on `OnboardingQuiz__mdt` (a static catalog flag, populated = retries allowed), NOT on `OnboardingProgress__c` as a runtime cooldown. The service does not "set" it; it only reads it. The LWC at `deliveryFeatureOnboarding.js:169` (`quizSubmitButtonDisabled` getter) already honors this flag: `if (this.quizSubmitted && !this.quizAllowsRetry) { return true; }`. The retry gate IS honored. No-op PR.
>
> All other findings hold and are serious.

## Headline

**Critical paths are incomplete end-to-end.** Feature toggle + onboarding happy path works. But:
- **No approval submission UI** (service exists, no LWC form to call it)
- **No approver auto-assignment** (admins must open each row to set `ApproverUserLookup__c`)
- **No audit-trail viewer** for `ActivityLog__c`, `WatcherDigest__c`, or `OnboardingProgress__c`
- **No notification on approval grant** (requester polls manually)
- **External onboarding checklist evaluators are stubs** (SoqlQuery / RestCall / WebhookReceived)
- **No Watcher-digest viewing UI** even though the data is being written

---

## Flow 1 — Feature Catalog browse — ✅ WORKS

Install handler seeds Feature__c rows; `deliveryFeatureCockpit` LWC renders the catalog with admin-only Enable/Disable + "Show dependencies" buttons.

**Gap:** card has no link to a feature record page or docs — discovery dead-ends at the catalog.

## Flow 2 — Admin toggles a feature — ⚠ MOSTLY WORKS

End-to-end happy path: LWC → toggleFeature() → onboarding gate → cascade enforce → Feature__c update → trigger → ActivityLog + settings mirror. Cascade refusal opens preview modal automatically.

**Gaps:**
1. ActivityLog__c audit row is written but no admin LWC surfaces it. Reachable only via SOQL or a report (and no report type ships).
2. The cascade enforcement path (`DeliveryFeatureCatalogController.enforceCascadeOrThrow`) and the preview path (`DeliveryFeatureGraphService.computeCascade`) are independent — patching one risks visible divergence (toggle allowed but preview warns, or vice versa). Architecture review flagged the same.

## Flow 3 — Non-admin onboarding — ⚠ PARTIAL

Lessons → 4/5 quiz pass → Manual checklist → toggle works.

**Gaps:**
1. **Error toast doesn't link to the feature record page.** User must navigate manually.
2. ~~**Quiz retry gate not honored in UI.** `AllowRetryDateTime__c` is set by the service but `deliveryFeatureOnboarding.js` doesn't check it before showing the retake button.~~ **STALE (verified 2026-05-22).** `AllowRetryDateTime__c` is on `OnboardingQuiz__mdt` (catalog config, not runtime state). `deliveryFeatureOnboarding.js:169` already honors `quizAllowsRetry` (derived from `AllowRetryDateTime__c != null`) in `quizSubmitButtonDisabled`. Audit got both location and semantics wrong. **Adjacent polish opportunity** (deferred — not load-bearing): show explanatory message under the disabled Submit button when retries are blocked, and change button label "Submit Quiz" → "Retry Quiz" when `quizSubmitted && quizAllowsRetry`.
3. **External checklist evaluators (SoqlQuery / RestCall / WebhookReceived) are PR 4 stubs** — only `Manual` attestation actually verifies. Items render but always fail eval.
4. **No completion notification.** User has to manually navigate back to the cockpit to discover the gate has lifted.

## Flow 4 — Approval workflow — ❌ NOT END-TO-END

**No submission UI exists.** `DeliveryFeatureApprovalService.submit()` is `@AuraEnabled global static` — callable from REST and an LWC — but no LWC form was built. The `deliveryFeatureApprovalInbox` LWC only displays pending approvals.

After submit:
- **`ApproverUserLookup__c` is null at create.** No admin UI to assign approvers; admin must open each `FeatureToggleApproval__c` row directly. The security review flagged that the grant/reject methods don't even verify caller-is-approver, so a non-approver could call them via REST.
- **No notification to the requester on grant.** Apply happens, ActivityLog row writes, requester has no idea.

## Flow 5 — Dependency cascade preview — ⚠ PARTIAL

Preview renders correctly IF dependencies exist.

**Gap:** **no UI to create FeatureDependency__c records.** Admins must use Data Loader / DML / direct record-page creation (and per the Admin UX audit, **no record page or layout exists for FeatureDependency__c**, so even that fallback is broken).

## Flow 6 — Dev-loop mirror — ⚠ PARTIAL (correction below)

**Correction to original audit:** the REST endpoint exists. `POST /scratch-orgs` + `PATCH /scratch-orgs/{id}` are implemented in `DeliveryPublicApiService.cls` (shipped in PR #804, in `release/0.246.0.4`).

**Real gaps:**
1. **No example GitHub Action workflow shipped** in `.github/workflows/` that actually calls the endpoint. Subscriber devs would need to write their own.
2. **No auto-create of WorkItem__c** when a branch name doesn't match an existing WI — the LWC only shows scratch orgs linked to an existing WI.
3. **No record page or layout for `ScratchOrgInstance__c`** per the Admin UX audit, so even when rows exist they're hard to inspect.

## Flow 7 — Dataset loading — ⚠ PARTIAL

`DatasetTemplate__c` and the `load_feature_data` CCI task ship. LWC shows the template list + copies the command.

**Gaps:**
1. **No execution-context guidance** — the LWC just copies a CLI command with no note about local-CCI vs scratch-org.
2. **Nothing writes `DatasetTemplateAssignment__c` rows** after a successful load. The audit-trail object is shipped empty.
3. **`load_feature_data` task body** in `cumulusci.yml` is a parameterized wrapper — confirm it actually invokes the per-feature `scripts/feature-data/<name>.apex` file. Only `invoice_generation.apex` ships; other features have no script.

## Flow 8 — Watcher daily digest — ⚠ PARTIAL (correction below)

**Correction:** Watcher v1 IS shipped to main and is in `release/0.246.0.4`. PRs #807 (PR-A schema), #809 (PR-B orchestrator + Signal 1 + stubs), #810 (PR-C Signals 2+3) all merged.

**Real gaps:**
1. **No admin setup UI for the master flag + recipient list.** Subscribers must open Setup → Custom Settings → DeliveryHubSettings → edit to flip `EnableWatcherDigestDateTime__c` and populate `WatcherDigestRecipientUserIdsTxt__c`. No friendly form, no user picker, no help text.
2. **No digest-viewing UI.** `WatcherDigest__c` rows accumulate (audit-of-runs purpose) but no LWC reads them. Per the Admin UX audit, the object also has **0 field perms granted** in the `DeliveryHubAdmin_App` permset, so subscribers literally cannot read them at all.
3. **Slack post is fire-and-forget.** No fallback if the webhook 4xx/5xx's. The `WatcherDigest__c` row records `StatusPk__c='Success'` even if Slack didn't deliver.

---

## Cross-flow gaps

| Category | Gap |
|---|---|
| **Notifications layer** | Feature toggles, approval grants, onboarding completion — none notify anyone. Users poll. |
| **Admin assignment UIs** | Approver assignment is per-row manual. Feature dependencies are data-loader-only. Watcher recipients are raw text-field. |
| **Audit-trail surfaces** | `ActivityLog__c`, `WatcherDigest__c`, `FeatureToggleRequest__c` history, `OnboardingProgress__c` history — all data-rich, zero LWC. |
| **Link nav between surfaces** | Onboarding-gate toast doesn't link to the feature record page. Catalog cards don't link to feature record pages. Approval inbox doesn't link to cascade snapshot. WatcherDigest doesn't link flagged WIs. |

---

## Top 5 "this won't actually work end-to-end without ___" gaps

| # | Gap | Blocks | Effort |
|---|---|---|---|
| 1 | **No approval submission UI** — service exists, no LWC to call it | Flow 4 entirely | 1-2d (LWC form + cockpit modal entry point) |
| 2 | **No approver auto-assignment** — null at create, admin must edit each row | Flow 4 usability | 1-2d (Routing__mdt config + auto-assign on insert, plus security review's caller-is-approver assertion) |
| 3 | **No audit-trail viewer LWCs** — ActivityLog, WatcherDigest, OnboardingProgress history all invisible | All flows | 2-3d (3 LWCs + record-page placement) |
| 4 | **Admin UX bundle** (per separate audit) — 9 new objects missing tabs/layouts/record pages | Discoverability of any new feature | ~3.5h metadata-only (see admin-ux-audit) |
| 5 | **No notification layer** — requesters/users never told their action completed | UX confidence on every async flow | 2-3d (queueable + CustomNotificationType for bell + reuse Slack outbound for chat) |

---

## Verdict

### Works end-to-end today
- Feature catalog browse (Flow 1)
- Admin feature toggle with cascade enforcement (Flow 2)
- Non-admin onboarding happy path: Lessons → Manual quiz pass → Manual checklist → toggle (Flow 3)
- Cascade preview rendering when dependencies exist (Flow 5)
- Watcher signal pipeline → digest record written → Slack posted (Flow 8 happy path)

### Code shipped but no UI
- Approval submission (`submit()` is callable but no form)
- Activity audit trail (writes happen, no viewer LWC)
- Watcher digest history (records accumulate, no viewer + can't read fields anyway)
- Approver assignment (null at create, no admin UI)
- Dependency definition (no edit UI; layout missing)

### Code or content not yet shipped
- Onboarding quiz retry gating UI (service sets `AllowRetryDateTime__c`; LWC ignores)
- Onboarding non-Manual evaluators (Soql/Rest/Webhook checklist verifiers are stubs)
- Notification side-effects on toggle/approval/completion
- Example GitHub Action workflow for the `/scratch-orgs` endpoint
- Per-feature dataset-load scripts beyond `invoice_generation.apex`
- `DatasetTemplateAssignment__c` row insertion after CCI runs

### Net assessment

The cockpit is **roughly 60% end-to-end** for the happy-path user (admin browsing, toggling, an onboarding learner). The remaining 40% is "code shipped but no UI" or "no notification loop." A subscriber who installs today would see the cockpit, would successfully toggle a feature, would walk a Manual-only onboarding track, would see Watcher's Slack message at 8am ET — but would never figure out how to submit a request for approval, never see the audit trail, never know that a Watcher digest was even written, and never get told when their approval landed.

**Most leveraged next push:** the **Admin UX gap PR bundle** (~3.5h) + a single **approval submission + assignment UI PR** (~2 days). That converts ~25 of the 40% gap to working surfaces.
