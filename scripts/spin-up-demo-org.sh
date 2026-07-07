#!/usr/bin/env bash
# ============================================================================
# Delivery Hub — one-command demo org  (no CumulusCI, no dev help required)
#
#   Usage:   bash scripts/spin-up-demo-org.sh [alias]        # default: dh-demo
#
# Cuts a fresh scratch org off the CURRENT repo working tree and stands up a
# fully-seeded, clickable Delivery Hub in one shot. Deliberately bypasses the
# two things that were silently breaking installs:
#   * cci flow run  -> stale-token auth bug (INVALID_AUTH_HEADER)
#   * sf source-track deploy -> Windows file-handle limit + no-default-FLS
# The reliable path: resolve namespace tokens -> convert to metadata (mdapi)
# -> deploy with --metadata-dir -> assign permset -> seed.
#
# Requires: sf CLI, python, a connected Dev Hub aliased "MF".
# ============================================================================
set -euo pipefail

ALIAS="${1:-dh-demo}"
DEVHUB="MF"
SCRATCH_DEF="orgs/dev.json"
DAYS=7
PERMSET="DeliveryHubAdmin_App"
SEED="scripts/load-demo-data.apex"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }

say "1/6  Creating fresh scratch org  ($ALIAS, ${DAYS}d, devhub=$DEVHUB)"
sf org create scratch --definition-file "$SCRATCH_DEF" --alias "$ALIAS" \
   --duration-days "$DAYS" --target-dev-hub "$DEVHUB" --wait 15 \
   | grep -viE "warning" || true
USERNAME="$(sf org display --target-org "$ALIAS" --json 2>/dev/null \
   | python -c "import sys,json;print(json.load(sys.stdin)['result']['username'])")"
echo "   username: $USERNAME"

say "2/6  Preparing source: resolving namespace tokens + stripping test files"
cp sfdx-project.json "$TMP/"
cp -r force-app "$TMP/force-app"
# Non-namespaced unmanaged install: NAMESPACE/NAMESPACE_DOT -> '' , NAMESPACE_OR_C -> 'c'
grep -rl '%%%NAMESPACE' "$TMP/force-app" 2>/dev/null | while read -r f; do
  sed -i 's/%%%NAMESPACE_DOT%%%//g; s/%%%NAMESPACE_OR_C%%%/c/g; s/%%%NAMESPACE%%%//g' "$f"
done
# .forceignore'd artifacts that break a raw (non-cci) deploy:
find "$TMP/force-app" -type d -name '__tests__' -prune -exec rm -rf {} + 2>/dev/null || true
find "$TMP/force-app" \( -name 'jsconfig.json' -o -name '.eslintrc.json' \) -delete 2>/dev/null || true
echo "   tokens resolved; __tests__/jsconfig/.eslintrc removed"

say "3/6  Converting source -> metadata format (bypasses source tracking)"
( cd "$TMP" && sf project convert source --source-dir force-app --output-dir mdout \
    | grep -viE "warning" ) || true

say "4/6  Deploying to $ALIAS  (~1670 components, a few minutes)"
sf project deploy start --metadata-dir "$TMP/mdout" --target-org "$ALIAS" --wait 30 \
   | grep -iE "Status:|Deployed|Elapsed|Components:" | tail -4

say "5/6  Assigning $PERMSET permission set"
sf org assign permset --name "$PERMSET" --target-org "$ALIAS" 2>&1 \
   | grep -iE "success|already|assign" || true

say "6/6  Seeding demo data"
sf apex run --file "$SEED" --target-org "$ALIAS" 2>&1 \
   | grep -iE "Compiled successfully|DEMO DATA|FATAL|Field does not exist" || true

say "DONE — record counts"
for o in NetworkEntity__c WorkItem__c WorkRequest__c WorkLog__c DeliveryDocument__c; do
  c="$(sf data query --target-org "$ALIAS" -q "SELECT COUNT() FROM $o" --json 2>/dev/null \
       | python -c "import sys,json;print(json.load(sys.stdin)['result']['totalSize'])" 2>/dev/null || echo '?')"
  printf '   %-22s %s\n' "$o" "$c"
done
echo ""
echo "   Open it:   sf org open --target-org $ALIAS"
echo "   Board:     sf org open --target-org $ALIAS --path lightning/n/Delivery_Board"
