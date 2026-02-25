/**
 * @description Tests for DeliveryWorkLogTriggerHandler.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkLogTriggerHandlerTest {

    @TestSetup
    static void setup() {
        Network_Entity__c client = new Network_Entity__c(
            Name = 'Test Client', EntityTypePk__c = 'Client', StatusPk__c = 'Active'
        );
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert new List<Network_Entity__c>{ client, vendor };

        Ticket__c linkedTicket = new Ticket__c(
            BriefDescriptionTxt__c   = 'Client Ticket',
            StageNamePk__c           = 'In Development',
            ClientNetworkEntityId__c = client.Id
        );
        Ticket__c unlinkedTicket = new Ticket__c(
            BriefDescriptionTxt__c = 'No Client Ticket',
            StageNamePk__c         = 'In Development'
        );
        insert new List<Ticket__c>{ linkedTicket, unlinkedTicket };

        // Every WorkLog__c is Master-Detail to Request__c — create one per ticket
        insert new List<Request__c>{
            new Request__c(
                TicketId__c           = linkedTicket.Id,
                DeliveryEntityId__c   = vendor.Id,
                QuotedHoursNumber__c  = 20,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            ),
            new Request__c(
                TicketId__c           = unlinkedTicket.Id,
                DeliveryEntityId__c   = vendor.Id,
                QuotedHoursNumber__c  = 10,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            )
        };
    }

    @IsTest
    static void testWorkLogOnClientTicketCreatesSyncItem() {
        Ticket__c ticket   = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Client Ticket' LIMIT 1];
        Request__c request = [SELECT Id FROM Request__c WHERE TicketId__c = :ticket.Id LIMIT 1];

        Test.startTest();
        insert new WorkLog__c(
            RequestId__c           = request.Id,
            TicketId__c            = ticket.Id,
            HoursLoggedNumber__c   = 3.5,
            WorkDateDate__c        = Date.today(),
            WorkDescriptionTxt__c  = 'Implemented feature X'
        );
        Test.stopTest();

        List<Sync_Item__c> items = [
            SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c, TicketId__c
            FROM Sync_Item__c
            WHERE TicketId__c = :ticket.Id
        ];
        System.assertEquals(1, items.size(), 'Should create 1 sync item for client-linked ticket');
        System.assertEquals('WorkLog__c', items[0].ObjectTypePk__c);
        System.assertEquals('Outbound', items[0].DirectionPk__c);
        System.assertEquals('Queued', items[0].StatusPk__c);
    }

    @IsTest
    static void testWorkLogOnUnlinkedTicketNoSyncItem() {
        Ticket__c ticket   = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'No Client Ticket' LIMIT 1];
        Request__c request = [SELECT Id FROM Request__c WHERE TicketId__c = :ticket.Id LIMIT 1];

        Test.startTest();
        insert new WorkLog__c(
            RequestId__c           = request.Id,
            TicketId__c            = ticket.Id,
            HoursLoggedNumber__c   = 2.0,
            WorkDateDate__c        = Date.today(),
            WorkDescriptionTxt__c  = 'Internal work only'
        );
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE TicketId__c = :ticket.Id];
        System.assertEquals(0, items.size(), 'Should not create sync items for tickets without a client');
    }

    @IsTest
    static void testTriggerControlDisabled() {
        Ticket__c ticket   = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Client Ticket' LIMIT 1];
        Request__c request = [SELECT Id FROM Request__c WHERE TicketId__c = :ticket.Id LIMIT 1];

        DeliveryTriggerControl.disableAfterLogic();

        Test.startTest();
        insert new WorkLog__c(
            RequestId__c           = request.Id,
            TicketId__c            = ticket.Id,
            HoursLoggedNumber__c   = 1.0,
            WorkDateDate__c        = Date.today(),
            WorkDescriptionTxt__c  = 'Trigger disabled test'
        );
        Test.stopTest();

        DeliveryTriggerControl.enableAfterLogic();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE TicketId__c = :ticket.Id];
        System.assertEquals(0, items.size(), 'Should not create sync items when trigger control is disabled');
    }
}
