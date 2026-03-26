/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Provides work item timeline data for the Delivery Timeline View LWC.
 *               Returns active work items grouped by NetworkEntity, including date ranges
 *               and stage info so the component can render a CSS-based horizontal Gantt chart.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryTimelineController {

    /**
     * @description Data Transfer Object representing a single timeline bar row.
     */
    public class TimelineRow {
        @AuraEnabled public String workItemId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String stage { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
        @AuraEnabled public String entityName { get; set; }
        @AuraEnabled public String entityId { get; set; }
        @AuraEnabled public String workflowType { get; set; }
        @AuraEnabled public Boolean hasExplicitDates { get; set; }
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public Decimal estimatedHours { get; set; }
        @AuraEnabled public Decimal loggedHours { get; set; }
        @AuraEnabled public Decimal progress { get; set; }
    }

    /**
     * @description Returns active work items with date ranges for timeline rendering.
     *              Items are grouped by NetworkEntity. Start date falls back from
     *              EstimatedStartDevDate to CreatedDate. End date falls back from
     *              EstimatedEndDevDate to ProjectedUATReadyDate to CalculatedETADate.
     * @param workflowTypeName Optional workflow type filter; defaults to all types.
     * @return List of TimelineRow ordered by entity name then start date.
     */
    @AuraEnabled(cacheable=true)
    public static List<TimelineRow> getTimelineData(String workflowTypeName) {
        try {
            String query = 'SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
                + 'PriorityPk__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
                + 'ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate, '
                + 'WorkflowTypeTxt__c, '
                + 'EstimatedHoursNumber__c, TotalLoggedHoursNumber__c, '
                + 'Developer__r.Name, '
                + 'ClientNetworkEntityId__c, ClientNetworkEntityId__r.Name '
                + 'FROM WorkItem__c '
                + 'WHERE IsActiveBool__c = true '
                + 'AND IsTemplateBool__c = false ';

            if (String.isNotBlank(workflowTypeName)) {
                query += 'AND WorkflowTypeTxt__c = :workflowTypeName ';
            }

            query += 'WITH SYSTEM_MODE '
                + 'ORDER BY ClientNetworkEntityId__r.Name ASC NULLS LAST, '
                + 'EstimatedStartDevDate__c ASC NULLS LAST, CreatedDate ASC';

            List<WorkItem__c> items = Database.query(query); // NOPMD — bind variable (:workflowTypeName) is safe
            List<TimelineRow> rows = new List<TimelineRow>();
            for (WorkItem__c item : items) {
                rows.add(mapWorkItemToRow(item));
            }
            return rows;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Maps a single WorkItem__c record to a TimelineRow DTO,
     *              resolving start/end date fallbacks.
     * @param item The WorkItem__c record to convert.
     * @return A populated TimelineRow instance.
     */
    private static TimelineRow mapWorkItemToRow(WorkItem__c item) {
        TimelineRow row = new TimelineRow();
        row.workItemId = item.Id;
        row.name = item.Name;
        row.description = item.BriefDescriptionTxt__c;
        row.stage = item.StageNamePk__c;
        row.priority = item.PriorityPk__c;
        row.workflowType = item.WorkflowTypeTxt__c;

        row.entityName = item.ClientNetworkEntityId__r != null
            ? item.ClientNetworkEntityId__r.Name : 'Unassigned';
        row.entityId = item.ClientNetworkEntityId__c;

        // Developer + hours
        row.developerName = item.Developer__r != null ? item.Developer__r.Name : null;
        row.estimatedHours = item.EstimatedHoursNumber__c;
        row.loggedHours = item.TotalLoggedHoursNumber__c;
        if (item.EstimatedHoursNumber__c != null && item.EstimatedHoursNumber__c > 0) {
            Decimal logged = item.TotalLoggedHoursNumber__c != null ? item.TotalLoggedHoursNumber__c : 0;
            row.progress = Math.min(logged / item.EstimatedHoursNumber__c, 1.0);
        } else {
            row.progress = 0;
        }

        // Determine if the item has at least one explicitly set date
        Boolean hasStart = item.EstimatedStartDevDate__c != null;
        Boolean hasEnd = item.EstimatedEndDevDate__c != null
            || item.ProjectedUATReadyDate__c != null
            || item.CalculatedETADate__c != null;
        row.hasExplicitDates = hasStart || hasEnd;

        // Start date: EstimatedStartDevDate > CreatedDate
        Date startDt = hasStart
            ? item.EstimatedStartDevDate__c
            : item.CreatedDate.date();
        row.startDate = String.valueOf(startDt);

        // End date: EstimatedEndDevDate > ProjectedUATReadyDate > CalculatedETA > start+14
        Date endDt = resolveEndDate(item, startDt);
        if (endDt < startDt) {
            endDt = startDt.addDays(1);
        }
        row.endDate = String.valueOf(endDt);

        return row;
    }

    /**
     * @description Resolves the effective end date for a work item using fallback chain:
     *              EstimatedEndDevDate > ProjectedUATReadyDate > CalculatedETADate > start+14.
     * @param item The WorkItem__c record.
     * @param startDt The resolved start date (used for the +14 day fallback).
     * @return The resolved end date.
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
