/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides work item timeline data for the Delivery Gantt Chart LWC.
 *              Returns active work items that have a projected UAT date, allowing the
 *              component to render a CSS-based horizontal bar chart.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryGanttController {

    /**
     * @description Data Transfer Object representing a single Gantt row.
     */
    public class GanttRow {
        /** @description Salesforce record Id */
        @AuraEnabled public String workItemId { get; set; }
        /** @description Auto-number work item name (e.g. WI-0001) */
        @AuraEnabled public String name { get; set; }
        /** @description Brief one-line description of the work item */
        @AuraEnabled public String description { get; set; }
        /** @description Current stage of the work item */
        @AuraEnabled public String stage { get; set; }
        /** @description Priority label */
        @AuraEnabled public String priority { get; set; }
        /** @description Projected UAT-ready date (ISO string YYYY-MM-DD) */
        @AuraEnabled public String uatDate { get; set; }
        /** @description Calculated ETA date (ISO string YYYY-MM-DD), may be null */
        @AuraEnabled public String etaDate { get; set; }
        /** @description Record creation date (ISO string YYYY-MM-DD) */
        @AuraEnabled public String createdDate { get; set; }
    }

    /**
     * @description Returns active WorkItem__c records that have a ProjectedUATReadyDate__c,
     *              ordered by that date ascending. Used by deliveryGanttChart to draw bars.
     * @return List&lt;GanttRow&gt; Ordered list of work item timeline rows.
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
     * @description Data Transfer Object representing a dependency link between two Gantt items.
     */
    public class GanttDependency {
        /** @description Salesforce record Id of the dependency junction record */
        @AuraEnabled public String id { get; set; }
        /** @description Id of the blocking (source) work item */
        @AuraEnabled public String source { get; set; }
        /** @description Id of the blocked (target) work item */
        @AuraEnabled public String target { get; set; }
        /** @description Dependency type picklist value (e.g. Blocks) */
        @AuraEnabled public String dependencyType { get; set; }
    }

    /**
     * @description Returns active WorkItemDependency__c records where both the blocked and
     *              blocking work items are active. Used by deliveryGanttChart to draw
     *              dependency arrows between bars.
     * @return List&lt;GanttDependency&gt; Flat list of dependency links.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttDependency> getGanttDependencies() {
        try {
            List<WorkItemDependency__c> deps = [
                SELECT Id, BlockingWorkItemId__c, BlockedWorkItemId__c, TypePk__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__r.IsActiveBool__c = true
                AND BlockingWorkItemId__r.IsActiveBool__c = true
                WITH SYSTEM_MODE
                LIMIT 500
            ];

            List<GanttDependency> result = new List<GanttDependency>();
            for (WorkItemDependency__c d : deps) {
                GanttDependency dep = new GanttDependency();
                dep.id             = d.Id;
                dep.source         = d.BlockingWorkItemId__c;
                dep.target         = d.BlockedWorkItemId__c;
                dep.dependencyType = d.TypePk__c;
                result.add(dep);
            }
            return result;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Updates the sort order of a single work item, used for drag-and-drop
     *              reordering in the Gantt chart.
     * @param workItemId The Id of the WorkItem__c to update.
     * @param sortOrder  The new sort order value.
     */
    @AuraEnabled
    public static void updateWorkItemSortOrder(String workItemId, Decimal sortOrder) {
        try {
            WorkItem__c item = new WorkItem__c(
                Id = workItemId,
                SortOrderNumber__c = sortOrder
            );
            update item;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }
}
