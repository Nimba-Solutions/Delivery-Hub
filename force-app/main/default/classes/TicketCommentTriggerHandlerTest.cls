@IsTest
private class TicketCommentTriggerHandlerTest {

    @TestSetup
    static void setup() {
        insert new Delivery_Hub_Settings__c(AutoCreateRequestFromTicketBool__c = false);
        Network_Entity__c vendor = new Network_Entity__c(Name='M', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c='T', StageNamePk__c='Backlog');
        insert t;
        insert new Request__c(TicketId__c=t.Id, DeliveryEntityId__c=vendor.Id, StatusPk__c='Active', RemoteTicketIdTxt__c='R-101');
    }

    @IsTest
    static void testInsertSyncsComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        insert new Ticket_Comment__c(TicketId__c = t.Id, BodyTxt__c = 'Hello');
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE ObjectTypePk__c LIKE '%Ticket_Comment__c'];
        System.assert(items.size() >= 1, 'Should create at least 1 Sync Item for comment insert');
    }

    @IsTest
    static void testUpdateSyncsComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Ticket_Comment__c c = new Ticket_Comment__c(TicketId__c = t.Id, BodyTxt__c = 'Old');
        insert c;
        delete [SELECT Id FROM Sync_Item__c];

        Test.startTest();
        c.BodyTxt__c = 'New';
        update c;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE ObjectTypePk__c LIKE '%Ticket_Comment__c'];
        System.assert(items.size() >= 1, 'Should create at least 1 Sync Item for comment update');
    }
}