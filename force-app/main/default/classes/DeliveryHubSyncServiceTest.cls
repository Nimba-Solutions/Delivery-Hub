@IsTest
private class DeliveryHubSyncServiceTest {

    @TestSetup
    static void makeData() {
        // 1. Create Network Entity (Vendor)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor'
        );
        insert vendor;

        // 2. Create Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog',
            EstimatedHoursNumber__c = 10,
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;

        // 3. Create Request (Link Ticket to Remote ID)
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteTicketIdTxt__c = 'REMOTE-TICKET-123',
            StatusPk__c = 'Open'
        );
        insert req;
    }

    /**
     * @description Verifies validation logic for invalid object types.
     */
    @IsTest
    static void testProcessSyncInvalidObject() {
        Map<String, Object> payload = new Map<String, Object>{ 'TargetId' => 'fakeid' };

        Test.startTest();
        try {
            DeliveryHubSyncService.processSync('Invalid_Object_Name__c', payload);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Invalid Object Type'), 'Exception should mention object type');
        } catch (Exception e) {
            System.assert(false, 'Wrong exception type thrown: ' + e.getTypeName());
        }
        Test.stopTest();
    }

    /**
     * @description Verifies a standard update on a Ticket object.
     */
    @IsTest
    static void testTicketUpdate() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Map<String, Object> payload = new Map<String, Object>{
            'TargetId' => t.Id,
            'StageNamePk__c' => 'In Progress',
            'EstimatedHoursNumber__c' => 20
        };

        Test.startTest();
        DeliveryHubSyncService.processSync('Ticket__c', payload);
        Test.stopTest();

        Ticket__c updatedT = [SELECT StageNamePk__c, EstimatedHoursNumber__c FROM Ticket__c WHERE Id = :t.Id];
        System.assertEquals('In Progress', updatedT.StageNamePk__c, 'Stage should be updated');
        System.assertEquals(20, updatedT.EstimatedHoursNumber__c, 'Hours should be updated');
    }

    /**
     * @description Verifies Comment Insertion, Parent Resolution, and Idempotency.
     */
    @IsTest
    static void testCommentInsertWithIdempotency() {
        // Use the Remote ID established in Setup ('REMOTE-TICKET-123')
        // This tests resolveLocalTicketId()
        String remoteTicketId = 'REMOTE-TICKET-123'; 
        String sourceId = 'REMOTE-COMMENT-999';

        Map<String, Object> payload = new Map<String, Object>{
            'TargetId' => remoteTicketId, 
            'SourceId' => sourceId,
            'body' => 'This is a test comment',
            'author' => 'Test User'
        };

        Test.startTest();
        
        // 1. First Sync: Should Insert
        DeliveryHubSyncService.processSync('Ticket_Comment__c', payload);
        
        // 2. Second Sync (Duplicate): Should Skip based on SourceId
        DeliveryHubSyncService.processSync('Ticket_Comment__c', payload);
        
        Test.stopTest();

        // Assertions
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        List<Ticket_Comment__c> comments = [
            SELECT Id, BodyTxt__c, AuthorTxt__c, TicketId__c 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :t.Id
        ];

        System.assertEquals(1, comments.size(), 'Should have inserted exactly 1 comment (Idempotency check)');
        System.assertEquals('This is a test comment', comments[0].BodyTxt__c);
        System.assertEquals('Test User', comments[0].AuthorTxt__c);

        // Verify Receipt Ledger
        Integer receipts = [
            SELECT COUNT() 
            FROM Sync_Item__c 
            WHERE RemoteExternalIdTxt__c = :sourceId 
            AND DirectionPk__c = 'Inbound'
        ];
        System.assertEquals(1, receipts, 'Should have created 1 receipt in the ledger');
    }
}