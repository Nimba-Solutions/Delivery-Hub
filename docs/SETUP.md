# Delivery Hub Setup Guide

Step-by-step install + smoke test for `release/0.248.0.3` (current production-promoted release as of 2026-05-25). The newest beta on top is `release/0.249.x` carrying the in-app notification layer (PR #822).

For deep architecture, see [ARCHITECTURE.md](ARCHITECTURE.md). For per-layer cockpit reference, see [COCKPIT.md](COCKPIT.md). For end-user walkthroughs (first work item, document signing, AI), see [GETTING_STARTED.md](GETTING_STARTED.md).

---

## 1. Pre-install checklist

You need:

- A Salesforce org with **My Domain enabled** (required for the LWC bundles)
- **System Administrator** profile or equivalent for the installing user
- Outbound network access from your org to your Slack workspace (optional, only if you'll use Watcher's Slack post)
- For developer / contributor work only:
  - [CumulusCI](https://cumulusci.readthedocs.io/) installed (`pip install cumulusci`)
  - A Salesforce **Dev Hub** org with scratch-org allocations available
  - The Salesforce CLI (`sf` or `sfdx`)

Subscribers do **not** need CCI or a Dev Hub to install — only contributors and CI do.

---

## 2. Install the package

### Production org

[![Install in Production](https://img.shields.io/badge/Install-Production-0070d2?logo=salesforce&style=for-the-badge)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000T0SrIAK)

### Sandbox / scratch / pre-prod

[![Install in Sandbox](https://img.shields.io/badge/Install-Sandbox-3e8b3e?logo=salesforce&style=for-the-badge)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tQr000000T0SrIAK)

The install links point at the latest **promoted** release. To install a specific version, browse [GitHub Releases](https://github.com/Nimba-Solutions/Delivery-Hub/releases) and use that tag's install URL.

**At the install prompt**: select **Install for All Users** (recommended). The package install handler (`DeliveryHubInstallHandler.onInstall`) runs automatically and:

- Seeds default `DeliveryHubSettings__c` values (including the 14 Watcher settings — master flag stays off; 3 per-signal flags default on)
- Seeds `Feature__c` rows from `FeatureDefinition__mdt` (Layer 4)
- Schedules all background jobs via `DeliveryHubScheduler.scheduleAll()` (idempotent)
- Backfills permset assignments for existing users via `UserAutoAssignConfig__mdt`
- Backfills stale `Status='New'` WorkItems

### Known CI quirk

- `install-beta` job in CI is **known to fail** on a DeliveryHubSite error — this does NOT block promotion. Safe to promote when `upload-beta` is green. (Documented in `CLAUDE.md`.)

---

## 3. Assign permission sets

| Permset | Who gets it | Apex name |
|---|---|---|
| `DeliveryHubApp` | All end users | `DeliveryHubApp` |
| `DeliveryHubAdmin_App` | Admins, superusers | `DeliveryHubAdmin_App` |
| `DeliveryHubGuestUser` | Site Guest profile (only if exposing public API) | `DeliveryHubGuestUser` |
| `Delivery_Hub_Gantt_Fullscreen` | Optional, anyone using full-screen Gantt | `Delivery_Hub_Gantt_Fullscreen` |

### Quickest assignment (current user — admin)

```apex
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App'];
insert new PermissionSetAssignment(
    AssigneeId      = UserInfo.getUserId(),
    PermissionSetId = ps.Id
);
```

### Bulk assignment via SF CLI

```bash
sf org assign permset --name DeliveryHubAdmin_App --target-org YOUR_ALIAS
```

### From Setup UI

Setup → **Permission Sets** → click the permset → **Manage Assignments** → **Add Assignments** → pick users → **Assign**.

---

## 4. Initial smoke test

After install + permset assignment, walk this checklist to verify the install came up clean:

### 4.1 Apps and tabs visible

1. **App Launcher** → search "Delivery Hub" → both **Delivery Hub** and **Delivery Hub Admin** apps should appear.
2. Open **Delivery Hub Admin**.
3. Tabs along the top should include: `Home`, `Workspace`, `WorkItem`, `Board`, `Timeline`, `Activity`, `Activity Dashboard`, `NetworkEntity`, `WorkRequest`, `WorkItemComment`, `SyncItem`, `ActivityLog`, **`Feature`**, **`FeatureToggleRequest`**, **`WatcherDigest`**, **`ScratchOrgInstance`**, `Permission Analyzer`, `Settings`, `Guide`, `Reports`.

The four bolded tabs are the cockpit additions. If they're missing, re-check the `DeliveryHubAdmin_App` permset assignment.

### 4.2 Cockpit visible

1. Open the **Home** tab in **Delivery Hub Admin**.
2. The **Feature Catalog** card should render with seeded `Feature__c` rows (Layer 4).
3. The **Approval Inbox** card should render (likely empty on a fresh install — that's correct).

### 4.3 Quickstart Connection wizard

1. On the Home tab, find the **Getting Started** card.
2. Click **Quickstart Connection** — this configures scheduled jobs, connection handshake, and default settings.
3. The connection-health indicator should flip to **Connected** within a few seconds.

### 4.4 Scheduled jobs

Setup → **Apex Jobs** → **Scheduled Jobs**. You should see:

- `DeliveryHubScheduler` (15-minute tick)
- `DeliveryActivityLogCleanup` (daily)
- Plus a handful of feature-specific jobs (poller, reconciliation, weekly digest, etc.)

If the list is empty, the install handler didn't run. Re-run manually:

```apex
delivery.DeliveryHubScheduler.scheduleAll();
```

### 4.5 Toggle a feature (admin context — no approval gate)

1. On the **Feature Catalog** card, find a feature with `EnabledDateTime__c` null.
2. Click **Enable** (admin context bypasses the onboarding gate).
3. The card should flip to enabled; an `ActivityLog__c` row should be written; the corresponding `DeliveryHubSettings__c.Enable*DateTime__c` field should be mirrored.

Inspect the audit row in the **ActivityLog** tab or via the `deliveryAuditChainViewer` LWC if added to a flexipage.

---

## 5. Optional setup steps

### 5.1 Enable Watcher daily digest

`WatcherDigest__c` rows accumulate from install (the 3 active signals fire), but **Slack post stays off** until you set:

```apex
delivery__DeliveryHubSettings__c s = delivery__DeliveryHubSettings__c.getOrgDefaults();
s.delivery__EnableWatcherDigestDateTime__c        = Datetime.now();
s.delivery__WatcherDigestRecipientUserIdsTxt__c   = '005...,005...';       // comma-separated User Ids
s.delivery__WatcherSlackWebhookUrlTxt__c          = 'https://hooks.slack.com/...';
upsert s;
```

The per-signal flags (`EnableWatcherSLABreachDateTime__c`, `EnableWatcherStuckStageDateTime__c`, `EnableWatcherARAgingDateTime__c`) default to enabled at install — toggle them off individually if you want to silence a signal without disabling the whole digest.

To view past digest runs, use the **WatcherDigest** tab or the `deliveryWatcherDigestHistory` LWC.

### 5.2 Enable cross-org sync

See [GETTING_STARTED.md §5](GETTING_STARTED.md#5-set-up-cross-org-sync-optional) for the full vendor-org + client-org setup. Summary:

1. Create a `NetworkEntity__c` on each side (one as Client, one as Vendor)
2. Add Remote Site Settings for the peer's domain
3. Create a `WorkRequest__c` linking a WorkItem to the vendor NetworkEntity
4. Optionally set `HmacSecretTxt__c` for HMAC-signed payloads
5. Optionally set `ApiKeyTxt__c` for API-key auth

### 5.3 Configure billing entity

```apex
delivery__DeliveryHubSettings__c s = delivery__DeliveryHubSettings__c.getOrgDefaults();
s.delivery__DefaultBillingEntityIdTxt__c = '<NetworkEntity Id>';
upsert s;
```

### 5.4 Configure OpenAI for AI features

Open **Delivery Hub Admin** → **Settings** tab → **AI Settings** → enter your OpenAI API key → Save.

This enables auto-drafting of work-item descriptions + acceptance criteria + weekly digest AI narratives.

---

## 6. Upgrades

The package upgrades cleanly via the install link — `DeliveryHubInstallHandler.onInstall` is idempotent. New settings get defaulted; new Feature__c rows get seeded; no data migration steps are required.

**One CI/CD note** specific to subscribers running the package in a downstream scratch / unlocked install:

- After upgrade, run `delivery.DeliveryHubScheduler.scheduleAll();` from anonymous Apex if you suspect scheduled jobs didn't re-register.
- For sync-heavy installs, run a reconciliation once after major upgrades: `delivery.DeliverySyncReconciler.reconcileAll();`

---

## 7. Common gotchas

| Symptom | Cause | Fix |
|---|---|---|
| `install-beta` CI job fails on DeliveryHubSite | Known issue; doesn't block promotion | Ignore; promote when `upload-beta` is green |
| LWC throws "object not found" at `[WorkItem__c]` | Calling without namespace in subscriber context | Use `[delivery__WorkItem__c]` — fixed broadly in PR #777, but custom code may still hit it |
| `Schema.getGlobalDescribe().get('Foo__c')` returns null | `delivery__` namespaced packaging context | Use typed `Foo__c.SObjectType.getDescribe()` instead (memory: `namespace-safe-typed-sobject-describe`) |
| `WITH USER_MODE` SOQL throws in tests | Namespaced package test context breaks USER_MODE | Use `WITH SYSTEM_MODE` |
| `UNABLE_TO_LOCK_ROW` in CI | Flaky scratch-org contention | Re-run the job |
| Feature toggle button does nothing for a non-admin | Onboarding gate refusing | The user must complete the linked OnboardingTrack first; admin can bypass |
| Approval inbox is always empty | `ApproverUserLookup__c` defaults to null on insert | Admin must open each `FeatureToggleApproval__c` row and assign the approver manually (auto-routing is on the roadmap) |
| `WatcherDigest__c` records exist but Slack never posts | Master `EnableWatcherDigestDateTime__c` flag is null | Set the flag + the webhook URL — see §5.1 |
| Tabs missing in the Admin app | `DeliveryHubAdmin_App` permset not assigned to the running user | Re-assign the permset |

---

## 8. Anonymous Apex cheat sheet

All of these are safe to run in **Setup → Developer Console → Open Execute Anonymous Window** in a subscriber org (with the `delivery__` namespace prefix). Use without the prefix in the publisher / source org.

```apex
// Show current settings
System.debug(delivery__DeliveryHubSettings__c.getOrgDefaults());

// Re-schedule background jobs (idempotent)
delivery.DeliveryHubScheduler.scheduleAll();

// Force a sync reconciliation (drift detection + repair)
delivery.DeliverySyncReconciler.reconcileAll();

// Manually run a Watcher digest (independent of cron)
System.enqueueJob(new delivery.WatcherDigestRunQueueable());

// Generate a fresh API key
String key = delivery.DeliveryPublicApiService.generateApiKey();
System.debug('API key: ' + key);
```

---

## 9. Uninstall

Standard Salesforce package uninstall via Setup → **Installed Packages** → **Uninstall** next to Delivery Hub. All `delivery__` objects, classes, triggers, LWCs, layouts, and tabs are removed.

Custom records created by your team in `WorkItem__c`, `WorkLog__c`, etc. will be **deleted** during uninstall. Export anything you want to retain first.
