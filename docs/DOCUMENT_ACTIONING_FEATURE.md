# Document Actioning + Signatures Feature

**Status: Phase 1-5 shipped** (PRs #586, #589, #591, #592, #593). Phase A hardening landed in PR #597. Fully demoable, fully audit-compliant, production-ready.

Native multi-party document signing for Delivery Hub. Built as a product feature, not a DocuSign integration. ESIGN Act / UETA compliant via tamper-evident hash chain (riding the existing `ActivityLog__c.HashChainTxt__c` infrastructure), per-signer access tokens, electronic consent capture, IP/user-agent recording, and a Certificate of Completion template.

## Why we built this natively

DocuSign isn't magic. Tamper-evident hash chains, audit trails, and per-signer authentication are all data-model and UX decisions. Delivery Hub already has `DeliveryAuditChainService.setHashOnInsert()` writing SHA-256 chain hashes on every `ActivityLog__c` row, so our signature events ride that existing chain. Customers don't pay $30/user/month per signer.

## Architecture

We extend DH's existing snapshot-based document generation. The frozen JSON snapshot stays frozen — signatures live in `DocumentAction__c` records and get composed by the viewer at render time. The "final signed document" is a composite of frozen snapshot + ordered signature records.

### Status flow

```
Draft → Ready → Sent → Awaiting_Signatures → Approved → Paid
                              ↓ (only when RequiresSigningCheckbox__c=true)
                         Viewed (skipped for sign-required docs)
```

Documents that don't require signing keep the existing `Sent → Viewed → Approved` flow via the legacy `DeliveryDocApprovalService.approveDocumentByToken`.

### Locked-in design decisions

| Decision | Choice |
|---|---|
| Slot configuration | New `DocumentTemplateSlot__mdt` child object (one CMT record per slot) |
| IP capture | `@RestResource` endpoint reading `X-Salesforce-SIP` header from edge |
| Admin signing | Gated behind `DeliveryHubSettings__c.EnableAdminSigningDateTime__c` feature flag |
| Consent disclosure | `ElectronicConsentTextTxt__c` field on `DocumentTemplate__mdt`, hardcoded fallback in LWC |
| Controller scope | `public` (not global) — uses primitives + `Map<String, Object>` |
| Sent transition | Auto-flip `Sent → Awaiting_Signatures` when `RequiresSigningCheckbox__c=true` |
| Signature block UI | Extracted into `deliveryDocumentSignatureBlock` child LWC, shared by viewer + portal |
| Hash computation | In `generateDocument()` immediately after snapshot build, not via trigger |

## Phase ordering

| Phase | Theme | Demo value | Shipped in |
|---|---|---|---|
| 1 | Data model + slot creation | Records exist, no UX | PR #586 |
| 2 | Text-stamp signing in embedded viewer (admin-side) | Glen can sign all 3 slots inside the org | PR #586 |
| 3 | Public portal signing (text stamp) + status transition | **Coleman demo: full lease signing flow** | PR #589 |
| 4 | Hash chain + audit trail render + Certificate of Completion | ESIGN/UETA compliance story | PR #592 (+ #595 hash re-query fix) |
| 5 | Canvas pad signature type | DocuSign-parity drawn signatures | PR #593 |
| Admin polish | Copy Signer Link button + token rotation | One-click admin workflow | PR #591 |
| Phase A hardening | Canvas persistence in REST API + FOR UPDATE + audit P0 fixes | Production-ready | PR #597 |

Coleman demo is fully demoable at end of Phase 3. All phases shipped and ready for production install as of 2026-04-07.

## Data model

### `DocumentAction__c` — Master-Detail child of DeliveryDocument__c

| Field | Type | Notes |
|---|---|---|
| `DocumentId__c` | Master-Detail | `reparentableMasterDetail=false` |
| `ActionLabelTxt__c` | Text(255) Required | "Sign as Consultant", "Sign as Client" |
| `AssignedEntityId__c` | Lookup → NetworkEntity__c | Optional |
| `StatusPk__c` | Picklist Restricted | Pending (default), Completed, Voided |
| `CompletedDateTime__c` | DateTime | When actioned |
| `SignatureTypePk__c` | Picklist Restricted | Text (default), Image |
| `SignatureDataTxt__c` | LongTextArea(32768) | Text stamp OR ContentVersion Id |
| `SignerNameTxt__c` | Text(255) | Always captured |
| `SignerEmailTxt__c` | Email | |
| `SortOrder__c` | Number(3,0) | Render order |
| `SignerTokenTxt__c` | Text(64) Unique Indexed | Per-signer access token |
| `PriorHashTxt__c` | Text(64) | Materialized from ActivityLog (Phase 4) |
| `IpAddressTxt__c` | Text(45) | IPv6 max length |
| `UserAgentTxt__c` | LongTextArea(2000) | |
| `ElectronicConsentDateTime__c` | DateTime | When consent box was checked |
| `ActivityLogId__c` | Text(18) | Pointer to canonical chain entry |

### `DocumentTemplateSlot__mdt` — new CMT

One record per signer slot per template type. Named `DocumentTemplateSlot.<TemplateType>_<Role>`.

| Field | Type | Notes |
|---|---|---|
| `TemplateTypeTxt__c` | Text(80) Required | Matches `DeliveryDocument__c.TemplatePk__c` |
| `ActionLabelTxt__c` | Text(255) Required | "Sign as Consultant" |
| `RoleTxt__c` | Text(80) Required | consultant, client, etc. |
| `SortOrder__c` | Number(3,0) Required | Render order |
| `AutoAssignTxt__c` | Text(80) | vendor / customer / none |

### `DeliveryDocument__c` field additions

| Field | Type | Notes |
|---|---|---|
| `DocumentHashTxt__c` | Text(64) | SHA-256 of snapshot (Phase 4 wires logic) |
| `RequiresSigningCheckbox__c` | Checkbox | Default false |

`StatusPk__c` gains `Awaiting_Signatures` value between Viewed and Approved.

### `DocumentTemplate__mdt` field additions

| Field | Type | Notes |
|---|---|---|
| `RequiresSigningCheckbox__c` | Checkbox | True on Client_Agreement, Contractor_Agreement |
| `ElectronicConsentTextTxt__c` | LongTextArea | Per-template consent disclosure |

## Phase 1 — Files

### New
- `force-app/main/default/objects/DocumentAction__c/` — object + 16 fields
- `force-app/main/default/objects/DocumentTemplateSlot__mdt/` — object + 5 fields
- `force-app/main/default/objects/DeliveryDocument__c/fields/DocumentHashTxt__c.field-meta.xml`
- `force-app/main/default/objects/DeliveryDocument__c/fields/RequiresSigningCheckbox__c.field-meta.xml`
- `force-app/main/default/objects/DocumentTemplate__mdt/fields/RequiresSigningCheckbox__c.field-meta.xml`
- `force-app/main/default/objects/DocumentTemplate__mdt/fields/ElectronicConsentTextTxt__c.field-meta.xml`
- `force-app/main/default/customMetadata/DocumentTemplateSlot.Client_Agreement_Consultant.md-meta.xml`
- `force-app/main/default/customMetadata/DocumentTemplateSlot.Client_Agreement_Client.md-meta.xml`
- `force-app/main/default/customMetadata/DocumentTemplateSlot.Contractor_Agreement_Company.md-meta.xml`
- `force-app/main/default/customMetadata/DocumentTemplateSlot.Contractor_Agreement_Contractor.md-meta.xml`
- `force-app/main/default/classes/DeliveryDocActionService.cls` (+ meta + test + test meta)

### Modified
- `force-app/main/default/objects/DeliveryDocument__c/fields/StatusPk__c.field-meta.xml` — add `Awaiting_Signatures`
- `force-app/main/default/customMetadata/DocumentTemplate.Client_Agreement.md-meta.xml` — add `RequiresSigningCheckbox__c=true`, consent text
- `force-app/main/default/customMetadata/DocumentTemplate.Contractor_Agreement.md-meta.xml` — same
- `force-app/main/default/classes/DeliveryDocGenerationService.cls` — set `RequiresSigningCheckbox__c`, call `createSlotsForTemplate`
- `unpackaged/post/testSuites/DH.testSuite-meta.xml` — add `DeliveryDocActionServiceTest`

### `DeliveryDocActionService` Phase 1 surface

```apex
public static Boolean templateRequiresSigning(String templateType)
public static List<DocumentAction__c> createSlotsForTemplate(Id documentId, String templateType, Map<String, Object> snapshot)
public static List<DocumentAction__c> getActionsForDocument(Id documentId)
public static String generateSignerToken()
@TestVisible private static List<DocumentTemplateSlot__mdt> loadSlotConfigForTemplate(String templateType)
```

## Phase 2 — Text-stamp signing in embedded viewer

Files to create:
- `classes/DeliveryDocActionController.cls` — public facade, primitives only
- `classes/DeliveryDocActionControllerTest.cls`
- `lwc/deliveryDocumentSignatureBlock/` — extracted child LWC consumed by both viewer and portal
- `objects/DeliveryHubSettings__c/fields/EnableAdminSigningDateTime__c.field-meta.xml`

Files to modify:
- `DeliveryDocActionService.cls` — `signActionInternal`, `maybeAdvanceDocumentStatus`
- `DeliveryDocQueryService.cls` — `buildDocumentResultMap` includes `actions` array
- `lwc/deliveryDocumentViewer/` — render signature block via child LWC, sign modal

Controller surface:
```apex
@AuraEnabled public static List<Map<String, Object>> getActionsForDocument(Id documentId)
@AuraEnabled public static Map<String, Object> signActionAdmin(Id actionId, String signerName, String signerEmail, Boolean consentGiven)
@AuraEnabled public static Map<String, Object> updateAssignedEntity(Id actionId, Id networkEntityId)
```

Text format ported from GSU `AutomatedDocuments.apex` lines 540–543: `<Name> (digitally signed Apr 6, 2026)`.

## Phase 3 — Public portal signing (Coleman demo)

Files to create:
- `lwc/deliveryDocumentSignPortal/` — guest-context portal LWC
- `classes/DeliveryDocActionRestApi.cls` — `@RestResource` POST `/sign/<token>` for IP capture

Files to modify:
- `DeliveryDocActionController.cls` — `getDocumentForSigner`, `signActionPublic`
- `DeliveryDocApprovalService.cls` — auto-transition `Sent → Awaiting_Signatures`
- `permissionsets/DeliveryHubGuestUser.permissionset-meta.xml`
- `pages/DeliveryDocumentPdf.page` — replace static signature stub with dynamic repeat
- `classes/DeliveryDocumentPdfController.cls` — `signatureRows` collection

## Phase 4 — Hash chain materialization + Certificate of Completion

Files to create:
- `customMetadata/DocumentTemplate.Certificate_Of_Completion.md-meta.xml`
- `classes/DeliveryDocCertificateService.cls`
- `scripts/backfill-document-hashes.apex`

## Phase 5 — Canvas pad signature type

Files created:
- `lwc/deliverySignaturePad/` — HTML5 canvas pad, ported from `mobilization-funding-githubrepo` with Flow code stripped
- Mouse + touch + Apple Pencil input; base64 PNG export; placed inside the signing modal alongside the text-stamp mode

## Phase A — Canvas REST API extension (PR #597)

`DeliveryDocActionRestApi.handlePost` originally hardcoded `ctx.signatureType = 'Text'` and silently dropped any canvas bytes from the REST body. This meant public portal users who drew a signature via the canvas pad had their image discarded and a text stamp persisted in its place.

Phase A landed the full canvas round-trip:

```json
POST /services/apexrest/sign/<signerToken>
{
  "signerName": "Coleman Cameron",
  "signerEmail": "coleman@example.com",
  "consentGiven": true,
  "signatureType": "Image",
  "signatureData": "data:image/png;base64,iVBOR…",
  "portalSessionEmail": "coleman@example.com"
}
```

Changes in `DeliveryDocActionRestApi.parseSignContextFromBody`:

- Reads optional `signatureType` / `signatureData` / `drawnSignature` fields
- Normalizes legacy `"Drawn"` spelling to `"Image"` (the persisted picklist value)
- Strips the `data:image/png;base64,` URI prefix so `EncodingUtil.base64Decode` doesn't choke
- Routes the bytes into `ctx.drawnSignature` so the service layer persists them as a ContentVersion
- Defaults to `"Text"` only when the body did not specify a type (legacy behavior)

Also in PR #597:

- `resolveClientIp` prefers `X-Forwarded-For` (portal proxy passes through the real client IP) over `X-Salesforce-SIP`; parses multi-hop chains and returns the leftmost originating client
- `portalSessionEmail` is appended to the user-agent string for audit until a dedicated `PortalSessionEmail__c` field lands
- `DeliveryDocActionService.loadPendingAction` uses `WITH SYSTEM_MODE ... FOR UPDATE` so two simultaneous signers cannot double-sign the same slot

## Signing slot visibility in `getDocumentByToken` (PR #597)

The portal at `cloudnimbusllc.com/portal/documents/<token>` needs to know (1) whether signing is required, (2) whether every slot is complete, (3) the list of slots with status + signer token, and (4) whether the audit chain is verified. PR #597 added `DeliveryDocQueryService.buildSigningStatusBlock` which surfaces exactly that shape on `GET /api/documents/<token>`:

```json
{
  "success": true,
  "data": {
    "id": "a07...",
    "signingRequired": true,
    "signingComplete": false,
    "signingSlots": [
      {
        "id": "a08...",
        "role": "Sign as Consultant",
        "signerName": "Glen Bradford",
        "signerEmail": "glen@cloudnimbusllc.com",
        "status": "Completed",
        "signedDate": "2026-04-06T18:42:00.000Z",
        "signerToken": null
      },
      {
        "id": "a09...",
        "role": "Sign as Client",
        "signerName": null,
        "signerEmail": null,
        "status": "Pending",
        "signedDate": null,
        "signerToken": "abc123…"
      }
    ],
    "hashChainVerified": false,
    "hashChainVerifiedAt": null
  }
}
```

Key behaviors:

- `signerToken` is `null` for completed slots (defense in depth — the service nulls the token on completion)
- `signingComplete` is `true` only when `signingRequired` is `true` AND every slot is `Completed` AND at least one slot exists
- `hashChainVerified` currently returns `false` by contract — the global `DeliveryAuditChainService.validateChain(batchSize)` exists but a per-document helper does not yet. Once `validateChainForDocument(Id)` lands, the portal will flip the "Audit chain verified" badge on automatically.

## Project rules (from `CLAUDE.md`)

- Branch/PR workflow — never commit to main
- `WITH SYSTEM_MODE` in tests, never `WITH USER_MODE`
- `getLocalName()` not `getName()` for field/object API names
- No ternary expressions in LWC templates — use getters
- Boolean `@api` props can't default to true — invert the prop name
- Don't assert on `AuraHandledException.getMessage()` content
- New tests added to `DH` test suite (`unpackaged/post/testSuites/DH.testSuite-meta.xml`)
- 75% coverage required
- `%%%NAMESPACE_DOT%%%` token in LWC imports
