/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger-layer allowlist enforcement for picklist fields that are backed
 *               by a GlobalValueSet but cannot be marked restricted=true due to the SF
 *               retrofit block on existing inline-defined picklist fields (Known Issue
 *               a028c00000qPzYUAA0).
 *
 *               Enterprise-scale bulk data loaders bypass DH's Apex services entirely,
 *               so without this service a loader could insert "Bogus" into StatusPk__c
 *               and break downstream processors. This service queries the live field
 *               describe (which resolves to the GVS values at runtime) so that future
 *               GVS value additions automatically extend the allowlist — no hardcoded
 *               value lists to maintain.
 *
 *               A transaction-local static cache (@TestVisible) ensures a single
 *               describe call per field for a bulk 200-record trigger fire.
 *
 * @author       Cloud Nimbus LLC
 */
public with sharing class DeliveryPicklistIntegrityService {

    /**
     * @description Per-transaction cache of allowed picklist values keyed by
     *              "ObjectApiName.FieldApiName" — wiped when the transaction ends.
     *              @TestVisible so bulk-run tests can assert cache hits.
     */
    @TestVisible
    private static Map<String, Set<String>> allowedValuesCache = new Map<String, Set<String>>();

    /**
     * @description Counter incremented on each underlying describe call (cache miss).
     *              @TestVisible so bulk-run tests can prove the cache is actually
     *              preventing repeat describes in a 200-record trigger batch.
     */
    @TestVisible
    private static Integer describeCallCount = 0;

    /**
     * @description Validates that a picklist field's value is in the GVS-backed allowlist.
     *              Call from a before-insert / before-update trigger handler — calls
     *              record.addError(fieldName, ...) when the value is not in the allowlist.
     *
     *              Null or blank values are IGNORED (integrity enforces value-in-set, not
     *              required-ness; enforce non-null separately via field metadata if needed).
     *
     *              The allowed set is loaded once per (object, field) pair per transaction
     *              via a static cache, so calling this inside a 200-record trigger only
     *              describes each field once.
     *
     * @param record             The SObject being validated (usually from Trigger.new).
     * @param fieldName          API name of the picklist field on the record.
     * @param globalValueSetName Developer name of the GlobalValueSet metadata backing
     *                           the field. Used only for error message clarity — the
     *                           actual allowlist is read from the field describe.
     */
    public static void validate(SObject record, String fieldName, String globalValueSetName) {
        if (record == null || String.isBlank(fieldName)) {
            return;
        }

        Object raw = record.get(fieldName);
        if (raw == null) {
            return;
        }
        String value = String.valueOf(raw);
        if (String.isBlank(value)) {
            return;
        }

        String objectApiName = record.getSObjectType().getDescribe().getLocalName();
        Set<String> allowed = getAllowedValues(record.getSObjectType(), fieldName);

        if (allowed == null || allowed.isEmpty()) {
            // Field describe returned no picklist entries — do not block writes on a
            // misconfigured or unreachable describe. Safer to let the row through
            // than to hard-block the entire object.
            return;
        }

        if (!allowed.contains(value)) {
            String label = String.isNotBlank(globalValueSetName) ? globalValueSetName : fieldName;
            record.addError(
                fieldName,
                'Value "' + value + '" is not in the allowed set for ' + label
                    + '. Allowed: ' + String.join(new List<String>(allowed), ', ')
            );
        }
    }

    /**
     * @description Returns the set of active allowed picklist values for a field,
     *              populating the transaction-local cache on first call.
     * @param sType     SObject type token (e.g. SyncItem__c.getSObjectType()).
     * @param fieldName API name of the picklist field.
     * @return The set of allowed values, or null if the field was not found.
     */
    private static Set<String> getAllowedValues(Schema.SObjectType sType, String fieldName) {
        String cacheKey = sType.getDescribe().getLocalName() + '.' + fieldName;
        if (allowedValuesCache.containsKey(cacheKey)) {
            return allowedValuesCache.get(cacheKey);
        }

        describeCallCount++;

        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();
        Schema.SObjectField token = fieldMap.get(fieldName);
        if (token == null) {
            allowedValuesCache.put(cacheKey, new Set<String>());
            return allowedValuesCache.get(cacheKey);
        }

        Schema.DescribeFieldResult dfr = token.getDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        allowedValuesCache.put(cacheKey, values);
        return values;
    }

    /**
     * @description Test-only hook to reset the transaction-local state between
     *              test methods in the same test run.
     */
    @TestVisible
    private static void resetForTest() {
        allowedValuesCache = new Map<String, Set<String>>();
        describeCallCount = 0;
    }
}
