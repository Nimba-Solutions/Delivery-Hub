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
public with sharing class DeliveryGanttController {

    /**
     * @description Legacy DTO for the CSS-based Gantt chart.
     */
    public class GanttRow {
        @AuraEnabled public String workItemId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String stage { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String uatDate { get; set; }
        @AuraEnabled public String etaDate { get; set; }
        @AuraEnabled public String createdDate { get; set; }
    }

    /**
     * @description Rich DTO for Frappe Gantt — includes hours, developer,
     *              client entity, progress, and resolved start/end dates.
     */
    public class GanttTask {
        @AuraEnabled public String workItemId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String stage { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public Decimal estimatedHours { get; set; }
        @AuraEnabled public Decimal loggedHours { get; set; }
        @AuraEnabled public Decimal progress { get; set; }
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public String entityId { get; set; }
        @AuraEnabled public String entityName { get; set; }
        @AuraEnabled public String parentWorkItemId { get; set; }
        @AuraEnabled public Boolean isCompleted { get; set; }
    }

    /**
     * @description Legacy: returns active work items with a ProjectedUATReadyDate__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttRow> getWorkItemsForGantt() {
        try {
            List<WorkItem__c> items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate
                FROM WorkItem__c
                WHERE IsActiveBool__c = true
                AND IsTemplateBool__c = false
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

    /**
     * @description Returns work items with full date/hour/developer/client data
     *              for the Frappe Gantt chart. Resolves start/end dates using a
     *              fallback chain and calculates progress from logged vs estimated hours.
     * @param showCompleted When true, includes completed (inactive) items.
     * @return List of GanttTask ordered by entity then start date.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttTask> getGanttData(Boolean showCompleted) {
        try {
            String query = 'SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
                + 'PriorityPk__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
                + 'ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate, '
                + 'EstimatedHoursNumber__c, TotalLoggedHoursNumber__c, '
                + 'IsActiveBool__c, ParentWorkItemId__c, '
                + 'Developer__r.Name, '
                + 'ClientNetworkEntityId__c, ClientNetworkEntityId__r.Name '
                + 'FROM WorkItem__c '
                + 'WHERE IsTemplateBool__c = false ';

            if (showCompleted != true) {
                query += 'AND IsActiveBool__c = true ';
            }

            query += 'WITH SYSTEM_MODE '
                + 'ORDER BY ClientNetworkEntityId__r.Name ASC NULLS LAST, '
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
            update item;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description DTO for dependency arrow data.
     */
    public class GanttDependency {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String source { get; set; }
        @AuraEnabled public String target { get; set; }
        @AuraEnabled public String dependencyType { get; set; }
    }

    /**
     * @description Returns all active work item dependencies for Gantt arrow rendering.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttDependency> getGanttDependencies() {
        try {
            List<GanttDependency> deps = new List<GanttDependency>();
            for (WorkItemDependency__c d : [
                SELECT Id, BlockedWorkItemId__c, BlockingWorkItemId__c, TypePk__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__r.IsActiveBool__c = true
                  AND BlockingWorkItemId__r.IsActiveBool__c = true
                WITH SYSTEM_MODE
                LIMIT 500
            ]) {
                GanttDependency dep = new GanttDependency();
                dep.id = d.Id;
                dep.source = d.BlockingWorkItemId__c;
                dep.target = d.BlockedWorkItemId__c;
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
     * @description Saves updated sort order after vertical drag reorder.
     */
    @AuraEnabled
    public static void updateWorkItemSortOrder(String workItemId, Decimal sortOrder) {
        try {
            WorkItem__c item = new WorkItem__c(Id = workItemId, SortOrderNumber__c = sortOrder);
            update item;
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
        task.loggedHours = item.TotalLoggedHoursNumber__c;
        task.isCompleted = item.IsActiveBool__c != true;
        task.parentWorkItemId = item.ParentWorkItemId__c;

        if (item.EstimatedHoursNumber__c != null && item.EstimatedHoursNumber__c > 0) {
            Decimal logged = item.TotalLoggedHoursNumber__c != null ? item.TotalLoggedHoursNumber__c : 0;
            task.progress = Math.min(logged / item.EstimatedHoursNumber__c, 1.0);
        } else {
            task.progress = 0;
        }

        task.developerName = item.Developer__r != null ? item.Developer__r.Name : null;

        task.entityName = item.ClientNetworkEntityId__r != null
            ? item.ClientNetworkEntityId__r.Name : null;
        task.entityId = item.ClientNetworkEntityId__c;

        Date startDt = item.EstimatedStartDevDate__c != null
            ? item.EstimatedStartDevDate__c
            : item.CreatedDate.date();
        task.startDate = String.valueOf(startDt);

        Date endDt = resolveEndDate(item, startDt);
        if (endDt < startDt) {
            endDt = startDt.addDays(1);
        }
        task.endDate = String.valueOf(endDt);

        return task;
    }

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
        return startDt.addDays(14);
    }
}
