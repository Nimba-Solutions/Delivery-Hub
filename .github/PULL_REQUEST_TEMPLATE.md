## Summary

<!-- What changed and why? -->

## Test plan

<!-- How to verify this works? -->

## Checklist

- [ ] PMD clean (CI runs `apex-scan` automatically — see `.github/workflows/feature_test.yml`. To run locally: `sf scanner run --target "force-app/**/*" --pmdconfig category/xml/default.xml --engine pmd`)
- [ ] All Apex tests pass (CI runs the `DH` test suite — see `unpackaged/post/testSuites/DH.testSuite-meta.xml`)
- [ ] No `console.log` left in LWC code
- [ ] No `System.debug` outside catch blocks (dev tracing must come out before merge)
- [ ] Backward compatible (no breaking changes to public APIs, custom object/field API names, REST endpoints, or CMT developer names — Master-Detail field renames are forbidden, see [docs/FIELD_NAMING.md](../docs/FIELD_NAMING.md))
- [ ] New tests added to the `DH` test suite

## Issues closed

<!-- e.g., Closes #123 -->
