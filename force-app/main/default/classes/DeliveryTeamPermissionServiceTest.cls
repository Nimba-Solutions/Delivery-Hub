/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryTeamPermissionService.
 *               Validates team lookup, granular permission checking,
 *               role-based defaults, and fallback behavior.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryTeamPermissionServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Team Test Entity',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        List<PortalAccess__c> accessRecords = new List<PortalAccess__c>{
            // Admin with no granular overrides — should use role defaults
            new PortalAccess__c(
                NetworkEntityLookup__c = entity.Id,
                EmailTxt__c = 'admin@example.com',
                RolePk__c = 'Admin'
            ),
            // Member with granular permissions override
            new PortalAccess__c(
                NetworkEntityLookup__c = entity.Id,
                EmailTxt__c = 'member-custom@example.com',
                RolePk__c = 'Member',
                PermissionsTxt__c = '["view_work_items","approve_work_logs"]'
            ),
            // Member with no overrides — should use role defaults
            new PortalAccess__c(
                NetworkEntityLookup__c = entity.Id,
                EmailTxt__c = 'member@example.com',
                RolePk__c = 'Member'
            )
        };
        insert accessRecords;
    }

    @IsTest
    static void testGetActiveTeamsReturnsCmtRecords() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> teams = DeliveryTeamPermissionService.getActiveTeams();
            Test.stopTest();

            // CMT records may or may not exist in scratch org; validate structure
            System.assertNotEquals(null, teams, 'Should return a non-null list');
        }
    }

    @IsTest
    static void testHasPermissionWithGranularOverride() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            // member-custom has explicit ["view_work_items","approve_work_logs"]
            Boolean hasView = DeliveryTeamPermissionService.hasPermission(
                'member-custom@example.com', entity.Id, 'view_work_items'
            );
            Boolean hasApprove = DeliveryTeamPermissionService.hasPermission(
                'member-custom@example.com', entity.Id, 'approve_work_logs'
            );
            Boolean hasSubmit = DeliveryTeamPermissionService.hasPermission(
                'member-custom@example.com', entity.Id, 'submit_requests'
            );
            Test.stopTest();

            System.assertEquals(true, hasView, 'Should have view_work_items from granular perms');
            System.assertEquals(true, hasApprove, 'Should have approve_work_logs from granular perms');
            System.assertEquals(false, hasSubmit, 'Should NOT have submit_requests — not in granular list');
        }
    }

    @IsTest
    static void testHasPermissionFallsBackToRoleDefaults() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            // admin@example.com has no granular overrides, role = Admin
            Boolean hasView = DeliveryTeamPermissionService.hasPermission(
                'admin@example.com', entity.Id, 'view_work_items'
            );
            Boolean hasManage = DeliveryTeamPermissionService.hasPermission(
                'admin@example.com', entity.Id, 'manage_portal_users'
            );
            Boolean hasBogus = DeliveryTeamPermissionService.hasPermission(
                'admin@example.com', entity.Id, 'bogus_permission'
            );
            Test.stopTest();

            System.assertEquals(true, hasView, 'Admin default should include view_work_items');
            System.assertEquals(true, hasManage, 'Admin default should include manage_portal_users');
            System.assertEquals(false, hasBogus, 'Admin default should NOT include bogus_permission');
        }
    }

    @IsTest
    static void testHasPermissionNoAccessRecord() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            Boolean result = DeliveryTeamPermissionService.hasPermission(
                'nonexistent@example.com', entity.Id, 'view_work_items'
            );
            Test.stopTest();

            System.assertEquals(false, result, 'Should return false when no access record exists');
        }
    }

    @IsTest
    static void testHasPermissionBlankInputs() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            Boolean nullEmail = DeliveryTeamPermissionService.hasPermission(null, entity.Id, 'view_work_items');
            Boolean blankEmail = DeliveryTeamPermissionService.hasPermission('', entity.Id, 'view_work_items');
            Boolean nullEntity = DeliveryTeamPermissionService.hasPermission('admin@example.com', null, 'view_work_items');
            Boolean nullPerm = DeliveryTeamPermissionService.hasPermission('admin@example.com', entity.Id, null);
            Test.stopTest();

            System.assertEquals(false, nullEmail, 'Null email should return false');
            System.assertEquals(false, blankEmail, 'Blank email should return false');
            System.assertEquals(false, nullEntity, 'Null entity should return false');
            System.assertEquals(false, nullPerm, 'Null permission should return false');
        }
    }

    @IsTest
    static void testGetPermissionsWithGranularOverride() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            List<String> perms = DeliveryTeamPermissionService.getPermissions(
                'member-custom@example.com', entity.Id
            );
            Test.stopTest();

            System.assertEquals(2, perms.size(), 'Should return 2 granular permissions');
            System.assert(perms.contains('view_work_items'), 'Should contain view_work_items');
            System.assert(perms.contains('approve_work_logs'), 'Should contain approve_work_logs');
        }
    }

    @IsTest
    static void testGetPermissionsRoleDefault() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            List<String> perms = DeliveryTeamPermissionService.getPermissions(
                'member@example.com', entity.Id
            );
            Test.stopTest();

            System.assertEquals(3, perms.size(), 'Member default should have 3 permissions');
            System.assert(perms.contains('view_work_items'), 'Should contain view_work_items');
            System.assert(perms.contains('submit_requests'), 'Should contain submit_requests');
            System.assert(perms.contains('view_documents'), 'Should contain view_documents');
        }
    }

    @IsTest
    static void testGetPermissionsNoAccess() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            Test.startTest();
            List<String> perms = DeliveryTeamPermissionService.getPermissions(
                'nonexistent@example.com', entity.Id
            );
            Test.stopTest();

            System.assertEquals(0, perms.size(), 'Should return empty list when no access record');
        }
    }

    @IsTest
    static void testGetPermissionsBlankInputs() {
        System.runAs(testUser) {
            Test.startTest();
            List<String> nullEmail = DeliveryTeamPermissionService.getPermissions(null, null);
            Test.stopTest();

            System.assertEquals(0, nullEmail.size(), 'Should return empty list for null inputs');
        }
    }

    @IsTest
    static void testGetDefaultPermissionsForRole() {
        System.runAs(testUser) {
            Test.startTest();
            List<String> adminPerms = DeliveryTeamPermissionService.getDefaultPermissionsForRole('Admin');
            List<String> memberPerms = DeliveryTeamPermissionService.getDefaultPermissionsForRole('Member');
            List<String> unknownPerms = DeliveryTeamPermissionService.getDefaultPermissionsForRole('Unknown');
            Test.stopTest();

            System.assertEquals(6, adminPerms.size(), 'Admin should have 6 default permissions');
            System.assertEquals(3, memberPerms.size(), 'Member should have 3 default permissions');
            System.assertEquals(0, unknownPerms.size(), 'Unknown role should return empty list');
        }
    }
}
