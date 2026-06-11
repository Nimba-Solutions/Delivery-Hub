# Handoff — Document/invoice email must send from a verified Org-Wide Email Address

**Date:** 2026-06-02
**Priority:** High — blocks sending invoices from dh-prod (the billing org).

## TL;DR
`DeliveryDocEmailService` sends DeliveryDocuments (invoices) as the **running user**, so in any org where that user's email domain isn't a verified sender, the send throws `INSUFFICIENT_ACCESS_OR_READONLY … domain isn't verified`. Fix: add a configurable **From Org-Wide Email Address** (`DeliveryHubSettings__c.DocumentFromOrgWideEmailTxt__c`) and call `email.setOrgWideEmailAddressId(...)` before send, falling back to the running user when unset. One field + one code block + one test. Operational verification of the OWEA is the org-owner's step.

## Symptom
Sending a `DeliveryDocument__c` (e.g. the monthly At Large invoice) from dh-prod fails:
```
SendEmail failed. First exception on row 0; first error: INSUFFICIENT_ACCESS_OR_READONLY,
We can't send your email because your email address domain isn't verified.
```

## Root cause
`DeliveryDocEmailService.cls` (~L60–86) builds the `Messaging.SingleEmailMessage` and **never calls `setOrgWideEmailAddressId(...)`**. So Salesforce uses the **running user's** address as the From — in dh-prod that's a Dev-Edition `…@agentforce.com` user whose domain is not a verified sender. Modern Salesforce requires the sender domain be verified, so the send is rejected.

(It already reads `DeliveryHubSettings__c.DocumentCcEmailTxt__c` for CC at L64 — same pattern should drive the From.)

## Fix — send from a configurable verified OWEA
1. Add a field to `DeliveryHubSettings__c`: **`DocumentFromOrgWideEmailTxt__c`** (Text) — the OWEA address to send documents from (e.g. `glen@cloudnimbusllc.com`).
2. In `DeliveryDocEmailService`, before `Messaging.sendEmail(...)`:
```apex
DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
if (settings != null && String.isNotBlank(settings.DocumentFromOrgWideEmailTxt__c)) {
    List<OrgWideEmailAddress> owea = [
        SELECT Id FROM OrgWideEmailAddress
        WHERE Address = :settings.DocumentFromOrgWideEmailTxt__c LIMIT 1];
    if (!owea.isEmpty()) {
        email.setOrgWideEmailAddressId(owea[0].Id);
    }
}
```
Fall back to the running user if unset/not found (current behavior).

## Prereqs in the subscriber org (operational, not code)
- The OWEA must **exist and be VERIFIED**. In dh-prod, `glen@cloudnimbusllc.com` OWEA was created 2026-06-02 (`0D2fj00000040flCAA`) — Glen must click the verification email.
- For best deliverability, DKIM/domain-verify `cloudnimbusllc.com` in the org (Setup → Email → Deliverability / Domain). Per-address OWEA verification may suffice for sending; domain verification improves inbox placement.
- Confirm Email Deliverability "Access to Send Email" = **All email** (not System only).

## Exact change set

### 1. New field — `DeliveryHubSettings__c.DocumentFromOrgWideEmailTxt__c`
`force-app/main/default/objects/DeliveryHubSettings__c/fields/DocumentFromOrgWideEmailTxt__c.field-meta.xml`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>DocumentFromOrgWideEmailTxt__c</fullName>
    <label>Document From (Org-Wide Email)</label>
    <type>Text</type>
    <length>255</length>
    <required>false</required>
    <description>Verified Org-Wide Email Address to send DeliveryDocuments (invoices/quotes) FROM. If blank, sends as the running user. The address must exist and be verified in the org.</description>
    <inlineHelpText>e.g. glen@cloudnimbusllc.com — must be a verified Org-Wide Email Address in this org.</inlineHelpText>
