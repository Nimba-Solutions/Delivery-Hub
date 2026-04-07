/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliveryWorkItemDependencies LWC.
 *              Returns blocking and blocked-by work item relationships for a given work item.
 * @author Cloud Nimbus LLC
 */
global with sharing class DeliveryWorkItemDependenciesController {

    /** @description Summary of a related work item shown in the dependency view. */
    global class DependencyRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public String type;
    }

    /**
     * @description Returns work items that this work item is blocking, and work items blocking this work item.
     * @param workItemId The WorkItem__c record Id.
     * @return Map with 'blocking' and 'blockedBy' lists of DependencyRow.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getDependencies(Id workItemId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('blocking',   fetchBlocking(workItemId));
        result.put('blockedBy',  fetchBlockedBy(workItemId));
        return result;
    }

    private static List<DependencyRow> fetchBlocking(Id workItemId) {
        List<DependencyRow> rows = new List<DependencyRow>();
        for (WorkItemDependency__c td : [
            SELECT BlockedWorkItemLookup__r.Id, BlockedWorkItemLookup__r.Name,
                   BlockedWorkItemLookup__r.BriefDescriptionTxt__c, BlockedWorkItemLookup__r.StageNamePk__c,
                   TypePk__c
            FROM WorkItemDependency__c
            WHERE BlockingWorkItemLookup__c = :workItemId
            WITH SYSTEM_MODE
            ORDER BY BlockedWorkItemLookup__r.Name ASC
            LIMIT 20
        ]) {
            DependencyRow row = new DependencyRow();
            row.id    = td.BlockedWorkItemLookup__r.Id;
            row.name  = td.BlockedWorkItemLookup__r.Name;
            row.title = td.BlockedWorkItemLookup__r.BriefDescriptionTxt__c;
            row.stage = td.BlockedWorkItemLookup__r.StageNamePk__c;
            row.type  = td.TypePk__c;
            rows.add(row);
        }
        return rows;
    }

    private static List<DependencyRow> fetchBlockedBy(Id workItemId) {
        List<DependencyRow> rows = new List<DependencyRow>();
        for (WorkItemDependency__c td : [
            SELECT BlockingWorkItemLookup__r.Id, BlockingWorkItemLookup__r.Name,
                   BlockingWorkItemLookup__r.BriefDescriptionTxt__c, BlockingWorkItemLookup__r.StageNamePk__c,
                   TypePk__c
            FROM WorkItemDependency__c
            WHERE BlockedWorkItemLookup__c = :workItemId
            WITH SYSTEM_MODE
            ORDER BY BlockingWorkItemLookup__r.Name ASC
            LIMIT 20
        ]) {
            DependencyRow row = new DependencyRow();
            row.id    = td.BlockingWorkItemLookup__r.Id;
            row.name  = td.BlockingWorkItemLookup__r.Name;
            row.title = td.BlockingWorkItemLookup__r.BriefDescriptionTxt__c;
            row.stage = td.BlockingWorkItemLookup__r.StageNamePk__c;
            row.type  = td.TypePk__c;
            rows.add(row);
        }
        return rows;
    }
}
