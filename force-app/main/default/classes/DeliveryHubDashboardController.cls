/**
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics and client-facing dashboard data.
 */
public with sharing class DeliveryHubDashboardController {

    // --- Inner classes for getClientDashboard ---

    public class TicketItem {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String title;
        @AuraEnabled public String stage;
        @AuraEnabled public String lastModified;
    }

    public class PhaseItem {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
    }

    /**
     * @description Calculates active tickets, sync health, and last active timestamp.
     * @return Map<String, Object> Metrics map (Object type to support String dates).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBudgetMetrics() {
        Map<String, Object> metrics = new Map<String, Object>();

        // 1. Ticket Metrics (Active Count)
        AggregateResult[] ticketStats = [
            SELECT Count(Id) total
            FROM Ticket__c 
            WHERE StageNamePk__c NOT IN ('Closed', 'Done')
        ];

        Decimal activeCount = (ticketStats[0].get('total') != null) ? (Decimal)ticketStats[0].get('total') : 0;
        metrics.put('activeRequests', activeCount);
        AggregateResult[] worklogStats = [
            SELECT Sum(HoursLoggedNumber__c) total
            FROM WorkLog__c
        ];
        Decimal totalHours = (worklogStats[0].get('total') != null) ? (Decimal)worklogStats[0].get('total') : 0;
        metrics.put('totalHours', totalHours);

        // 2. Last Entry Logic (Find most recent activity on tickets)
        List<Ticket__c> lastActivity = [
            SELECT LastModifiedDate 
            FROM Ticket__c 
            WHERE StageNamePk__c != 'Closed' 
            ORDER BY LastModifiedDate DESC 
            LIMIT 1
        ];

        if (!lastActivity.isEmpty()) {
            // Format to EST (America/New_York)
            String formattedDate = lastActivity[0].LastModifiedDate.format('MM/dd h:mm a', UserInfo.getTimeZone().getId());
            metrics.put('lastEntry', formattedDate);
        } else {
            metrics.put('lastEntry', '--');
        }

        // 3. Sync Health Metrics
        // FIX: Alias 'StatusPk__c' to 'val' to prevent "Invalid field" errors in AggregateResult
        AggregateResult[] syncStats = [
            SELECT StatusPk__c val, Count(Id) cnt 
            FROM Sync_Item__c 
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
     * @description Returns client-facing dashboard data: attention items, phase counts, recent tickets.
     * @return Map containing attentionTickets, phases, and recentTickets lists.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getClientDashboard() {
        Map<String, Object> result = new Map<String, Object>();

        // --- 1. Tickets needing client attention ---
        Set<String> clientStages = new Set<String>{
            'Ready for Client Approval', 'In Client Approval',
            'Ready for Client UAT', 'In Client UAT',
            'Ready for UAT Sign-off'
        };

        List<Ticket__c> attentionRecs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c
            FROM Ticket__c
            WHERE StageNamePk__c IN :clientStages
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];

        List<TicketItem> attentionList = new List<TicketItem>();
        for (Ticket__c t : attentionRecs) {
            TicketItem item = new TicketItem();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            attentionList.add(item);
        }
        result.put('attentionTickets', attentionList);

        // --- 2. Phase counts ---
        Map<String, String> stageToPhase = new Map<String, String>();
        for (String s : new List<String>{'Backlog', 'Scoping In Progress', 'Clarification Requested (Pre-Dev)', 'Providing Clarification', 'Ready for Sizing', 'Sizing Underway', 'Ready for Prioritization', 'Prioritizing', 'Proposal Requested', 'Drafting Proposal'}) {
            stageToPhase.put(s, 'Planning');
        }
        for (String s : new List<String>{'Ready for Tech Review', 'Tech Reviewing', 'Ready for Client Approval', 'In Client Approval', 'Ready for Final Approval', 'Final Approving'}) {
            stageToPhase.put(s, 'Approval');
        }
        for (String s : new List<String>{'Ready for Development', 'In Development', 'Dev Clarification Requested', 'Providing Dev Clarification', 'Dev Blocked', 'Back For Development'}) {
            stageToPhase.put(s, 'Development');
        }
        for (String s : new List<String>{'Ready for Scratch Test', 'Scratch Testing', 'Ready for QA', 'QA In Progress', 'Ready for Internal UAT', 'Internal UAT'}) {
            stageToPhase.put(s, 'Testing');
        }
        for (String s : new List<String>{'Ready for Client UAT', 'In Client UAT', 'Ready for UAT Sign-off', 'Processing Sign-off'}) {
            stageToPhase.put(s, 'UAT');
        }
        for (String s : new List<String>{'Ready for Merge', 'Merging', 'Ready for Deployment', 'Deploying'}) {
            stageToPhase.put(s, 'Deployment');
        }

        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Approval' => 0, 'Development' => 0,
            'Testing' => 0, 'UAT' => 0, 'Deployment' => 0
        };

        AggregateResult[] stageCounts = [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM Ticket__c
            WHERE StageNamePk__c NOT IN ('Done', 'Cancelled', 'Deployed to Prod')
            WITH USER_MODE
            GROUP BY StageNamePk__c
        ];

        for (AggregateResult ar : stageCounts) {
            String stage = (String)ar.get('stage');
            Integer cnt = ((Decimal)ar.get('cnt')).intValue();
            String phase = stageToPhase.get(stage);
            if (phase != null) {
                phaseCounts.put(phase, phaseCounts.get(phase) + cnt);
            }
        }

        List<PhaseItem> phaseList = new List<PhaseItem>();
        for (String ph : new List<String>{'Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment'}) {
            PhaseItem pi = new PhaseItem();
            pi.label = ph;
            pi.count = phaseCounts.get(ph);
            phaseList.add(pi);
        }
        result.put('phases', phaseList);

        // --- 3. Recently updated tickets ---
        List<Ticket__c> recentRecs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, LastModifiedDate
            FROM Ticket__c
            WHERE StageNamePk__c NOT IN ('Done', 'Cancelled')
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ];

        List<TicketItem> recentList = new List<TicketItem>();
        for (Ticket__c t : recentRecs) {
            TicketItem item = new TicketItem();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            item.lastModified = t.LastModifiedDate.format('MM/dd h:mm a', UserInfo.getTimeZone().getId());
            recentList.add(item);
        }
        result.put('recentTickets', recentList);

        return result;
    }
}