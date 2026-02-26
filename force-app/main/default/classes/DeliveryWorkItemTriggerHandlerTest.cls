/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliveryWorkItemTriggerHandlerTest {

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(AutoCreateWorkRequestBool__c = true);
        NetworkEntity__c vendor = new NetworkEntity__c(Name='V', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        insert new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StatusPk__c = 'In Progress', StageNamePk__c = 'In Development');
    }

    @IsTest
    static void testDeliverySyncEngineIntegrationOnUpdate() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        NetworkEntity__c v = [SELECT Id FROM NetworkEntity__c LIMIT 1];
        insert new WorkRequest__c(WorkItemId__c = t.Id, DeliveryEntityId__c = v.Id, StatusPk__c = 'Active', RemoteWorkItemIdTxt__c = 'R-123');

        delete [SELECT Id FROM SyncItem__c]; 

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Sync Update';
        update t;
        Test.stopTest();

        List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemId__c = :t.Id];
        System.assert(items.size() >= 1, 'Sync Engine should trigger on update');
    }
}