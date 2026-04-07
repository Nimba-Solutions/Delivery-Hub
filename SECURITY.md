# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Delivery Hub, please report it
responsibly. **Do not open a public GitHub issue.**

Email: **security@cloudnimbusllc.com**

Include as much detail as possible:

- Description of the vulnerability
- Steps to reproduce
- Affected component (Apex, LWC, REST API, sync engine, document signing,
  audit chain, etc.)
- Potential impact

We will acknowledge receipt within 48 hours and provide an initial assessment
within 5 business days.

## Security Posture

Delivery Hub ships with a defense-in-depth posture and audit-grade integrity
controls. The short version:

### Audit integrity

- **SHA-256 hash chain** on every `ActivityLog__c` record via
  `DeliveryAuditChainService.setHashOnInsert()`. Each row stores its own hash
  and the parent row's hash, producing a tamper-evident ledger. Tamper with any
  field and every downstream hash mismatches.
- **Legal hold mode** — set `LegalHoldEnabledDateTime__c` on
  `DeliveryHubSettings__c` and the audit chain records cannot be deleted.
- **Chain verification** — `DeliveryAuditChainService.validateChain(batchSize)`
  walks the chain and returns the first mismatch.
- **Document signing hash chain** — `DocumentAction__c.PriorHashTxt__c`
  materializes the chain parent at sign time so every signature is cryptographically
  linked to every prior audit event.

### Data integrity

- **`FOR UPDATE` locks** on critical hot paths. `DeliveryDocActionService.loadPendingAction`
  uses `WITH SYSTEM_MODE ... FOR UPDATE` so two simultaneous signers cannot
  double-sign the same slot. The sync reconciler uses the same pattern for
  concurrent drift-detection runs.
- **Immutable JSON snapshots** — every generated document stores a frozen JSON
  snapshot. Changing hours, rates, or descriptions after generation does not
  mutate previously-generated documents. Regeneration creates a new version
  with `PreviousVersionId__c` linking back and the superseded document marked
  `Superseded`, excluded from A/R rollups.
- **Master-Detail ownership** — signing, transaction, and portal access
  records are all child records of their parent (document, network entity)
  with `reparentableMasterDetail=false`, preventing cross-tenant leaks via
  parent reassignment.

### Authentication & authorization

- **Public API**: `X-Api-Key` header matched against `NetworkEntity__c.ApiKeyTxt__c`
  with `ConnectionStatusPk__c = 'Connected'`. Data is scoped to the authenticated
  entity — cross-entity reads return 403.
- **Sync API**: opt-in `X-Api-Key` + opt-in HMAC-SHA256 body signing via
  `X-Signature` header and `HmacSecretTxt__c` on the target NetworkEntity.
  Backward compatible — no secret means no signature validation.
- **Document signing**: per-signer tokens in `DocumentAction__c.SignerTokenTxt__c`.
  Tokens rotate to `null` on completion as defense in depth. Admin-side signing
  is gated behind `DeliveryHubSettings__c.EnableAdminSigningDateTime__c` and
  off by default.
- **FLS posture**: portal and sync controllers run `WITHOUT SHARING` with
  `WITH SYSTEM_MODE` queries by design (these are system-level code paths
  operating on behalf of authenticated external callers). Entity-level access
  checks are enforced in Apex via NetworkEntity relationship validation, not
  via org-wide sharing rules. Sensitive fields like
  `DocumentAction__c.SignerTokenTxt__c` are excluded from the guest-user
  permission set (PR #597).
- **Rate limiting**: opt-in per-entity throttling on both Public API
  (`PublicApiRateLimitNumber__c`, default 100/hr) and Sync API
  (`SyncApiRateLimitNumber__c`, default 60/hr). HTTP 429 + `Retry-After: 3600`
  header on breach.

### Clickjacking

- Salesforce Site `clickjackProtectionLevel` is set to `SameOriginOnly`
  (PR #597). Delivery Hub does not allow all framing.

### Secrets

- Shared secrets (`HmacSecretTxt__c`, `ApiKeyTxt__c`, OpenAI key on
  `CloudNimbusGlobalSettings__mdt`) are stored in standard Salesforce fields
  with field-level security enforced. Do not log secrets. Do not commit
  secrets to `.env` files in the repo.

## Scope

The following areas are in scope for security reports:

- **Apex controllers and services** — SOQL injection, CRUD/FLS bypass,
  unauthorized data access, Apex sharing bypass
- **LWC components** — XSS, insecure data handling, exposed secrets in
  `@track` fields, missing output escaping
- **REST API endpoints** — authentication bypass, authorization flaws,
  injection attacks, rate limit bypass, CORS misconfiguration
- **Cross-org sync engine** — data leakage between tenants, replay attacks,
  echo suppression bypass, HMAC signature forgery
- **Document signing** — token reuse after completion, double-sign races,
  signature forgery, hash chain tampering, consent capture bypass,
  IP/user-agent spoofing
- **Audit chain** — hash chain tampering, legal hold bypass, activity log
  deletion with legal hold enabled
- **Custom Metadata and configuration** — privilege escalation via metadata
  manipulation, stage gate bypass, approval chain bypass

## Out of Scope

- Salesforce platform vulnerabilities (report those to Salesforce directly)
- Social engineering attacks
- Denial of service against Salesforce infrastructure (rate limiting is
  configurable — see above)
- Issues only exploitable by a user with full System Administrator access
  to the target org

## Disclosure

We follow coordinated disclosure. Once a fix is released, we will credit the
reporter (unless anonymity is requested) and publish a summary in the release
notes and [docs/CHANGELOG.md](docs/CHANGELOG.md).
