# Contributing to Delivery Hub

Thank you for your interest in contributing. Delivery Hub is licensed under the
[Business Source License 1.1](LICENSE.md) (converts to Apache 2.0 four years
after each release).

## Getting Started

1. **Fork** the repository and clone your fork.
2. Install [CumulusCI](https://cumulusci.readthedocs.io/) and ensure you have
   access to a Salesforce Dev Hub org.
3. Create a scratch org for development:
   ```bash
   cci flow run dev_org --org dev
   cci org browser dev
   ```

## Branch Workflow

1. Create a feature branch from `main`. Any branch name works — CI runs on every
   branch since PR #587. Historically `feature/*` was required; that gate is gone.
   ```bash
   git checkout -b feature/your-feature main
   ```
2. Make your changes and commit with descriptive messages.
3. Push to your fork and open a pull request against `main`.
4. **Never commit directly to `main`.** All changes go through PRs. CI will not
   run on direct pushes to main, and a direct push will bypass the PMD + Apex
   test gates.

## Pull Request Requirements

Every PR is validated by CI, which runs the following checks in a namespaced
scratch org:

- **PMD static analysis** (`apex-scan` job) — zero violations at priority 1-4
  required. The ruleset lives in [`category/xml/default.xml`](category/xml/default.xml)
  and includes the custom `*FieldNamingConvention` rules enforcing the
  type-suffix convention documented in [docs/FIELD_NAMING.md](docs/FIELD_NAMING.md).
- **Apex tests** (`feature-test` job) — all tests must pass with 75%+ coverage.
  The job spins up a namespaced scratch org, installs CumulusCI's dependency
  chain, deploys `force-app/` and `unpackaged/post/`, and runs the `DH` test
  suite defined in `unpackaged/post/testSuites/DH.testSuite-meta.xml`.
  Since PR #587 the workflow runs on every branch, not just `feature/*`.
- **No `console.log`** statements in LWC JavaScript. A pre-commit hook strips
  inline `/* eslint */` comments — rule config must live in `.eslintrc.json`,
  not inline.
- **Backward compatible** — no breaking changes to public APIs, custom object
  field API names, REST endpoints, or CMT developer names. Field renames on
  Master-Detail fields are forbidden; see
  [docs/FIELD_NAMING.md](docs/FIELD_NAMING.md) for the full constraint.
- **New tests added to the `DH` test suite**. Every new Apex class needs a
  matching test class that is referenced in the suite.

Please fill out the PR template completely, including a summary and test plan.

### Known CI quirks

- `install-beta` job historically fails on a pre-existing `DeliveryHubSite`
  ApexPage error. It does NOT block the upload-beta step or promotion. Safe to
  promote when `upload-beta` is green.
- `UNABLE_TO_LOCK_ROW` failures are flaky scratch-org contention — just re-run.
- Each PR check + each manual trigger consumes two scratch orgs. Batch related
  fixes into fewer PRs when possible.

## Code Style

- **Apex**: follow the existing naming conventions (`Delivery*` prefix for all
  production classes). Apex class name limit is 40 characters. When making an
  Apex class `global`, ALL inner classes used as return/param types must also
  be `global` (except `Queueable`/`Schedulable` implementations).
- **LWC**: component names use the `delivery` prefix (e.g., `deliveryHubBoard`).
  LWC `@api` boolean props cannot default to `true` (LWC1503) — use an inverted
  prop name. LWC templates do not support ternary expressions in API v62 — use
  getters instead.
- **SOQL**: use `WITH SYSTEM_MODE` in tests, never `WITH USER_MODE` — the
  namespaced package test context rejects `USER_MODE` with `SecurityException`.
- **Custom fields**: follow the type-suffix convention in
  [docs/FIELD_NAMING.md](docs/FIELD_NAMING.md). PMD blocks violations at
  priority 2. **No new Boolean fields** — use the `*DateTime__c` pattern (null
  = off, populated timestamp = on + when).
- **No `System.debug` outside catch blocks.** Dev tracing has to come out
  before merge. The `AvoidDebugStatements` PMD rule is currently disabled but
  will come back.
- Keep methods focused and testable. Method parameter count is capped at 5 by
  the tuned `ExcessiveParameterList` rule — use a DTO if you need more.

## Reporting Issues

Open a [GitHub issue](https://github.com/Nimba-Solutions/Delivery-Hub/issues)
with steps to reproduce, expected behavior, and actual behavior.

Security vulnerabilities — see [SECURITY.md](SECURITY.md). Do NOT open a public
issue for security reports.

## Questions?

Reach out via [GitHub Discussions](https://github.com/Nimba-Solutions/Delivery-Hub/discussions)
or email hello@cloudnimbusllc.com.
