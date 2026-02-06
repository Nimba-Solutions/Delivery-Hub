/**
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics: Active Tickets and Sync Health.
 */
public with sharing class DeliveryHubDashboardController {

    /**
     * @description Calculates active tickets and sync health stats.
     * @return Map<String, Decimal> Metrics map.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getBudgetMetrics() {
        Map<String, Decimal> metrics = new Map<String, Decimal>();

        // 1. Ticket Metrics (Active Count Only)
        // Removed LoggedHoursNum__c to fix deployment error
        AggregateResult[] ticketStats = [
            SELECT Count(Id) total
            FROM Ticket__c 
            WHERE StageNamePk__c NOT IN ('Closed', 'Done')
        ];

        Decimal activeCount = (ticketStats[0].get('total') != null) ? (Decimal)ticketStats[0].get('total') : 0;
        
        metrics.put('activeRequests', activeCount);
        metrics.put('totalHours', 0); // Placeholder until field exists

        // 2. Sync Health Metrics (Succeeded vs Failed)
        AggregateResult[] syncStats = [
            SELECT StatusPk__c, Count(Id) cnt 
            FROM Sync_Item__c 
            WHERE StatusPk__c IN ('Synced', 'Failed')
            GROUP BY StatusPk__c
        ];

        Decimal success = 0;
        Decimal failed = 0;

        for (AggregateResult ar : syncStats) {
            String status = (String)ar.get('StatusPk__c');
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