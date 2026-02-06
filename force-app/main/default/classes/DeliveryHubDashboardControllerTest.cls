@IsTest
private class DeliveryHubDashboardControllerTest {
    
    @IsTest
    static void testGetMetrics() {
        // 1. Create Active Ticket
        // We do not set LoggedHoursNum__c here as the field does not exist yet
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
        // Return type is now Map<String, Object> to support the String date
        Map<String, Object> metrics = DeliveryHubDashboardController.getBudgetMetrics();
        Test.stopTest();

        // 3. Assertions
        // We cast the Decimal values because the map values are generic Objects
        System.assertEquals(1, (Decimal)metrics.get('activeRequests'), 'Should count 1 active ticket');
        System.assertEquals(1, (Decimal)metrics.get('succeededSyncs'), 'Should count 1 success');
        System.assertEquals(1, (Decimal)metrics.get('failedSyncs'), 'Should count 1 failure');
        
        // 4. Verify Last Entry
        System.assert(metrics.containsKey('lastEntry'), 'Should return lastEntry key');
        String lastEntry = (String)metrics.get('lastEntry');
        
        System.assertNotEquals(null, lastEntry, 'Last Entry should not be null');
        System.assertNotEquals('--', lastEntry, 'Last Entry should have a formatted date value');
    }
}