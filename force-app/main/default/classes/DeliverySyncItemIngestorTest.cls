/**
 * @description Verifies inbound ingestion logic with namespace awareness.
 */
@IsTest
private class DeliverySyncItemIngestorTest {

    @TestSetup
    static void makeData() {
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Base Ticket',
            BriefDescriptionTxt__c = 'Initial Description'
        );
        insert t;

        insert new Request__c(
            TicketId__c = t.Id,
            RemoteTicketIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'Active'
        );
    }

    @IsTest
    static void testProcessInboundTicketUpdate() {
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => 'REMOTE-123',
            'BriefDescriptionTxt__c' => 'Updated via Inbound Sync'
        };

        Test.startTest();
        DeliverySyncItemIngestor.processInboundItem('Ticket__c', payload);
        Test.stopTest();

        Ticket__c updated = [SELECT BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Updated via Inbound Sync', updated.BriefDescriptionTxt__c, 'Ticket description should be updated via robust field mapping');
    }

    @IsTest
    static void testProcessInboundCommentInsert() {
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => 'REMOTE-COMM-456',
            'TargetId' => 'REMOTE-123',
            'BodyTxt__c' => 'New Inbound Comment',
            'AuthorTxt__c' => 'Mothership'
        };

        Test.startTest();
        DeliverySyncItemIngestor.processInboundItem('Ticket_Comment__c', payload);
        Test.stopTest();

        // Verify insertion and ledger creation
        Ticket_Comment__c comm = [SELECT BodyTxt__c FROM Ticket_Comment__c WHERE AuthorTxt__c = 'Mothership' LIMIT 1];
        System.assertNotEquals(null, comm, 'Comment should be inserted');
        
        Sync_Item__c ledger = [SELECT ObjectTypePk__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = 'REMOTE-COMM-456' LIMIT 1];
        System.assert(ledger.ObjectTypePk__c.contains('Ticket_Comment__c'), 'Ledger must have valid ObjectTypePk__c value');
    }
}