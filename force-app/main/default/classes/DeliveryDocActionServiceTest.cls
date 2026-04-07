/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocActionService.
 *               Covers templateRequiresSigning, createSlotsForTemplate slot creation,
 *               auto-assignment of vendor and customer entities, signer token uniqueness,
 *               and end-to-end integration with DeliveryDocGenerationService.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc, PMD.MethodNamingConventions')
private class DeliveryDocActionServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Action Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 150
        );
        insert entity;

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Client_Agreement',
            PeriodStartDate__c = Date.newInstance(2026, 1, 1),
            PeriodEndDate__c = Date.newInstance(2026, 1, 31),
            PublicTokenTxt__c = 'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44',
            StatusPk__c = 'Draft',
            TotalCurrency__c = 0
        );
        insert doc;

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DeliveryDocument__c getDoc() {
        return [
            SELECT Id, NetworkEntityId__c, TemplatePk__c, RequireSigningDateTime__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44'
            LIMIT 1
        ];
    }

    private static NetworkEntity__c getEntity() {
        return [SELECT Id, Name FROM NetworkEntity__c WHERE Name = 'Action Test Client' LIMIT 1];
    }

    @IsTest
    static void testTemplateRequiresSigningTrue() {
        System.runAs(testUser) {
            Test.startTest();
            Boolean result = DeliveryDocActionService.templateRequiresSigning('Client_Agreement');
            Test.stopTest();
            System.assertEquals(true, result, 'Client_Agreement should require signing');
        }
    }

    @IsTest
    static void testTemplateRequiresSigningFalseForInvoice() {
        System.runAs(testUser) {
            Test.startTest();
            Boolean result = DeliveryDocActionService.templateRequiresSigning('Invoice');
            Test.stopTest();
            System.assertEquals(false, result, 'Invoice should not require signing');
        }
    }

    @IsTest
    static void testTemplateRequiresSigningBlankReturnsFalse() {
        System.runAs(testUser) {
            System.assertEquals(false, DeliveryDocActionService.templateRequiresSigning(null), 'Null template should return false');
            System.assertEquals(false, DeliveryDocActionService.templateRequiresSigning(''), 'Blank template should return false');
        }
    }

    @IsTest
    static void testCreateSlotsForClientAgreement() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            NetworkEntity__c entity = getEntity();
            Map<String, Object> snapshot = new Map<String, Object>{
                'entity' => new Map<String, Object>{ 'id' => entity.Id, 'name' => entity.Name }
            };

            Test.startTest();
            List<DocumentAction__c> created = DeliveryDocActionService.createSlotsForTemplate(
                doc.Id, 'Client_Agreement', snapshot
            );
            Test.stopTest();

            System.assertEquals(2, created.size(), 'Client_Agreement should create 2 slots (consultant, client)');

            List<DocumentAction__c> slots = DeliveryDocActionService.getActionsForDocument(doc.Id);
            System.assertEquals(2, slots.size(), 'Should query back 2 slots');
            System.assertEquals('Sign as Consultant', slots[0].ActionLabelTxt__c, 'First slot should be Consultant');
            System.assertEquals(1, slots[0].SortOrderNumber__c, 'Consultant should have sort order 1');
            System.assertEquals('Pending', slots[0].StatusPk__c, 'New slots should be Pending');
            System.assertEquals('Text', slots[0].SignatureTypePk__c, 'New slots should default to Text type');
            System.assertNotEquals(null, slots[0].SignerTokenTxt__c, 'Signer token should be populated');
            System.assertEquals(64, slots[0].SignerTokenTxt__c.length(), 'Signer token should be 64 chars');

            System.assertEquals('Sign as Client', slots[1].ActionLabelTxt__c, 'Second slot should be Client');
            System.assertEquals(2, slots[1].SortOrderNumber__c, 'Client should have sort order 2');
            System.assertEquals(entity.Id, slots[1].AssignedEntityLookup__c, 'Client slot should auto-assign to customer entity');
        }
    }

    @IsTest
    static void testCreateSlotsForInvoiceCreatesNothing() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Map<String, Object> snapshot = new Map<String, Object>{
                'entity' => new Map<String, Object>{ 'id' => doc.NetworkEntityId__c }
            };

            Test.startTest();
            List<DocumentAction__c> created = DeliveryDocActionService.createSlotsForTemplate(
                doc.Id, 'Invoice', snapshot
            );
            Test.stopTest();

            System.assertEquals(0, created.size(), 'Invoice should create zero slots');
            System.assertEquals(0, DeliveryDocActionService.getActionsForDocument(doc.Id).size(), 'No slots should exist for Invoice');
        }
    }

    @IsTest
    static void testCreateSlotsForUnknownTemplate() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();

            Test.startTest();
            List<DocumentAction__c> created = DeliveryDocActionService.createSlotsForTemplate(
                doc.Id, 'NonexistentTemplate', new Map<String, Object>()
            );
            Test.stopTest();

            System.assertEquals(0, created.size(), 'Unknown template should create zero slots');
        }
    }

    @IsTest
    static void testCreateSlotsWithNullDocumentId() {
        System.runAs(testUser) {
            Test.startTest();
            List<DocumentAction__c> created = DeliveryDocActionService.createSlotsForTemplate(
                null, 'Client_Agreement', new Map<String, Object>()
            );
            Test.stopTest();
            System.assertEquals(0, created.size(), 'Null document Id should create zero slots');
        }
    }

    @IsTest
    static void testSignerTokenUniquenessAcrossSlots() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            NetworkEntity__c entity = getEntity();
            Map<String, Object> snapshot = new Map<String, Object>{
                'entity' => new Map<String, Object>{ 'id' => entity.Id }
            };

            Test.startTest();
            List<DocumentAction__c> first = DeliveryDocActionService.createSlotsForTemplate(
                doc.Id, 'Client_Agreement', snapshot
            );
            Test.stopTest();

            Set<String> tokens = new Set<String>();
            for (DocumentAction__c a : first) {
                System.assertNotEquals(null, a.SignerTokenTxt__c, 'Token must not be null');
                tokens.add(a.SignerTokenTxt__c);
            }
            System.assertEquals(first.size(), tokens.size(), 'All signer tokens must be unique within a document');
        }
    }

    @IsTest
    static void testGenerateSignerTokenIsHex() {
        System.runAs(testUser) {
            String token = DeliveryDocActionService.generateSignerToken();
            System.assertNotEquals(null, token, 'Token must not be null');
            System.assertEquals(64, token.length(), 'Token should be 64 hex chars');
            System.assert(Pattern.matches('[0-9a-fA-F]+', token), 'Token should be hex characters');
        }
    }

    @IsTest
    static void testGetActionsForNullDocumentId() {
        System.runAs(testUser) {
            System.assertEquals(0, DeliveryDocActionService.getActionsForDocument(null).size(), 'Null doc id should return empty list');
        }
    }

    @IsTest
    static void testIntegrationWithGenerationService() {
        System.runAs(testUser) {
            NetworkEntity__c entity = getEntity();

            Test.startTest();
            Id generatedDocId = DeliveryDocGenerationService.generateDocument(
                entity.Id,
                'Client_Agreement',
                Date.newInstance(2026, 2, 1),
                Date.newInstance(2026, 2, 28),
                null
            );
            Test.stopTest();

            System.assertNotEquals(null, generatedDocId, 'Generated document Id should be returned');

            DeliveryDocument__c generated = [
                SELECT Id, RequireSigningDateTime__c, TemplatePk__c
                FROM DeliveryDocument__c
                WHERE Id = :generatedDocId
                LIMIT 1
            ];
            System.assertNotEquals(null, generated.RequireSigningDateTime__c, 'Agreement should be flagged as requiring signing');

            List<DocumentAction__c> slots = DeliveryDocActionService.getActionsForDocument(generatedDocId);
            System.assertEquals(2, slots.size(), 'Generation should auto-create 2 slots for Client_Agreement');
        }
    }

    @IsTest
    static void testIntegrationWithGenerationServiceForInvoice() {
        System.runAs(testUser) {
            NetworkEntity__c entity = getEntity();

            Test.startTest();
            Id generatedDocId = DeliveryDocGenerationService.generateDocument(
                entity.Id,
                'Invoice',
                Date.newInstance(2026, 2, 1),
                Date.newInstance(2026, 2, 28),
                null
            );
            Test.stopTest();

            DeliveryDocument__c generated = [
                SELECT Id, RequireSigningDateTime__c
                FROM DeliveryDocument__c
                WHERE Id = :generatedDocId
                LIMIT 1
            ];
            System.assertEquals(null, generated.RequireSigningDateTime__c, 'Invoice should not be flagged as requiring signing');

            List<DocumentAction__c> slots = DeliveryDocActionService.getActionsForDocument(generatedDocId);
            System.assertEquals(0, slots.size(), 'Invoice should have zero slots');
        }
    }
}
