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

    // Pre-built CSV of clone fields for dynamic SOQL
    private static final String CLONE_FIELDS_CSV = String.join(CLONE_FIELDS, ', ');

    // Day-of-week name to Salesforce dayOfWeek integer (Sunday=1 .. Saturday=7)
    private static final Map<String, Integer> DAY_NAME_TO_NUMBER = new Map<String, Integer>{
        'Sunday' => 1, 'Monday' => 2, 'Tuesday' => 3, 'Wednesday' => 4,
        'Thursday' => 5, 'Friday' => 6, 'Saturday' => 7
    };

    // Schedule type to weeks-ahead mapping for weekly-based schedules
    private static final Map<String, Integer> WEEKLY_SCHEDULES = new Map<String, Integer>{
        'Weekly' => 1, 'Biweekly' => 2
    };

    // Schedule type to months-ahead mapping for month-based schedules
    private static final Map<String, Integer> MONTHLY_SCHEDULES = new Map<String, Integer>{
        'Monthly' => 1, 'Quarterly' => 3
    };

    private static final String DEFAULT_WORKFLOW = 'Software_Delivery';
    private static final String DEFAULT_STAGE = 'Backlog';

    /**
     * @description Called by the scheduler to process all recurring work items whose
     * NextRecurrenceDate__c is today or in the past. Creates clones and advances
     * the next recurrence date.
     */
    public static void processRecurringItems() {
        List<WorkItem__c> recurringItems = queryRecurringItems(Date.today());

        List<WorkItem__c> newItems = new List<WorkItem__c>();
        List<WorkItem__c> updatedSources = new List<WorkItem__c>();
        List<ActivityLog__c> logs = new List<ActivityLog__c>();

        for (WorkItem__c source : recurringItems) {
            WorkItem__c clone = initClone(source.WorkflowTypeTxt__c, source.Id, source.OwnerId);
            copyCloneFields(clone, source);
            newItems.add(clone);

            updatedSources.add(new WorkItem__c(
                Id = source.Id,
                NextRecurrenceDate__c = calculateNextDate(
                    source.RecurrenceScheduleTxt__c,
                    source.RecurrenceDayTxt__c,
                    source.NextRecurrenceDate__c
                )
            ));

            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'Feature_Use',
                ComponentNameTxt__c = 'DeliveryRecurringItemService',
                ContextDataTxt__c = '{"action":"recurring_clone","sourceId":"' + source.Id + '","schedule":"' + source.RecurrenceScheduleTxt__c + '"}'
            ));
        }

        Database.insert(newItems, AccessLevel.SYSTEM_MODE);
        Database.update(updatedSources, AccessLevel.SYSTEM_MODE);
        Database.insert(logs, AccessLevel.SYSTEM_MODE);
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
            AuraHandledException ex = new AuraHandledException('Template Id is required.');
            ex.setMessage('Template Id is required.');
            throw ex;
        }

        WorkItem__c template = queryTemplate(templateId);
        WorkItem__c clone = buildTemplateClone(template, overrides);

        Database.insert(new List<WorkItem__c>{ clone }, AccessLevel.SYSTEM_MODE);

        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'Feature_Use',
            ComponentNameTxt__c = 'DeliveryRecurringItemService',
            ContextDataTxt__c = '{"action":"template_clone","templateId":"' + template.Id + '","newId":"' + clone.Id + '"}'
        );
        Database.insert(new List<ActivityLog__c>{ log }, AccessLevel.SYSTEM_MODE);

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

        Integer weeksAhead = WEEKLY_SCHEDULES.get(schedule);
        if (weeksAhead != null) {
            return calculateNextWeeklyDate(recurrenceDay, fromDate, weeksAhead);
        }

        Integer monthsAhead = MONTHLY_SCHEDULES.get(schedule);
        if (monthsAhead != null) {
            Integer dayNum = parseDayOfMonth(recurrenceDay);
            Date nextMonth = fromDate.addMonths(monthsAhead);
            return Date.newInstance(nextMonth.year(), nextMonth.month(), dayNum);
        }

        return fromDate.addDays(7); // Fallback: 1 week
    }

    // -------------------------------------------------------------------------
    // Private helpers -- query
    // -------------------------------------------------------------------------

    private static List<WorkItem__c> queryRecurringItems(Date today) {
        String fieldList = String.escapeSingleQuotes(CLONE_FIELDS_CSV);

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
        String fieldList = String.escapeSingleQuotes(CLONE_FIELDS_CSV);

        String query = 'SELECT Id, OwnerId, ' + fieldList +
            ', IsTemplateBool__c' +
            ' FROM WorkItem__c WHERE Id = :templateId WITH SYSTEM_MODE LIMIT 1';

        List<WorkItem__c> templates = Database.query(query);
        if (templates.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('Template not found.');
            ex.setMessage('Template not found.');
            throw ex;
        }
        return templates[0];
    }

    // -------------------------------------------------------------------------
    // Private helpers -- clone builders
    // -------------------------------------------------------------------------

    private static WorkItem__c buildTemplateClone(WorkItem__c template, Map<String, Object> overrides) {
        Map<String, Object> safeOverrides = overrides != null ? overrides : new Map<String, Object>();
        String workflowType = safeOverrides.containsKey('WorkflowTypeTxt__c')
            ? (String) safeOverrides.get('WorkflowTypeTxt__c')
            : template.WorkflowTypeTxt__c;
        WorkItem__c clone = initClone(workflowType, template.Id, template.OwnerId);
        copyCloneFields(clone, template);
        for (String field : safeOverrides.keySet()) {
            clone.put(field, safeOverrides.get(field));
        }
        return clone;
    }

    private static WorkItem__c initClone(String workflowType, Id sourceId, Id ownerId) {
        WorkItem__c clone = new WorkItem__c();
        clone.IsActiveBool__c = true;
        clone.IsTemplateBool__c = false;
        clone.IsRecurringBool__c = false;
        clone.StageNamePk__c = getFirstStageForWorkflow(workflowType);
        clone.TemplateSourceId__c = sourceId;
        clone.OwnerId = ownerId;
        return clone;
    }

    private static void copyCloneFields(WorkItem__c target, WorkItem__c source) {
        for (String field : CLONE_FIELDS) {
            target.put(field, source.get(field));
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers -- date calculations
    // -------------------------------------------------------------------------

    private static Date calculateNextWeeklyDate(String dayName, Date fromDate, Integer weeksAhead) {
        Integer targetDayNum = DAY_NAME_TO_NUMBER.get(dayName);
        if (targetDayNum == null) {
            return fromDate.addDays(7 * weeksAhead);
        }

        Integer currentSfDay = getSalesforceDayOfWeek(fromDate);
        Integer daysUntilTarget = targetDayNum - currentSfDay;
        if (daysUntilTarget <= 0) {
            daysUntilTarget += 7;
        }
        daysUntilTarget += 7 * (weeksAhead - 1);

        return fromDate.addDays(daysUntilTarget);
    }

    private static Integer getSalesforceDayOfWeek(Date d) {
        DateTime dt = DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        Integer isoDay = Integer.valueOf(dt.format('u'));
        // ISO: Monday=1..Sunday=7 -> SF: Sunday=1..Saturday=7
        return Math.mod(isoDay, 7) + 1;
    }

    private static Integer parseDayOfMonth(String dayOfMonth) {
        Integer dayNum = 1;
        if (String.isNotBlank(dayOfMonth) && dayOfMonth.trim().isNumeric()) {
            dayNum = Integer.valueOf(dayOfMonth.trim());
        }
        return Math.max(1, Math.min(dayNum, 28));
    }

    private static String getFirstStageForWorkflow(String workflowType) {
        String resolvedType = String.isBlank(workflowType) ? DEFAULT_WORKFLOW : workflowType;

        List<WorkflowStage__mdt> stages = [
            SELECT ApiValueTxt__c
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :resolvedType
            AND IsTerminalBool__c = false
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST
            LIMIT 1
        ];

        return stages.isEmpty() ? DEFAULT_STAGE : stages[0].ApiValueTxt__c;
    }
}
