/**
 * @description Controller for the Delivery Hub Dashboard LWC.
 * Returns System Pulse metrics: Active Tickets, Hours, and Sync Health.
 */
public with sharing class DeliveryHubDashboardController {

    /**
     * @description Calculates active tickets, total hours, and sync health stats.
     * @return Map<String, Decimal> Metrics map.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getBudgetMetrics() {
        Map<String, Decimal> metrics = new Map<String, Decimal>();

        // 1. Ticket Metrics (Active Count & Hours)
        // We use Ticket__c as it is the main object for the Delivery Hub
        AggregateResult[] ticketStats = [
            SELECT Count(Id) total, Sum(LoggedHoursNum__c) hours 
            FROM Ticket__c 
            WHERE StageNamePk__c NOT IN ('Closed', 'Done')
        ];

        Decimal activeCount = (ticketStats[0].get('total') != null) ? (Decimal)ticketStats[0].get('total') : 0;
        Decimal totalHours = (ticketStats[0].get('hours') != null) ? (Decimal)ticketStats[0].get('hours') : 0;

        metrics.put('activeRequests', activeCount);
        metrics.put('totalHours', totalHours);

        // 2. Sync Health Metrics (Succeeded vs Failed)
        // Aggregate by Status to get counts efficiently
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
        
        // Remove legacy estimatedSpend (or set to 0 if UI still references it temporarily)
        metrics.put('estimatedSpend', 0);

        return metrics;
    }
}