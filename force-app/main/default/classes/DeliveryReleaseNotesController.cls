/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Release Notes Generator LWC. Queries completed
 * WorkItem__c records within a date range, groups them by RequestTypePk__c, and
 * returns structured data for formatted release notes display.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryReleaseNotesController {

    /** @description Default workflow type when none is specified. */
    private static final String DEFAULT_WORKFLOW = 'Software_Delivery';

    /** @description Category label used when RequestTypePk__c is blank. */
    private static final String UNCATEGORIZED = 'Other';

    /** @description Maximum work items returned in a single query. */
    private static final Integer QUERY_LIMIT = 500;

    /**
     * @description Generates structured release notes from completed work items within
     * a date range. Items are grouped by RequestTypePk__c for display.
     * @param startDate The beginning of the date range (inclusive).
     * @param endDate The end of the date range (inclusive, full day).
     * @param workflowTypeName The DeveloperName of the workflow type to use.
     *                         Defaults to 'Software_Delivery' if blank.
     * @return Map containing title, totalItems, and sections keys.
     */
    @AuraEnabled
    public static Map<String, Object> generateReleaseNotes(
        Date startDate, Date endDate, String workflowTypeName
    ) {
        try {
            String resolvedWorkflow = resolveWorkflowType(workflowTypeName);
            Datetime startDt = buildStartDatetime(startDate);
            Datetime endDt = buildEndDatetime(endDate);

            Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(resolvedWorkflow);

            List<WorkItem__c> items = queryCompletedItems(terminalStages, startDt, endDt);

            return assembleResult(startDate, endDate, items);
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Resolves workflow type name, defaulting to Software_Delivery when blank.
     * @param workflowTypeName The provided workflow type name.
     * @return String The resolved workflow type name.
     */
    private static String resolveWorkflowType(String workflowTypeName) {
        return String.isBlank(workflowTypeName) ? DEFAULT_WORKFLOW : workflowTypeName;
    }

    /**
     * @description Converts a start Date to a Datetime at midnight.
     * @param startDate The start date.
     * @return Datetime The start of the given date.
     */
    private static Datetime buildStartDatetime(Date startDate) {
        return Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
    }

    /**
     * @description Converts an end Date to a Datetime at the start of the next day,
     * ensuring the full end day is included.
     * @param endDate The end date.
     * @return Datetime Midnight of the day after endDate.
     */
    private static Datetime buildEndDatetime(Date endDate) {
        return Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
    }

    /**
     * @description Queries WorkItem__c records in terminal stages within the date range.
     * @param terminalStages Set of terminal stage API values.
     * @param startDt Start datetime (inclusive).
     * @param endDt End datetime (exclusive, day after end date).
     * @return List of matching WorkItem__c records.
     */
    private static List<WorkItem__c> queryCompletedItems(
        Set<String> terminalStages, Datetime startDt, Datetime endDt
    ) {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   RequestTypePk__c, PriorityPk__c,
                   Developer__c, Developer__r.Name, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND LastModifiedDate >= :startDt
            AND LastModifiedDate < :endDt
            WITH SYSTEM_MODE
            ORDER BY RequestTypePk__c ASC, LastModifiedDate DESC
            LIMIT :QUERY_LIMIT
        ];
    }

    /**
     * @description Assembles the final result map from queried work items.
     * @param startDate Original start date for the title.
     * @param endDate Original end date for the title.
     * @param items List of completed WorkItem__c records.
     * @return Map with title, totalItems, and sections keys.
     */
    private static Map<String, Object> assembleResult(
        Date startDate, Date endDate, List<WorkItem__c> items
    ) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('title', 'Release Notes \u2014 ' + formatDate(startDate) + ' to ' + formatDate(endDate));
        result.put('totalItems', items.size());

        if (items.isEmpty()) {
            result.put('sections', new List<Map<String, Object>>());
            return result;
        }

        result.put('sections', buildSections(items));
        return result;
    }

    /**
     * @description Groups work items by RequestTypePk__c and builds section maps.
     * @param items List of WorkItem__c records to group.
     * @return List of section maps, each with category and items keys.
     */
    private static List<Map<String, Object>> buildSections(List<WorkItem__c> items) {
        Map<String, List<Map<String, Object>>> grouped = groupByCategory(items);

        List<Map<String, Object>> sections = new List<Map<String, Object>>();
        List<String> sortedCategories = new List<String>(grouped.keySet());
        sortedCategories.sort();

        for (String category : sortedCategories) {
            Map<String, Object> section = new Map<String, Object>();
            section.put('category', category);
            section.put('items', grouped.get(category));
            sections.add(section);
        }
        return sections;
    }

    /**
     * @description Groups work items into a map keyed by category (RequestTypePk__c).
     * @param items List of WorkItem__c records.
     * @return Map from category string to list of item detail maps.
     */
    private static Map<String, List<Map<String, Object>>> groupByCategory(
        List<WorkItem__c> items
    ) {
        Map<String, List<Map<String, Object>>> grouped =
            new Map<String, List<Map<String, Object>>>();

        for (WorkItem__c item : items) {
            String category = String.isNotBlank(item.RequestTypePk__c)
                ? item.RequestTypePk__c
                : UNCATEGORIZED;

            if (!grouped.containsKey(category)) {
                grouped.put(category, new List<Map<String, Object>>());
            }
            grouped.get(category).add(buildItemMap(item));
        }
        return grouped;
    }

    /**
     * @description Converts a single WorkItem__c record to a flat map for LWC consumption.
     * @param item The WorkItem__c record.
     * @return Map with name, title, priority, developer, and completedDate keys.
     */
    private static Map<String, Object> buildItemMap(WorkItem__c item) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('name', item.Name);
        m.put('title', item.BriefDescriptionTxt__c);
        m.put('priority', item.PriorityPk__c);
        m.put('developer', item.Developer__r != null ? item.Developer__r.Name : null);
        m.put('completedDate', item.LastModifiedDate.format('yyyy-MM-dd'));
        return m;
    }

    /**
     * @description Formats a Date as yyyy-MM-dd string for display.
     * @param d The date to format.
     * @return String formatted date string.
     */
    private static String formatDate(Date d) {
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
    }
}
