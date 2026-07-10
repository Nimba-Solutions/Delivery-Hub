# Delivery Hub — The Confirmed Happy Path (do-it-yourself runbook)

> **What this is.** The one loop that takes a piece of client work from *first request* to a *paid invoice*, written as manual steps you can reproduce by hand on a **fresh, blank install**. Every step names the exact app, screen, button, and the Apex method behind it — and states, honestly, what has been verified and what you confirm by clicking.
>
> **Verified:** 2026-07-09, on a brand-new non-namespaced scratch org (`david-walk`, no seed data), by driving each step's real `@AuraEnabled` controller method end to end. Result: a **$2,100 invoice (12h × $175)** generated from the delivered work.
>
> **What "verified" means here — read this.** The backend logic of each step was exercised on a fresh install, **as a System Administrator (Apex system-mode)**. That is strong, but it is *not* the same as a browser click by a permission-set-gated buyer user. Two things it deliberately does **not** cover, and that you confirm by clicking through `david-walk` yourself:
> 1. **Field-level security for a non-admin/buyer user** — metadata-deployed fields start with zero FLS; the loop-critical fields have been backfilled into the app permsets (PRs #958/#959), but the *buyer-permset* WorkItem-create FLS and the `DeveloperDaysSizeNumber__c` sizing field are the known landmines to watch.
> 2. **The board's "+ New Work Item" modal render** (historically F16/F17). The record *data model* is proven; the *modal UI* is the thing to eyeball.
>
> So: **green below = "backend proven on fresh install." You close the loop by clicking it in `david-walk`.** That is the proof-to-yourself.

---

## The confirmed path at a glance

| # | Step | App | One-click? | Backend verified |
|---|------|-----|-----------|:---:|
| 1 | Onboard client + generate agreement | **Admin** | ✅ button | ✅ |
| 2 | Client signs the agreement | (client link) | e-sign page | ⚠️ engine ✅, click-through unverified |
| 3 | Work comes in (Report Issue) | Both | ✅ button | ✅ |
| 4 | Route intake → Ready for Sizing | Both | ✅ button | ✅ |
| 5 | Create the vendor request (vendor + rate) | **Admin** | field edits | ✅ |
| 6 | Size it (hours) | Both | field edits | ✅ |
| 7 | **Send to vendor** (→ Offer Sent) | **Admin** | ✅ button | ✅ |
| 8 | Approve the estimate | Both | ✅ button | ✅ |
| 9 | Log the hours delivered | Buyer record page | ✅ button | ✅ |
| 10 | Mark done (close out) | Both | ✅ button | ✅ |
| 11 | Generate the invoice | **Admin** | ✅ button | ✅ ($2,100) |

**Use the Admin app** (`Delivery Hub Admin`). Three steps (1, 5, 11) only exist there. The buyer app (`Delivery Hub`) is the simplified surface and does **not** carry the document/vendor screens.

**Two preconditions that are not buttons — get these right or the demo breaks:**
- **A work item must be linked to the client** (`Client` field on the Work Item record) or its hours will **not** roll into that client's invoice — you'll get a **$0 invoice**. Ghost/Report-Issue captures do *not* set this automatically.
- **Approve only works after "Send to vendor"** puts the request in **Offer Sent**. That's the state the approval queue reads. Approve a request that isn't Offer Sent and it errors (correctly).

---

## Before you start: open the blank org

```bash
sf org open --target-org david-walk
# board:  sf org open --target-org david-walk --path lightning/n/Delivery_Board
```

`david-walk` = a fresh non-namespaced install, **no seed data**, `DeliveryHubAdmin_App` permset assigned. Instance: `power-energy-1387-dev-ed.scratch.my.salesforce.com` (7-day scratch org). Switch to the **Delivery Hub Admin** app (App Launcher → Delivery Hub Admin).

> To reproduce the whole thing headless (what the verification run does), see `scripts/` and the driver in the session scratchpad. To do it by hand, follow the steps below.

---

## The steps

### 1 · Onboard the client + generate the agreement  — Admin
- **Where:** Admin Home → *Delivery Client Onboarding* card (LWC `deliveryClientOnboarding`).
- **Do:** enter client name (e.g. *Acme Corp*), AP email, hourly rate → **Create Client & Generate Agreement** → **Send Agreement Email**.
- **Behind it:** `DeliveryClientOnboardingController.onboardClient(name, email, rate, phone, address)` creates the `NetworkEntity__c` client and a `Client_Agreement` `DeliveryDocument__c` (status **Draft**, `RequireSigningDateTime__c` stamped, signature slots created).
- **Note:** the doc becomes **Awaiting Signatures** *automatically* when the client first opens the signing link — there is no "set to awaiting" button. To force the state by hand, edit `StatusPk__c` on the DeliveryDocument record (reach it via the client's *Documents* related list).
- **Status:** ✅ backend proven on fresh install.

### 2 · Client signs the agreement  — client-facing link
- **Where:** the public signing page opened from the *Send Agreement Email* link; admin-side signing is `deliveryDocumentSignatureBlock` on the document record.
- **Behind it:** native multi-party signing (SHA-256 hash chain, no DocuSign). `DeliveryDocActionController.signActionAdmin` for the admin-side sign.
- **Status:** ⚠️ the document/agreement **engine** is proven (same engine generates the invoice in step 11). The **e-sign click-through** itself is not yet exercised — this is the one genuinely-untested link in the chain. Treat as "demo it live, don't claim it's regression-tested."

### 3 · Work comes in — "Report Issue"  — both apps
- **Where:** Home or the utility bar → **Report Issue** (LWC `deliveryGhostRecorder`) → *Report Bug* / *Submit Feature*.
- **Do:** subject (e.g. *Build client onboarding flow*), description, priority → submit.
- **Behind it:** `DeliveryGhostController.createQuickRequest(subject, description, priority, contextData, workItemType)` → new `WorkItem__c` in **Backlog / New**, **un-activated** (lands in the Intake queue, not the board yet).
- **⚠️ Precondition reminder:** this does **not** set the client link. If this item will be billed, set its **Client** field (step 6b) before you invoice.
- **Status:** ✅ backend proven.

### 4 · Route intake → Ready for Sizing  — both apps
- **Where:** Home *Intake* queue / Workspace *Intake* tab (LWC `deliveryIntakeQueue`).
- **Do:** on the row → **Route to dev** (pick a developer).
- **Behind it:** `DeliveryTriageController.routeToDev(List<Id> workItemIds, Id developerUserId)` — the **only** UI path that writes `StageNamePk__c = 'Ready for Sizing'` and stamps `ActivatedDateTime__c` (activates it onto the board).
- **Status:** ✅ backend proven (verified: stage → *Ready for Sizing*, activated → true).

### 5 · Create the vendor request (vendor + rate)  — Admin
- **Where:** the Work Item (Admin page) → *Requests* related list → **New**; or the `WorkRequest` tab → **New**.
- **Do:** set **Delivery Entity** (the vendor, e.g. *Cloud Nimbus LLC*) and **Hourly Rate** (e.g. *175*) on the request record (Dynamic Forms).
- **Behind it:** standard record create on `WorkRequest__c` (`WorkItemId__c`, `DeliveryEntityLookup__c`, `HourlyRateCurrency__c`). There is **no** one-shot "create vendor request" action that sets vendor + rate — it's a record create plus field edits. Buyer app cannot do this (no WorkRequest surface).
- **Status:** ✅ backend proven.

### 6 · Size it  — both apps
- **Where:** the board **+ New Work Item** modal (`DeveloperDaysSizeNumber__c`), or inline-edit on the Work Item / Work Request record.
- **Do:** set **Estimated Hours** on the Work Item and **Quoted / Pre-Approved Hours** on the Work Request (e.g. *12*).
- **Behind it:** standard field edits (LDS) — there is **no** Apex "size" method; sizing is field values.
- **⚠️ Watch:** the board create modal is the historically-broken F16/F17 surface. The fields and data model are proven; give the modal render a real look in the browser.
- **Status:** ✅ data model proven; modal UI is the eyeball item.

### 6b · Link the item to the client  *(precondition, not a headline step)*
- **Where:** the Work Item record page → **Client** field (`ClientNetworkEntityLookup__c`, present on both the buyer and admin record pages).
- **Do:** set it to the client (*Acme Corp*).
- **Why:** the invoice (step 11) sums hours only for work items where `ClientNetworkEntityLookup__c = the client`. Skip this and the invoice is **$0**.
- **Status:** ✅ field confirmed editable on the record page.

### 7 · Send to vendor  — Admin
- **Where:** the Work Request record → **Send to vendor** (LWC `deliveryManageRequest`).
- **Behind it:** `DeliveryRequestManagerController.sendRequestToVendor(requestId)` → sets `StatusPk__c = 'Offer Sent'` (verified by real call) and syncs the request out. **This is what makes it approvable.**
- **Status:** ✅ backend proven (verified: status → *Offer Sent*).

### 8 · Approve the estimate  — both apps
- **Where:** Home → **Pending Work Approvals** card (LWC `deliveryApprovalQueue`).
- **Do:** **Approve** (or *Approve with change* → Confirm; or bulk *Approve selected*).
- **Behind it:** `DeliveryWorkApprovalService.approve(workRequestId, approvedHours, note)` → request → **Accepted**, raises the Work Item's `ClientPreApprovedHoursNumber__c` cap, moves stage to *Ready for Development*. **Guard:** the request must be **Offer Sent** or it throws *"This request is not awaiting a decision."* — that's step 7's job.
- **Status:** ✅ backend proven (verified: status → *Accepted*).

### 9 · Log the hours delivered  — buyer Work Item record page
- **Where:** the Work Item record page → *Actions* sidebar → **Log Time** (LWC `deliveryTimeLogger`, preset chips 15m–8h).
- **Behind it:** `DeliveryTimeLoggerController.logHours(workItemId, hours, notes, workDate)` → new `WorkLog__c`. Defaults to **Approved** when `RequireWorkLogApprovalDateTime__c` is unset (the default). Requires an active Work Request to exist (steps 5/7).
- **Note:** this card is on the **buyer** Work Item record page, not the admin one. Stage → Done is a *separate* action (step 10). If work-log approval is switched on, logs land **Draft** and there is **no** in-package manual approval screen — so leave that flag off for the simple loop.
- **Status:** ✅ backend proven (verified: worklog created, 12h).

### 10 · Mark done (close out)  — both apps
- **Where:** Home → **Close Outs** card (LWC `deliveryCloseOutQueue`), or the board, or the record's *Advance Stage*.
- **Do:** **Mark Done**.
- **Behind it:** `DeliveryTriageController.markDone(List<Id> workItemIds)` → `StageNamePk__c = 'Done'`. **Note:** this sets the stage only — it does **not** write client acceptance into `AcceptanceCriteriaTxt__c`. To capture sign-off text, edit that field on the record.
- **Status:** ✅ backend proven (verified: stage → *Done*).

### 11 · Generate the invoice  — Admin
- **Where:** Admin Home *Documents* card, or the client's *Documents* tab (LWC `deliveryDocumentViewer`) → **Generate Document** → template **Invoice** → **Generate**.
- **Behind it:** `DeliveryDocumentController.generateDocument(entityId, 'Invoice', periodStart, periodEnd, null)` → sums in-period **Approved** work logs for the client's items (`Σ hours × rate`) into a **Draft** `DeliveryDocument__c`.
- **The money check:** with the client link (6b) and approved hours in period, this produced **$2,100.00 / 12.00 h** on the fresh org. Without the client link it produces **$0** — the failure mode to avoid.
- **Note:** the manual *Generate* button is **not** flag-gated. Only the *scheduled* invoice run needs `EnableInvoiceGenerationDateTime__c` + per-entity `EnableBillingDateTime__c`.
- **Status:** ✅ backend proven (verified: DOC-000011, $2,100, Draft).
- **Then:** send → record payment → the doc auto-marks **Paid** (invoice→paid is proven separately in prior sessions; not re-run here).

---

## What is NOT in this path (on purpose)

Everything else Delivery Hub ships — the 8-layer cockpit, Watcher digest, forecasting, AI drafting, cross-org sync, the feature-toggle/approval framework, onboarding tracks, dev-loop mirror — is **off by default** or lives in the Admin "junk drawer." None of it is needed to run a client engagement from request to paid invoice. The install seeds only two internal flags on. Treat the rest as *available*, not *the product*. See `docs/DELIVERY-HUB-FUTURE.md` for what's worth finishing next.

## Honest status summary

- **Proven on a fresh blank install (backend / admin context):** the full 11-step loop, ending in a correct $2,100 invoice.
- **You confirm by clicking `david-walk`:** the browser UI for each step, and especially (a) the board create/size modal render, (b) buyer-permset FLS if you drive it as a non-admin.
- **Genuinely untested:** the e-sign click-through (step 2). Demo it live; don't claim it's regression-covered.
- **Landmines to remember:** the client-link precondition (→ $0 invoice) and the Offer-Sent precondition (→ approve error).

*Maintained alongside `simple-happy-path.md` (the status view) and `dh-happy-path-mf-jose.md` (the Jose loop framing). This runbook supersedes them for "how do I actually drive it by hand."*
