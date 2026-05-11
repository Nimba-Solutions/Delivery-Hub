# Depth-charge audit architecture

**Status:** scaffold shipped in PR #760 (schema + local-segment assembly). Recursive cross-org probe + response handling is a follow-on PR — see "Follow-on PR" section below.

## What it is

A way for an upstream client (e.g., a regulated lender, a government primary contractor, a HIPAA-covered entity) to ask their direct vendor: "**Show me the fulfillment chain for this work item.** Who actually did the work, what jurisdictions did they operate from, and how deep does the chain go?"

The vendor answers based on each downstream peer's **opt-in reveal level**, returning a tree the upstream caller can visualize and attest against.

## Use cases

- **ITAR / export control** — verify all developers were US-located
- **GDPR data residency** — verify data didn't leave EU
- **State-licensed work** — verify CA-licensed contractor signed off on CA-jurisdiction work
- **SEC compliance** — verify chain didn't cross sanctioned jurisdictions
- **HIPAA BAA chain** — verify all peers in the chain are BAA-covered
- **DoD subcontractor reporting** — supply chain transparency

## Schema (in this PR)

### `SyncItem__c.ChangeTypeTxt__c` (Text 80, free-form)
Categorizes payload purpose. Backward-compat blank/`record_change` = standard cross-org sync. New values:
- `depth_probe` — outbound query asking peers to reveal their chain
- `depth_response` — inbound reply carrying chain segment

Free-text on purpose so future packet types add without restricted-picklist propagation pain.

### `NetworkEntity__c.RevealFulfillmentDepthPk__c` (restricted picklist, default `Off`)
Per-peer consent setting:
| Value | Meaning |
|---|---|
| `Off` | Refuse all probes. Audit chain stops here, surfaces as redacted leaf. |
| `OrgOnly` | Reveal this peer's org identity only. No jurisdiction, no downstream. |
| `OrgAndJurisdiction` | Reveal org + jurisdiction (country/state). Sufficient for most regulatory checks. |
| `Full` | Reveal everything: org + jurisdiction + downstream peers + per-user attribution. |

Default `Off` so consent is opt-in per-peer. Admins set this on each NetworkEntity row to participate in upstream audits.

### `NetworkEntity__c.JurisdictionTxt__c` (Text 100)
Geographic / regulatory zone. Recommended values: ISO country code (US, DE, IN), country-state (US-CA, US-NY), or named regulatory zone (EU, GDPR, ITAR-US). Surfaced when reveal level is `OrgAndJurisdiction` or higher.

## API (scaffold today)

```apex
DeliveryDepthProbeService.DepthChainNode root =
    DeliveryDepthProbeService.getFulfillmentChain(workItemId, maxDepth);
```

Returns a tree:
```
DepthChainNode {
    orgId: String       // null when peer reveal=Off
    orgName: String     // "[redacted]" when peer reveal=Off
    jurisdiction: String  // null unless reveal>=OrgAndJurisdiction
    revealLevel: String   // Off / OrgOnly / OrgAndJurisdiction / Full
    children: List<DepthChainNode>
}
```

Today: returns local segment only (this org's identity + this org's downstream Vendor peers, each filtered by its own reveal level). `children` of those peer nodes are empty until the recursive probe ships.

## Follow-on PR (full implementation)

1. **Outbound probe**: when `getFulfillmentChain(...)` is called and a Vendor peer has reveal != Off, emit an outbound `SyncItem` with `ChangeTypeTxt='depth_probe'` and payload `{ workItemRef, remainingDepth, requestId }`. Use the existing sync transport.
2. **Receiver-side probe handler**: new branch in `DeliverySyncItemIngestor.processInboundItem` that recognizes `ChangeTypeTxt='depth_probe'`. Builds local segment via `getFulfillmentChain`. Emits outbound `SyncItem` with `ChangeTypeTxt='depth_response'` and the JSON-serialized chain in payload.
3. **Aggregator**: caller-side handler that receives `depth_response` payloads, deserializes, stitches into the original DepthChainNode tree by `requestId`. Returns to the original caller (likely an LWC waiting on a Promise).
4. **Visualization** (CN side, not DH): react-flow tree rendering, greyed leaves for opt-out vendors, jurisdiction-color coding.
5. **Rate limiting + recursion budget**: prevent abuse / fan-out storms. Cap `maxDepth` at 5. Block re-probes within N minutes per (caller, workItem) tuple.
6. **Audit log**: every outbound probe + inbound response logged to `ActivityLog__c` for the original caller's audit trail.

## Pricing positioning (cloudnimbusllc.com)

Per the 2026-05-03 4th-node round-trip goal doc — depth-charge is positioned as a billable **"Audit Chain Visibility"** feature on cloudnimbusllc pricing. Each customer tenant pays for the upstream-audit capability; downstream peers participate by setting their reveal level.

Estimated effort for full implementation: ~16-24h spread across DH + cloudnimbusllc.

## What this PR includes
- 3 new fields (above)
- `DeliveryDepthProbeService.cls` with local-only chain assembly
- `DepthChainNode` DTO
- 4 unit tests (root assembly + Off / OrgOnly / OrgAndJurisdiction reveal filters)
- This doc

## What this PR doesn't include
- Recursive cross-org probe + response (the network round-trip)
- Aggregator / response stitching
- Caller-facing API (LWC / REST)
- Rate limiting + recursion budget
- ActivityLog audit trail
- Visualization (CN-side)

Glen reviews the schema + DTO shape here. Follow-on PR scopes the network machinery once the design is locked.
