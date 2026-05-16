# Namespace Hygiene Audit (2026-05-13)

> **Status as of 2026-05-16: PARTIALLY RESOLVED.** 4 of 5 confirmed bugs closed
> by PR #777 (merged 2026-05-13, released 0.238.0.1): Bug 1 (deliveryWorkItemRefiner
> field-name namespacing), Bug 2 (deliveryWorkItemActionCenter apiName strings),
> Bug 3 (CustomNotificationType DeveloperName — silent bell-notification regression),
> Bug 5 (FlexiPage dynamic-related-list parent-field refs). **Remaining: Bug 4
> (PermissionSetGroup DeveloperName) at `DeliveryHubDashboardController.cls:586`
> and `DeliverySyncDismissalService.cls:223` — 5-line fix, queued as a separate
> PR.** File preserved for Bug 4 follow-on.

Branch scanned: `fix/lwc-namespace-workitem-refs` (7 files in flight; their target patterns excluded per the PR-in-progress notice).

## Executive summary

1. **`deliveryWorkItemRefiner.html` lines 57, 58, 63, 67** ship unnamespaced `field-name=` attributes inside the *same* `lightning-record-edit-form` you're already fixing on line 18. The object fix alone won't unblock save on MF-Prod — the field bindings throw too. **Add these to the same PR.**
2. **`deliveryWorkItemActionCenter.js` lines 119, 127, 136, 144** hand string `apiName` values (`'ClientPreApprovedHoursNumber__c'`, etc.) to a `<lightning-input-field field-name={field.apiName}>` rendered inside a record-edit-form. Same failure class as #1 — these flow through `field.apiName` into the binding the .html fix touches.
3. **`DeliveryEscalationNotifService.cls:184`** and **`DeliveryWorkItemCommentTriggerHandler.cls:73`** query `CustomNotificationType WHERE DeveloperName = 'Delivery_Hub_Alert'`. The notification type ships in the package so subscriber orgs see `delivery__Delivery_Hub_Alert`. Result: bell notifications silently return zero rows and skip the send. No exception, just no notification — exactly the kind of silent regression that hides for weeks.
4. **`DeliveryHubDashboardController.cls:586`** and **`DeliverySyncDismissalService.cls:223`** query `PermissionSetGroup.DeveloperName = 'DeliveryHubAdmin'`. Same class as #3 — both PSGs (`DeliveryHubAdmin`, `DeliveryHubUser`) are packaged. The dashboard's `isAdminUser()` returns false for every subscriber admin, hiding admin UI. Confirm on MF-Prod whether PSG DeveloperName is namespace-prefixed on install (Glen has hit this before — pull one PSG record from MF-Prod via Tooling API to confirm).
5. **FlexiPage `DeliveryWorkItemAdmin.flexipage-meta.xml`** has three `<value>WorkItem__c.Id</value>` parent-field references and three `Requests__r` / `Sync_Items__r` relationship names. Salesforce normally namespaces these at install for `lst:dynamicRelatedList`, but spot-checking on MF-Prod is cheap and worthwhile given category-3/4 risk is already real.

## Confirmed bugs (will fail on subscriber org)

### Bug 1 — Unnamespaced `field-name` inside the record-edit-form

`force-app/main/default/lwc/deliveryWorkItemRefiner/deliveryWorkItemRefiner.html`
- Line 57: `<lightning-input-field field-name="AcceptanceCriteriaTxt__c"></lightning-input-field>`
- Line 58: `<lightning-input-field field-name="StepsToReproduceTxt__c"></lightning-input-field>`
- Line 63: `<lightning-input-field field-name="ClientPreApprovedHoursNumber__c"></lightning-input-field>`
- Line 67: `<lightning-input-field field-name="ProjectedUATReadyDate__c"></lightning-input-field>`

**Why it breaks on subscriber:** Even after you swap line 18 to `object-api-name="%%%NAMESPACE_DOT%%%WorkItem__c"`, the field-name strings still need to resolve against `delivery__WorkItem__c`. `lightning-input-field` expects either an unprefixed name on a same-namespace form *or* the prefixed name in a cross-namespace form. The form is now in the consuming org's namespace (subscriber) trying to bind to a packaged field — needs `delivery__`.

