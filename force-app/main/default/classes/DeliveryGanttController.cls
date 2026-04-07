/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides work item data for timeline/Gantt chart LWCs.
 *              getWorkItemsForGantt: legacy CSS chart (UAT-date-only items).
 *              getGanttData: rich data for Frappe Gantt (hours, developer,
 *              client grouping, resolved start/end dates, progress).
 *              updateWorkItemDates: saves date changes from drag-to-reschedule.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryGanttController {

    /**
     * @description Legacy DTO for the CSS-based Gantt chart.
     */
    public class GanttRow {
        /** @description Salesforce record Id */
        @AuraEnabled public String workItemId { get; set; }
        /** @description Auto-number work item name */
        @AuraEnabled public String name { get; set; }
        /** @description Brief description of the work item */
        @AuraEnabled public String description { get; set; }
        /** @description Current workflow stage */
        @AuraEnabled public String stage { get; set; }
        /** @description Priority level (High, Medium, Low) */
        @AuraEnabled public String priority { get; set; }
        /** @description Projected UAT-ready date as ISO string */
        @AuraEnabled public String uatDate { get; set; }
        /** @description Calculated ETA date as ISO string */
        @AuraEnabled public String etaDate { get; set; }
        /** @description Record created date as ISO string */
        @AuraEnabled public String createdDate { get; set; }
    }

    /**
     * @description Rich DTO for Frappe Gantt — includes hours, developer,
     *              client entity, progress, and resolved start/end dates.
     */
    public class GanttTask {
        /** @description Salesforce record Id */
        @AuraEnabled public String workItemId { get; set; }
        /** @description Auto-number work item name */
        @AuraEnabled public String name { get; set; }
        /** @description Brief description of the work item */
        @AuraEnabled public String description { get; set; }
        /** @description Current workflow stage */
        @AuraEnabled public String stage { get; set; }
        /** @description Priority level (High, Medium, Low) */
        @AuraEnabled public String priority { get; set; }
        /** @description Resolved start date as ISO string */
        @AuraEnabled public String startDate { get; set; }
        /** @description Resolved end date as ISO string */
        @AuraEnabled public String endDate { get; set; }
        /** @description Estimated hours for this work item */
        @AuraEnabled public Decimal estimatedHours { get; set; }
        /** @description Total logged hours against this work item */
        @AuraEnabled public Decimal loggedHours { get; set; }
        /** @description Progress ratio (0-1) based on logged vs estimated hours, or null when no estimate exists */
        @AuraEnabled public Decimal progress { get; set; }
        /** @description Name of the assigned developer */
        @AuraEnabled public String developerName { get; set; }
        /** @description Client entity record Id */
        @AuraEnabled public String entityId { get; set; }
        /** @description Client entity name for grouping */
        @AuraEnabled public String entityName { get; set; }
        /** @description Parent work item Id for hierarchy */
        @AuraEnabled public String parentWorkItemId { get; set; }
        /** @description True when the work item is no longer in the active workflow (ActivatedDateTime is null) */
        @AuraEnabled public Boolean isInactive { get; set; }
        /** @description True when endDate was synthesized (no real EstimatedEnd / UAT / ETA date existed) */
        @AuraEnabled public Boolean hasFallbackEndDate { get; set; }
    }

    /**
     * @description Legacy: returns active work items with a ProjectedUATReadyDate__c.
     * @return List of GanttRow ordered by UAT date.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttRow> getWorkItemsForGantt() {
        try {
            List<WorkItem__c> items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate
                FROM WorkItem__c
                WHERE ActivatedDateTime__c != null
                AND TemplateMarkedDateTime__c = null
                AND ProjectedUATReadyDate__c != null
                WITH SYSTEM_MODE
                ORDER BY ProjectedUATReadyDate__c ASC
            ];

            List<GanttRow> rows = new List<GanttRow>();
            for (WorkItem__c t : items) {
                GanttRow row     = new GanttRow();
                row.workItemId   = t.Id;
                row.name         = t.Name;
                row.description = t.BriefDescriptionTxt__c;
                row.stage     = t.StageNamePk__c;
                row.priority  = t.PriorityPk__c;
                row.uatDate   = String.valueOf(t.ProjectedUATReadyDate__c);
                row.etaDate   = t.CalculatedETADate__c != null ? String.valueOf(t.CalculatedETADate__c) : null;
                row.createdDate = String.valueOf(t.CreatedDate.date());
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /** @description Default freshness window (days) when including completed items. */
    @TestVisible private static final Integer DEFAULT_STALE_CUTOFF_DAYS = 90;

    /**
     * @description Returns work items with full date/hour/developer/client data
     *              for the Frappe Gantt chart. Resolves start/end dates using a
     *              fallback chain and calculates progress from logged vs estimated hours.
     *              When showCompleted is true, completed items are still bounded by
     *              LastModifiedDate >= LAST_N_DAYS:90 so the timeline does not get
     *              flooded with archived work.
     * @param showCompleted When true, includes inactive (completed/archived) items.
     * @return List of GanttTask ordered by entity then start date.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttTask> getGanttData(Boolean showCompleted) {
        try {
            String query = 'SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
                + 'PriorityPk__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
                + 'ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate, '
                + 'EstimatedHoursNumber__c, TotalLoggedHoursSum__c, '
                + 'ActivatedDateTime__c, ParentWorkItemLookup__c, '
                + 'DeveloperLookup__r.Name, '
                + 'ClientNetworkEntityLookup__c, ClientNetworkEntityLookup__r.Name '
                + 'FROM WorkItem__c '
                + 'WHERE TemplateMarkedDateTime__c = null ';

            if (showCompleted == true) {
                // Active items always show; inactive items must be recently modified.
                query += 'AND (ActivatedDateTime__c != null '
                    + 'OR LastModifiedDate >= LAST_N_DAYS:' + DEFAULT_STALE_CUTOFF_DAYS + ') ';
            } else {
                query += 'AND ActivatedDateTime__c != null ';
            }

            query += 'WITH SYSTEM_MODE '
                + 'ORDER BY ClientNetworkEntityLookup__r.Name ASC NULLS LAST, '
                + 'EstimatedStartDevDate__c ASC NULLS LAST, CreatedDate ASC';

            List<WorkItem__c> items = Database.query(query); // NOPMD — dynamic for conditional WHERE
            List<GanttTask> tasks = new List<GanttTask>();
            for (WorkItem__c item : items) {
                tasks.add(mapToGanttTask(item));
            }
            return tasks;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Saves updated start/end dates after a drag-to-reschedule
     *              action in the Gantt chart.
     * @param workItemId The Salesforce record Id.
     * @param startDate  New start date (ISO YYYY-MM-DD).
     * @param endDate    New end date (ISO YYYY-MM-DD).
     */
    @AuraEnabled
    public static void updateWorkItemDates(String workItemId, String startDate, String endDate) {
        try {
            WorkItem__c item = new WorkItem__c(Id = workItemId);
            if (String.isNotBlank(startDate)) {
                item.EstimatedStartDevDate__c = Date.valueOf(startDate);
            }
            if (String.isNotBlank(endDate)) {
                item.EstimatedEndDevDate__c = Date.valueOf(endDate);
            }
            update item; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    private static GanttTask mapToGanttTask(WorkItem__c item) {
        GanttTask task = new GanttTask();
        task.workItemId = item.Id;
        task.name = item.Name;
        task.description = item.BriefDescriptionTxt__c;
        task.stage = item.StageNamePk__c;
        task.priority = item.PriorityPk__c;
        task.estimatedHours = item.EstimatedHoursNumber__c;
        task.loggedHours = item.TotalLoggedHoursSum__c;
        task.isInactive = item.ActivatedDateTime__c == null;
        task.parentWorkItemId = item.ParentWorkItemLookup__c;

        // Progress is null (not 0) when no estimate exists, so the LWC can render
        // "no estimate" differently from "0% complete".
        if (item.EstimatedHoursNumber__c != null && item.EstimatedHoursNumber__c > 0) {
            Decimal logged = item.TotalLoggedHoursSum__c != null ? item.TotalLoggedHoursSum__c : 0;
            task.progress = Math.min(logged / item.EstimatedHoursNumber__c, 1.0);
        } else {
            task.progress = null;
        }

        task.developerName = item.DeveloperLookup__r != null ? item.DeveloperLookup__r.Name : null;

        task.entityName = item.ClientNetworkEntityLookup__r != null
            ? item.ClientNetworkEntityLookup__r.Name : null;
        task.entityId = item.ClientNetworkEntityLookup__c;

        Date startDt = item.EstimatedStartDevDate__c != null
            ? item.EstimatedStartDevDate__c
            : item.CreatedDate.date();
        task.startDate = String.valueOf(startDt);

        Boolean hasRealEndDate = item.EstimatedEndDevDate__c != null
            || item.ProjectedUATReadyDate__c != null
            || item.CalculatedETADate__c != null;
        task.hasFallbackEndDate = !hasRealEndDate;

        Date endDt = resolveEndDate(item, startDt);
        if (endDt < startDt) {
            endDt = startDt.addDays(1);
        }
        task.endDate = String.valueOf(endDt);

        return task;
    }

    /**
     * @description DTO representing a dependency between two work items on the Gantt chart.
     */
    public class GanttDependency {
        /** @description Dependency record Id */
        @AuraEnabled public String id { get; set; }
        /** @description Blocking (predecessor) work item Id */
        @AuraEnabled public String source { get; set; }
        /** @description Blocked (successor) work item Id */
        @AuraEnabled public String target { get; set; }
        /** @description Type of dependency relationship */
        @AuraEnabled public String dependencyType { get; set; }
    }

    /**
     * @description Returns work item dependencies for rendering arrows on the
     *              Gantt chart. When showCompleted is true, dependencies that
     *              touch inactive items are also returned so the dependency
     *              graph stays consistent with the visible task set.
     * @param showCompleted Mirrors the same flag on getGanttData.
     * @return List of GanttDependency for the relevant blocked/blocking pairs.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttDependency> getGanttDependencies(Boolean showCompleted) {
        try {
            List<WorkItemDependency__c> rows;
            if (showCompleted == true) {
                rows = [
                    SELECT Id, BlockedWorkItemLookup__c, BlockingWorkItemLookup__c, TypePk__c
                    FROM WorkItemDependency__c
                    WITH SYSTEM_MODE
                    LIMIT 500
                ];
            } else {
                rows = [
                    SELECT Id, BlockedWorkItemLookup__c, BlockingWorkItemLookup__c, TypePk__c
                    FROM WorkItemDependency__c
                    WHERE BlockedWorkItemLookup__r.ActivatedDateTime__c != null
                      AND BlockingWorkItemLookup__r.ActivatedDateTime__c != null
                    WITH SYSTEM_MODE
                    LIMIT 500
                ];
            }
            List<GanttDependency> deps = new List<GanttDependency>();
            for (WorkItemDependency__c d : rows) {
                GanttDependency dep = new GanttDependency();
                dep.id = d.Id;
                dep.source = d.BlockingWorkItemLookup__c;
                dep.target = d.BlockedWorkItemLookup__c;
                dep.dependencyType = d.TypePk__c;
                deps.add(dep);
            }
            return deps;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Updates the sort order of a work item after a drag-to-reorder
     *              action in the Gantt chart.
     * @param workItemId The Salesforce record Id.
     * @param sortOrder  New sort position value.
     */
    @AuraEnabled
    public static void updateWorkItemSortOrder(String workItemId, Decimal sortOrder) {
        try {
            WorkItem__c item = new WorkItem__c(Id = workItemId, SortOrderNumber__c = sortOrder);
            update item; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Resolves an end date from the first non-null real date
     *              field. When all are null, falls back to a 14-day bar
     *              anchored to the LATER of (startDt, today) so stale items
     *              don't render as floating bars in the past.
     */
    private static Date resolveEndDate(WorkItem__c item, Date startDt) {
        if (item.EstimatedEndDevDate__c != null) {
            return item.EstimatedEndDevDate__c;
        }
        if (item.ProjectedUATReadyDate__c != null) {
            return item.ProjectedUATReadyDate__c;
        }
        if (item.CalculatedETADate__c != null) {
            return item.CalculatedETADate__c;
        }
        Date today = Date.today();
        Date anchor = startDt > today ? startDt : today;
        return anchor.addDays(14);
    }
}
