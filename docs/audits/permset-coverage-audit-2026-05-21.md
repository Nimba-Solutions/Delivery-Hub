# Permset + Test-Coverage Audit — 2026-05-21

## Headline

- **Total Apex classes scanned:** 287 (139 test + 148 production)
- **Apex classes without a test:** 2 (out of 148 non-test classes)
- **Zombie permset entries (deleted schema):** 0
- **Apex classes in permsets but missing from `DH.testSuite-meta.xml`:** 2
- **Total field permissions scanned:** 175 fields
- **Zombie field permset entries:** 0

Net: DH maintains excellent permset/schema hygiene. Only gaps are two test classes missing from the suite + one untested service with high DML/billing exposure.

## 1. Untested Classes

| Class | Risk | Rationale |
|---|---|---|
| `DeliveryDocGenerationService` | **HIGH** | Contains DML (insert/update), complex document snapshot logic, calculates charges & prior balance; publicly exposed via document generation API. Failure impacts billing & document delivery pipeline |
| `DeliveryForecastAlertQueueable` | LOW | Thin wrapper around `DeliveryForecastAlertService` (which IS tested). Pure orchestration / callout handler; service logic covered by the parent's tests |

## 2. Permset Classes Missing from `DH.testSuite-meta.xml`

| Test class | Likely cause | Action |
|---|---|---|
| `DeliveryDashboardCardControllerTest` | Recently-added controller; manually-maintained suite was forgotten during PR | Add to `unpackaged/post/testSuites/DH.testSuite-meta.xml` near line 105 |
| `DeliveryPermissionAnalyzerControllerTest` | Same shape; possible oversight from refactor or recent feature-add | Add to same suite |

## 3. Field-Level Permset Coverage

- **Total field permissions defined:** 175 (both permsets combined)
- **Verified field existence:** 100% (0 missing)
- **Zero zombie entries:** every referenced field exists in schema
- **Custom Settings handled correctly:** `DeliveryHubSettings__c` has only 1 field-perm entry (`DefaultRetentionDaysNumber__c`); other Custom Settings fields rely on the global-readable semantics (correct)

## 4. Apex Class Permset Coverage

- **Permset references:** 55 unique Apex classes across `DeliveryHubApp` + `DeliveryHubAdmin_App`
- **Verified class existence:** 100%
- **Zero zombie entries**

## Recommended Cleanup PR

Minimal, low-risk; addresses test-suite maintenance drift and the one high-risk untested service:

1. Add `DeliveryDashboardCardControllerTest` to `DH.testSuite-meta.xml` (~line 105) — 5 min
2. Add `DeliveryPermissionAnalyzerControllerTest` to same suite — 5 min
3. **Write** `DeliveryDocGenerationServiceTest.cls` — document-gen, snapshot validation, charge-calc — **HIGH PRIORITY** given DML + billing exposure — ~2-2.5h

**Total effort:** 2-3 hours. **Risk:** minimal — suite entries are mechanical; the new test class adds coverage without any schema change.
