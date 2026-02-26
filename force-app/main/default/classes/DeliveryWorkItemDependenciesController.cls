/**
 * @description Controller for the deliveryWorkItemDependencies LWC.
 *              Returns blocking and blocked-by ticket relationships for a given ticket.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryWorkItemDependenciesController {

    /** @description Summary of a related ticket shown in the dependency view. */
    public class DependencyRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public String type;
    }

    /**
     * @description Returns tickets that this ticket is blocking, and tickets blocking this ticket.
     * @param ticketId The WorkItem__c record Id.
     * @return Map with 'blocking' and 'blockedBy' lists of DependencyRow.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDependencies(Id ticketId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('blocking',   fetchBlocking(ticketId));
        result.put('blockedBy',  fetchBlockedBy(ticketId));
        return result;
    }

    private static List<DependencyRow> fetchBlocking(Id ticketId) {
        List<DependencyRow> rows = new List<DependencyRow>();
        for (WorkItemDependency__c td : [
            SELECT Blocked_Ticket__r.Id, Blocked_Ticket__r.Name,
                   Blocked_Ticket__r.BriefDescriptionTxt__c, Blocked_Ticket__r.StageNamePk__c,
                   TypePk__c
            FROM WorkItemDependency__c
            WHERE Blocking_WorkItem__c = :ticketId
            WITH SYSTEM_MODE
            ORDER BY Blocked_Ticket__r.Name ASC
            LIMIT 20
        ]) {
            DependencyRow row = new DependencyRow();
            row.id    = td.Blocked_Ticket__r.Id;
            row.name  = td.Blocked_Ticket__r.Name;
            row.title = td.Blocked_Ticket__r.BriefDescriptionTxt__c;
            row.stage = td.Blocked_Ticket__r.StageNamePk__c;
            row.type  = td.TypePk__c;
            rows.add(row);
        }
        return rows;
    }

    private static List<DependencyRow> fetchBlockedBy(Id ticketId) {
        List<DependencyRow> rows = new List<DependencyRow>();
        for (WorkItemDependency__c td : [
            SELECT Blocking_Ticket__r.Id, Blocking_Ticket__r.Name,
                   Blocking_Ticket__r.BriefDescriptionTxt__c, Blocking_Ticket__r.StageNamePk__c,
                   TypePk__c
            FROM WorkItemDependency__c
            WHERE Blocked_WorkItem__c = :ticketId
            WITH SYSTEM_MODE
            ORDER BY Blocking_Ticket__r.Name ASC
            LIMIT 20
        ]) {
            DependencyRow row = new DependencyRow();
            row.id    = td.Blocking_Ticket__r.Id;
            row.name  = td.Blocking_Ticket__r.Name;
            row.title = td.Blocking_Ticket__r.BriefDescriptionTxt__c;
            row.stage = td.Blocking_Ticket__r.StageNamePk__c;
            row.type  = td.TypePk__c;
            rows.add(row);
        }
        return rows;
    }
}
