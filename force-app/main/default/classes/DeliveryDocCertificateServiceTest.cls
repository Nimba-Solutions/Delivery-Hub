/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocCertificateService and the
 *               DeliveryDocActionController.getCertificateOfCompletion facade.
 *               Covers empty / partial / fully signed scenarios and verifies that
 *               the hash chain head materializes correctly across multiple signers.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
private class DeliveryDocCertificateServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        // Enable admin signing for these tests
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                EnableAdminSigningDateTime__c = Datetime.now()
            );
            insert settings;
        } else {
            settings.EnableAdminSigningDateTime__c = Datetime.now();
            update settings;
        }

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Cert Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 200
        );
        insert entity;

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Client_Agreement',
            PeriodStartDate__c = Date.newInstance(2026, 4, 1),
            PeriodEndDate__c = Date.newInstance(2026, 4, 30),
            PublicTokenTxt__c = 'cc44dd55ee66ff77aa88bb99cc44dd55ee66ff77aa88bb99cc44dd55ee66ff77',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 5000,
            RequireSigningDateTime__c = Datetime.now(),
            DocumentHashTxt__c = 'fakehash000000000000000000000000000000000000000000000000000000ff'
        );
        insert doc;

        Map<String, Object> snapshot = new Map<String, Object>{
            'entity' => new Map<String, Object>{ 'id' => entity.Id, 'name' => entity.Name }
        };
        DeliveryDocActionService.createSlotsForTemplate(doc.Id, 'Client_Agreement', snapshot);

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DeliveryDocument__c getDoc() {
        return [
            SELECT Id, StatusPk__c, DocumentHashTxt__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'cc44dd55ee66ff77aa88bb99cc44dd55ee66ff77aa88bb99cc44dd55ee66ff77'
            LIMIT 1
        ];
    }

    private static List<DocumentAction__c> getActions(Id documentId) {
        return [
            SELECT Id FROM DocumentAction__c
            WHERE DocumentId__c = :documentId
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ];
    }

    private static Map<String, Object> signPayload(String name) {
        return new Map<String, Object>{
            'signerName'   => name,
            'consentGiven' => true
        };
    }

    @IsTest
    static void testBuildCertificateForUnsignedDocReturnsEmptySigners() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            Map<String, Object> cert = DeliveryDocCertificateService.buildCertificate(doc.Id);
            Test.stopTest();

            System.assertEquals(doc.Id, cert.get('documentId'), 'Should echo document Id');
            System.assertEquals(doc.DocumentHashTxt__c, cert.get('documentHash'),
                'Should surface the document hash');
            System.assertEquals(false, cert.get('allSigned'),
                'Unsigned document should not be flagged allSigned');
            System.assertEquals(2, cert.get('pendingCount'),
                'Both slots should be reported as pending');
            List<Object> signers = (List<Object>) cert.get('signers');
            System.assertEquals(0, signers.size(),
                'No completed signers yet');
            System.assertEquals(null, cert.get('chainHead'),
                'Chain head should be null with no signers');
        }
    }

    @IsTest
    static void testBuildCertificatePartiallySignedReportsOneSigner() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;

            Test.startTest();
            DeliveryDocActionController.signActionAdmin(firstActionId, signPayload('Glen Bradford'));
            Map<String, Object> cert = DeliveryDocCertificateService.buildCertificate(doc.Id);
            Test.stopTest();

            System.assertEquals(false, cert.get('allSigned'),
                'Half-signed should not be allSigned');
            System.assertEquals(1, cert.get('pendingCount'),
                'One slot should still be pending');
            List<Object> signers = (List<Object>) cert.get('signers');
            System.assertEquals(1, signers.size(),
                'One completed signer');
            Map<String, Object> first = (Map<String, Object>) signers[0];
            System.assertEquals('Glen Bradford', first.get('signerName'));
            System.assertNotEquals(null, first.get('priorHash'),
                'Phase 4: priorHash should be materialized from the audit log');
            System.assertNotEquals(null, cert.get('chainHead'),
                'Chain head should be set after first signature');
            System.assertEquals(first.get('priorHash'), cert.get('chainHead'),
                'Chain head should equal the only signer hash');
        }
    }

    @IsTest
    static void testBuildCertificateFullySignedReportsAllSignersInOrder() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            List<DocumentAction__c> actions = getActions(doc.Id);

            Test.startTest();
            DeliveryDocActionController.signActionAdmin(actions[0].Id, signPayload('Consultant Signer'));
            DeliveryDocActionController.signActionAdmin(actions[1].Id, signPayload('Client Signer'));
            Map<String, Object> cert = DeliveryDocCertificateService.buildCertificate(doc.Id);
            Test.stopTest();

            System.assertEquals(true, cert.get('allSigned'),
                'All slots completed should be allSigned');
            System.assertEquals(0, cert.get('pendingCount'),
                'No pending slots remain');
            List<Object> signers = (List<Object>) cert.get('signers');
            System.assertEquals(2, signers.size(),
                'Two completed signers');

            Map<String, Object> first = (Map<String, Object>) signers[0];
            Map<String, Object> second = (Map<String, Object>) signers[1];
            System.assertEquals('Consultant Signer', first.get('signerName'),
                'First by sort order should be the consultant');
            System.assertEquals('Client Signer', second.get('signerName'),
                'Second by sort order should be the client');

            System.assertNotEquals(null, first.get('priorHash'),
                'First signer should have a hash');
            System.assertNotEquals(null, second.get('priorHash'),
                'Second signer should have a hash');
            System.assertNotEquals(first.get('priorHash'), second.get('priorHash'),
                'Each signer should chain a different hash forward');
            System.assertEquals(second.get('priorHash'), cert.get('chainHead'),
                'Chain head should equal the most recent signer hash');
        }
    }

    @IsTest
    static void testBuildCertificateThrowsForMissingDocument() {
        System.runAs(testUser) {
            Test.startTest();
            try {
                DeliveryDocCertificateService.buildCertificate(null);
                System.assert(false, 'Expected AuraHandledException for null document Id');
            } catch (AuraHandledException e) {
                System.assertNotEquals(null, e, 'Expected exception instance');
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetCertificateOfCompletionFacade() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Id firstActionId = getActions(doc.Id)[0].Id;
            DeliveryDocActionController.signActionAdmin(firstActionId, signPayload('Test Signer'));

            Test.startTest();
            Map<String, Object> cert = DeliveryDocActionController.getCertificateOfCompletion(doc.Id);
            Test.stopTest();

            System.assertNotEquals(null, cert, 'Facade should return the certificate');
            System.assertEquals(doc.Id, cert.get('documentId'),
                'Facade should pass through to the service');
            List<Object> signers = (List<Object>) cert.get('signers');
            System.assertEquals(1, signers.size(),
                'Facade should reflect one signed slot');
        }
    }
}
