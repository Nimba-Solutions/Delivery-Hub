/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for board saved-filter CRUD operations. Backed by
 *               a per-user JSON blob on DeliveryHubSettings__c (the Hierarchy
 *               custom setting). Replaces the prior DeliverySavedFilter__c
 *               custom object — same per-user privacy semantics, no slot cost
 *               against the namespaced custom-object cap.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier')
global with sharing class DeliverySavedFilterController {

    private static final String DEFAULT_WORKFLOW = 'Software_Delivery';

    /**
     * @description One saved filter — the JSON shape stored inside
     *              DeliveryHubSettings__c.SavedFiltersJsonTxt__c. Made global
     *              so the LWC wire result keeps the same field names callers
     *              already consume.
     */
    global class FilterRow {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String filterJson;
        @AuraEnabled public Boolean defaultSet;
        @AuraEnabled public String workflowType;
    }

    /**
     * @description Returns all saved filters owned by the running user for a given workflow type.
     * @param workflowType The WorkflowType DeveloperName to filter by.
     * @return List of FilterRow ordered by label.
     */
    @AuraEnabled(cacheable=true)
    global static List<FilterRow> getSavedFilters(String workflowType) {
        String wf = String.isBlank(workflowType) ? DEFAULT_WORKFLOW : workflowType;
        List<FilterRow> all = readAllForUser(UserInfo.getUserId());
        List<FilterRow> matching = new List<FilterRow>();
        for (FilterRow r : all) {
            if (wf.equals(r.workflowType)) {
                matching.add(r);
            }
        }
        matching.sort(new FilterRowLabelComparator());
        return matching;
    }

    /**
     * @description Creates or updates a saved filter. When isDefault is true,
     *              any other default filter for the same user and workflow type is un-defaulted.
     * @param filterId Null for new filter, existing synthetic id for update.
     * @param label User-given display name.
     * @param filterJson Serialized filter criteria JSON.
     * @param isDefault Whether this should be the default filter.
     * @param workflowType The workflow type this filter applies to.
     * @return The upserted FilterRow.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    global static FilterRow saveBoardFilter(
        String filterId,
        String label,
        String filterJson,
        Boolean isDefault,
        String workflowType
    ) {
        validateSaveInputs(label, filterJson);
        String wf = String.isBlank(workflowType) ? DEFAULT_WORKFLOW : workflowType;
        Id userId = UserInfo.getUserId();
        List<FilterRow> all = readAllForUser(userId);
        FilterRow target = findOrCreateRow(all, filterId);
        applySaveFields(target, label, filterJson, wf, isDefault == true);
        if (isDefault == true) {
            clearOtherDefaults(all, target.id, wf);
        }
        writeAllForUser(userId, all);
        return target;
    }

    private static void validateSaveInputs(String label, String filterJson) {
        if (String.isBlank(label)) {
            throw createAuraException('Filter name is required.');
        }
        if (String.isBlank(filterJson)) {
            throw createAuraException('Filter criteria cannot be empty.');
        }
    }

    private static FilterRow findOrCreateRow(List<FilterRow> all, String filterId) {
        if (filterId != null) {
            for (FilterRow r : all) {
                if (filterId.equals(r.id)) {
                    return r;
                }
            }
        }
        FilterRow created = new FilterRow();
        created.id = newSyntheticId();
        all.add(created);
        return created;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void applySaveFields(FilterRow target, String label, String filterJson,
        String workflowType, Boolean isDefault) {
        target.label = label;
        target.filterJson = filterJson;
        target.workflowType = workflowType;
        target.defaultSet = isDefault;
    }

    private static void clearOtherDefaults(List<FilterRow> all, String targetId, String workflowType) {
        for (FilterRow r : all) {
            if (r.id != targetId && workflowType.equals(r.workflowType)) {
                r.defaultSet = false;
            }
        }
    }

    /**
     * @description Deletes a saved filter for the running user.
     * @param filterId The synthetic id of the filter to remove.
     */
    @AuraEnabled
    global static void deleteSavedFilter(String filterId) {
        if (String.isBlank(filterId)) {
            throw createAuraException('Filter Id is required.');
        }
        Id userId = UserInfo.getUserId();
        List<FilterRow> all = readAllForUser(userId);
        List<FilterRow> kept = new List<FilterRow>();
        Boolean removedAny = false;
        for (FilterRow r : all) {
            if (filterId.equals(r.id)) {
                removedAny = true;
            } else {
                kept.add(r);
            }
        }
        if (!removedAny) {
            throw createAuraException('Filter not found or already deleted.');
        }
        writeAllForUser(userId, kept);
    }

    @TestVisible
    private static List<FilterRow> readAllForUser(Id userId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance(userId);
        if (settings == null || String.isBlank(settings.SavedFiltersJsonTxt__c)) {
            return new List<FilterRow>();
        }
        try {
            List<FilterRow> rows = (List<FilterRow>) JSON.deserialize(
                settings.SavedFiltersJsonTxt__c, List<FilterRow>.class);
            return rows == null ? new List<FilterRow>() : rows;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliverySavedFilterController] Could not parse SavedFiltersJsonTxt__c: '
                + e.getMessage());
            return new List<FilterRow>();
        }
    }

    @TestVisible
    private static void writeAllForUser(Id userId, List<FilterRow> rows) {
        DeliveryHubSettings__c row = loadOrCreatePerUserRow(userId);
        row.SavedFiltersJsonTxt__c = JSON.serialize(rows);
        Database.upsert(row, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Resolve (or create) the per-user DeliveryHubSettings__c
     *              row for upsert. Hierarchy custom setting permits one row
     *              per SetupOwnerId; we manage that directly to avoid the
     *              org-default fallback path overwriting another user's data.
     * @param userId The Salesforce User Id this row belongs to.
     * @return Per-user DeliveryHubSettings__c row (existing or new).
     */
    @TestVisible
    private static DeliveryHubSettings__c loadOrCreatePerUserRow(Id userId) {
        List<DeliveryHubSettings__c> existing = [
            SELECT Id, SavedFiltersJsonTxt__c, NotificationPreferencesJsonTxt__c
            FROM DeliveryHubSettings__c
            WHERE SetupOwnerId = :userId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        return new DeliveryHubSettings__c(SetupOwnerId = userId);
    }

    private static String newSyntheticId() {
        return 'sf_' + String.valueOf(Datetime.now().getTime())
            + '_' + String.valueOf(Math.abs(Crypto.getRandomLong())).right(8);
    }

    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * @description Sort comparator that orders FilterRow records by label
     *              ascending, with null/blank labels falling to the end.
     */
    public class FilterRowLabelComparator implements System.Comparator<FilterRow> {
        /**
         * @description Compare two FilterRow values by lowercased label.
         * @param a Left side of the comparison.
         * @param b Right side of the comparison.
         * @return -1 / 0 / 1 per Comparator contract.
         */
        public Integer compare(FilterRow a, FilterRow b) {
            String al = a == null || a.label == null ? '' : a.label.toLowerCase();
            String bl = b == null || b.label == null ? '' : b.label.toLowerCase();
            if (al == bl) { return 0; }
            return al < bl ? -1 : 1;
        }
    }
}
