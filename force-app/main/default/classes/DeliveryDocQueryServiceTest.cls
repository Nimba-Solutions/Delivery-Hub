/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocQueryService.
 *               Covers getDocumentByToken, getDocumentById, getDocumentsForEntity,
 *               first-view status transition, getPendingInvoices, getTransactionsForDocument,
 *               getTotalPaid, and getDefaultBillingEntityId.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryDocQueryServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Query Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            DefaultHourlyRateCurrency__c = 100
        );
        insert entity;

        // Draft document
        DeliveryDocument__c draftDoc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Invoice',
            PeriodStartDate__c = Date.newInstance(2026, 3, 1),
            PeriodEndDate__c = Date.newInstance(2026, 3, 31),
            PublicTokenTxt__c = 'qry00001qry00001qry00001qry00001qry00001qry00001qry00001qry0001a',
            StatusPk__c = 'Draft',
            TotalHoursNumber__c = 20,
            TotalCurrency__c = 2000
        );

        // Sent document (for viewing test)
        DeliveryDocument__c sentDoc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Invoice',
            PeriodStartDate__c = Date.newInstance(2026, 2, 1),
            PeriodEndDate__c = Date.newInstance(2026, 2, 28),
            PublicTokenTxt__c = 'qry00002qry00002qry00002qry00002qry00002qry00002qry00002qry0002b',
            StatusPk__c = 'Sent',
            SentDateTime__c = Datetime.now().addDays(-3),
            TotalHoursNumber__c = 30,
            TotalCurrency__c = 3000
        );

        insert new List<DeliveryDocument__c>{ draftDoc, sentDoc };

        // Create a transaction for the sent doc
        insert new DeliveryTransaction__c(
            DocumentId__c = sentDoc.Id,
            TypePk__c = 'Payment',
            AmountCurrency__c = 1000,
            TransactionDateDate__c = Date.today()
        );

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static DeliveryDocument__c getDraftDoc() {
        return [
            SELECT Id, PublicTokenTxt__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'qry00001qry00001qry00001qry00001qry00001qry00001qry00001qry0001a'
            LIMIT 1
        ];
    }

    private static DeliveryDocument__c getSentDoc() {
        return [
            SELECT Id, PublicTokenTxt__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'qry00002qry00002qry00002qry00002qry00002qry00002qry00002qry0002b'
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetDocumentByToken() {
        System.runAs(testUser) {
            DeliveryDocument__c draft = getDraftDoc();

            Test.startTest();
            Map<String, Object> result = DeliveryDocQueryService.getDocumentByToken(draft.PublicTokenTxt__c);
            Test.stopTest();

            System.assertEquals(draft.Id, result.get('id'), 'Document ID should match');
            System.assertEquals('Invoice', result.get('template'), 'Template should match');
            System.assertEquals('Query Test Client', result.get('entityName'), 'Entity name should match');
            System.assertNotEquals(null, result.get('periodStart'), 'Period start should be returned');
            System.assertNotEquals(null, result.get('periodEnd'), 'Period end should be returned');
            // Draft docs should NOT be auto-marked Viewed
            System.assertEquals('Draft', result.get('status'), 'Draft status should not change on access');
        }
    }

    @IsTest
    static void testFirstViewMarksViewed() {
        System.runAs(testUser) {
            DeliveryDocument__c sent = getSentDoc();

            Test.startTest();
            Map<String, Object> result = DeliveryDocQueryService.getDocumentByToken(sent.PublicTokenTxt__c);
            Test.stopTest();

            System.assertEquals('Viewed', result.get('status'), 'Sent document should transition to Viewed');
            System.assertNotEquals(null, result.get('viewedDate'), 'ViewedDateTime should be set');
        }
    }

    @IsTest
    static void testSecondViewDoesNotResetTimestamp() {
        System.runAs(testUser) {
            DeliveryDocument__c sent = getSentDoc();

            // First view — transitions to Viewed
            DeliveryDocQueryService.getDocumentByToken(sent.PublicTokenTxt__c);

            // Capture the viewedDate
            DeliveryDocument__c afterFirstView = [
                SELECT ViewedDateTime__c FROM DeliveryDocument__c WHERE Id = :sent.Id
            ];
            Datetime firstViewedAt = afterFirstView.ViewedDateTime__c;

            Test.startTest();
            Map<String, Object> result = DeliveryDocQueryService.getDocumentByToken(sent.PublicTokenTxt__c);
            Test.stopTest();

            // ViewedDateTime should not change on subsequent views
            DeliveryDocument__c afterSecondView = [
                SELECT ViewedDateTime__c FROM DeliveryDocument__c WHERE Id = :sent.Id
            ];
            System.assertEquals(firstViewedAt, afterSecondView.ViewedDateTime__c,
                'ViewedDateTime should not change on second view');
        }
    }

    @IsTest
    static void testGetDocumentById() {
        System.runAs(testUser) {
            DeliveryDocument__c draft = getDraftDoc();

            Test.startTest();
            Map<String, Object> result = DeliveryDocQueryService.getDocumentById(draft.Id);
            Test.stopTest();

            System.assertEquals(draft.Id, result.get('id'), 'Document ID should match');
            System.assertNotEquals(null, result.get('publicToken'), 'Admin view should include public token');
        }
    }

    @IsTest
    static void testGetDocumentByTokenNotFound() {
        System.runAs(testUser) {
            Boolean threw = false;

            Test.startTest();
            try {
                DeliveryDocQueryService.getDocumentByToken('nonexistent0nonexistent0nonexistent0nonexistent0nonexistent00aa');
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw AuraHandledException for invalid token');
        }
    }

    @IsTest
    static void testListByEntity() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Query Test Client' LIMIT 1];

            Test.startTest();
            List<Map<String, Object>> docs = DeliveryDocQueryService.getDocumentsForEntity(entity.Id);
            Test.stopTest();

            System.assertEquals(2, docs.size(), 'Should return 2 documents for entity');
            for (Map<String, Object> d : docs) {
                System.assertNotEquals(null, d.get('id'), 'Each doc should have an id');
                System.assertNotEquals(null, d.get('template'), 'Each doc should have a template');
                System.assertNotEquals(null, d.get('status'), 'Each doc should have a status');
                System.assertEquals('Query Test Client', d.get('entityName'), 'Entity name should match');
            }
        }
    }

    @IsTest
    static void testListByEntityNull() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, Object>> docs = DeliveryDocQueryService.getDocumentsForEntity(null);
            Test.stopTest();

            System.assert(docs.size() >= 2, 'Null entity should return all documents');
        }
    }

    @IsTest
    static void testGetPendingInvoices() {
        System.runAs(testUser) {
            Test.startTest();
            Map<String, Object> result = DeliveryDocQueryService.getPendingInvoices();
            Test.stopTest();

            Integer count = (Integer) result.get('count');
            List<Object> documents = (List<Object>) result.get('documents');
            System.assertEquals(1, count, 'Should find 1 draft invoice');
            System.assertEquals(1, documents.size(), 'Documents list should match count');
        }
    }

    @IsTest
    static void testGetTransactionsForDocument() {
        System.runAs(testUser) {
            DeliveryDocument__c sent = getSentDoc();

            Test.startTest();
            List<Map<String, Object>> txns = DeliveryDocQueryService.getTransactionsForDocument(sent.Id);
            Test.stopTest();

            System.assertEquals(1, txns.size(), 'Should return 1 transaction');
            System.assertEquals('Payment', txns[0].get('type'), 'Transaction type should be Payment');
            System.assertEquals(1000, (Decimal) txns[0].get('amount'), 'Amount should be 1000');
        }
    }

    @IsTest
    static void testGetTotalPaid() {
        System.runAs(testUser) {
            DeliveryDocument__c sent = getSentDoc();

            Test.startTest();
            Decimal totalPaid = DeliveryDocQueryService.getTotalPaid(sent.Id);
            Test.stopTest();

            System.assertEquals(1000, totalPaid, 'Total paid should be 1000');
        }
    }

    @IsTest
    static void testGetTotalPaidNoTransactions() {
        System.runAs(testUser) {
            DeliveryDocument__c draft = getDraftDoc();

            Test.startTest();
            Decimal totalPaid = DeliveryDocQueryService.getTotalPaid(draft.Id);
            Test.stopTest();

            System.assertEquals(0, totalPaid, 'Total paid should be 0 with no transactions');
        }
    }

    @IsTest
    static void testGetDocumentTemplates() {
        System.runAs(testUser) {
            Test.startTest();
            List<Map<String, String>> templates = DeliveryDocQueryService.getDocumentTemplates();
            Test.stopTest();

            // DocumentTemplate__mdt may or may not have records in scratch org
            // Just verify it returns a list and doesn't throw
            System.assertNotEquals(null, templates, 'Templates list should not be null');
        }
    }

    @IsTest
    static void testGetDefaultBillingEntityId() {
        System.runAs(testUser) {
            Test.startTest();
            String entityId = DeliveryDocQueryService.getDefaultBillingEntityId();
            Test.stopTest();

            // No settings configured, should be null
            System.assertEquals(null, entityId, 'Should return null when no default billing entity configured');
        }
    }
}
