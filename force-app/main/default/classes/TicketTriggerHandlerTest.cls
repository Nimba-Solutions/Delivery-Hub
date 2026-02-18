@IsTest
public class TicketTriggerHandlerTest {

    @TestSetup
    static void setup() {
        insert new Delivery_Hub_Settings__c(AutoCreateRequestFromTicketBool__c = true);
        Network_Entity__c vendor = new Network_Entity__c(Name='M', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        insert new Ticket__c(BriefDescriptionTxt__c = 'Blocker', StatusPk__c = 'In Progress', StageNamePk__c = 'In Development');
    }

    @IsTest
    static void testSyncEngineIntegrationOnUpdate() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Network_Entity__c vendor = [SELECT Id FROM Network_Entity__c LIMIT 1];
        insert new Request__c(TicketId__c = t.Id, DeliveryEntityId__c = vendor.Id, StatusPk__c = 'Active', RemoteTicketIdTxt__c = 'R-123');

        // Clear bridge/setup noise to isolate the update check
        delete [SELECT Id FROM Sync_Item__c]; 

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Sync Update';
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE TicketId__c = :t.Id];
        // Use flexible assertion to account for potential multiple trigger entries in the org 
        System.assert(items.size() >= 1, 'Sync Engine should create at least 1 Sync Item on update.');
    }
}