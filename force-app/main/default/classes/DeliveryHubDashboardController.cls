/**
 * @description Controller for the Delivery Budget Summary LWC.
 * Aggregates financial and hour metrics for active requests.
 */
public with sharing class DeliveryHubDashboardController {

    /**
     * @description Calculates total hours, estimated spend, and active request count.
     * @return Map<String, Decimal> A map containing 'totalHours', 'estimatedSpend', and 'activeRequests'.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getBudgetMetrics() {
        // Sum up hours for all "Active" requests (assuming status isn't Closed/Done)
        AggregateResult[] results = [
            SELECT SUM(PreApprovedHoursNumber__c) totalHours, AVG(HourlyRateCurrency__c) avgRate
            FROM Request__c
            WHERE StatusPk__c NOT IN ('Closed', 'Completed', 'Cancelled')
            WITH USER_MODE
        ];

        Decimal totalHours = (Decimal)results[0].get('totalHours');
        Decimal avgRate = (Decimal)results[0].get('avgRate');
        
        if (totalHours == null) {
            totalHours = 0;
        }
        
        if (avgRate == null) {
            avgRate = 0;
        }

        return new Map<String, Decimal>{
            'totalHours' => totalHours,
            'estimatedSpend' => totalHours * avgRate,
            'activeRequests' => [SELECT COUNT() FROM Request__c WHERE StatusPk__c NOT IN ('Closed', 'Completed') WITH USER_MODE]
        };
    }
}