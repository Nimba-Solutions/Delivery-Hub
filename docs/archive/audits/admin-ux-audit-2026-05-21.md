# Admin/Setup UX Audit — 2026-05-21

## Headline

**Significant subscriber-blocking gaps.** Cockpit + Watcher objects shipped with Apex controllers + field perms but **no tabs, no page layouts, no record pages**. They're discoverable only via LWC cards on home pages — admins can't navigate by tab, can't edit records via standard record pages, and `WatcherDigest__c` has **0 field perms granted** so subscribers literally can't read it.

This is the most serious gap surfaced in the post-cycle audit sweep. Most of these are 30min-2h fixes; bundling them as PRs is straightforward.

---

## 1. Tabs

| Object | Tab? | Finding |
|---|---|---|
| `Feature__c` | ❌ | Only via `deliveryFeatureCockpit` LWC on home page |
| `FeatureDependency__c` | ❌ | Nested in cockpit only |
| `FeatureToggleRequest__c` | ❌ | REST + Apex; no admin visibility |
| `FeatureToggleApproval__c` | ❌ | No audit interface |
| `OnboardingProgress__c` | ❌ | Via LWC only |
| `ScratchOrgInstance__c` | ❌ | No admin list view |
| `DatasetTemplate__c` | ❌ | LWC only |
| `DatasetTemplateAssignment__c` | ❌ | No direct access |
| `WatcherDigest__c` | ❌ | No tab or inbox UI |

## 2. App Menu Inclusion

`DeliveryHub.app-meta.xml` and `DeliveryHubAdmin.app-meta.xml`: **no new objects' tabs included** (would need to be created first).

## 3. Page Layouts

**0 of 9 new objects have a layout.** Record detail pages fall back to system defaults — fields are read-only / unordered regardless of permset access. Admins cannot edit records via UI.

## 4. FlexiPages

**What's there:**
- `DeliveryFeatureCockpit.flexipage-meta.xml` (App Page hosting `deliveryFeatureCockpit`) ✅
- `DeliveryHubHome.flexipage-meta.xml` has `deliveryFeatureCockpit` + `deliveryFeatureApprovalInbox` cards ✅

**What's missing — 0/9 record pages:**
No FlexiPage for any new object. Approval inbox is only on the user-facing home page; **not** on the admin home (`DeliveryHubAdminHome.flexipage`).

## 5. Permission Set Coverage

`DeliveryHubAdmin_App.permissionset-meta.xml` grants **most** new-object field perms:
- ✅ Feature__c, FeatureDependency__c, FeatureToggleRequest__c, FeatureToggleApproval__c
- ✅ OnboardingProgress__c, ScratchOrgInstance__c
- ✅ DatasetTemplate__c, DatasetTemplateAssignment__c
- ✅ ~~`WatcherDigest__c` has 0 field perms~~ — **stale claim.** Verified during PR #816 retry: all readable WatcherDigest__c fields + `<objectPermissions>` were shipped in PR-A #807. Audit snapshot was wrong on this row.

