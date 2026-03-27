/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides work item data for the Delivery Gantt Chart LWC.
 *              Supports both the legacy CSS-based chart (getWorkItemsForGantt)
 *              and the DHTMLX Gantt-powered chart (getGanttData) which includes
 *              hours, developer, client grouping, and date fallback logic.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryGanttController {

    /**
     * @description Data Transfer Object representing a single Gantt row (legacy).
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
     * @description Richer DTO for DHTMLX Gantt chart — includes hours, developer,
     *              client entity, and resolved start/end dates.
     */
    public class DhtmlxGanttTask {
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
        @AuraEnabled public Boolean isCompleted { get; set; }
    }

    /**
     * @description Returns active WorkItem__c records that have a ProjectedUATReadyDate__c,
     *              ordered by that date ascending. Legacy method for the CSS-based chart.
     * @return List of GanttRow ordered by UAT date.
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
     * @description Returns work items with full date/hour/developer/client data for
     *              the DHTMLX Gantt chart. Includes resolved start/end dates using
     *              the same fallback chain as DeliveryTimelineController.
     * @param showCompleted When true, includes completed (inactive) items.
     * @return List of DhtmlxGanttTask ordered by entity then start date.
     */
    @AuraEnabled(cacheable=true)
    public static List<DhtmlxGanttTask> getGanttData(Boolean showCompleted) {
        try {
            String query = 'SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
                + 'PriorityPk__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
                + 'ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate, '
                + 'EstimatedHoursNumber__c, TotalLoggedHoursNumber__c, '
                + 'IsActiveBool__c, '
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

            List<WorkItem__c> items = Database.query(query); // NOPMD — bind variable not used; dynamic for conditional WHERE clause
            List<DhtmlxGanttTask> tasks = new List<DhtmlxGanttTask>();
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
     * @description Maps a single WorkItem__c record to a DhtmlxGanttTask DTO.
     */
    private static DhtmlxGanttTask mapToGanttTask(WorkItem__c item) {
        DhtmlxGanttTask task = new DhtmlxGanttTask();
        task.workItemId = item.Id;
        task.name = item.Name;
        task.description = item.BriefDescriptionTxt__c;
        task.stage = item.StageNamePk__c;
        task.priority = item.PriorityPk__c;
        task.estimatedHours = item.EstimatedHoursNumber__c;
        task.loggedHours = item.TotalLoggedHoursNumber__c;
        task.isCompleted = item.IsActiveBool__c != true;

        // Progress = logged / estimated, capped at 1.0
        if (item.EstimatedHoursNumber__c != null && item.EstimatedHoursNumber__c > 0) {
            Decimal logged = item.TotalLoggedHoursNumber__c != null ? item.TotalLoggedHoursNumber__c : 0;
            task.progress = Math.min(logged / item.EstimatedHoursNumber__c, 1.0);
        } else {
            task.progress = 0;
        }

        // Developer name
        task.developerName = item.Developer__r != null ? item.Developer__r.Name : null;

        // Client entity
        task.entityName = item.ClientNetworkEntityId__r != null
            ? item.ClientNetworkEntityId__r.Name : 'Unassigned';
        task.entityId = item.ClientNetworkEntityId__c;

        // Start date: EstimatedStartDevDate > CreatedDate
        Date startDt = item.EstimatedStartDevDate__c != null
            ? item.EstimatedStartDevDate__c
            : item.CreatedDate.date();
        task.startDate = String.valueOf(startDt);

        // End date: EstimatedEndDevDate > ProjectedUATReadyDate > CalculatedETA > start+14
        Date endDt = resolveEndDate(item, startDt);
        if (endDt < startDt) {
            endDt = startDt.addDays(1);
        }
        task.endDate = String.valueOf(endDt);

        return task;
    }

    /**
     * @description Resolves the effective end date using fallback chain:
     *              EstimatedEndDevDate > ProjectedUATReadyDate > CalculatedETADate > start+14.
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
        return startDt.addDays(14);
    }
}
