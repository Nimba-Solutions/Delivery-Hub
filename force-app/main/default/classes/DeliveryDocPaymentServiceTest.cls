/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryDocPaymentService.
 *               Covers recordPayment, auto-mark-paid logic, prior balance
 *               calculation, unpaid invoices summary, and aggregate helpers.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDocPaymentServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Payment Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        // Invoice 1 — older period, unpaid
        DeliveryDocument__c doc1 = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Invoice',
            PeriodStartDate__c = Date.newInstance(2026, 1, 1),
            PeriodEndDate__c = Date.newInstance(2026, 1, 31),
            PublicTokenTxt__c = 'pay00001pay00001pay00001pay00001pay00001pay00001pay00001pay0001a',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 3000
        );

        // Invoice 2 — current period
        DeliveryDocument__c doc2 = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Invoice',
            PeriodStartDate__c = Date.newInstance(2026, 2, 1),
            PeriodEndDate__c = Date.newInstance(2026, 2, 28),
            PublicTokenTxt__c = 'pay00002pay00002pay00002pay00002pay00002pay00002pay00002pay0002b',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 5000
        );

        insert new List<DeliveryDocument__c>{ doc1, doc2 };

        DeliveryTriggerControl.enableAfterLogic();
    }

    private static NetworkEntity__c getEntity() {
        return [SELECT Id FROM NetworkEntity__c WHERE Name = 'Payment Test Client' LIMIT 1];
    }

    private static DeliveryDocument__c getDoc1() {
        return [
            SELECT Id, StatusPk__c, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'pay00001pay00001pay00001pay00001pay00001pay00001pay00001pay0001a'
            LIMIT 1
        ];
    }

    private static DeliveryDocument__c getDoc2() {
        return [
            SELECT Id, StatusPk__c, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = 'pay00002pay00002pay00002pay00002pay00002pay00002pay00002pay0002b'
            LIMIT 1
        ];
    }

    @IsTest
    static void testRecordPayment() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc2();

            Test.startTest();
            DeliveryDocPaymentService.recordPayment(doc.Id, 2500, Date.today(), 'Check #1234');
            Test.stopTest();

            List<DeliveryTransaction__c> txns = [
                SELECT TypePk__c, AmountCurrency__c, NoteTxt__c
                FROM DeliveryTransaction__c
                WHERE DocumentId__c = :doc.Id AND TypePk__c = 'Payment'
            ];
            System.assertEquals(1, txns.size(), 'Should create one payment transaction');
            System.assertEquals(2500, txns[0].AmountCurrency__c, 'Amount should match');
            System.assertEquals('Check #1234', txns[0].NoteTxt__c, 'Note should match');

            // Document should still be Sent (partial payment)
            DeliveryDocument__c updated = [SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id];
            System.assertEquals('Sent', updated.StatusPk__c, 'Should remain Sent after partial payment');
        }
    }

    @IsTest
    static void testAutoMarkPaid() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc2();

            Test.startTest();
            // Pay full amount
            DeliveryDocPaymentService.recordPayment(doc.Id, 5000, Date.today(), 'Full payment');
            Test.stopTest();

            DeliveryDocument__c updated = [SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id];
            System.assertEquals('Paid', updated.StatusPk__c, 'Should auto-mark as Paid when fully paid');
        }
    }

    @IsTest
    static void testAutoMarkPaidWithOverpayment() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc2();

            Test.startTest();
            DeliveryDocPaymentService.recordPayment(doc.Id, 6000, Date.today(), 'Overpayment');
            Test.stopTest();

            DeliveryDocument__c updated = [SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id];
            System.assertEquals('Paid', updated.StatusPk__c, 'Should auto-mark as Paid when overpaid');
        }
    }

    @IsTest
    static void testPriorBalanceCalculation() {
        System.runAs(testUser) {
            NetworkEntity__c entity = getEntity();
            DeliveryDocument__c doc1 = getDoc1();

            // Make a partial payment on doc1
            insert new DeliveryTransaction__c(
                DocumentId__c = doc1.Id,
                TypePk__c = 'Payment',
                AmountCurrency__c = 1000,
                TransactionDateDate__c = Date.today()
            );

            Test.startTest();
            // Calculate prior balance as of Feb period start — only doc1 (Jan) qualifies
            Decimal balance = DeliveryDocPaymentService.calculatePriorBalance(
                entity.Id, Date.newInstance(2026, 2, 1)
            );
            Test.stopTest();

            // doc1 total = 3000, paid = 1000, outstanding = 2000
            System.assertEquals(2000, balance, 'Prior balance should be total minus payments');
        }
    }

    @IsTest
    static void testPriorBalanceZeroWhenAllPaid() {
        System.runAs(testUser) {
            NetworkEntity__c entity = getEntity();
            DeliveryDocument__c doc1 = getDoc1();

            // Pay doc1 in full
            doc1.StatusPk__c = 'Paid';
            update doc1;

            Test.startTest();
            Decimal balance = DeliveryDocPaymentService.calculatePriorBalance(
                entity.Id, Date.newInstance(2026, 2, 1)
            );
            Test.stopTest();

            System.assertEquals(0, balance, 'Prior balance should be 0 when all docs are paid');
        }
    }

    @IsTest
    static void testBuildUnpaidInvoicesSummary() {
        System.runAs(testUser) {
            NetworkEntity__c entity = getEntity();

            Test.startTest();
            List<Map<String, Object>> summary = DeliveryDocPaymentService.buildUnpaidInvoicesSummary(entity.Id);
            Test.stopTest();

            System.assertEquals(2, summary.size(), 'Should return 2 unpaid invoices');
            for (Map<String, Object> item : summary) {
                System.assertNotEquals(null, item.get('name'), 'Each item should have a name');
                System.assertNotEquals(null, item.get('total'), 'Each item should have a total');
                System.assertNotEquals(null, item.get('outstanding'), 'Each item should have outstanding amount');
            }
        }
    }

    @IsTest
    static void testRecordPaymentInvalidInputThrows() {
        System.runAs(testUser) {
            Boolean threw = false;

            Test.startTest();
            try {
                DeliveryDocPaymentService.recordPayment(null, 100, Date.today(), null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw for null document ID');
        }
    }

    @IsTest
    static void testRecordPaymentZeroAmountThrows() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc2();
            Boolean threw = false;

            Test.startTest();
            try {
                DeliveryDocPaymentService.recordPayment(doc.Id, 0, Date.today(), null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();

            System.assert(threw, 'Should throw for zero payment amount');
        }
    }

    @IsTest
    static void testAggregatePaidByDocument() {
        System.runAs(testUser) {
            DeliveryDocument__c doc1 = getDoc1();
            DeliveryDocument__c doc2 = getDoc2();

            // Insert payments on both docs
            insert new List<DeliveryTransaction__c>{
                new DeliveryTransaction__c(
                    DocumentId__c = doc1.Id, TypePk__c = 'Payment',
                    AmountCurrency__c = 500, TransactionDateDate__c = Date.today()
                ),
                new DeliveryTransaction__c(
                    DocumentId__c = doc2.Id, TypePk__c = 'Payment',
                    AmountCurrency__c = 1500, TransactionDateDate__c = Date.today()
                )
            };

            Test.startTest();
            Map<Id, Decimal> paidMap = DeliveryDocPaymentService.aggregatePaidByDocument(
                new Set<Id>{ doc1.Id, doc2.Id }
            );
            Test.stopTest();

            System.assertEquals(500, paidMap.get(doc1.Id), 'Doc1 paid should be 500');
            System.assertEquals(1500, paidMap.get(doc2.Id), 'Doc2 paid should be 1500');
        }
    }
}