**Object-level CRUD note:** all 9 new objects have `<objectPermissions>` in both permsets (verified during PR #816). The original "search-confirmed" caveat was an audit gap, not a code gap.

## 6. Custom Settings Configuration UX

`DeliveryHubSettings__c` got 14 new Watcher fields in PR-A. Currently configurable only via Setup → Custom Settings (UX-hostile native UI) OR via `deliveryHubSetup` LWC card (which may or may not surface the Watcher fields — verify).

If `deliveryHubSetup` doesn't expose `EnableWatcherDigestDateTime__c` + `WatcherDigestRecipientUserIdsTxt__c`, the master flag and recipient list are essentially unreachable for non-developers.

## 7. Site Guest / Public Perms — OK

No new public/guest endpoints. New REST routes are X-Api-Key gated. No new ConnectedApp / Auth Provider needed.

## 8. CustomNotificationType — Major gap

**Directory `customNotificationTypes/` does not exist in the repo.**

No Watcher_Digest, Feature_Toggle, or ApprovalRequest notification types defined. This means:
- Approval requests cannot trigger in-app bell notifications (mobile-unfriendly)
- Watcher digest is Slack-only (no Salesforce alternative)
- Toggle decisions don't notify requesters in-platform

The Slack flow from PR 7 leans entirely on Slack outbound; a Salesforce-native fallback was never wired.

## 9. Quick Actions / Buttons — none for new objects

No "Request Toggle", "Approve/Reject", "Complete Onboarding", "Provision Scratch Org" quick actions. Everything goes through LWCs.

## 10. Reports + Report Types — none for new objects

No report types for `WatcherDigest__c` (30-day trends), `FeatureToggleRequest__c` (audit), `OnboardingProgress__c` (completion rates). Rich data, zero out-of-the-box reporting.

## 11. Email Templates — none for new flows

No completion / approval / digest email templates. Onboarding-complete and Watcher both async-only.

---

## Recommended PRs

### Subscriber-blocking (ship before GA)

| # | PR | Effort | Impact |
|---|---|---|---|
| 1 | **Add page layouts for 9 new objects** | ~2h | Without these, record-detail pages are broken — admins can't view/edit records via UI |
| 2 | **Grant `WatcherDigest__c` field perms in `DeliveryHubAdmin_App`** | ~5min | 0 fields visible today; subscribers see empty record pages |
| 3 | **Verify object-level CRUD grants for all 9 new objects in both permsets** | ~15min audit + however many fixes surface | Object perms may be missing entirely |
| 4 | **Add tabs for `Feature__c`, `FeatureToggleRequest__c`, `WatcherDigest__c`, `ScratchOrgInstance__c`** + add to `DeliveryHubAdmin` app menu | ~1h | Non-dev admins can't navigate to these objects today |

**Subtotal: ~3.5h, ships as one bundled PR. All low-risk metadata-only.**

### Polish (strongly recommended within 30 days)

| # | PR | Effort | Impact |
|---|---|---|---|
| 5 | Add record-page FlexiPages for Feature, ToggleRequest, WatcherDigest | ~2h | Embed dependency-graph, approval-chain, signal-summary LWCs in context |
| 6 | Add CustomNotificationTypes for Watcher_Digest + ApprovalRequest | ~1h + wire in Apex | In-app bell notifications; mobile parity with Slack |
| 7 | Verify `deliveryHubSetup` LWC surfaces the 14 new Watcher settings (extend it if not) | ~1h | Master flag + recipient list become reachable via friendly UI |

### Post-GA polish

| # | PR | Effort |
|---|---|---|
| 8 | Report types for WatcherDigest / FeatureToggleRequest / OnboardingProgress | ~1.5h |

---

## Verdict

### Works end-to-end today
- Feature cockpit (read + admin toggle via LWC)
- Approval workflow (via LWC inbox)
- Onboarding stepper (via LWC on Feature record page)
- Dev-loop guide + Dataset templates (LWC-only displays)

### Apex/REST-only (no admin UI)
- Feature toggle requests via REST — no audit UI for admins
- Watcher digest — runs in batch, no human-visible inbox
- FeatureDependency cascades — graph logic invisible to admins

### Broken in the UI right now
1. **No tabs** for any new object — Salesforce-navigator-only discovery
2. **No layouts** for any new object — record detail pages broken even when found
3. **`WatcherDigest__c` 0 field perms** — unreadable even by admin permset holders
4. **No approval audit trail** visible to admins
5. **No in-app notifications** — Slack-or-nothing on approvals

**Recommendation:** **ship PRs 1-4 (subscriber-blocking bundle, ~3.5h) before any external GA announcement.** PR 4 (tabs) and PR 1 (layouts) are the most embarrassing gaps — they make the package look unfinished even though the Apex/LWC is solid.
