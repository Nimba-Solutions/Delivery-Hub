/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDataLineageController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDataLineageControllerTest {

    @TestSetup
    static void setup() {
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor Hub', EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', ConnectionStatusPk__c = 'Connected'
        );
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Test Client Org', EntityTypePk__c = 'Client',
            StatusPk__c = 'Active', ConnectionStatusPk__c = 'Connected'
        );
        insert new List<NetworkEntity__c>{ vendor, client };
    }

    @IsTest
    static void testGetNetworkEntities() {
        Test.startTest();
        Map<String, Object> result = DeliveryDataLineageController.getNetworkEntities();
        Test.stopTest();

        System.assertNotEquals(null, result.get('localOrgName'), 'Should return local org name');
        System.assertNotEquals(null, result.get('localOrgId'), 'Should return local org Id');

        List<Object> entities = (List<Object>) result.get('entities');
        System.assertEquals(2, entities.size(), 'Should return 2 active entities');
    }

    @IsTest
    static void testGetNetworkEntitiesWithSyncItems() {
        NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Lineage Test',
            StageNamePk__c = 'Backlog',
            ClientNetworkEntityId__c = client.Id
        );
        insert wi;

        insert new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Synced',
            WorkItemId__c = wi.Id,
            LocalRecordIdTxt__c = wi.Id
        );

        Test.startTest();
        Map<String, Object> result = DeliveryDataLineageController.getNetworkEntities();
        Test.stopTest();

        List<Object> entities = (List<Object>) result.get('entities');
        Boolean foundClient = false;
        for (Object obj : entities) {
            Map<String, Object> e = (Map<String, Object>) obj;
            if (e.get('name') == 'Test Client Org') {
                foundClient = true;
                System.assertEquals(100, e.get('healthPct'), 'Should be 100% health with 1 synced, 0 failed');
                System.assertEquals(1, e.get('syncedCount'));
            }
        }
        System.assert(foundClient, 'Should find client entity');
    }

    @IsTest
    static void testGetSyncHealth() {
        Test.startTest();
        Map<String, Object> health = DeliveryDataLineageController.getSyncHealth();
        Test.stopTest();

        System.assertNotEquals(null, health, 'Should return health map');
    }

    @IsTest
    static void testNoEntities() {
        delete [SELECT Id FROM NetworkEntity__c];

        Test.startTest();
        Map<String, Object> result = DeliveryDataLineageController.getNetworkEntities();
        Test.stopTest();

        List<Object> entities = (List<Object>) result.get('entities');
        System.assertEquals(0, entities.size(), 'Should return empty list');
    }
}