**Fix:** Token-prefix all four:
```html
<lightning-input-field field-name="%%%NAMESPACE_DOT%%%AcceptanceCriteriaTxt__c"></lightning-input-field>
<lightning-input-field field-name="%%%NAMESPACE_DOT%%%StepsToReproduceTxt__c"></lightning-input-field>
<lightning-input-field field-name="%%%NAMESPACE_DOT%%%ClientPreApprovedHoursNumber__c"></lightning-input-field>
<lightning-input-field field-name="%%%NAMESPACE_DOT%%%ProjectedUATReadyDate__c"></lightning-input-field>
```

Also update `deliveryWorkItemRefiner.js:62` (the `querySelector` referencing `field-name="AcceptanceCriteriaTxt__c"`) — it must match the rendered attribute value after CCI token replacement, which means querying `[field-name="${ns}AcceptanceCriteriaTxt__c"]` or using a stable `data-*` attribute instead.

Reference shape (already correct in this repo): `deliveryHubBoard.html:627-644` uses `field-name="%%%NAMESPACE_DOT%%%BriefDescriptionTxt__c"` etc.

### Bug 2 — Action Center `apiName` strings drive the field-name binding

`force-app/main/default/lwc/deliveryWorkItemActionCenter/deliveryWorkItemActionCenter.js`
- Line 119: `apiName: 'ClientPreApprovedHoursNumber__c',`
- Line 127: `apiName: 'EstimatedHoursNumber__c',`
- Line 136: `apiName: 'DeveloperLookup__c',`
- Line 144: `apiName: 'AcceptanceCriteriaTxt__c',`

These flow into `deliveryWorkItemActionCenter.html:36`:
```html
<lightning-input-field field-name={field.apiName} variant="label-hidden"></lightning-input-field>
```
inside the `<lightning-record-edit-form>` on line 31. Same break as Bug 1.

**Fix options:**
- (Recommended) Switch the four `apiName` values to imported field references via `@salesforce/schema` and use `.fieldApiName` (lines 16-22 already import `ESTIMATED_HOURS_FIELD`, `PRE_APPROVED_HOURS_FIELD`, `DEVELOPER_FIELD`, `CRITERIA_FIELD` from `@salesforce/schema/WorkItem__c.*` — use those rather than re-typing the strings).

  ```js
  this.missingFields.push({
      apiName: PRE_APPROVED_HOURS_FIELD.fieldApiName,
      reason: 'Define Budget to enable Fast Track'
  });
  ```

- (Alternative) Hard-code the `%%%NAMESPACE_DOT%%%` token in each string. Functional but bypasses the LDS schema validation the imports give you.

### Bug 3 — `CustomNotificationType` lookup by unprefixed DeveloperName

`force-app/main/default/classes/DeliveryEscalationNotifService.cls:182-186`
```apex
List<CustomNotificationType> types = [
    SELECT Id FROM CustomNotificationType
    WHERE DeveloperName = 'Delivery_Hub_Alert'
    LIMIT 1
];
```

`force-app/main/default/classes/DeliveryWorkItemCommentTriggerHandler.cls:71-74`
```apex
List<CustomNotificationType> notifTypes = [
    SELECT Id FROM CustomNotificationType
    WHERE DeveloperName = 'Delivery_Hub_Alert'
```

The notification type lives in `force-app/main/default/notificationtypes/Delivery_Hub_Alert.notiftype-meta.xml` — packaged metadata, so on subscriber orgs its `DeveloperName` is `delivery__Delivery_Hub_Alert`. Both queries return empty, the calling code's `isEmpty()` guard short-circuits, and **no notification fires**. No exception, no warning — totally silent.

**Fix:** Match either form. Cheapest:
```apex
WHERE DeveloperName = 'Delivery_Hub_Alert'
   OR DeveloperName = 'delivery__Delivery_Hub_Alert'
```
or use a `LIKE` on the suffix:
```apex
WHERE DeveloperName LIKE '%Delivery_Hub_Alert'
```
Validate either way with a packaged-context smoke test on MF-Prod. This is the same shape as the `@salesforce/schema` import pattern — the platform knows the package namespace, the query string doesn't.

### Bug 4 — `PermissionSetGroup.DeveloperName = 'DeliveryHubAdmin'` literal

