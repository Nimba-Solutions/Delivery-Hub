/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for the WorkItemComment__c trigger verifying that comment
 *              inserts and updates produce outbound SyncItem__c ledger entries.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemCommentTriggerTest {

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(AutoCreateWorkRequestBool__c = false);
        NetworkEntity__c vendor = new NetworkEntity__c(Name='M', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        WorkItem__c t = new WorkItem__c(BriefDescriptionTxt__c='T', StageNamePk__c='Backlog');
        insert t;
        insert new WorkRequest__c(WorkItemId__c=t.Id, DeliveryEntityId__c=vendor.Id, StatusPk__c='Active', RemoteWorkItemIdTxt__c='R-101');
    }

    @IsTest
    static void testInsertSyncsComment() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        delete [SELECT Id FROM SyncItem__c];

        Test.startTest();
        insert new WorkItemComment__c(WorkItemId__c = t.Id, BodyTxt__c = 'Hello');
        Test.stopTest();

        List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE ObjectTypePk__c LIKE '%WorkItemComment__c'];
        System.assert(items.size() >= 1, 'Should create at least 1 Sync Item for comment insert');
    }

    @IsTest
    static void testUpdateSyncsComment() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        WorkItemComment__c c = new WorkItemComment__c(WorkItemId__c = t.Id, BodyTxt__c = 'Old');
        insert c;
        delete [SELECT Id FROM SyncItem__c];

        Test.startTest();
        c.BodyTxt__c = 'New';
        update c;
        Test.stopTest();

        List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE ObjectTypePk__c LIKE '%WorkItemComment__c'];
        System.assert(items.size() >= 1, 'Should create at least 1 Sync Item for comment update');
    }
}