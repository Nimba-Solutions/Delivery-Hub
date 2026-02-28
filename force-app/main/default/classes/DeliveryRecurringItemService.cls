/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Service class for recurring work items and template cloning.
 * Handles scheduled creation of recurring items and on-demand cloning from templates.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryRecurringItemService {

    // Fields to copy when cloning a work item (descriptive / config fields only)
    private static final List<String> CLONE_FIELDS = new List<String>{
        'BriefDescriptionTxt__c',
        'DetailsTxt__c',
        'PriorityPk__c',
        'RequestTypePk__c',
        'WorkflowTypeTxt__c',
        'EstimatedHoursNumber__c',
        'DeveloperDaysSizeNumber__c',
        'Tags__c',
        'AcceptanceCriteriaTxt__c',
        'StepsToReproduceTxt__c',
        'Epic__c',
        'ClientIntentionPk__c',
        'Developer__c'
    };

    // Day-of-week name to Datetime dayOfWeek integer mapping (Sunday=1 .. Saturday=7)
    private static final Map<String, Integer> DAY_NAME_TO_NUMBER = new Map<String, Integer>{
        'Sunday' => 1, 'Monday' => 2, 'Tuesday' => 3, 'Wednesday' => 4,
        'Thursday' => 5, 'Friday' => 6, 'Saturday' => 7
    };

    /**
     * @description Called by the scheduler to process all recurring work items whose
     * NextRecurrenceDate__c is today or in the past. Creates clones and advances
     * the next recurrence date.
     */
    public static void processRecurringItems() {
        Date today = Date.today();

        List<WorkItem__c> recurringItems = queryRecurringItems(today);

        if (recurringItems.isEmpty()) {
            return;
        }

        List<WorkItem__c> newItems = new List<WorkItem__c>();
        List<WorkItem__c> updatedSources = new List<WorkItem__c>();
        List<ActivityLog__c> logs = new List<ActivityLog__c>();

        for (WorkItem__c source : recurringItems) {
            newItems.add(buildRecurringClone(source));
            updatedSources.add(buildUpdatedSource(source));
            logs.add(buildRecurringLog(source));
        }

        persistRecurringResults(newItems, updatedSources, logs);
    }

    /**
     * @description Clones a template work item with optional field overrides.
     * Called from the deliveryWorkItemTemplates LWC.
     * @param templateId The Id of the template WorkItem__c to clone.
     * @param overrides Map of field API names to values to override on the clone.
     * @return Id The Id of the newly created work item.
     */
    @AuraEnabled
    public static Id cloneFromTemplate(Id templateId, Map<String, Object> overrides) {
        if (templateId == null) {
            throw createAuraException('Template Id is required.');
        }

        WorkItem__c template = queryTemplate(templateId);
        WorkItem__c clone = buildTemplateClone(template, overrides);

        Database.insert(new List<WorkItem__c>{ clone }, AccessLevel.SYSTEM_MODE);

        logTemplateUsage(template.Id, clone.Id);

        return clone.Id;
    }

    /**
     * @description Retrieves all template work items grouped by workflow type for the template browser.
     * @return List of template WorkItem__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkItem__c> getTemplates() {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c,
                   Tags__c, WorkflowTypeTxt__c, RequestTypePk__c, EstimatedHoursNumber__c,
                   DeveloperDaysSizeNumber__c, Epic__c
            FROM WorkItem__c
            WHERE IsTemplateBool__c = true
            AND IsActiveBool__c = true
            WITH SYSTEM_MODE
            ORDER BY WorkflowTypeTxt__c ASC, BriefDescriptionTxt__c ASC
        ];
    }

    /**
     * @description Calculates the next recurrence date based on schedule type and day preference.
     * @param schedule The recurrence schedule: Weekly, Biweekly, Monthly, or Quarterly.
     * @param recurrenceDay The day of week (e.g. Monday) or day of month (e.g. 1, 15).
     * @param fromDate The date to calculate from (typically the current NextRecurrenceDate__c).
     * @return Date The next recurrence date.
     */
    @TestVisible
    static Date calculateNextDate(String schedule, String recurrenceDay, Date fromDate) {
        if (String.isBlank(schedule) || fromDate == null) {
            return null;
        }

        if (schedule == 'Weekly') {
            return calculateNextWeeklyDate(recurrenceDay, fromDate, 1);
        } else if (schedule == 'Biweekly') {
            return calculateNextWeeklyDate(recurrenceDay, fromDate, 2);
        } else if (schedule == 'Monthly') {
            return calculateNextMonthlyDate(recurrenceDay, fromDate, 1);
        } else if (schedule == 'Quarterly') {
            return calculateNextMonthlyDate(recurrenceDay, fromDate, 3);
        }

        return fromDate.addDays(7); // Fallback: 1 week
    }

    // -------------------------------------------------------------------------
    // Private helpers -- query
    // -------------------------------------------------------------------------

    private static List<WorkItem__c> queryRecurringItems(Date today) {
        String fieldList = String.escapeSingleQuotes(buildFieldList());

        String query = 'SELECT Id, OwnerId, ' + fieldList +
            ', IsRecurringBool__c, RecurrenceScheduleTxt__c, RecurrenceDayTxt__c, NextRecurrenceDate__c' +
            ' FROM WorkItem__c' +
            ' WHERE IsRecurringBool__c = true' +
            ' AND IsTemplateBool__c = false' +
            ' AND NextRecurrenceDate__c <= :today' +
            ' AND NextRecurrenceDate__c != null';

        return Database.query(query);
    }

    private static WorkItem__c queryTemplate(Id templateId) {
        String fieldList = String.escapeSingleQuotes(buildFieldList());

        String query = 'SELECT Id, OwnerId, ' + fieldList +
            ', IsTemplateBool__c, WorkflowTypeTxt__c' +
            ' FROM WorkItem__c WHERE Id = :templateId WITH SYSTEM_MODE LIMIT 1';

        List<WorkItem__c> templates = Database.query(query);
        if (templates.isEmpty()) {
            throw createAuraException('Template not found.');
        }
        return templates[0];
    }

    // -------------------------------------------------------------------------
    // Private helpers -- clone builders
    // -------------------------------------------------------------------------

    private static WorkItem__c buildRecurringClone(WorkItem__c source) {
        String firstStage = getFirstStageForWorkflow(source.WorkflowTypeTxt__c);

        WorkItem__c clone = new WorkItem__c();
        clone.IsActiveBool__c = true;
        clone.IsTemplateBool__c = false;
        clone.IsRecurringBool__c = false;
        clone.StageNamePk__c = firstStage;
        clone.TemplateSourceId__c = source.Id;
        clone.OwnerId = source.OwnerId;

        copyCloneFields(clone, source);
        return clone;
    }

    private static WorkItem__c buildTemplateClone(WorkItem__c template, Map<String, Object> overrides) {
        String workflowType = (overrides != null && overrides.containsKey('WorkflowTypeTxt__c'))
            ? (String) overrides.get('WorkflowTypeTxt__c')
            : template.WorkflowTypeTxt__c;
        String firstStage = getFirstStageForWorkflow(workflowType);

        WorkItem__c clone = new WorkItem__c();
        clone.IsActiveBool__c = true;
        clone.IsTemplateBool__c = false;
        clone.IsRecurringBool__c = false;
        clone.StageNamePk__c = firstStage;
        clone.TemplateSourceId__c = template.Id;
        clone.OwnerId = template.OwnerId;

        copyCloneFields(clone, template);
        applyOverrides(clone, overrides);
        return clone;
    }

    private static void copyCloneFields(WorkItem__c target, WorkItem__c source) {
        for (String field : CLONE_FIELDS) {
            target.put(field, source.get(field));
        }
    }

    private static void applyOverrides(WorkItem__c clone, Map<String, Object> overrides) {
        if (overrides == null) {
            return;
        }
        for (String field : overrides.keySet()) {
            clone.put(field, overrides.get(field));
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers -- source update & logging
    // -------------------------------------------------------------------------

    private static WorkItem__c buildUpdatedSource(WorkItem__c source) {
        Date nextDate = calculateNextDate(
            source.RecurrenceScheduleTxt__c,
            source.RecurrenceDayTxt__c,
            source.NextRecurrenceDate__c
        );
        return new WorkItem__c(
            Id = source.Id,
            NextRecurrenceDate__c = nextDate
        );
    }

    private static ActivityLog__c buildRecurringLog(WorkItem__c source) {
        return new ActivityLog__c(
            ActionTypePk__c = 'Feature_Use',
            ComponentNameTxt__c = 'DeliveryRecurringItemService',
            ContextDataTxt__c = '{"action":"recurring_clone","sourceId":"' + source.Id + '","schedule":"' + source.RecurrenceScheduleTxt__c + '"}'
        );
    }

    private static void logTemplateUsage(Id templateId, Id cloneId) {
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'Feature_Use',
            ComponentNameTxt__c = 'DeliveryRecurringItemService',
            ContextDataTxt__c = '{"action":"template_clone","templateId":"' + templateId + '","newId":"' + cloneId + '"}'
        );
        Database.insert(new List<ActivityLog__c>{ log }, AccessLevel.SYSTEM_MODE);
    }

    private static void persistRecurringResults(
        List<WorkItem__c> newItems,
        List<WorkItem__c> updatedSources,
        List<ActivityLog__c> logs
    ) {
        if (!newItems.isEmpty()) {
            Database.insert(newItems, AccessLevel.SYSTEM_MODE);
        }
        if (!updatedSources.isEmpty()) {
            Database.update(updatedSources, AccessLevel.SYSTEM_MODE);
        }
        if (!logs.isEmpty()) {
            Database.insert(logs, AccessLevel.SYSTEM_MODE);
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers -- date calculations
    // -------------------------------------------------------------------------

    private static Date calculateNextWeeklyDate(String dayName, Date fromDate, Integer weeksAhead) {
        if (String.isBlank(dayName) || !DAY_NAME_TO_NUMBER.containsKey(dayName)) {
            return fromDate.addDays(7 * weeksAhead);
        }

        Integer targetDayNum = DAY_NAME_TO_NUMBER.get(dayName);
        // Get the day-of-week for fromDate: use DateTime to get dayOfWeek
        DateTime fromDt = DateTime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0));
        // Salesforce: Sunday=1, Monday=2... Saturday=7
        // We need to map from Date. Using format('u') gives ISO day (1=Monday..7=Sunday)
        String isoDayStr = fromDt.format('u');
        Integer currentIsoDay = Integer.valueOf(isoDayStr);
        // Convert ISO (1=Mon..7=Sun) to SF (1=Sun..7=Sat)
        Integer currentSfDay = (currentIsoDay == 7) ? 1 : currentIsoDay + 1;

        Integer daysUntilTarget = targetDayNum - currentSfDay;
        if (daysUntilTarget <= 0) {
            daysUntilTarget += 7;
        }

        // For biweekly, add an extra week
        if (weeksAhead > 1) {
            daysUntilTarget += 7 * (weeksAhead - 1);
        }

        return fromDate.addDays(daysUntilTarget);
    }

    private static Date calculateNextMonthlyDate(String dayOfMonth, Date fromDate, Integer monthsAhead) {
        Integer dayNum = 1;
        if (String.isNotBlank(dayOfMonth)) {
            try {
                dayNum = Integer.valueOf(dayOfMonth.trim());
            } catch (Exception e) {
                dayNum = 1;
            }
        }
        if (dayNum < 1) { dayNum = 1; }
        if (dayNum > 28) { dayNum = 28; } // Safe max to avoid month-boundary issues

        Date nextMonth = fromDate.addMonths(monthsAhead);
        return Date.newInstance(nextMonth.year(), nextMonth.month(), dayNum);
    }

    private static String getFirstStageForWorkflow(String workflowType) {
        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }

        List<WorkflowStage__mdt> stages = [
            SELECT ApiValueTxt__c
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowType
            AND IsTerminalBool__c = false
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST
            LIMIT 1
        ];

        if (!stages.isEmpty()) {
            return stages[0].ApiValueTxt__c;
        }

        return 'Backlog'; // Fallback
    }

    private static String buildFieldList() {
        return String.join(CLONE_FIELDS, ', ');
    }

    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
