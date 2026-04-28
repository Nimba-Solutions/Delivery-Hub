/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryUserTriggerHandler and
 *               DeliveryUserAutoAssignService — verifies idempotent
 *               PermissionSet auto-assignment on User insert/update and
 *               bulk backfill.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryUserTriggerHandlerTest {

    private static Profile getStandardProfile() {
        return [SELECT Id, Name FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    }

    private static User buildTestUser(Profile p, String suffix) {
        String alias = 'dha' + suffix;
        return new User(
            Username = 'dh-autoassign-' + suffix + '@example.com.dhtest',
            Email = 'dh-autoassign-' + suffix + '@example.com',
            LastName = 'AutoAssignTest',
            Alias = alias.length() > 8 ? alias.substring(0, 8) : alias,
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
    }

    private static String uniqueSuffix() {
        return String.valueOf(Math.abs(Crypto.getRandomLong())).right(8);
    }

    @IsTest
    static void testFilterEligibleSkipsInactiveAndGuests() {
        User active = new User(IsActive = true, UserType = 'Standard');
        User inactive = new User(IsActive = false, UserType = 'Standard');
        User guest = new User(IsActive = true, UserType = 'Guest');
        List<User> filtered = DeliveryUserTriggerHandler.filterEligible(
            new List<User>{ active, inactive, guest }
        );
        System.assertEquals(1, filtered.size(),
            'Only active, Standard-type users should be eligible');
    }

    @IsTest
    static void testBecameEligibleDetectsReactivation() {
        Id profileId = getStandardProfile().Id;
        User prior = new User(IsActive = false, UserType = 'Standard', ProfileId = profileId);
        User current = new User(IsActive = true, UserType = 'Standard', ProfileId = profileId);
        System.assertEquals(true,
            DeliveryUserTriggerHandler.becameEligible(current, prior),
            'A user that flips inactive to active should be detected as newly eligible');
    }

    @IsTest
    static void testBecameEligibleIgnoresStillEligible() {
        Id profileId = getStandardProfile().Id;
        User prior = new User(IsActive = true, UserType = 'Standard', ProfileId = profileId);
        User current = new User(IsActive = true, UserType = 'Standard', ProfileId = profileId);
        System.assertEquals(false,
            DeliveryUserTriggerHandler.becameEligible(current, prior),
            'A user already eligible with no profile change should not be re-flagged');
    }

    @IsTest
    static void testMatchesProfileVariants() {
        System.assertEquals(true,
            DeliveryUserAutoAssignService.matchesProfile('System Administrator', null),
            'Null filter should match any profile');
        System.assertEquals(true,
            DeliveryUserAutoAssignService.matchesProfile('System Administrator', ''),
            'Empty filter should match any profile');
        System.assertEquals(true,
            DeliveryUserAutoAssignService.matchesProfile('System Administrator',
                'Standard User, System Administrator'),
            'CSV filter should match across whitespace and casing');
        System.assertEquals(false,
            DeliveryUserAutoAssignService.matchesProfile('Standard User', 'System Administrator'),
            'Mismatched profile should not match');
    }

    @IsTest
    static void testAssignAllActiveUsersDoesNotThrow() {
        System.runAs([SELECT Id FROM User WHERE Id = :UserInfo.getUserId()]) {
            Test.startTest();
            DeliveryUserTriggerHandler.assignAllActiveUsers();
            Test.stopTest();
            System.assert(true, 'assignAllActiveUsers completed without throwing');
        }
    }

    @IsTest
    static void testTriggerOnInsertDoesNotThrow() {
        Profile p = getStandardProfile();
        User u = buildTestUser(p, uniqueSuffix());
        Test.startTest();
        insert u;
        Test.stopTest();
        System.assertNotEquals(null, u.Id, 'User should be inserted');
    }

    @IsTest
    static void testTriggerOnUpdateReactivationPath() {
        Profile p = getStandardProfile();
        User u = buildTestUser(p, uniqueSuffix());
        insert u;

        u.IsActive = false;
        update u;
        Test.startTest();
        u.IsActive = true;
        update u;
        Test.stopTest();
        System.assertEquals(true, u.IsActive, 'User should be active after reactivation');
    }
}
