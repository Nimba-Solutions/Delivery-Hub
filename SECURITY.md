# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Delivery Hub, please report it
responsibly. **Do not open a public GitHub issue.**

Email: **security@cloudnimbusllc.com**

Include as much detail as possible:

- Description of the vulnerability
- Steps to reproduce
- Affected component (Apex, LWC, REST API, sync engine, etc.)
- Potential impact

We will acknowledge receipt within 48 hours and provide an initial assessment
within 5 business days.

## Scope

The following areas are in scope for security reports:

- **Apex controllers and services** -- SOQL injection, CRUD/FLS bypass,
  unauthorized data access
- **LWC components** -- XSS, insecure data handling, exposed secrets
- **REST API endpoints** -- authentication bypass, authorization flaws,
  injection attacks
- **Cross-org sync engine** -- data leakage between tenants, replay attacks,
  echo suppression bypass
- **Custom Metadata and configuration** -- privilege escalation via metadata
  manipulation

## Out of Scope

- Salesforce platform vulnerabilities (report those to Salesforce directly)
- Social engineering attacks
- Denial of service against Salesforce infrastructure

## Disclosure

We follow coordinated disclosure. Once a fix is released, we will credit the
reporter (unless anonymity is requested) and publish a summary in the release
notes.
