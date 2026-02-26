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
            SELECT BlockedWorkItemId__r.Id, BlockedWorkItemId__r.Name,
                   BlockedWorkItemId__r.BriefDescriptionTxt__c, BlockedWorkItemId__r.StageNamePk__c,
                   TypePk__c
            FROM WorkItemDependency__c
            WHERE BlockingWorkItemId__c = :ticketId
            WITH SYSTEM_MODE
            ORDER BY BlockedWorkItemId__r.Name ASC
            LIMIT 20
        ]) {
            DependencyRow row = new DependencyRow();
            row.id    = td.BlockedWorkItemId__r.Id;
            row.name  = td.BlockedWorkItemId__r.Name;
            row.title = td.BlockedWorkItemId__r.BriefDescriptionTxt__c;
            row.stage = td.BlockedWorkItemId__r.StageNamePk__c;
            row.type  = td.TypePk__c;
            rows.add(row);
        }
        return rows;
    }

    private static List<DependencyRow> fetchBlockedBy(Id ticketId) {
        List<DependencyRow> rows = new List<DependencyRow>();
        for (WorkItemDependency__c td : [
            SELECT BlockingWorkItemId__r.Id, BlockingWorkItemId__r.Name,
                   BlockingWorkItemId__r.BriefDescriptionTxt__c, BlockingWorkItemId__r.StageNamePk__c,
                   TypePk__c
            FROM WorkItemDependency__c
            WHERE BlockedWorkItemId__c = :ticketId
            WITH SYSTEM_MODE
            ORDER BY BlockingWorkItemId__r.Name ASC
            LIMIT 20
        ]) {
            DependencyRow row = new DependencyRow();
            row.id    = td.BlockingWorkItemId__r.Id;
            row.name  = td.BlockingWorkItemId__r.Name;
            row.title = td.BlockingWorkItemId__r.BriefDescriptionTxt__c;
            row.stage = td.BlockingWorkItemId__r.StageNamePk__c;
            row.type  = td.TypePk__c;
            rows.add(row);
        }
        return rows;
    }
}
