# Invoice Dispute Patterns

Every dispute/adjustment scenario below uses ONLY existing metadata. No new objects, no new fields, no code changes required.

## Pattern A — Pre-send adjustment ("fix before they see it")

The invoice is still `Draft`. Client hasn't seen anything. Easiest case.

**Steps:**
1. Optionally set `DeliveryDocument__c.DisputeReasonTxt__c` with why you're adjusting (paper trail).
2. Remove or edit the offending WorkLogs / WorkItems.
3. Call `DeliveryDocumentController.generateDocument(entityId, 'Invoice', periodStart, periodEnd, null)`.
4. Old draft auto-flips to `Superseded`, new version created with incremented `VersionNumber__c` and `PreviousVersionLookup__c` chain.
5. Send the new version.

**Metadata used:** `DeliveryDocument__c.StatusPk__c`, `VersionNumber__c`, `PreviousVersionLookup__c`, `DisputeReasonTxt__c`, `DocumentHashTxt__c`.

## Pattern B — Deferral (revenue recognized on acceptance)

Client disputes specific hours. You agree the work isn't "done" from their perspective, but you want to preserve the billable dollars for when it IS accepted. This is the GAAP-friendly answer — revenue recognized on acceptance, not on performance date.

Shipped as first-class UI in PR #686 (`deliveryInvoicePreviewDeferPanel` LWC).

**Steps:**
1. Open the invoice preview viewer.
2. In the Defer Hours panel, checkbox the specific WorkLogs under dispute.
3. Pick a milestone date (e.g., 2026-06-15 = expected acceptance).
4. Enter a reason (e.g., "Jose/Jared pushback — QB integration cohort not accepted until acceptance test passes").
5. Click Defer → selected WorkLogs:
   - `StatusPk__c` flipped from `Approved` to `Draft`
   - `WorkDescriptionTxt__c` prepended with `[DEFERRED to 2026-06-15]`
   - `ActivityLog__c` entry stamped with action `WorkLog_Deferral` (telemetry)
6. Regenerate invoice. Excluded hours drop off. Reduced invoice goes to client.

**On acceptance (when the work lands):**
1. Open the invoice for the acceptance-month period (e.g., June).
2. Click "Release Deferred to this Period" in the Defer panel.
3. The deferred WorkLogs get:
   - `StatusPk__c` flipped back to `Approved`
   - `WorkDateDate__c` shifted to the parsed milestone date (so they land in the right invoice period)
   - Description tag stripped, original description restored
4. Regenerate June's invoice. Those hours now appear in June's billing.

**Metadata used:** `WorkLog__c.StatusPk__c`, `WorkDateDate__c`, `WorkDescriptionTxt__c`, `ActivityLog__c.ActionTypePk__c='WorkLog_Deferral'`.

## Pattern C — Post-send credit / full re-issue

The invoice was already Sent. Client disputes AFTER receipt. You need to "take it back" and issue a revised one.

**Steps:**
1. Set `DisputeReasonTxt__c` on the Sent doc describing the dispute.
2. Regenerate with adjusted totals → the generator auto-supersedes the Sent version.
3. The new doc has `VersionNumber__c = N+1`, `PreviousVersionLookup__c = <old doc id>`.
4. Send the new version. Reference the superseded one in the email ("this replaces DOC-00000X we sent on DATE").

Client's A/R summary on future invoices will still reflect their TRUE outstanding because `buildUnpaidInvoicesSummary()` filters out Superseded documents.

**Metadata used:** same as Pattern A + the Sent doc stays in the system as audit-visible Superseded.

## Pattern D — Record payment

Payment arrives (ACH, check, Stripe, etc.). You record it so DH's A/R shows the reduction.

**Steps:**
1. Find the doc that was paid.
2. Call `DeliveryDocumentController.recordPayment(documentId, amount, paymentDate, note)`. Creates a `DeliveryTransaction__c` with `TypePk__c='Payment'`.
3. If `totalPaid >= doc.TotalCurrency__c`, the service auto-flips the doc to `Paid` status.
4. Next invoice generated for that client shows the reduced prior balance automatically.

**Metadata used:** `DeliveryTransaction__c`, `DeliveryDocument__c.StatusPk__c`.

## Pattern E — Partial credit without re-issue

Client will pay most of the invoice but disputes a specific line. You don't want to re-issue; you want to record a partial credit offsetting the disputed amount.

**Current workaround (until Task #7 ships the full auditable-accounting PR):**
- Manual `DeliveryTransaction__c` insert with a descriptive `NoteTxt__c`
- Record a second "Payment" transaction for the agreed reduced amount once received
- Flip the doc to `Paid` manually when `totalPaid + creditNote = doc.TotalCurrency__c`

Quick and reversible. Full credit/refund/writeoff support as first-class transaction types is on the Task #7 roadmap — not needed while invoicing is manually managed.

**Metadata used:** `DeliveryTransaction__c.NoteTxt__c` + manual status flip on the doc.

## When to ship Task #7 (auditable accounting full build)

Consider the full PR when one of the following happens:
- A CPA or finance person starts auditing DH's A/R surface
- Credit/writeoff frequency exceeds ~5/month (manual workaround becomes error-prone)
- You have 10+ active client entities — partial-credit complexity compounds
- An enterprise client requires `TypePk__c = Credit/Refund/Adjustment/Writeoff` semantics in reports

Until one of those, the patterns above cover every dispute scenario with existing metadata.
