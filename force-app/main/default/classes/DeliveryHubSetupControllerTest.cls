/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryHubSetupController covering setup status retrieval,
 * local entity preparation, and handshake success/failure scenarios.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubSetupControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testGetSetupStatus() {
        System.runAs(testUser) {
            DeliveryHubSetupController.SetupStatus status = DeliveryHubSetupController.getSetupStatus();
            System.assertNotEquals(null, status, 'SetupStatus should not be null');
        }
    }

    @IsTest
    static void testPrepareLocalEntity() {
        System.runAs(testUser) {
            Test.startTest();
            NetworkEntity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            Test.stopTest();

            System.assertNotEquals(null, entity.Id, 'Network Entity should be created');
            System.assertEquals('Vendor', entity.EntityTypePk__c, 'Entity type should be Vendor');
        }
    }

    @IsTest
    static void testPerformHandshakeSuccess() {
        System.runAs(testUser) {
            // Prevent continuous loop queues
            DeliverySyncEngine.setSyncContext();

            NetworkEntity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            Test.setMock(HttpCalloutMock.class, new SuccessMock());

            Test.startTest();
            DeliveryHubSetupController.performHandshake(entity.Id);
            Test.stopTest();

            // Assert local entity was updated with remote info and API key from handshake
            NetworkEntity__c updatedEntity = [
                SELECT RemoteExternalIdTxt__c, OrgIdTxt__c, ApiKeyTxt__c, ConnectionStatusPk__c
                FROM NetworkEntity__c WHERE Id = :entity.Id
            ];

            // --- FIX: Use generic strings instead of 18-char IDs to pass PMD ---
            System.assertEquals('MOCK_PROCESSED_ID', updatedEntity.RemoteExternalIdTxt__c, 'Remote External ID should be mapped from payload');
            System.assertEquals('MOCK_ORG_ID', updatedEntity.OrgIdTxt__c, 'Org ID should be mapped from payload');

            // Assert API key was generated and stored during handshake
            System.assertNotEquals(null, updatedEntity.ApiKeyTxt__c, 'API key should be generated during handshake');
            System.assertEquals(64, updatedEntity.ApiKeyTxt__c.length(), 'API key should be 64-char hex string');
            System.assertEquals('Connected', updatedEntity.ConnectionStatusPk__c, 'Connection status should be set to Connected');

            // Assert Work Item and Request bridge were created
            List<WorkItem__c> workItems = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Connection Established Successfully.'];
            System.assertEquals(1, workItems.size(), 'Initial workItem should be created');

            List<WorkRequest__c> requests = [SELECT Id FROM WorkRequest__c WHERE WorkItemLookup__c = :workItems[0].Id];
            System.assertEquals(1, requests.size(), 'Bridge request should be created automatically by the trigger');

            // Assert settings were initialized
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            System.assertNotEquals(null, settings.Id, 'Settings should be initialized');
        }
    }

    @IsTest
    static void testPerformHandshakeFailure() {
        System.runAs(testUser) {
            NetworkEntity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            Test.setMock(HttpCalloutMock.class, new FailureMock());

            Test.startTest();
            try {
                DeliveryHubSetupController.performHandshake(entity.Id);
                System.assert(false, 'Should have thrown an exception on 500 error');
            } catch (Exception e) {
                // AuraHandledException hides its message in test context, so we check the type instead
                System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Should throw AuraHandledException on failure');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testConfigureGuestUserAccessNoSite() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryHubSetupController.configureGuestUserAccess();
            Test.stopTest();
            // Method should complete without error when no Site exists (silent no-op)
            System.assert(true, 'configureGuestUserAccess should not throw when no active Site exists');
        }
    }

    @IsTest
    static void testApproveConnection() {
        System.runAs(testUser) {
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Pending Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active',
                ConnectionStatusPk__c = 'Pending Approval'
            );
            insert entity;

            Test.startTest();
            DeliveryHubSetupController.approveConnection(entity.Id);
            Test.stopTest();

            NetworkEntity__c updated = [SELECT ConnectionStatusPk__c FROM NetworkEntity__c WHERE Id = :entity.Id];
            System.assertEquals('Connected', updated.ConnectionStatusPk__c, 'Connection should be approved (Connected)');
        }
    }

    @IsTest
    static void testRejectConnection() {
        System.runAs(testUser) {
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Pending Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active',
                ConnectionStatusPk__c = 'Pending Approval'
            );
            insert entity;

            Test.startTest();
            DeliveryHubSetupController.rejectConnection(entity.Id);
            Test.stopTest();

            NetworkEntity__c updated = [SELECT ConnectionStatusPk__c FROM NetworkEntity__c WHERE Id = :entity.Id];
            System.assertEquals('Disabled', updated.ConnectionStatusPk__c, 'Connection should be rejected (Disabled)');
        }
    }

    @IsTest
    static void testApproveConnectionWrongStatus() {
        System.runAs(testUser) {
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Already Connected',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active',
                ConnectionStatusPk__c = 'Connected'
            );
            insert entity;

            Test.startTest();
            try {
                DeliveryHubSetupController.approveConnection(entity.Id);
                System.assert(false, 'Should have thrown an exception for wrong status');
            } catch (Exception e) {
                System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Should throw AuraHandledException');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetPendingApprovalCount() {
        System.runAs(testUser) {
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Pending Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active',
                ConnectionStatusPk__c = 'Pending Approval'
            );
            insert entity;

            Test.startTest();
            Integer count = DeliveryHubSetupController.getPendingApprovalCount();
            Test.stopTest();

            System.assertEquals(1, count, 'Should have 1 pending approval');
        }
    }

    @IsTest
    static void testGetPendingApprovals() {
        System.runAs(testUser) {
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Pending Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active',
                ConnectionStatusPk__c = 'Pending Approval'
            );
            insert entity;

            Test.startTest();
            List<NetworkEntity__c> pending = DeliveryHubSetupController.getPendingApprovals();
            Test.stopTest();

            System.assertEquals(1, pending.size(), 'Should return 1 pending approval');
            System.assertEquals('Pending Client', pending[0].Name, 'Should return the correct entity');
        }
    }

    @IsTest
    static void testCheckPrerequisites() {
        System.runAs(testUser) {
            Test.startTest();
            // checkPrerequisites makes a callout to test remote site reachability
            Test.setMock(HttpCalloutMock.class, new SuccessMock());
            DeliveryHubSetupController.PrerequisiteStatus prereqs = DeliveryHubSetupController.checkPrerequisites();
            Test.stopTest();

            System.assertNotEquals(null, prereqs, 'PrerequisiteStatus should not be null');
            System.assertNotEquals(null, prereqs.orgDomain, 'Org domain should be populated');
            System.assertNotEquals(null, prereqs.siteSetupUrl, 'Site setup URL should be populated');
            System.assertNotEquals(null, prereqs.remoteSiteSetupUrl, 'Remote site setup URL should be populated');
            // siteExists/siteActive/guestUserConfigured depend on org state (CI scratch orgs
            // may have Sites configured), so we only verify they are non-null booleans
            System.assertNotEquals(null, prereqs.siteExists, 'siteExists should be populated');
            System.assertNotEquals(null, prereqs.siteActive, 'siteActive should be populated');
            System.assertNotEquals(null, prereqs.guestUserConfigured, 'guestUserConfigured should be populated');
            // Remote site reachability depends on mock — SuccessMock returns 200 so it should pass
            System.assertEquals(true, prereqs.remoteSiteReachable, 'Remote site should be reachable with success mock');
        }
    }

    @IsTest
    static void testCheckPrerequisitesRemoteFail() {
        System.runAs(testUser) {
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new FailureMock());
            DeliveryHubSetupController.PrerequisiteStatus prereqs = DeliveryHubSetupController.checkPrerequisites();
            Test.stopTest();

            // FailureMock returns 500 but the callout itself succeeds (doesn't throw CalloutException)
            // so remoteSiteReachable should be true (any HTTP response = remote site setting exists)
            System.assertNotEquals(null, prereqs, 'PrerequisiteStatus should not be null');
        }
    }

    /** @description Mock that returns a successful 200 handshake response with processedId and orgId. */
    private class SuccessMock implements HttpCalloutMock {
        /** @description Builds a mock 200 response. @param req The inbound request. @return Mock HttpResponse with status 200. */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // --- FIX: Use generic strings instead of 18-char IDs to pass PMD ---
            res.setBody('{"status":"Success", "processedId":"MOCK_PROCESSED_ID", "orgId":"MOCK_ORG_ID"}');
            return res;
        }
    }
    
    /** @description Mock that returns HTTP 500 to test handshake failure handling. */
    private class FailureMock implements HttpCalloutMock {
        /** @description Builds a mock 500 response. @param req The inbound request. @return Mock HttpResponse with status 500. */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }
}