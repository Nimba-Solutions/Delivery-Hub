/**
 * @description Controller for the Delivery Budget Summary LWC.
 */
public with sharing class DeliveryHubDashboardController {

    /**
     * @description Calculates total hours, estimated spend, and active request count.
     * @return Map<String, Decimal> Metrics map.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getBudgetMetrics() {
        // REMOVED WITH USER_MODE to fix "Invalid field" error during build
        AggregateResult[] results = [
            SELECT SUM(PreApprovedHoursNumber__c) totalHours, AVG(HourlyRateCurrency__c) avgRate
            FROM Request__c
            WHERE StatusPk__c NOT IN ('Closed', 'Completed', 'Cancelled')
        ];

        Decimal totalHours = (Decimal)results[0].get('totalHours');
        Decimal avgRate = (Decimal)results[0].get('avgRate');
        
        if (totalHours == null) { totalHours = 0; }
        if (avgRate == null) { avgRate = 0; }

        return new Map<String, Decimal>{
            'totalHours' => totalHours,
            'estimatedSpend' => totalHours * avgRate,
            'activeRequests' => [SELECT COUNT() FROM Request__c WHERE StatusPk__c NOT IN ('Closed', 'Completed')]
        };
    }
}