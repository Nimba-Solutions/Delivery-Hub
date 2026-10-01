/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryAccessService: the org admin running the
 *               tests is an admin; a plain Standard User is neither admin nor
 *               approver until named as the approver / backup approver in
 *               DeliveryHubSettings__c; malformed ids in settings are ignored.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryAccessServiceTest {

    private static User createStandardUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String stamp = String.valueOf(Datetime.now().getTime())
            + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6);
        User u = new User(
            Alias = alias, Email = alias + stamp + '@example.com',
            EmailEncodingKey = 'UTF-8', LastName = 'Access',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
            ProfileId = p.Id, TimeZoneSidKey = 'America/New_York',
            Username = alias + stamp + '@example.com.dhtest'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    private static void setApprovers(String primary, String backup) {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.ApproverUserIdTxt__c = primary;
        s.ApproverBackupUserIdTxt__c = backup;
        upsert s;
    }

    @IsTest
    static void runningAdminIsAdminAndApprover() {
        // The deploying/test-running user is a System Administrator
        // (Modify All Data + Customize Application on the profile).
        System.assertEquals(true, DeliveryAccessService.isAdmin(), 'org admin should be an admin');
        System.assertEquals(true, DeliveryAccessService.isApproverOrAdmin(), 'admin is always allowed to approve');
        DeliveryAccessService.requireAdmin('do admin things');
        DeliveryAccessService.requireApproverOrAdmin('approve hours');
    }

    @IsTest
    static void standardUserIsNeitherUntilNamedApprover() {
        User u = createStandardUser('dhacc1');
        Boolean deniedAdmin = false;
        Boolean deniedApprover = false;
        System.runAs(u) {
            System.assertEquals(false, DeliveryAccessService.isAdmin(), 'standard user is not an admin');
            System.assertEquals(false, DeliveryAccessService.isApproverOrAdmin(), 'standard user is not an approver');
            try {
                DeliveryAccessService.requireAdmin('change settings');
            } catch (AuraHandledException e) {
                deniedAdmin = true;
            }
            try {
                DeliveryAccessService.requireApproverOrAdmin('approve hours');
            } catch (AuraHandledException e) {
                deniedApprover = true;
            }
        }
        System.assertEquals(true, deniedAdmin, 'requireAdmin should throw for a standard user');
        System.assertEquals(true, deniedApprover, 'requireApproverOrAdmin should throw for a standard user');

        setApprovers(String.valueOf(u.Id), null);
        System.runAs(u) {
            System.assertEquals(true, DeliveryAccessService.isApproverOrAdmin(), 'named approver may decide');
            System.assertEquals(false, DeliveryAccessService.isAdmin(), 'being the approver does not make you an admin');
        }
    }

    @IsTest
    static void backupApproverCountsAndBadIdsAreIgnored() {
        User u = createStandardUser('dhacc2');
        setApprovers('not-an-id', String.valueOf(u.Id));
        System.runAs(u) {
            System.assertEquals(true, DeliveryAccessService.isApproverOrAdmin(), 'backup approver may decide');
        }
        System.assertEquals(false, DeliveryAccessService.isConfiguredApprover(null), 'null user is never an approver');
        System.assertEquals(false, DeliveryAccessService.isConfiguredApprover(UserInfo.getUserId()),
            'malformed primary id and a different backup do not match the admin');
    }

    @IsTest
    static void adminOverrideSeamForcesTheAnswer() {
        DeliveryAccessService.adminOverride = false;
        System.assertEquals(false, DeliveryAccessService.isAdmin(), 'override false wins over the real check');
        DeliveryAccessService.adminOverride = true;
        System.assertEquals(true, DeliveryAccessService.isAdmin(), 'override true wins over the real check');
    }
}