`force-app/main/default/classes/DeliveryHubDashboardController.cls:582-589` (`isAdminUser`)
```apex
return ![
    SELECT Id FROM PermissionSetAssignment
    WHERE AssigneeId = :UserInfo.getUserId()
    AND PermissionSetGroup.DeveloperName = 'DeliveryHubAdmin'
    WITH SYSTEM_MODE
    LIMIT 1
].isEmpty();
```

`force-app/main/default/classes/DeliverySyncDismissalService.cls:223` — identical filter.

Both PSGs (`DeliveryHubAdmin.permissionsetgroup-meta.xml`, `DeliveryHubUser.permissionsetgroup-meta.xml`) are packaged. PSG DeveloperName behavior on subscriber: typically not namespace-prefixed (Salesforce treats PSG DeveloperName like PermissionSet — no prefix) — **but this needs MF-Prod confirmation** since this controller drives admin-only UI on the dashboard.

**Fix (defensive, costs ~10ms):**
```apex
AND (PermissionSetGroup.DeveloperName = 'DeliveryHubAdmin'
     OR PermissionSetGroup.DeveloperName = 'delivery__DeliveryHubAdmin')
```

**Verification step:** `cci org shell MF-Prod` →
```
SELECT DeveloperName, NamespacePrefix FROM PermissionSetGroup WHERE DeveloperName LIKE '%DeliveryHub%'
```
If `NamespacePrefix='delivery'` and `DeveloperName='DeliveryHubAdmin'` (no prefix in DeveloperName), the SOQL works as-is. If `DeveloperName='delivery__DeliveryHubAdmin'`, this is silently broken.

## Suspicious patterns (probably OK but worth a closer look)

### FlexiPage `parentFieldApiName` values

`force-app/main/default/flexipages/DeliveryWorkItemAdmin.flexipage-meta.xml`
- Line 107: `<value>WorkItem__c.Id</value>` (parentFieldApiName)
- Line 111: `<value>Requests__r</value>` (relatedListApiName)
- Line 164: `<value>WorkItem__c.Id</value>`
- Line 168: `<value>Sync_Items__r</value>`
- Line 221: `<value>WorkItem__c.ClientNetworkEntityLookup__c</value>` (custom-field grouping)
- Line 225: `<value>Requests__r</value>`

Also in `DeliveryDocumentRecordPage.flexipage-meta.xml:882-886` and `DeliveryNetworkEntityRecordPage.flexipage-meta.xml:598-602` and `DeliveryWorkItemCommentRecordPage.flexipage-meta.xml:289-293`.

**Why suspicious:** FlexiPage metadata normally gets auto-namespaced by the Metadata API on package install, so `WorkItem__c.Id` materializes as `delivery__WorkItem__c.Id` on subscriber. That's the documented Salesforce behavior. **But** the `DeliveryWorkItemAdmin.flexipage-meta.xml:221` value (`WorkItem__c.ClientNetworkEntityLookup__c`) is non-Id, and the related-list `relationshipName` (`Requests__r`, `Sync_Items__r`) doesn't carry a `__c` suffix — those are the cases where install-time namespace normalization sometimes misses.

**Action:** Pull one of these record pages on MF-Prod, open the related list, click any record — if it renders without error, you're safe. If the dynamic related list shows "Cannot find relationship" or similar, that's the bug.

### `<object>X__c</object>` in `*.js-meta.xml` `targetConfigs`

24 LWCs declare their targetObjects as unprefixed (`WorkItem__c`, `DeliveryDocument__c`, etc.). This is the documented Salesforce convention — the platform namespaces these on install. **Confirmed clean** based on existing successful component placements on subscriber FlexiPages (per memory note `feedback_field_manageability_only_on_mdt.md` — sibling LWC metadata files have shipped fine).

### Apex `Type.forName(className)` callsites

`force-app/main/default/classes/DeliveryWebhookEventRouter.cls:102-104` already does the namespace-tolerant double-lookup:
```apex
Type t = Type.forName(className);
if (t == null) {
    t = Type.forName('delivery', className);
}
```
`force-app/main/default/classes/IntegrationDispatcher.cls:200-203` does the same. **Clean** — the pattern is the right one and is being applied consistently.

