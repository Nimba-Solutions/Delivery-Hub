/**
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliveryWorkItemTriggerHandlerTest {

    @TestSetup
    static void setup() {
        insert new Delivery_Hub_Settings__c(AutoCreateWorkRequestBool__c = true);
        Network_Entity__c vendor = new Network_Entity__c(Name='V', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        insert new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StatusPk__c = 'In Progress', StageNamePk__c = 'In Development');
    }

    @IsTest
    static void testDeliverySyncEngineIntegrationOnUpdate() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        Network_Entity__c v = [SELECT Id FROM Network_Entity__c LIMIT 1];
        insert new WorkRequest__c(WorkItemId__c = t.Id, DeliveryEntityId__c = v.Id, StatusPk__c = 'Active', RemoteWorkItemIdTxt__c = 'R-123');

        delete [SELECT Id FROM Sync_Item__c]; 

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Sync Update';
        update t;
        Test.stopTest();

        List<Sync_Item__c> items = [SELECT Id FROM Sync_Item__c WHERE WorkItemId__c = :t.Id];
        System.assert(items.size() >= 1, 'Sync Engine should trigger on update');
    }
}