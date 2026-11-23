/**
 * @name         Delivery Hub
 * @license      BSL 1.1 - See LICENSE.md
 * @description  Back-fills deprecated-but-still-REQUIRED legacy fields on subscriber orgs.
 *
 *               WHY THIS EXISTS
 *               ---------------
 *               Fields renamed in #590 (e.g. BountyClaim__c.ClaimantEmailTxt__c ->
 *               ClaimantEmail__c) and the old WorkItemDependency__c Blocked/BlockingWorkItemId__c
 *               lookups were removed from source, but an unlocked-package upgrade does NOT delete
 *               them from a subscriber org: they stay behind as manageableState
 *               "deprecatedEditable" with Required=true (verified in MF-Prod 2026-11-23, and the
 *               unpackaged/pre destructive step only runs in CI flows, never on a subscriber).
 *               Every insert that leaves them blank fails with REQUIRED_FIELD_MISSING, in tests
 *               AND in production (Gantt dependency create, bounty claim).
 *
 *               Because the fields are not in source they cannot be referenced statically, so this
 *               copies the value of the current replacement field into the legacy one via the
 *               describe map. It is a no-op when the legacy field does not exist (CI/dev orgs) or
 *               is not required, so it is safe everywhere.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryLegacyFieldFiller {

    /** @description legacy field local name -> current replacement local name. */
    private static final Map<String, String> LEGACY_TO_CURRENT = new Map<String, String>{
        'BlockedWorkItemId__c' => 'BlockedWorkItemLookup__c',
        'BlockingWorkItemId__c' => 'BlockingWorkItemLookup__c',
        'ClaimantEmailTxt__c' => 'ClaimantEmail__c'
    };

    /**
     * @description Populates any still-required legacy field from its replacement field.
     * @param records Records about to be inserted (any SObject type; unrelated types are ignored).
     */
    public static void fill(List<SObject> records) {
        if (records == null) {
            return;
        }
        Map<Schema.SObjectType, Map<String, Schema.DescribeFieldResult>> byType =
            new Map<Schema.SObjectType, Map<String, Schema.DescribeFieldResult>>();
        for (SObject rec : records) {
            Schema.SObjectType t = rec.getSObjectType();
            if (!byType.containsKey(t)) {
                Map<String, Schema.DescribeFieldResult> byLocal = new Map<String, Schema.DescribeFieldResult>();
                for (Schema.SObjectField f : t.getDescribe().fields.getMap().values()) {
                    Schema.DescribeFieldResult d = f.getDescribe();
                    byLocal.put(unprefixed(d.getName()), d);
                }
                byType.put(t, byLocal);
            }
            Map<String, Schema.DescribeFieldResult> fields = byType.get(t);
            for (String legacy : LEGACY_TO_CURRENT.keySet()) {
                Schema.DescribeFieldResult legacyField = fields.get(legacy);
                Schema.DescribeFieldResult currentField = fields.get(LEGACY_TO_CURRENT.get(legacy));
                if (legacyField == null || currentField == null || legacyField.isNillable()) {
                    continue;
                }
                if (rec.get(legacyField.getName()) == null) {
                    Object value = rec.get(currentField.getName());
                    if (value != null) {
                        rec.put(legacyField.getName(), value);
                    }
                }
            }
        }
    }

    /**
     * @description Strips a leading namespace ("delivery__") so lookups work whether or not the
     *              org is namespaced. getLocalName() is NOT used: its result depends on the
     *              namespace of the calling code.
     * @param apiName Field API name, possibly namespace-prefixed.
     * @return API name without the namespace prefix.
     */
    private static String unprefixed(String apiName) {
        return apiName.countMatches('__') > 1 ? apiName.substringAfter('__') : apiName;
    }

    /**
     * @description Single-record convenience overload.
     * @param record Record about to be inserted.
     */
    public static void fill(SObject record) {
        fill(new List<SObject>{ record });
    }
}
