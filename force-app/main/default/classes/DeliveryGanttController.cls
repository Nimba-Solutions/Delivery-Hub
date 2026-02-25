/**
 * @description Provides ticket timeline data for the Delivery Gantt Chart LWC.
 *              Returns active tickets that have a projected UAT date, allowing the
 *              component to render a CSS-based horizontal bar chart.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryGanttController {

    /**
     * @description Data Transfer Object representing a single Gantt row.
     */
    public class GanttRow {
        /** @description Salesforce record Id */
        @AuraEnabled public String ticketId { get; set; }
        /** @description Auto-number ticket name (e.g. TKT-0001) */
        @AuraEnabled public String name { get; set; }
        /** @description Brief one-line description of the ticket */
        @AuraEnabled public String description { get; set; }
        /** @description Current stage of the ticket */
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
     * @description Returns active Ticket__c records that have a ProjectedUATReadyDate__c,
     *              ordered by that date ascending. Used by deliveryGanttChart to draw bars.
     * @return List&lt;GanttRow&gt; Ordered list of ticket timeline rows.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttRow> getTicketsForGantt() {
        List<Ticket__c> tickets = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate
            FROM Ticket__c
            WHERE IsActiveBool__c = true
            AND ProjectedUATReadyDate__c != null
            WITH SYSTEM_MODE
            ORDER BY ProjectedUATReadyDate__c ASC
        ];

        List<GanttRow> rows = new List<GanttRow>();
        for (Ticket__c t : tickets) {
            GanttRow row  = new GanttRow();
            row.ticketId  = t.Id;
            row.name      = t.Name;
            row.description = t.BriefDescriptionTxt__c;
            row.stage     = t.StageNamePk__c;
            row.priority  = t.PriorityPk__c;
            row.uatDate   = String.valueOf(t.ProjectedUATReadyDate__c);
            row.etaDate   = t.CalculatedETADate__c != null ? String.valueOf(t.CalculatedETADate__c) : null;
            row.createdDate = String.valueOf(t.CreatedDate.date());
            rows.add(row);
        }
        return rows;
    }
}
