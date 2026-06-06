/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryCartService + CartExperienceProfile. Covers the
 *               cart query (Will Do + Sizing Only, excludes activated / Deferred /
 *               On Hold), add/remove/reorder, freeform create, checkout (activates
 *               Will Do ONLY — not Sizing Only), and the profile resolution matrix
 *               (dollars off by default; on when EnableCartDollarsDateTime__c set AND a
 *               rate exists; checkoutMode default Invoice). Never asserts on
 *               AuraHandledException.getMessage() (generic in managed package). SOQL is
 *               WITH SYSTEM_MODE; TestDataFactory defaults are allowlist-compliant.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryCartServiceTest {

    /**
     * @description Creates a permset-assigned user so the stripInaccessible-guarded
     *              service writes have edit-FLS in the namespaced packaging test
     *              context (the package-version-create test user has no permset, so
     *              the fields would otherwise be silently stripped). @TestSetup runs
     *              in its own transaction, so there is no MIXED_DML with the WorkItem
     *              DML the test methods do.
     */
    @TestSetup
    static void makeCartUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'cartu',
            Email = 'cart.test@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CartTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'cart.test.user.' + System.currentTimeMillis() + '@example.com.dhcart'
        );
        insert u;
        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App' LIMIT 1
        ];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
    }

    /**
     * @description The permset-assigned cart test user (see makeCartUser), used to
     *              call the stripInaccessible-guarded service writes with FLS.
     * @return The DeliveryHubAdmin_App-assigned User created in @TestSetup.
     */
    private static User cartUser() {
        return [
            SELECT Id FROM User
            WHERE UserName LIKE 'cart.test.user.%@example.com.dhcart'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
    }

    /**
     * @description Helper: a non-activated cart WorkItem with the given intention.
     * @param intention The ClientIntentionPk__c value to set.
     * @param hours The EstimatedHoursNumber__c value to set.
     * @return The inserted WorkItem__c.
     */
    private static WorkItem__c cartItem(String intention, Decimal hours) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'ClientIntentionPk__c' => intention,
            'EstimatedHoursNumber__c' => hours,
            'ActivatedDateTime__c' => null,
            'StageNamePk__c' => 'Backlog'
        });
    }

    @IsTest
    static void getCartReturnsOnlyNonActivatedCartIntentions() {
        WorkItem__c willDo = cartItem('Will Do', 10);
        WorkItem__c sizing = cartItem('Sizing Only', 5);
        // Excluded: Deferred, On Hold, and an activated Will Do.
        cartItem('Deferred', 8);
        cartItem('On Hold', 8);
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'ClientIntentionPk__c' => 'Will Do',
            'EstimatedHoursNumber__c' => 99,
            'ActivatedDateTime__c' => Datetime.now()
        });

        Test.startTest();
        DeliveryCartService.CartDTO cart = DeliveryCartService.getCart();
        Test.stopTest();

        System.assertEquals(2, cart.lines.size(), 'Only the 2 non-activated cart lines should return.');
        System.assertEquals(2, cart.summary.count, 'Summary count should match line count.');
        System.assertEquals(1, cart.summary.willDoCount, 'One Will Do line.');
        System.assertEquals(1, cart.summary.sizingOnlyCount, 'One Sizing Only line.');
        System.assertEquals(10, cart.summary.willDoHours, 'Will Do hours roll up.');
        System.assertEquals(5, cart.summary.sizingOnlyHours, 'Sizing Only hours roll up.');

        Set<Id> ids = new Set<Id>();
        for (DeliveryCartService.CartLineDTO line : cart.lines) {
            ids.add(line.workItemId);
        }
        System.assert(ids.contains(willDo.Id), 'Will Do line present.');
        System.assert(ids.contains(sizing.Id), 'Sizing Only line present.');
    }

    @IsTest
    static void addRemoveAndReorderUpdateIntentionAndPriority() {
        WorkItem__c wi = cartItem('Sizing Only', 4);
        User u = cartUser();

        Test.startTest();
        System.runAs(u) {
            DeliveryCartService.addToCart(wi.Id, 'Will Do');
            DeliveryCartService.reorder(wi.Id, 'High');
        }
        Test.stopTest();

        WorkItem__c after = [
            SELECT ClientIntentionPk__c, PriorityPk__c FROM WorkItem__c WHERE Id = :wi.Id
        ];
        System.assertEquals('Will Do', after.ClientIntentionPk__c, 'Intention promoted to Will Do.');
        System.assertEquals('High', after.PriorityPk__c, 'Priority reordered.');

        System.runAs(u) {
            DeliveryCartService.removeFromCart(wi.Id);
        }
        WorkItem__c removed = [SELECT ClientIntentionPk__c FROM WorkItem__c WHERE Id = :wi.Id];
        System.assertEquals('Deferred', removed.ClientIntentionPk__c, 'Remove sets Deferred (out of cart).');
    }

    @IsTest
    static void addToCartRejectsInvalidIntention() {
        WorkItem__c wi = cartItem('Sizing Only', 4);
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryCartService.addToCart(wi.Id, 'Bogus');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Invalid intention should throw.');
    }

    @IsTest
    static void createCartItemAddsNonActivatedLine() {
        User u = cartUser();
        Test.startTest();
        Id newId;
        System.runAs(u) {
            newId = DeliveryCartService.createCartItem('New cart work', 7, 'Sizing Only');
        }
        Test.stopTest();

        WorkItem__c created = [
            SELECT ClientIntentionPk__c, EstimatedHoursNumber__c, ActivatedDateTime__c,
                   BriefDescriptionTxt__c
            FROM WorkItem__c WHERE Id = :newId
        ];
        System.assertEquals('Sizing Only', created.ClientIntentionPk__c, 'Intention set.');
        System.assertEquals(7, created.EstimatedHoursNumber__c, 'Hours set.');
        System.assertEquals(null, created.ActivatedDateTime__c, 'Cart line not activated.');
        System.assertEquals('New cart work', created.BriefDescriptionTxt__c, 'Description set.');
    }

    @IsTest
    static void createCartItemRejectsOutOfCartIntention() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryCartService.createCartItem('x', 1, 'Deferred');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Deferred is not a valid add intention.');
    }

    @IsTest
    static void checkoutActivatesWillDoOnlyNotSizingOnly() {
        WorkItem__c willDo = cartItem('Will Do', 12);
        WorkItem__c sizing = cartItem('Sizing Only', 6);
        User u = cartUser();

        Test.startTest();
        DeliveryCartService.CheckoutResultDTO result;
        System.runAs(u) {
            result = DeliveryCartService.checkout();
        }
        Test.stopTest();

        System.assertEquals(1, result.activatedCount, 'Only the Will Do line activates.');

        WorkItem__c willDoAfter = [SELECT ActivatedDateTime__c FROM WorkItem__c WHERE Id = :willDo.Id];
        WorkItem__c sizingAfter = [SELECT ActivatedDateTime__c FROM WorkItem__c WHERE Id = :sizing.Id];
        System.assertNotEquals(null, willDoAfter.ActivatedDateTime__c, 'Will Do line activated.');
        System.assertEquals(null, sizingAfter.ActivatedDateTime__c, 'Sizing Only stays in the cart.');
    }

    @IsTest
    static void checkoutWithNoWillDoLinesIsNoOp() {
        cartItem('Sizing Only', 6);
        Test.startTest();
        DeliveryCartService.CheckoutResultDTO result = DeliveryCartService.checkout();
        Test.stopTest();
        System.assertEquals(0, result.activatedCount, 'Nothing to check out.');
    }

    @IsTest
    static void profileDefaultsDollarsOffModeInvoice() {
        // No settings, no rate.
        Test.startTest();
        CartExperienceProfile profile = CartExperienceProfile.resolve();
        Test.stopTest();
        System.assertEquals(false, profile.showDollars, 'Dollars off by default.');
        System.assertEquals(false, profile.selfServe, 'Self-serve off by default.');
        System.assertEquals('Invoice', profile.checkoutMode, 'Mode defaults to Invoice.');
    }

    @IsTest
    static void profileDollarsOnWhenOptInAndRateExists() {
        // A single active rated NetworkEntity -> resolvable blended rate.
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 90,
            'StatusPk__c' => 'Active'
        });
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableCartDollarsDateTime__c = Datetime.now(),
            EnableCartSelfServeDateTime__c = Datetime.now(),
            CheckoutModeTxt__c = 'Stripe'
        );
        insert settings;

        Test.startTest();
        CartExperienceProfile profile = CartExperienceProfile.resolve();
        Test.stopTest();

        System.assertEquals(true, profile.showDollars, 'Dollars on with opt-in + rate.');
        System.assertEquals(90, profile.blendedRate, 'Blended rate resolved.');
        System.assertEquals(true, profile.selfServe, 'Self-serve on.');
        System.assertEquals('Stripe', profile.checkoutMode, 'Mode honored.');
    }

    @IsTest
    static void profileDollarsOffWhenOptInButNoRate() {
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableCartDollarsDateTime__c = Datetime.now()
        );
        insert settings;

        Test.startTest();
        CartExperienceProfile profile = CartExperienceProfile.resolve();
        Test.stopTest();

        System.assertEquals(false, profile.showDollars, 'No rate => hours-only even with opt-in.');
        System.assertEquals(null, profile.blendedRate, 'No single rate resolvable.');
    }

    @IsTest
    static void normalizeModeValidatesValues() {
        System.assertEquals('Invoice', CartExperienceProfile.normalizeMode(null), 'Blank => Invoice.');
        System.assertEquals('Invoice', CartExperienceProfile.normalizeMode(''), 'Empty => Invoice.');
        System.assertEquals('Invoice', CartExperienceProfile.normalizeMode('whatever'), 'Unknown => Invoice.');
        System.assertEquals('Approve', CartExperienceProfile.normalizeMode('approve'), 'Case-insensitive Approve.');
        System.assertEquals('Stripe', CartExperienceProfile.normalizeMode('STRIPE'), 'Case-insensitive Stripe.');
        System.assertEquals('Invoice', CartExperienceProfile.normalizeMode('Invoice'), 'Invoice passes through.');
    }
}
