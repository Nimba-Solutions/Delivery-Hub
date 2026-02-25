/**
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics and client-facing dashboard data.
 */
public with sharing class DeliveryHubDashboardController {

    /** @description Wrapper for a ticket summary row used in the client dashboard. */
    public class TicketItem {
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
        result.put('attentionTickets', fetchAttentionTickets());
        result.put('phases', fetchPhaseList());
        result.put('recentTickets', fetchRecentTickets());
        result.put('announcements', fetchVendorAnnouncements());
        return result;
    }

    // -------------------------------------------------------------------------
    // Private helpers — keep getClientDashboard complexity at 1
    // -------------------------------------------------------------------------

    private static List<TicketItem> fetchAttentionTickets() {
        Set<String> clientStages = new Set<String>{
            'Ready for Client Approval', 'In Client Approval',
            'Ready for Client UAT', 'In Client UAT',
            'Ready for UAT Sign-off'
        };

        List<Ticket__c> recs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c
            FROM Ticket__c
            WHERE StageNamePk__c IN :clientStages
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ];

        List<TicketItem> items = new List<TicketItem>();
        for (Ticket__c t : recs) {
            TicketItem item = new TicketItem();
            item.id = t.Id;
            item.name = t.Name;
            item.title = t.BriefDescriptionTxt__c;
            item.stage = t.StageNamePk__c;
            items.add(item);
        }
        return items;
    }

    private static List<PhaseItem> fetchPhaseList() {
        Map<String, String> stageToPhase = buildStagePhaseMap();
        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Approval' => 0, 'Development' => 0,
            'Testing' => 0, 'UAT' => 0, 'Deployment' => 0
        };

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM Ticket__c
            WHERE StageNamePk__c NOT IN ('Done', 'Cancelled', 'Deployed to Prod')
            WITH USER_MODE
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

    private static List<TicketItem> fetchRecentTickets() {
        List<Ticket__c> recs = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, LastModifiedDate
            FROM Ticket__c
            WHERE StageNamePk__c NOT IN ('Done', 'Cancelled')
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ];

        List<TicketItem> items = new List<TicketItem>();
        for (Ticket__c t : recs) {
            TicketItem item = new TicketItem();
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
        List<Network_Entity__c> vendors = [
            SELECT VendorAnnouncementTxt__c, Name
            FROM Network_Entity__c
            WHERE EntityTypePk__c = 'Vendor'
            AND StatusPk__c = 'Active'
            AND VendorAnnouncementTxt__c != null
            WITH USER_MODE
            ORDER BY Name ASC
        ];
        List<String> texts = new List<String>();
        for (Network_Entity__c v : vendors) {
            texts.add(v.VendorAnnouncementTxt__c);
        }
        return texts;
    }

    private static Map<String, String> buildStagePhaseMap() {
        return new Map<String, String>{
            'Backlog' => 'Planning',
            'Scoping In Progress' => 'Planning',
            'Clarification Requested (Pre-Dev)' => 'Planning',
            'Providing Clarification' => 'Planning',
            'Ready for Sizing' => 'Planning',
            'Sizing Underway' => 'Planning',
            'Ready for Prioritization' => 'Planning',
            'Prioritizing' => 'Planning',
            'Proposal Requested' => 'Planning',
            'Drafting Proposal' => 'Planning',
            'Ready for Tech Review' => 'Approval',
            'Tech Reviewing' => 'Approval',
            'Ready for Client Approval' => 'Approval',
            'In Client Approval' => 'Approval',
            'Ready for Final Approval' => 'Approval',
            'Final Approving' => 'Approval',
            'Ready for Development' => 'Development',
            'In Development' => 'Development',
            'Dev Clarification Requested' => 'Development',
            'Providing Dev Clarification' => 'Development',
            'Dev Blocked' => 'Development',
            'Back For Development' => 'Development',
            'Ready for Scratch Test' => 'Testing',
            'Scratch Testing' => 'Testing',
            'Ready for QA' => 'Testing',
            'QA In Progress' => 'Testing',
            'Ready for Internal UAT' => 'Testing',
            'Internal UAT' => 'Testing',
            'Ready for Client UAT' => 'UAT',
            'In Client UAT' => 'UAT',
            'Ready for UAT Sign-off' => 'UAT',
            'Processing Sign-off' => 'UAT',
            'Ready for Merge' => 'Deployment',
            'Merging' => 'Deployment',
            'Ready for Deployment' => 'Deployment',
            'Deploying' => 'Deployment'
        };
    }
}
