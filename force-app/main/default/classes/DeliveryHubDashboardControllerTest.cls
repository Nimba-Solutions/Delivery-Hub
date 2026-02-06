@IsTest
private class DeliveryHubDashboardControllerTest {
    
    @IsTest
    static void testGetMetrics() {
        // 1. Create Active Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StageNamePk__c = 'In Progress'
        );
        insert t;

        // 2. Create Sync Items (1 Success, 1 Failure)
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        
        items.add(new Sync_Item__c(
            ObjectTypePk__c = 'Ticket__c',
            StatusPk__c = 'Synced',
            PayloadTxt__c = '{}',
            TicketId__c = t.Id
        ));
        
        items.add(new Sync_Item__c(
            ObjectTypePk__c = 'Ticket__c',
            StatusPk__c = 'Failed',
            PayloadTxt__c = '{}',
            TicketId__c = t.Id
        ));
        
        insert items;

        Test.startTest();
        Map<String, Decimal> metrics = DeliveryHubDashboardController.getBudgetMetrics();
        Test.stopTest();

        // 3. Assertions
        System.assertEquals(1, metrics.get('activeRequests'), 'Should count 1 active ticket');
        System.assertEquals(1, metrics.get('succeededSyncs'), 'Should count 1 success');
        System.assertEquals(1, metrics.get('failedSyncs'), 'Should count 1 failure');
    }
}