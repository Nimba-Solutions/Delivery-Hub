# Delivery Hub — Documentation Index

This folder holds the durable reference documentation for Delivery Hub. Point-in-time
artifacts (dated audits, completed plans, consumed handoffs) live under
[`archive/`](archive/) once they are superseded — they are kept for history, not as
current guidance.

## Getting started & contributing

| Doc | What it covers |
|-----|----------------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | First-run setup and orientation for new developers. |
| [SETUP.md](SETUP.md) | Environment / org setup steps. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branch/PR workflow, conventions, and review expectations. |
| [EXAMPLE_GITHUB_ACTIONS.md](EXAMPLE_GITHUB_ACTIONS.md) | Reference CI/CD workflow examples. |

## Architecture & design

| Doc | What it covers |
|-----|----------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture overview. |
| [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) | Product/engineering design principles. |
| [COCKPIT.md](COCKPIT.md) | Operator cockpit / admin surface overview. |
| [FLOW_REFERENCE.md](FLOW_REFERENCE.md) | Flow reference. |
| [depth-charge-architecture.md](depth-charge-architecture.md) | Audit-chain ("depth-charge") feature architecture (scaffold + recursive cross-org probe BOTH shipped — #760, #769, #772). |

## Conventions & integrity

| Doc | What it covers |
|-----|----------------|
| [FIELD_NAMING.md](FIELD_NAMING.md) | Canonical field-naming conventions. **Read before specifying any field name.** |
| [PICKLIST_INTEGRITY.md](PICKLIST_INTEGRITY.md) | Picklist / GlobalValueSet integrity rules. |

## Feature & integration guides

| Doc | What it covers |
|-----|----------------|
| [PUBLIC_API_GUIDE.md](PUBLIC_API_GUIDE.md) | Public REST API surface and usage. |
| [SYNC_API_GUIDE.md](SYNC_API_GUIDE.md) | Cross-org sync API. |
| [BOUNTY_API_GUIDE.md](BOUNTY_API_GUIDE.md) | Bounty API. |
| [SLACK_INTEGRATION.md](SLACK_INTEGRATION.md) | Slack integration. |
| [DOCUMENT_ACTIONING_FEATURE.md](DOCUMENT_ACTIONING_FEATURE.md) | Document-actioning (invoice/doc email) feature. |
| [INVOICE_DISPUTE_PATTERNS.md](INVOICE_DISPUTE_PATTERNS.md) | Invoice dispute handling patterns. |

## Release history

| Doc | What it covers |
|-----|----------------|
| [CHANGELOG.md](CHANGELOG.md) | Versioned release changelog. |

## Active plans

| Doc | What it covers |
|-----|----------------|
| [plans/phase-2-watcher-design.md](plans/phase-2-watcher-design.md) | Original design recon for the Watcher v1 aggregation layer (now SHIPPED at 0.246 — #807/#809/#810; kept for design history). |

## Archive

[`archive/`](archive/) holds superseded, point-in-time documents preserved for history:

- `archive/audits/` — dated audit snapshots (dead-code, namespace, PMD baselines, page/field, security, etc., May–Jun 2026).
- `archive/handoffs/` — consumed handoff requests (e.g. nimbus-gantt upgrade asks since adopted).
- `archive/plans/` — completed/shipped plans (e.g. Checkout Cart procurement, shipped in the Checkout Cart release).
