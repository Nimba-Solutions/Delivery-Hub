#!/usr/bin/env python3
"""
Post-install beta package smoke test: picklist value propagation.

Problem this exists to catch:
-----------------------------
1. CCI content-hash can reuse a stale 04t package version when it doesn't
   detect enough source change, so an "upload-beta" marked fresh can actually
   point at an OLDER build missing source changes.
2. Salesforce does not reliably propagate NEW values on *restricted*
   picklists to subscriber orgs on package upgrade (Known Issue
   a028c00000qPzYUAA0). Our picklists are non-restricted to dodge this at
   DML-time, but describe-time propagation still fails silently if the
   package metadata itself is stale.

What this script does:
----------------------
- Parses the authoritative expected picklist values from each field-meta.xml
  listed in EXPECTED_PICKLISTS below.
- Calls `sf sobject describe --sobject <ns>__<obj>__c -o <target-org>` against
  the freshly-installed-beta subscriber scratch org.
- Fails with a non-zero exit and a diff if any expected value is missing from
  the describe response.

Extending:
----------
To add a new picklist to the smoke test, append an entry to EXPECTED_PICKLISTS
with object_dir, field_file, and the desired namespaced SObject API name. The
script auto-parses the expected values from the field-meta.xml.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
OBJECTS_DIR = REPO_ROOT / "force-app" / "main" / "default" / "objects"
MDAPI_NS = "{http://soap.sforce.com/2006/04/metadata}"


@dataclass(frozen=True)
class PicklistCheck:
    # Source-of-truth
    object_dir: str           # e.g. "SyncItem__c"
    field_file: str           # e.g. "StatusPk__c.field-meta.xml"
    # What we expect to see in the subscriber describe
    sobject_api_name: str     # e.g. "delivery__SyncItem__c"
    field_api_name: str       # e.g. "delivery__StatusPk__c"


# 4 HIGH-churn picklists per today's research report. Extend freely.
EXPECTED_PICKLISTS: list[PicklistCheck] = [
    PicklistCheck(
        object_dir="SyncItem__c",
        field_file="StatusPk__c.field-meta.xml",
        sobject_api_name="delivery__SyncItem__c",
        field_api_name="delivery__StatusPk__c",
    ),
    PicklistCheck(
        object_dir="SyncItem__c",
        field_file="ObjectTypePk__c.field-meta.xml",
        sobject_api_name="delivery__SyncItem__c",
        field_api_name="delivery__ObjectTypePk__c",
    ),
    PicklistCheck(
        object_dir="NotificationPreference__c",
        field_file="EventTypePk__c.field-meta.xml",
        sobject_api_name="delivery__NotificationPreference__c",
        field_api_name="delivery__EventTypePk__c",
    ),
    PicklistCheck(
        object_dir="ActivityLog__c",
        field_file="ActionTypePk__c.field-meta.xml",
        sobject_api_name="delivery__ActivityLog__c",
        field_api_name="delivery__ActionTypePk__c",
    ),
]


def parse_expected_values(field_meta_path: Path) -> list[str]:
    """Extract <fullName> values from a picklist field-meta.xml."""
    if not field_meta_path.exists():
        raise FileNotFoundError(f"Field meta not found: {field_meta_path}")
    tree = ET.parse(field_meta_path)
    root = tree.getroot()
    values: list[str] = []
    for value_el in root.iter(f"{MDAPI_NS}value"):
        full_name_el = value_el.find(f"{MDAPI_NS}fullName")
        if full_name_el is not None and full_name_el.text:
            values.append(full_name_el.text.strip())
    return values


def describe_sobject(sobject: str, target_org: str) -> dict:
    """Run `sf sobject describe` and return the parsed JSON payload."""
    cmd = [
        "sf", "sobject", "describe",
        "--sobject", sobject,
        "-o", target_org,
        "--json",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        sys.stderr.write(
            f"[FAIL] `sf sobject describe` exited {result.returncode} for "
            f"{sobject}\n--- stdout ---\n{result.stdout}\n--- stderr ---\n{result.stderr}\n"
        )
        sys.exit(2)
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"[FAIL] Could not parse describe JSON for {sobject}: {exc}\n")
        sys.stderr.write(result.stdout[:2000])
        sys.exit(2)
    return payload.get("result", payload)


def actual_picklist_values(describe: dict, field_api_name: str) -> list[str] | None:
    for field in describe.get("fields", []):
        if field.get("name", "").lower() == field_api_name.lower():
            return [pv.get("value") for pv in field.get("picklistValues", [])]
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target-org",
        required=True,
        help="SF CLI org alias/username with the beta package installed.",
    )
    args = parser.parse_args()

    failures: list[str] = []
    for check in EXPECTED_PICKLISTS:
        field_path = OBJECTS_DIR / check.object_dir / "fields" / check.field_file
        expected = parse_expected_values(field_path)
        if not expected:
            failures.append(
                f"{check.field_api_name}: source field-meta.xml has NO picklist values "
                f"(parse error at {field_path})"
            )
            continue

        describe = describe_sobject(check.sobject_api_name, args.target_org)
        actual = actual_picklist_values(describe, check.field_api_name)

        if actual is None:
            failures.append(
                f"{check.field_api_name}: field NOT PRESENT on {check.sobject_api_name} "
                f"in subscriber describe - beta package is stale or missing this field."
            )
            continue

        missing = sorted(set(expected) - set(actual))
        if missing:
            failures.append(
                f"{check.field_api_name}: subscriber is MISSING picklist values "
                f"{missing}. Expected (from source): {expected}. Got (from describe): {actual}."
            )
        else:
            print(
                f"[OK] {check.field_api_name}: all {len(expected)} expected values "
                f"present ({expected})."
            )

    if failures:
        print("\n=== PICKLIST PROPAGATION SMOKE TEST FAILED ===", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        print(
            "\nLikely causes:\n"
            "  1. CCI content-hash reused a stale 04t (source change not detected).\n"
            "  2. Restricted-picklist propagation quirk - check <restricted>false</restricted>.\n"
            "  3. Field-meta.xml not actually included in the package.\n"
            "Inspect the uploaded beta 04t's metadata vs force-app/ source.\n",
            file=sys.stderr,
        )
        return 1

    print(f"\n[OK] All {len(EXPECTED_PICKLISTS)} picklist checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
