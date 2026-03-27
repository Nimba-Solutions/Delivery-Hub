/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics and client-facing dashboard data.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryHubDashboardController {

    /** @description Wrapper for a work item summary row used in the client dashboard. */
    public class WorkItemSummary {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public String lastModified;
        @AuraEnabled public Integer attentionScore;
        @AuraEnabled public String urgency;
        @AuraEnabled public String priority;
        @AuraEnabled public Integer daysInStage;
        @AuraEnabled public Boolean isComment;
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
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBudgetMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();

        // 1. Work Item Metrics (Active Count) — use CMT terminal stages so no hardcoded 'Closed'
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        AggregateResult[] workItemStats = [
            SELECT Count(Id) total
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND TemplateMarkedDateTime__c = null

        ];

        Decimal activeCount = (workItemStats[0].get('total') != null) ? (Decimal)workItemStats[0].get('total') : 0;
        metrics.put('activeRequests', activeCount);
        Date firstOfMonth = Date.today().toStartOfMonth();
        Date firstOfLastMonth = firstOfMonth.addMonths(-1);

        AggregateResult[] mtdStats = [
            SELECT Sum(HoursLoggedNumber__c) total FROM WorkLog__c
            WHERE WorkDateDate__c >= :firstOfMonth

        ];
        metrics.put('hoursThisMonth', mtdStats[0].get('total') != null ? (Decimal)mtdStats[0].get('total') : 0);

        AggregateResult[] lastMonthStats = [
            SELECT Sum(HoursLoggedNumber__c) total FROM WorkLog__c
            WHERE WorkDateDate__c >= :firstOfLastMonth
            AND WorkDateDate__c < :firstOfMonth

        ];
        metrics.put('hoursLastMonth', lastMonthStats[0].get('total') != null ? (Decimal)lastMonthStats[0].get('total') : 0);

        // 2. Last Entry Logic (Find most recent activity on work items)
        List<WorkItem__c> lastActivity = [
            SELECT LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
            AND TemplateMarkedDateTime__c = null
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
        ];
    }

    /**
     * @description Returns client-facing dashboard data: attention items, phase counts,
     *              recent work items, vendor announcements, and this-week metrics.
     * @param timeRange The time range filter — 'thisWeek', 'lastWeek', or 'thisMonth'. Defaults to 'thisWeek'.
     * @param workflowType The workflow configuration key (e.g. 'Software_Delivery'). Defaults to 'Software_Delivery'.
     * @return Map containing attentionWorkItems, phases, recentWorkItems, announcements, and thisWeek keys.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getClientDashboard(String timeRange, String workflowType) {
        if (String.isBlank(timeRange)) {
            timeRange = 'thisWeek';
        }
        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }
        Map<String, Object> result = new Map<String, Object>();
        result.put('attentionWorkItems', fetchAttentionWorkItems(workflowType));
        result.put('phases', fetchPhaseList(workflowType));
        result.put('recentWorkItems', fetchRecentWorkItems());
        result.put('announcements', fetchVendorAnnouncements());
        result.put('thisWeek', fetchTimeRangeMetrics(timeRange, workflowType));
        return result;
    }

    // -------------------------------------------------------------------------
    // Private helpers — keep getClientDashboard complexity at 1
    // -------------------------------------------------------------------------

    private static List<WorkItemSummary> fetchAttentionWorkItems(String workflowType) {
        Set<String> clientStages = DeliveryWorkflowConfigService.getAttentionStageValues(workflowType);

        List<WorkItem__c> recs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   PriorityPk__c, LastModifiedDate, CalculatedETADate__c, Developer__c
            FROM WorkItem__c
            WHERE StageNamePk__c IN :clientStages
            LIMIT 50
        ];

        List<WorkItemSummary> items = new List<WorkItemSummary>();
        for (WorkItem__c t : recs) {
            WorkItemSummary item = new WorkItemSummary();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            item.priority = t.PriorityPk__c;
            item.daysInStage = Date.today().daysBetween(Date.today()) >= 0
                ? (Integer) t.LastModifiedDate.date().daysBetween(Date.today())
                : 0;
            item.attentionScore = calculateAttentionScore(t, item.daysInStage);
            item.urgency = scoreToUrgency(item.attentionScore);
            items.add(item);
        }

        // Sort by attention score descending (highest urgency first)
        items.sort(new AttentionScoreComparator());
        // Return top 20 after scoring
        if (items.size() > 20) {
            List<WorkItemSummary> top = new List<WorkItemSummary>();
            for (Integer i = 0; i < 20; i++) {
                top.add(items[i]);
            }
            return top;
        }
        return items;
    }

    /**
     * @description Computes an attention score for a work item based on multiple risk factors.
     * Higher score = needs more immediate attention.
     * @param t The work item record
     * @param daysInStage Number of days since last modification
     * @return Integer attention score (0-100+)
     */
    private static Integer calculateAttentionScore(WorkItem__c t, Integer daysInStage) {
        Integer score = 0;

        // Factor 1: Time in stage (2 points per day, max 30)
        score += Math.min(daysInStage * 2, 30);

        // Factor 2: Priority weight
        String priority = t.PriorityPk__c;
        if (priority == 'Critical') {
            score += 20;
        } else if (priority == 'High') {
            score += 12;
        } else if (priority == 'Medium') {
            score += 6;
        } else {
            score += 2;
        }

        // Factor 3: No developer assigned (needs staffing)
        if (t.Developer__c == null) {
            score += 8;
        }

        // Factor 4: Overdue ETA
        if (t.CalculatedETADate__c != null && t.CalculatedETADate__c < Date.today()) {
            score += 15;
        }

        return score;
    }

    /**
     * @description Maps a numeric attention score to an urgency label.
     * @param score The attention score
     * @return String urgency level: 'critical', 'high', 'medium', or 'low'
     */
    private static String scoreToUrgency(Integer score) {
        if (score >= 40) {
            return 'critical';
        } else if (score >= 25) {
            return 'high';
        } else if (score >= 15) {
            return 'medium';
        }
        return 'low';
    }

    /**
     * @description Comparator to sort WorkItemSummary by attentionScore descending.
     */
    private class AttentionScoreComparator implements Comparator<WorkItemSummary> {
        /**
         * @description Compares two WorkItemSummary objects by attentionScore descending.
         * @param a First summary
         * @param b Second summary
         * @return Integer negative if a > b, positive if a < b
         */
        public Integer compare(WorkItemSummary a, WorkItemSummary b) {
            return b.attentionScore - a.attentionScore;
        }
    }

    private static List<PhaseItem> fetchPhaseList(String workflowType) {
        Map<String, String> stageToPhase = DeliveryWorkflowConfigService.getStagePhaseMap(workflowType);
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);
        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Approval' => 0, 'Development' => 0,
            'Testing' => 0, 'UAT' => 0, 'Deployment' => 0
        };

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM WorkItem__c
            WHERE StageNamePk__c NOT IN :terminalStages
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
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ];

        // Use a parallel list of raw Datetime values for accurate sorting
        List<WorkItemSummary> items = new List<WorkItemSummary>();
        List<Datetime> sortDates = new List<Datetime>();

        for (WorkItem__c t : recs) {
            WorkItemSummary item = new WorkItemSummary();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            item.isComment = false;
            items.add(item);
            sortDates.add(t.LastModifiedDate);
        }

        // Merge recent comments into the list
        List<WorkItemComment__c> recentComments = [
            SELECT Id, WorkItemId__c, WorkItemId__r.Name, WorkItemId__r.BriefDescriptionTxt__c,
                   WorkItemId__r.StageNamePk__c, AuthorTxt__c, BodyTxt__c, CreatedDate
            FROM WorkItemComment__c
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];

        for (WorkItemComment__c c : recentComments) {
            WorkItemSummary item = new WorkItemSummary();
            item.id = c.WorkItemId__c;
            item.name = c.WorkItemId__r.Name;
            String body = c.BodyTxt__c != null ? c.BodyTxt__c : '';
            item.title = (body.length() > 80 ? body.substring(0, 80) : body)
                + ' \u2014 ' + (c.AuthorTxt__c != null ? c.AuthorTxt__c : '');
            item.stage = c.WorkItemId__r.StageNamePk__c;
            item.isComment = true;
            items.add(item);
            sortDates.add(c.CreatedDate);
        }

        // Sort by raw datetime descending using index-based selection sort
        Integer size = items.size();
        for (Integer i = 0; i < size - 1; i++) {
            Integer maxIdx = i;
            for (Integer j = i + 1; j < size; j++) {
                if (sortDates[j] > sortDates[maxIdx]) {
                    maxIdx = j;
                }
            }
            if (maxIdx != i) {
                // Swap items
                WorkItemSummary tmpItem = items[i];
                items[i] = items[maxIdx];
                items[maxIdx] = tmpItem;
                // Swap dates
                Datetime tmpDate = sortDates[i];
                sortDates[i] = sortDates[maxIdx];
                sortDates[maxIdx] = tmpDate;
            }
        }

        // Cap at 7 items and format the display date
        Integer cap = Math.min(size, 7);
        List<WorkItemSummary> result = new List<WorkItemSummary>();
        String tz = UserInfo.getTimeZone().getId();
        for (Integer i = 0; i < cap; i++) {
            items[i].lastModified = sortDates[i].format('MM/dd h:mm a', tz);
            result.add(items[i]);
        }
        return result;
    }

    private static List<String> fetchVendorAnnouncements() {
        List<NetworkEntity__c> vendors = [
            SELECT VendorAnnouncementTxt__c, Name
            FROM NetworkEntity__c
            WHERE EntityTypePk__c = 'Vendor'
            AND StatusPk__c = 'Active'
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

    private static Map<String, Object> fetchTimeRangeMetrics(String timeRange, String workflowType) {
        Map<String, Object> metrics = new Map<String, Object>();

        // Determine date range based on timeRange parameter
        Date startDate;
        Date endDate; // null means "today" (open-ended)
        if (timeRange == 'lastWeek') {
            startDate = Date.today().toStartOfWeek().addDays(-7);
            endDate = Date.today().toStartOfWeek();
        } else if (timeRange == 'thisMonth') {
            startDate = Date.today().toStartOfMonth();
            endDate = null;
        } else {
            // Default: 'thisWeek'
            startDate = Date.today().toStartOfWeek();
            endDate = null;
        }

        Datetime startDt = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDt = endDate != null ? Datetime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)) : null;

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);

        // Items completed in range
        Integer completed;
        if (endDt != null) {
            completed = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND LastModifiedDate >= :startDt
                AND LastModifiedDate < :endDt
            ];
        } else {
            completed = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND LastModifiedDate >= :startDt
            ];
        }
        metrics.put('completed', completed);

        // Items modified (stage changed) in range
        Integer moved;
        if (endDt != null) {
            moved = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE LastModifiedDate >= :startDt
                AND LastModifiedDate < :endDt
                AND StageNamePk__c NOT IN :terminalStages
            ];
        } else {
            moved = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE LastModifiedDate >= :startDt
                AND StageNamePk__c NOT IN :terminalStages
            ];
        }
        metrics.put('moved', moved);

        // Hours logged in range
        AggregateResult[] hoursAgg;
        if (endDate != null) {
            hoursAgg = [
                SELECT SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkDateDate__c >= :startDate
                AND WorkDateDate__c < :endDate
            ];
        } else {
            hoursAgg = [
                SELECT SUM(HoursLoggedNumber__c) total
                FROM WorkLog__c
                WHERE WorkDateDate__c >= :startDate
            ];
        }
        Decimal hours = hoursAgg[0].get('total') != null ? (Decimal)hoursAgg[0].get('total') : 0;
        metrics.put('hoursLogged', hours);

        // Currently blocked items (not time-bounded — always current state)
        Set<Id> blockedIds = new Set<Id>();
        for (WorkItemDependency__c dep : [
            SELECT BlockedWorkItemId__c
            FROM WorkItemDependency__c
            WHERE BlockingWorkItemId__c IN (
                SELECT Id FROM WorkItem__c WHERE StageNamePk__c NOT IN :terminalStages
            )
        ]) {
            blockedIds.add(dep.BlockedWorkItemId__c);
        }
        metrics.put('blocked', blockedIds.size());

        return metrics;
    }

    /**
     * @description Looks up report IDs by DeveloperName for dashboard drill-through.
     * @param developerNames List of report DeveloperNames to look up.
     * @return Map of DeveloperName to Report Id (only found reports included).
     */
    @AuraEnabled
    public static Map<String, String> getReportIds(List<String> developerNames) {
        Map<String, String> result = new Map<String, String>();
        for (Report r : [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :developerNames
            WITH SYSTEM_MODE
        ]) {
            result.put(r.DeveloperName, r.Id);
        }
        return result;
    }

    /**
     * @description Checks if the current user has the DeliveryHubAdmin permission set group.
     * @return True if the user is a Delivery Hub admin.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isAdminUser() {
        return ![
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSetGroup.DeveloperName = 'DeliveryHubAdmin'
            WITH SYSTEM_MODE
            LIMIT 1
        ].isEmpty();
    }

}

// trigger rebuild
