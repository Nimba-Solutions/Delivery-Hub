/**
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubDashboardControllerTest {
    
    @IsTest
    static void testGetMetrics() {
        // 1. Create Active Ticket
        // We do not set LoggedHoursNum__c here as the field does not exist yet
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket',
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

    @IsTest
    static void testGetClientDashboard() {
        List<Ticket__c> tickets = new List<Ticket__c>{
            new Ticket__c(BriefDescriptionTxt__c = 'Backlog Ticket',    StageNamePk__c = 'Backlog'),
            new Ticket__c(BriefDescriptionTxt__c = 'Dev Ticket',        StageNamePk__c = 'In Development'),
            new Ticket__c(BriefDescriptionTxt__c = 'Attention Ticket',  StageNamePk__c = 'In Client Approval')
        };
        insert tickets;

        Test.startTest();
        Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard();
        Test.stopTest();

        System.assert(result.containsKey('attentionTickets'), 'Should return attentionTickets key');
        System.assert(result.containsKey('phases'), 'Should return phases key');
        System.assert(result.containsKey('recentTickets'), 'Should return recentTickets key');

        List<DeliveryHubDashboardController.TicketItem> attention =
            (List<DeliveryHubDashboardController.TicketItem>)result.get('attentionTickets');
        System.assertEquals(1, attention.size(), 'Should return 1 attention ticket');
        System.assertEquals('In Client Approval', attention[0].stage, 'Attention ticket stage should match');

        List<DeliveryHubDashboardController.PhaseItem> phases =
            (List<DeliveryHubDashboardController.PhaseItem>)result.get('phases');
        System.assertEquals(6, phases.size(), 'Should return all 6 phase buckets');

        List<DeliveryHubDashboardController.TicketItem> recent =
            (List<DeliveryHubDashboardController.TicketItem>)result.get('recentTickets');
        System.assert(recent.size() > 0, 'Should return at least one recent ticket');
    }

    @IsTest
    static void testGetAttentionCount() {
        insert new List<Ticket__c>{
            new Ticket__c(BriefDescriptionTxt__c = 'UAT Ticket',      StageNamePk__c = 'In Client UAT'),
            new Ticket__c(BriefDescriptionTxt__c = 'Approval Ticket', StageNamePk__c = 'Ready for Client Approval'),
            new Ticket__c(BriefDescriptionTxt__c = 'Dev Ticket',      StageNamePk__c = 'In Development')
        };

        Test.startTest();
        Integer count = DeliveryHubDashboardController.getAttentionCount();
        Test.stopTest();

        System.assertEquals(2, count, 'Should count tickets in client-facing stages only');
    }

    @IsTest
    static void testVendorAnnouncementIncludedInDashboard() {
        insert new Network_Entity__c(
            Name                      = 'Announcing Vendor',
            EntityTypePk__c           = 'Vendor',
            StatusPk__c               = 'Active',
            VendorAnnouncementTxt__c  = 'Scheduled maintenance this weekend.'
        );

        Test.startTest();
        Map<String, Object> result = DeliveryHubDashboardController.getClientDashboard();
        Test.stopTest();

        List<Object> announcements = (List<Object>) result.get('announcements');
        System.assertEquals(1, announcements.size(), 'Should include vendor announcement in dashboard');
        System.assertEquals('Scheduled maintenance this weekend.', (String) announcements[0]);
    }
}