</CustomField>
```

### 2. `DeliveryDocEmailService.cls` — set the From OWEA before send
Insert immediately before `Messaging.sendEmail(...)` (current ~L85). Note the `email.setSaveAsActivity(false)` line already reads org defaults via the CC block at L64, so reuse that `settings` variable rather than re-querying:
```apex
// From: verified Org-Wide Email Address, if configured (else running user)
if (settings != null && String.isNotBlank(settings.DocumentFromOrgWideEmailTxt__c)) {
    List<OrgWideEmailAddress> fromOwea = [
        SELECT Id FROM OrgWideEmailAddress
        WHERE Address = :settings.DocumentFromOrgWideEmailTxt__c
        LIMIT 1
    ];
    if (!fromOwea.isEmpty()) {
        email.setOrgWideEmailAddressId(fromOwea[0].Id);
    }
}
```
(`settings` is already fetched at L64 — hoist it above the CC block if scoping requires, or re-fetch; it's cached so cost is negligible.)

## Tests
- `DeliveryDocEmailServiceTest`: add a case where `DeliveryHubSettings__c.DocumentFromOrgWideEmailTxt__c` is set to an address with NO matching OWEA → asserts it falls back cleanly (no exception, sends as running user). You cannot create/verify a real `OrgWideEmailAddress` in a test context, so assert on the query-empty branch; guard the actual `setOrgWideEmailAddressId` path behind the non-empty list so tests don't require a live OWEA.
- Keep the existing `Test.isRunningTest()` PDF guard (L46–50) intact.

## Edge cases / gotchas
- **OWEA must be VERIFIED**, not just present. An unverified OWEA still throws on send. The address is verified via the link Salesforce emails to it (operational step below).
- If the OWEA address in settings doesn't match an OWEA record, the code silently falls back to the running user (who will fail again if their domain is unverified) — that's intended; document it so config typos are diagnosable.
- `setOrgWideEmailAddressId` overrides the From; `setReplyTo` is untouched (replies still go where currently configured). Confirm that's desired, or also set ReplyTo to the OWEA.

## Operational checklist (subscriber org, after install)
1. Verify the OWEA: Setup → Org-Wide Addresses → `glen@cloudnimbusllc.com` → click the verification link Salesforce emailed (created in dh-prod 2026-06-02, `0D2fj00000040flCAA`).
2. Set `DeliveryHubSettings__c.DocumentFromOrgWideEmailTxt__c = glen@cloudnimbusllc.com` (org default).
3. Confirm Setup → Deliverability → Access to Send Email = **All email**.
4. (Recommended) DKIM/domain-verify `cloudnimbusllc.com` for inbox deliverability.
5. Send a DeliveryDocument → confirm From = glen@cloudnimbusllc.com and status flips to Sent.

## Done when (acceptance)
- [ ] `DocumentFromOrgWideEmailTxt__c` field added to `DeliveryHubSettings__c` and packaged.
- [ ] `DeliveryDocEmailService` sets `setOrgWideEmailAddressId` from that setting when present; falls back to running user when blank/unmatched.
- [ ] `DeliveryDocEmailServiceTest` covers both branches (configured-OWEA path guarded; blank/unmatched fallback) and passes.
- [ ] New beta/release version cut; install key handed to Glen.
- [ ] (Subscriber/dh-prod, by Glen) OWEA verified + setting populated → a test DeliveryDocument sends from glen@cloudnimbusllc.com and flips to Sent.

## Files
- `force-app/main/default/classes/DeliveryDocEmailService.cls` (L60–86)
- `force-app/main/default/classes/DeliveryDocEmailServiceTest.cls`
- `DeliveryHubSettings__c` → new field `DocumentFromOrgWideEmailTxt__c`

## Note
The invoice itself is correct and unblocked — **DOC-000017** (At Large, May, **236.5h / $21,285**, Draft) is generated in dh-prod. This handoff only concerns sending it *from* `glen@cloudnimbusllc.com` via the in-app button. Until shipped, the invoice PDF can be downloaded from the record and sent manually, then the doc marked Sent.

