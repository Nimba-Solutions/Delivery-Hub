@IsTest
private class DeliveryHubDashboardControllerTest {
    @IsTest
    static void testGetMetrics() {
        // Create dummy request
        Network_Entity__c v = new Network_Entity__c(Name='V', IntegrationEndpointUrlTxt__c='x'); 
        insert v;
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c='T'); 
        insert t;
        
        Request__c r = new Request__c(
            TicketId__c=t.Id, 
            DeliveryEntityId__c=v.Id, 
            StatusPk__c='Draft',
            PreApprovedHoursNumber__c=10, 
            HourlyRateCurrency__c=100
        );
        insert r;

        Test.startTest();
        Map<String, Decimal> metrics = DeliveryHubDashboardController.getBudgetMetrics();
        Test.stopTest();

        System.assertEquals(10, metrics.get('totalHours'));
        System.assertEquals(1000, metrics.get('estimatedSpend'));
        System.assertEquals(1, metrics.get('activeRequests'));
    }
}