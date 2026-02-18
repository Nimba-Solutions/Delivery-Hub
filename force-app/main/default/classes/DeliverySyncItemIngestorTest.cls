@IsTest
private class DeliverySyncItemIngestorTest {

    @TestSetup
    static void setupData() {
        // 1. Setup Settings
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Setup Network Entity (Vendor)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        // 3. Setup a local Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Local Ticket',
            BriefDescriptionTxt__c = 'Initial Description',
            StageNamePk__c = 'Backlog'
        );
        insert t;

        // 4. Setup the Bridge (Request) linking Local ID to a Remote ID
        insert new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-TKT-001'
        );
    }

    /**
     * @description Verifies that an inbound payload for a Ticket correctly identifies
     * the local record via the Request bridge and updates it.
     */
    @IsTest
    static void testProcessInboundTicketUpdate() {
        String remoteId = 'REMOTE-TKT-001';
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => remoteId,
            'BriefDescriptionTxt__c' => 'Updated via Inbound Sync',
            'StageNamePk__c' => 'In Development'
        };

        Test.startTest();
        // Uses the newly renamed class DeliverySyncItemIngestor
        DeliverySyncItemIngestor.processInboundItem('Ticket__c', payload);
        Test.stopTest();

        // Verify Ticket Update - SourcePk__c removed from query to match schema
        Ticket__c updatedT = [SELECT BriefDescriptionTxt__c, StageNamePk__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Updated via Inbound Sync', updatedT.BriefDescriptionTxt__c, 'Ticket description should be updated.');
        System.assertEquals('In Development', updatedT.StageNamePk__c, 'Ticket stage should be updated.');
    }

    /**
     * @description Verifies that an inbound payload for a Comment correctly creates
     * a local record, links it to the local parent ticket, and creates a Ledger entry.
     */
    @IsTest
    static void testProcessInboundCommentInsert() {
        String remoteCommentId = 'REMOTE-CMT-999';
        String remoteTicketId = 'REMOTE-TKT-001'; 
        
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => remoteCommentId,
            'TargetId' => remoteTicketId,
            'BodyTxt__c' => 'New Inbound Comment',
            'AuthorTxt__c' => 'Remote User'
        };

        Test.startTest();
        DeliverySyncItemIngestor.processInboundItem('Ticket_Comment__c', payload);
        Test.stopTest();

        // 1. Verify Comment was created and parented
        Ticket__c localTicket = [SELECT Id FROM Ticket__c LIMIT 1];
        Ticket_Comment__c newCmt = [SELECT BodyTxt__c, TicketId__c FROM Ticket_Comment__c WHERE AuthorTxt__c = 'Remote User' LIMIT 1];
        
        System.assertEquals('New Inbound Comment', newCmt.BodyTxt__c);
        System.assertEquals(localTicket.Id, newCmt.TicketId__c, 'Comment should be linked to the local parent ticket.');

        // 2. Verify Ledger entry was created in Sync_Item__c
        List<Sync_Item__c> ledger = [
            SELECT LocalRecordIdTxt__c 
            FROM Sync_Item__c 
            WHERE RemoteExternalIdTxt__c = :remoteCommentId 
            AND DirectionPk__c = 'Inbound'
        ];
        System.assertEquals(1, ledger.size(), 'A ledger entry should be created for new inbound child records.');
        System.assertEquals((String)newCmt.Id, ledger[0].LocalRecordIdTxt__c, 'Ledger should map remote ID to the new local ID.');
    }

    /**
     * @description Verifies that an inbound payload for an existing child (Comment)
     * correctly identifies the local record via the Sync_Item ledger and updates it.
     */
    @IsTest
    static void testProcessInboundCommentUpdateViaLedger() {
        // 1. Pre-create a comment and a Ledger entry
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Ticket_Comment__c c = new Ticket_Comment__c(TicketId__c = t.Id, BodyTxt__c = 'Old Body');
        insert c;

        String remoteCmtId = 'REMOTE-CMT-123';
        insert new Sync_Item__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Synced',
            ObjectTypePk__c = 'Ticket_Comment__c',
            RemoteExternalIdTxt__c = remoteCmtId,
            LocalRecordIdTxt__c = (String)c.Id
        );

        // 2. Simulate update payload
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => remoteCmtId,
            'BodyTxt__c' => 'Updated Ledger Body'
        };

        Test.startTest();
        DeliverySyncItemIngestor.processInboundItem('Ticket_Comment__c', payload);
        Test.stopTest();

        // 3. Verify update
        Ticket_Comment__c updatedC = [SELECT BodyTxt__c FROM Ticket_Comment__c WHERE Id = :c.Id];
        System.assertEquals('Updated Ledger Body', updatedC.BodyTxt__c, 'Existing comment should be updated via Ledger lookup.');
    }

    @IsTest
    static void testInvalidObjectType() {
        try {
            DeliverySyncItemIngestor.processInboundItem('Invalid__c', new Map<String, Object>());
            System.assert(false, 'Should have thrown an exception for invalid object type.');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Invalid Object Type'), 'Error message should be descriptive.');
        }
    }
}