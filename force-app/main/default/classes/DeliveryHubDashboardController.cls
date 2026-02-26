/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics and client-facing dashboard data.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryHubDashboardController {

    /** @description Wrapper for a work item summary row used in the client dashboard. */
    public class WorkItemSummary {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public String lastModified;
    }

    /** @description Wrapper for a phase bucket count used in the client dashboard. */
    public class PhaseItem {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    /**
     * @description Calculates active work items, sync health, and last active timestamp.
     * @return Map<String, Object> Metrics map (Object type to support String dates).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBudgetMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();

        // 1. Work Item Metrics (Active Count) — use CMT terminal stages so no hardcoded 'Closed'
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        AggregateResult[] workItemStats = [
            SELECT Count(Id) total
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
        ];

        Decimal activeCount = (workItemStats[0].get('total') != null) ? (Decimal)workItemStats[0].get('total') : 0;
        metrics.put('activeRequests', activeCount);
        Date firstOfMonth = Date.today().toStartOfMonth();
        Date firstOfLastMonth = firstOfMonth.addMonths(-1);

        AggregateResult[] mtdStats = [
            SELECT Sum(HoursLoggedNumber__c) total FROM WorkLog__c
            WHERE WorkDateDate__c >= :firstOfMonth WITH SYSTEM_MODE
        ];
        metrics.put('hoursThisMonth', mtdStats[0].get('total') != null ? (Decimal)mtdStats[0].get('total') : 0);

        AggregateResult[] lastMonthStats = [
            SELECT Sum(HoursLoggedNumber__c) total FROM WorkLog__c
            WHERE WorkDateDate__c >= :firstOfLastMonth
            AND WorkDateDate__c < :firstOfMonth WITH SYSTEM_MODE
        ];
        metrics.put('hoursLastMonth', lastMonthStats[0].get('total') != null ? (Decimal)lastMonthStats[0].get('total') : 0);

        // 2. Last Entry Logic (Find most recent activity on work items)
        List<WorkItem__c> lastActivity = [
            SELECT LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (!lastActivity.isEmpty()) {
            String formattedDate = lastActivity[0].LastModifiedDate.format('MM/dd h:mm a', UserInfo.getTimeZone().getId());
            metrics.put('lastEntry', formattedDate);
        } else {
            metrics.put('lastEntry', '--');
        }

        // 3. Sync Health Metrics
        // FIX: Alias 'StatusPk__c' to 'val' to prevent "Invalid field" errors in AggregateResult
        AggregateResult[] syncStats = [
            SELECT StatusPk__c val, Count(Id) cnt
            FROM SyncItem__c
            WHERE StatusPk__c IN ('Synced', 'Failed')
            GROUP BY StatusPk__c
        ];

        Decimal success = 0;
        Decimal failed = 0;

        for (AggregateResult ar : syncStats) {
            // Use the alias 'val'
            String status = (String)ar.get('val');
            Decimal count = (Decimal)ar.get('cnt');

            if (status == 'Synced') {
                success = count;
            } else if (status == 'Failed') {
                failed = count;
            }
        }

        metrics.put('succeededSyncs', success);
        metrics.put('failedSyncs', failed);
        metrics.put('estimatedSpend', 0);

        return metrics;
    }

    /**
     * @description Returns client-facing dashboard data: attention items, phase counts, recent work items.
     * @return Map containing attentionWorkItems, phases, and recentWorkItems lists.
     */
    /**
     * @description Returns the count of work items currently waiting on client action.
     * @return Integer count of attention-requiring work items.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getAttentionCount() {
        Set<String> clientStages = DeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');
        return [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c IN :clientStages
            WITH SYSTEM_MODE
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getClientDashboard() {
        Map<String, Object> result = new Map<String, Object>();
        result.put('attentionWorkItems', fetchAttentionWorkItems());
        result.put('phases', fetchPhaseList());
        result.put('recentWorkItems', fetchRecentWorkItems());
        result.put('announcements', fetchVendorAnnouncements());
        result.put('thisWeek', fetchThisWeekMetrics());
        return result;
    }

    // -------------------------------------------------------------------------
    // Private helpers — keep getClientDashboard complexity at 1
    // -------------------------------------------------------------------------

    private static List<WorkItemSummary> fetchAttentionWorkItems() {
        Set<String> clientStages = DeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');

        List<WorkItem__c> recs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c
            FROM WorkItem__c
            WHERE StageNamePk__c IN :clientStages
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];

        List<WorkItemSummary> items = new List<WorkItemSummary>();
        for (WorkItem__c t : recs) {
            WorkItemSummary item = new WorkItemSummary();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            items.add(item);
        }
        return items;
    }

    private static List<PhaseItem> fetchPhaseList() {
        Map<String, String> stageToPhase = DeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');
        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Approval' => 0, 'Development' => 0,
            'Testing' => 0, 'UAT' => 0, 'Deployment' => 0
        };

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN ('Done', 'Cancelled', 'Deployed to Prod')
            WITH SYSTEM_MODE
            GROUP BY StageNamePk__c
        ]) {
            String phase = stageToPhase.get((String)ar.get('stage'));
            if (phase != null) {
                phaseCounts.put(phase, phaseCounts.get(phase) + ((Decimal)ar.get('cnt')).intValue());
            }
        }

        List<PhaseItem> phaseList = new List<PhaseItem>();
        for (String ph : new List<String>{'Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment'}) {
            PhaseItem pi = new PhaseItem();
            pi.label = ph;
            pi.count = phaseCounts.get(ph);
            phaseList.add(pi);
        }
        return phaseList;
    }

    private static List<WorkItemSummary> fetchRecentWorkItems() {
        List<WorkItem__c> recs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN ('Done', 'Cancelled')
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ];

        List<WorkItemSummary> items = new List<WorkItemSummary>();
        for (WorkItem__c t : recs) {
            WorkItemSummary item = new WorkItemSummary();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            item.lastModified = t.LastModifiedDate.format('MM/dd h:mm a', UserInfo.getTimeZone().getId());
            items.add(item);
        }
        return items;
    }

    private static List<String> fetchVendorAnnouncements() {
        List<NetworkEntity__c> vendors = [
            SELECT VendorAnnouncementTxt__c, Name
            FROM NetworkEntity__c
            WHERE EntityTypePk__c = 'Vendor'
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ];
        List<String> texts = new List<String>();
        for (NetworkEntity__c v : vendors) {
            if (String.isNotBlank(v.VendorAnnouncementTxt__c)) {
                texts.add(v.VendorAnnouncementTxt__c);
            }
        }
        return texts;
    }

    private static Map<String, Object> fetchThisWeekMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();
        Date weekStart = Date.today().toStartOfWeek();
        Datetime weekStartDt = Datetime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');

        // Items completed this week
        Integer completed = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE StageNamePk__c IN :terminalStages
            AND LastModifiedDate >= :weekStartDt
            WITH SYSTEM_MODE
        ];
        metrics.put('completed', completed);

        // Items modified (stage changed) this week
        Integer moved = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE LastModifiedDate >= :weekStartDt
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ];
        metrics.put('moved', moved);

        // Hours logged this week
        AggregateResult[] hoursAgg = [
            SELECT SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkDateDate__c >= :weekStart
            WITH SYSTEM_MODE
        ];
        Decimal hours = hoursAgg[0].get('total') != null ? (Decimal)hoursAgg[0].get('total') : 0;
        metrics.put('hoursLogged', hours);

        // Currently blocked items
        Set<Id> blockedIds = new Set<Id>();
        for (WorkItemDependency__c dep : [
            SELECT BlockedWorkItemId__c
            FROM WorkItemDependency__c
            WHERE BlockingWorkItemId__c IN (
                SELECT Id FROM WorkItem__c WHERE StageNamePk__c NOT IN :terminalStages
            )
            WITH SYSTEM_MODE
        ]) {
            blockedIds.add(dep.BlockedWorkItemId__c);
        }
        metrics.put('blocked', blockedIds.size());

        return metrics;
    }

}

