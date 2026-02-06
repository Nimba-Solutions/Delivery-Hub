/**
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics: Active Tickets, Hours, Sync Health, and Last Entry.
 */
public with sharing class DeliveryHubDashboardController {

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
        metrics.put('totalHours', 0); // Placeholder until field exists

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
            String formattedDate = lastActivity[0].LastModifiedDate.format('MM/dd h:mm a', 'America/New_York');
            metrics.put('lastEntry', formattedDate + ' EST');
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
}