### `deliveryHubBoard.js` defensive lookups

Lines 405, 657, 663, 1259 of `deliveryHubBoard.js` do `r[FIELDS.SORT_ORDER] || r['delivery__SortOrderNumber__c'] || r['SortOrderNumber__c']` — namespace-tolerant fallbacks. **Clean** but worth a code-review note: this pattern proliferating is a smell, and `deliveryHoursPills.js:43-56` has a much cleaner `_field()` helper that does case-insensitive suffix-matching once. Consider promoting that helper to a shared utility for the next consolidation pass.

### CSV import field-key strings

`force-app/main/default/lwc/deliveryCsvImport/deliveryCsvImport.js:16-24` and again at 493-497 use string literals like `'BriefDescriptionTxt__c'` as target SObject field keys. **Clean** — these flow into an Apex Aura method `DeliveryCsvImportController`, which handles namespace resolution server-side via `Schema.getGlobalDescribe()` + `getNamespacePrefix()` lookups (see `DeliveryCsvImportController.cls:228-235`). Confirmed by the existing comment block on line 228-229.

### deliveryProFormaTimeline NG fieldSchema

`deliveryProFormaTimeline.js:629-645` uses unprefixed `key` values like `'BriefDescriptionTxt__c'`. **Clean** per the inline comment at lines 622-627 — `Apex updateWorkItemFields` resolves namespace server-side. Verified consistent with the existing `DeliveryGanttController.updateWorkItemFields` pattern.

## Areas confirmed clean

- **Platform event channels:** All eight callsites (`deliveryActivityFeed`, `deliveryActivityTimeline`, `deliveryBoardMetrics`, `deliveryProFormaTimeline`, `deliveryHubBoard`, `deliveryWorkItemDependencies`, `deliveryWorkItemChat`, `deliveryRecordLiveRefresh`) use `'/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e'` uniformly.
- **`@salesforce/schema/...` imports:** Every LWC field/object import uses the unprefixed name; this is the correct LWC pattern — Salesforce resolves namespace at runtime via the platform schema service.
- **Apex `getInstance()` on custom settings / CMDT:** All 28 callsites compile in package namespace and are fine.
- **`Schema.SObjectType.X__c.isCreateable()` and equivalents:** All Apex schema accessors compile in package namespace — safe.
- **`Schema.getGlobalDescribe().get('delivery__' + apiName)`:** `DeliverySyncItemIngestor.cls:1052-1054` does namespace-tolerant lookup with explicit prefix fallback. Pattern is correct.
- **`endsWithIgnoreCase('WorkItem__c')` in `DeliverySyncItemIngestor`:** Lines 204, 773, 796 use suffix matching — namespace-tolerant by design.
- **Test classes' `DeveloperName='R'` / `'TestRule'` / `'Test_Provider'` / `'Test_Inbound'`:** These are test-data inserts (`new __mdt(DeveloperName=...)`) — values supplied at test time, not lookups, so no namespace concern.
- **`PageReference('apex/...')`:** zero matches — no VF redirect patterns to audit.
- **`Site.getName()` / static-resource literals:** zero matches.
- **FieldSet API references:** zero matches (no `getFieldSets()` callsites).

---

## Cross-reference to existing memory

The `feedback_upload_beta_gotchas_consolidated.md` memory file catalogs CI-time namespace gotchas (Master-Detail required, reserved-word, bucket-alignment) but does **not** cover the *runtime* subscriber-org namespace class this audit surfaces. Bugs 1-4 above are net-new categories worth a separate feedback entry once fixed:

- **`field-name=` inside `lightning-record-edit-form`** — namespace token required even when the form's `object-api-name` is tokenized.
- **`apiName` strings driving `field-name` bindings via for:each** — same class, JS-side.
- **Cross-namespace `CustomNotificationType` / `PermissionSetGroup` DeveloperName lookups** — both need `delivery__`-aware filters.

Recommend a `TestDataFactory.lwcNamespaceAttribute(name)` helper (already on the consolidated-gotchas roadmap) be extended to lint these patterns in CI — `field-name=` without `%%%NAMESPACE_` + `WHERE DeveloperName =` literals against packaged metadata DeveloperNames.
