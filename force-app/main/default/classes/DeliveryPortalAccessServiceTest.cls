/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryPortalAccessService.
 * Validates email-to-entity access lookups and access validation.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryPortalAccessServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        // Two network entities
        NetworkEntity__c entityA = new NetworkEntity__c(
            Name = 'Alpha Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        NetworkEntity__c entityB = new NetworkEntity__c(
            Name = 'Beta Inc',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ entityA, entityB };

        // User with access to both entities (different roles)
        // User with access to only one entity
        List<PortalAccess__c> accessRecords = new List<PortalAccess__c>{
            new PortalAccess__c(
                NetworkEntityLookup__c = entityA.Id,
                EmailTxt__c = 'multiuser@example.com',
                RolePk__c = 'Admin'
            ),
            new PortalAccess__c(
                NetworkEntityLookup__c = entityB.Id,
                EmailTxt__c = 'multiuser@example.com',
                RolePk__c = 'Member'
            ),
            new PortalAccess__c(
                NetworkEntityLookup__c = entityA.Id,
                EmailTxt__c = 'singleuser@example.com',
                RolePk__c = 'Member'
            )
        };
        insert accessRecords;
    }

    @IsTest
    static void testGetEntitiesForEmailMultipleEntities() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> entities = DeliveryPortalAccessService.getEntitiesForEmail('multiuser@example.com');
            Test.stopTest();

            System.assertEquals(2, entities.size(), 'Multi-access user should see 2 entities');

            // Results are ordered by name ASC: Alpha Corp, Beta Inc
            System.assertEquals('Alpha Corp', entities[0].get('name'), 'First entity should be Alpha Corp');
            System.assertEquals('Admin', entities[0].get('role'), 'Role for Alpha Corp should be Admin');
            System.assertEquals('Beta Inc', entities[1].get('name'), 'Second entity should be Beta Inc');
            System.assertEquals('Member', entities[1].get('role'), 'Role for Beta Inc should be Member');

            // Verify ids are present
            System.assertNotEquals(null, entities[0].get('id'), 'Entity id should not be null');
            System.assertNotEquals(null, entities[1].get('id'), 'Entity id should not be null');
        }
    }

    @IsTest
    static void testGetEntitiesForEmailSingleEntity() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> entities = DeliveryPortalAccessService.getEntitiesForEmail('singleuser@example.com');
            Test.stopTest();

            System.assertEquals(1, entities.size(), 'Single-access user should see 1 entity');
            System.assertEquals('Alpha Corp', entities[0].get('name'), 'Should be Alpha Corp');
            System.assertEquals('Member', entities[0].get('role'), 'Role should be Member');
        }
    }

    @IsTest
    static void testGetEntitiesForEmailUnknown() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> entities = DeliveryPortalAccessService.getEntitiesForEmail('unknown@example.com');
            Test.stopTest();

            System.assertEquals(0, entities.size(), 'Unknown email should return empty list');
        }
    }

    @IsTest
    static void testGetEntitiesForEmailBlank() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> entities = DeliveryPortalAccessService.getEntitiesForEmail('');
            Test.stopTest();

            System.assertEquals(0, entities.size(), 'Blank email should return empty list');
        }
    }

    @IsTest
    static void testGetEntitiesForEmailNull() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> entities = DeliveryPortalAccessService.getEntitiesForEmail(null);
            Test.stopTest();

            System.assertEquals(0, entities.size(), 'Null email should return empty list');
        }
    }

    @IsTest
    static void testValidateAccessGranted() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            Test.startTest();
            Boolean hasAccess = DeliveryPortalAccessService.validateAccess('multiuser@example.com', entityA.Id);
            Test.stopTest();

            System.assertEquals(true, hasAccess, 'multiuser@example.com should have access to Alpha Corp');
        }
    }

    @IsTest
    static void testValidateAccessGrantedSecondEntity() {
        System.runAs(testUser) {
            NetworkEntity__c entityB = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Beta Inc' LIMIT 1];

            Test.startTest();
            Boolean hasAccess = DeliveryPortalAccessService.validateAccess('multiuser@example.com', entityB.Id);
            Test.stopTest();

            System.assertEquals(true, hasAccess, 'multiuser@example.com should have access to Beta Inc');
        }
    }

    @IsTest
    static void testValidateAccessDenied() {
        System.runAs(testUser) {
            NetworkEntity__c entityB = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Beta Inc' LIMIT 1];

            Test.startTest();
            Boolean hasAccess = DeliveryPortalAccessService.validateAccess('singleuser@example.com', entityB.Id);
            Test.stopTest();

            System.assertEquals(false, hasAccess, 'singleuser@example.com should NOT have access to Beta Inc');
        }
    }

    @IsTest
    static void testValidateAccessUnknownEmail() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            Test.startTest();
            Boolean hasAccess = DeliveryPortalAccessService.validateAccess('nobody@example.com', entityA.Id);
            Test.stopTest();

            System.assertEquals(false, hasAccess, 'Unknown email should not have access');
        }
    }

    @IsTest
    static void testValidateAccessBlankEmail() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            Test.startTest();
            Boolean hasAccess = DeliveryPortalAccessService.validateAccess('', entityA.Id);
            Test.stopTest();

            System.assertEquals(false, hasAccess, 'Blank email should return false');
        }
    }

    @IsTest
    static void testValidateAccessNullParams() {
        System.runAs(testUser) {
            Test.startTest();
            Boolean hasAccess = DeliveryPortalAccessService.validateAccess(null, null);
            Test.stopTest();

            System.assertEquals(false, hasAccess, 'Null params should return false');
        }
    }

    // -------------------------------------------------------------------------
    // generatePortalAccess tests
    // -------------------------------------------------------------------------

    @IsTest
    static void testGeneratePortalAccessNewRecord() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            Test.startTest();
            PortalAccess__c pa = DeliveryPortalAccessService.generatePortalAccess(
                entityA.Id, 'newuser@example.com', 'Admin'
            );
            Test.stopTest();

            System.assertNotEquals(null, pa.Id, 'Should return created record');
            System.assertEquals('newuser@example.com', pa.EmailTxt__c, 'Email should match');
            System.assertEquals('Admin', pa.RolePk__c, 'Role should be Admin');
            System.assertNotEquals(null, pa.AccessTokenTxt__c, 'Token should be generated');
            System.assert(pa.AccessTokenTxt__c.length() > 10, 'Token should be a substantial string');
        }
    }

    @IsTest
    static void testGeneratePortalAccessDefaultRole() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            Test.startTest();
            PortalAccess__c pa = DeliveryPortalAccessService.generatePortalAccess(
                entityA.Id, 'defaultrole@example.com', null
            );
            Test.stopTest();

            System.assertEquals('Member', pa.RolePk__c, 'Role should default to Member');
        }
    }

    @IsTest
    static void testGeneratePortalAccessExistingRecord() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            // multiuser@example.com already has access to Alpha Corp from TestSetup
            Test.startTest();
            PortalAccess__c pa = DeliveryPortalAccessService.generatePortalAccess(
                entityA.Id, 'multiuser@example.com', 'Member'
            );
            Test.stopTest();

            System.assertNotEquals(null, pa.Id, 'Should return the updated record');
            System.assertEquals('Member', pa.RolePk__c, 'Role should be updated to Member');
            System.assertNotEquals(null, pa.AccessTokenTxt__c, 'Token should be regenerated');
        }
    }

    @IsTest
    static void testGeneratePortalAccessNullEntityId() {
        System.runAs(testUser) {
            Boolean threw = false;
            try {
                DeliveryPortalAccessService.generatePortalAccess(null, 'test@test.com', 'Admin');
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assert(threw, 'Should throw for null entity Id');
        }
    }

    @IsTest
    static void testGeneratePortalAccessBlankEmail() {
        System.runAs(testUser) {
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Alpha Corp' LIMIT 1];

            Boolean threw = false;
            try {
                DeliveryPortalAccessService.generatePortalAccess(entityA.Id, '', 'Admin');
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assert(threw, 'Should throw for blank email');
        }
    }

    @IsTest
    static void testGeneratePortalAccessInvalidEntity() {
        System.runAs(testUser) {
            // Use a fake Id that won't match any real entity
            Id fakeId = NetworkEntity__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

            Boolean threw = false;
            try {
                DeliveryPortalAccessService.generatePortalAccess(fakeId, 'test@test.com', 'Admin');
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assert(threw, 'Should throw for invalid entity Id');
        }
    }
}
