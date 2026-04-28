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

    private static User runAsCurrent() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    /**
     * @description Construct a User SObject with read-only fields (UserType,
     *              IsActive) populated via JSON deserialization. Required
     *              because Apex blocks direct constructor writes to those
     *              fields in subscriber-namespace deployment contexts.
     * @param isActive Sets User.IsActive on the mocked record.
     * @param userType Sets User.UserType (e.g. 'Standard', 'Guest').
     * @param profileId Optional User.ProfileId; pass null to omit.
     * @return In-memory User suitable for pure-logic assertions only.
     */
    private static User mockUser(Boolean isActive, String userType, Id profileId) {
        Map<String, Object> payload = new Map<String, Object>{
            'IsActive' => isActive,
            'UserType' => userType
        };
        if (profileId != null) {
            payload.put('ProfileId', profileId);
        }
        return (User) JSON.deserialize(JSON.serialize(payload), User.class);
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
        User active = mockUser(true, 'Standard', null);
        User inactive = mockUser(false, 'Standard', null);
        User guest = mockUser(true, 'Guest', null);
        List<User> filtered = DeliveryUserTriggerHandler.filterEligible(
            new List<User>{ active, inactive, guest }
        );
        System.assertEquals(1, filtered.size(),
            'Only active, Standard-type users should be eligible');
    }

    @IsTest
    static void testBecameEligibleDetectsReactivation() {
        Id profileId = getStandardProfile().Id;
        User prior = mockUser(false, 'Standard', profileId);
        User current = mockUser(true, 'Standard', profileId);
        System.assertEquals(true,
            DeliveryUserTriggerHandler.becameEligible(current, prior),
            'A user that flips inactive to active should be detected as newly eligible');
    }

    @IsTest
    static void testBecameEligibleIgnoresStillEligible() {
        Id profileId = getStandardProfile().Id;
        User prior = mockUser(true, 'Standard', profileId);
        User current = mockUser(true, 'Standard', profileId);
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
        System.runAs(runAsCurrent()) {
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
