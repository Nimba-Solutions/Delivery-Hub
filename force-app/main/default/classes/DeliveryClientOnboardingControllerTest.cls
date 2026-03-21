/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryClientOnboardingController.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@isTest
private class DeliveryClientOnboardingControllerTest {

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.runAfterLogic = false;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Cloud Nimbus LLC',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;
    }

    private static DeliveryClientOnboardingController.OnboardingRequest buildRequest(
        String name, String email, Decimal rate
    ) {
        DeliveryClientOnboardingController.OnboardingRequest req =
            new DeliveryClientOnboardingController.OnboardingRequest();
        req.clientName = name;
        req.contactEmail = email;
        req.hourlyRate = rate;
        return req;
    }

    @isTest
    static void testOnboardClientSuccess() {
        DeliveryClientOnboardingController.OnboardingRequest req =
            buildRequest('Acme Corp', 'ceo@acme.com', 150.00);
        req.contactPhone = '555-1234';
        req.address = '100 Main St';

        Test.startTest();
        Map<String, Object> result = DeliveryClientOnboardingController.onboardClient(req);
        Test.stopTest();

        System.assertNotEquals(null, result.get('entityId'), 'Should return entity ID');
        System.assertNotEquals(null, result.get('documentId'), 'Should return document ID');
        System.assertNotEquals(null, result.get('documentName'), 'Should return document name');
        System.assertNotEquals(null, result.get('publicToken'), 'Should return public token');

        // Verify entity was created correctly
        NetworkEntity__c entity = [
            SELECT Name, EntityTypePk__c, StatusPk__c, DefaultHourlyRateCurrency__c,
                   ContactEmailTxt__c, ContactPhoneTxt__c, AddressTxt__c
            FROM NetworkEntity__c WHERE Id = :(Id)result.get('entityId')
        ];
        System.assertEquals('Acme Corp', entity.Name, 'Entity name should match');
        System.assertEquals('Client', entity.EntityTypePk__c, 'Should be Client type');
        System.assertEquals('Active', entity.StatusPk__c, 'Should be Active');
        System.assertEquals(150.00, entity.DefaultHourlyRateCurrency__c, 'Rate should match');
        System.assertEquals('ceo@acme.com', entity.ContactEmailTxt__c, 'Email should match');
        System.assertEquals('555-1234', entity.ContactPhoneTxt__c, 'Phone should match');
        System.assertEquals('100 Main St', entity.AddressTxt__c, 'Address should match');

        // Verify agreement was generated
        DeliveryDocument__c doc = [
            SELECT TemplatePk__c, StatusPk__c, MetadataTxt__c
            FROM DeliveryDocument__c WHERE Id = :(Id)result.get('documentId')
        ];
        System.assertEquals('Client_Agreement', doc.TemplatePk__c, 'Should be Client Agreement');
        System.assertEquals('Draft', doc.StatusPk__c, 'Should be Draft');
        System.assert(doc.MetadataTxt__c.contains('clauses'), 'Should have agreement clauses');
    }

    @isTest
    static void testOnboardClientMinimalFields() {
        DeliveryClientOnboardingController.OnboardingRequest req =
            buildRequest('Minimal Corp', 'hi@minimal.com', 90.00);

        Test.startTest();
        Map<String, Object> result = DeliveryClientOnboardingController.onboardClient(req);
        Test.stopTest();

        System.assertNotEquals(null, result.get('entityId'), 'Should create entity with minimal fields');
    }

    @isTest
    static void testOnboardClientDuplicateName() {
        DeliveryTriggerControl.runAfterLogic = false;
        insert new NetworkEntity__c(
            Name = 'Existing Corp', EntityTypePk__c = 'Client', StatusPk__c = 'Active'
        );

        DeliveryClientOnboardingController.OnboardingRequest req =
            buildRequest('Existing Corp', 'test@test.com', 100.00);

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryClientOnboardingController.onboardClient(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw for duplicate entity name');
    }

    @isTest
    static void testOnboardClientMissingName() {
        DeliveryClientOnboardingController.OnboardingRequest req =
            buildRequest('', 'test@test.com', 100.00);

        Boolean threw = false;
        try {
            DeliveryClientOnboardingController.onboardClient(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for blank name');
    }

    @isTest
    static void testOnboardClientMissingEmail() {
        DeliveryClientOnboardingController.OnboardingRequest req =
            buildRequest('Test Corp', '', 100.00);

        Boolean threw = false;
        try {
            DeliveryClientOnboardingController.onboardClient(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for blank email');
    }

    @isTest
    static void testOnboardClientInvalidRate() {
        DeliveryClientOnboardingController.OnboardingRequest req =
            buildRequest('Test Corp', 'test@test.com', -50.00);

        Boolean threw = false;
        try {
            DeliveryClientOnboardingController.onboardClient(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for negative rate');
    }

    @isTest
    static void testGetExistingClients() {
        DeliveryTriggerControl.runAfterLogic = false;
        insert new NetworkEntity__c(
            Name = 'Client A', EntityTypePk__c = 'Client', StatusPk__c = 'Active'
        );

        Test.startTest();
        List<Map<String, String>> clients = DeliveryClientOnboardingController.getExistingClients();
        Test.stopTest();

        System.assert(clients.size() >= 1, 'Should return at least 1 client');
        Boolean found = false;
        for (Map<String, String> c : clients) {
            if (c.get('name') == 'Client A') {
                found = true;
            }
        }
        System.assert(found, 'Should include Client A');
    }
}
