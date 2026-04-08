/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDataLineageController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDataLineageControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

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
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryDataLineageController.getNetworkEntities();
            Test.stopTest();

            System.assertNotEquals(null, result.get('localOrgName'), 'Should return local org name');
            System.assertNotEquals(null, result.get('localOrgId'), 'Should return local org Id');

            List<Object> entities = (List<Object>) result.get('entities');
            System.assertEquals(2, entities.size(), 'Should return 2 active entities');
        }
    }

    @IsTest
    static void testGetNetworkEntitiesWithSyncItems() {
        System.runAs(testUser) {
            NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];
            WorkItem__c wi = new WorkItem__c(
                BriefDescriptionTxt__c = 'Lineage Test',
                StageNamePk__c = 'Backlog',
                ClientNetworkEntityLookup__c = client.Id
            );
            insert wi;

            insert new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c = 'Outbound',
                StatusPk__c = 'Synced',
                WorkItemLookup__c = wi.Id,
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
    }

    @IsTest
    static void testGetSyncHealth() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> health = DeliveryDataLineageController.getSyncHealth();
            Test.stopTest();

            System.assertNotEquals(null, health, 'Should return health map');
        }
    }

    /**
     * @description Bug B regression guard: vendors should display LastInboundSyncDateTime__c
     *              and clients should display LastOutboundSyncDateTime__c. Pre-fix every
     *              entity read the inbound field, so client connections always rendered
     *              "Last sync: Never" because nothing ever stamped the inbound field for
     *              outbound destinations.
     */
    @IsTest
    static void testLastSyncReadsCorrectFieldPerDirection() {
        System.runAs(testUser) {
            DateTime inboundStamp = DateTime.newInstance(2026, 4, 1, 9, 30, 0);
            DateTime outboundStamp = DateTime.newInstance(2026, 4, 8, 14, 45, 0);

            // Stamp BOTH fields differently on each entity so we can detect which one is read.
            NetworkEntity__c vendor = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Vendor' LIMIT 1];
            vendor.LastInboundSyncDateTime__c = inboundStamp;
            vendor.LastOutboundSyncDateTime__c = outboundStamp;
            update vendor;

            NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];
            client.LastInboundSyncDateTime__c = inboundStamp;
            client.LastOutboundSyncDateTime__c = outboundStamp;
            update client;

            Test.startTest();
            Map<String, Object> result = DeliveryDataLineageController.getNetworkEntities();
            Test.stopTest();

            List<Object> entities = (List<Object>) result.get('entities');
            String vendorLastSync = null;
            String clientLastSync = null;
            for (Object obj : entities) {
                Map<String, Object> e = (Map<String, Object>) obj;
                if (e.get('entityType') == 'Vendor') {
                    vendorLastSync = (String) e.get('lastSync');
                } else if (e.get('entityType') == 'Client') {
                    clientLastSync = (String) e.get('lastSync');
                }
            }

            // Vendor should display the inbound stamp (Apr 1, 9:30 AM).
            System.assertNotEquals(null, vendorLastSync, 'Vendor should have a lastSync value');
            System.assert(vendorLastSync.contains('Apr 1'),
                'Vendor lastSync should reflect inbound stamp (Apr 1) but got: ' + vendorLastSync);

            // Client should display the outbound stamp (Apr 8, 2:45 PM).
            System.assertNotEquals(null, clientLastSync, 'Client should have a lastSync value');
            System.assert(clientLastSync.contains('Apr 8'),
                'Client lastSync should reflect outbound stamp (Apr 8) but got: ' + clientLastSync);
        }
    }

    @IsTest
    static void testNoEntities() {
        System.runAs(testUser) {
            delete [SELECT Id FROM NetworkEntity__c];

            Test.startTest();
            Map<String, Object> result = DeliveryDataLineageController.getNetworkEntities();
            Test.stopTest();

            List<Object> entities = (List<Object>) result.get('entities');
            System.assertEquals(0, entities.size(), 'Should return empty list');
        }
    }
}
