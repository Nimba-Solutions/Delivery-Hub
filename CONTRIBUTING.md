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

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature main
   ```
2. Make your changes and commit with descriptive messages.
3. Push to your fork and open a pull request against `main`.

## Pull Request Requirements

Every PR is validated by CI, which runs the following checks in a namespaced
scratch org:

- **PMD static analysis** -- zero violations required.
- **Apex tests** -- all tests must pass with 75%+ code coverage.
- **No `console.log`** statements left in LWC JavaScript.
- **Backward compatible** -- no breaking changes to public APIs, custom object
  fields, or REST endpoints.

Please fill out the PR template completely, including a summary and test plan.

## Code Style

- Apex: follow the existing naming conventions (`Delivery*` prefix for all
  classes).
- LWC: component names use the `delivery` prefix (e.g., `deliveryHubBoard`).
- Keep methods focused and testable. Every new Apex class needs a corresponding
  test class.

## Reporting Issues

Open a [GitHub issue](https://github.com/Nimba-Solutions/Delivery-Hub/issues)
with steps to reproduce, expected behavior, and actual behavior.

## Questions?

Reach out via [GitHub Discussions](https://github.com/Nimba-Solutions/Delivery-Hub/discussions)
or email hello@cloudnimbusllc.com.
