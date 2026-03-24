# Changelog

All notable changes to the Delivery Hub package are documented here.

---

## 2026-03-24

### PR #428 — Configurable settings wired into Apex + admin dynamic forms + PDF hyperlinks

- **Configurable settings**: Four operational parameters previously hardcoded in Apex are now read from `DeliveryHubSettings__c` at runtime:
  - `ReconciliationHourNumber__c` (default 6) — controls the GMT hour for daily sync reconciliation
  - `SyncRetryLimitNumber__c` (default 3) — max retry attempts for failed sync items
  - `ActivityLogRetentionDaysNumber__c` (default 90) — activity log purge threshold
  - `EscalationCooldownHoursNumber__c` (default 24) — minimum hours between re-escalating the same work item
- **Dynamic Forms**: WorkItem Admin record page converted from page layout to Dynamic Forms with field-level conditional visibility
- **PDF hyperlinks**: Work item names in invoice PDFs are now clickable links to their Salesforce records (both work items table and time log detail table)
- **PMD compliance**: Non-final static fields renamed to camelCase

### PR #427 — LWC placements on record pages

- `deliveryScore` placed on WorkItem record page sidebar
- `deliveryDocumentViewer` placed on Document record page (Preview tab)
- `deliverySyncRetryPanel` placed on NetworkEntity record page sidebar

### PR #426 — Settings page overhaul

- DateTime activation toggles replace boolean switches for feature flags (e.g., Work Log Approval records the exact activation timestamp)
- Four new configurable settings exposed in the Settings UI: reconciliation hour, sync retry limit, activity log retention days, escalation cooldown hours
- Settings container redesigned with grouped cards

### PR #425 — Zero-hour invoice filtering

- Work items with zero logged hours in the billing period are automatically excluded from generated invoices

### PR #424 — Record page assignments + VF URL fix + PDF page-break fix

- Record page assignments added for all Lightning apps (Delivery Hub + Delivery Hub Admin)
- Visualforce `DeliveryDocumentPdf.page` uses runtime namespace detection instead of `%%%NAMESPACE_PREFIX%%%` merge tokens
- PDF page-break CSS fix for multi-page documents
- Invoice footer now includes a cloudnimbusllc.com hyperlink

---

## 2026-03-17

### PR #423 — Final PMD compliance

- Zero PMD violations across the entire codebase

### PR #422 — DashboardController PMD + record page guide

- DashboardController PMD compliance
- Record page assignment documentation
