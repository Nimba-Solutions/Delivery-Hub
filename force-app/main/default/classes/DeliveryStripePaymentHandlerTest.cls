/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryStripePaymentHandler — happy-path payment
 *               recording, unsupported types ignored, missing metadata
 *               fails terminal, cents → dollar conversion, payment_intent
 *               variant.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class DeliveryStripePaymentHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

    @TestSetup
    static void setupDocument() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Stripe Customer',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;
        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c = entity.Id,
            TemplatePk__c = 'Invoice',
            StatusPk__c = 'Sent',
            TotalCurrency__c = 100.00,
            PeriodStartDate__c = Date.today().addDays(-30),
            PeriodEndDate__c = Date.today()
        );
        insert doc;
    }

    private static DeliveryDocument__c getDoc() {
        return [SELECT Id, StatusPk__c, TotalCurrency__c FROM DeliveryDocument__c LIMIT 1];
    }

    private static Map<String, Object> buildStripeEvent(String type, Id docId, Long amountCents) {
        return new Map<String, Object>{
            'type' => type,
            'data' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'id' => 'ch_test_' + amountCents,
                    'amount' => amountCents,
                    'amount_received' => amountCents,
                    'metadata' => new Map<String, Object>{ 'document_id' => String.valueOf(docId) }
                }
            }
        };
    }

    @IsTest
    static void unsupportedEventIsIgnored() {
        DeliveryStripePaymentHandler h = new DeliveryStripePaymentHandler();
        WebhookHandlerResult r = h.handle('customer.created',
            new Map<String, Object>{ 'data' => new Map<String, Object>{ 'object' => new Map<String, Object>{} } });
        System.assertEquals(true, r.success);
        System.assertEquals(200, r.httpStatus,
            'Unsupported Stripe events should be 200 ignored');
    }

    @IsTest
    static void missingDocumentIdReturnsTerminal() {
        Map<String, Object> evt = new Map<String, Object>{
            'type' => 'charge.succeeded',
            'data' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'amount' => 10000,
                    'metadata' => new Map<String, Object>()
                }
            }
        };
        WebhookHandlerResult r = new DeliveryStripePaymentHandler().handle(
            'charge.succeeded', evt);
        System.assertEquals(false, r.success);
        System.assertEquals(400, r.httpStatus);
    }

    @IsTest
    static void invalidDocumentIdReturnsTerminal() {
        Map<String, Object> evt = new Map<String, Object>{
            'type' => 'charge.succeeded',
            'data' => new Map<String, Object>{
                'object' => new Map<String, Object>{
                    'amount' => 10000,
                    'metadata' => new Map<String, Object>{ 'document_id' => 'not_a_real_id' }
                }
            }
        };
        WebhookHandlerResult r = new DeliveryStripePaymentHandler().handle(
            'charge.succeeded', evt);
        System.assertEquals(false, r.success);
    }

    @IsTest
    static void chargeSucceededRecordsPaymentAndMarksPaid() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            // Stripe sends 10000 cents = $100.00 (matches doc total).
            Map<String, Object> evt = buildStripeEvent('charge.succeeded', doc.Id, 10000);

            Test.startTest();
            WebhookHandlerResult r = new DeliveryStripePaymentHandler().handle(
                'charge.succeeded', evt);
            Test.stopTest();

            System.assertEquals(true, r.success, r.message);
            System.assertEquals(200, r.httpStatus);
            DeliveryDocument__c after = [SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id];
            System.assertEquals('Paid', after.StatusPk__c,
                'Document should auto-flip to Paid when payment matches total');
            Integer txnCount = [SELECT COUNT() FROM DeliveryTransaction__c WHERE DocumentId__c = :doc.Id];
            System.assertEquals(1, txnCount,
                'A DeliveryTransaction__c should be inserted for the payment');
        }
    }

    @IsTest
    static void paymentIntentSucceededAlsoWorks() {
        System.runAs(testUser) {
            DeliveryDocument__c doc = getDoc();
            Map<String, Object> evt = buildStripeEvent('payment_intent.succeeded', doc.Id, 5000);

            Test.startTest();
            WebhookHandlerResult r = new DeliveryStripePaymentHandler().handle(
                'payment_intent.succeeded', evt);
            Test.stopTest();

            System.assertEquals(true, r.success, r.message);
            DeliveryDocument__c after = [SELECT StatusPk__c FROM DeliveryDocument__c WHERE Id = :doc.Id];
            System.assertEquals('Sent', after.StatusPk__c,
                'Partial payment should NOT flip the document to Paid');
        }
    }

    @IsTest
    static void readAmountConvertsCentsToDollars() {
        Map<String, Object> dataObj = new Map<String, Object>{ 'amount' => 12345 };
        Decimal d = DeliveryStripePaymentHandler.readAmount(dataObj);
        System.assertEquals(123.45, d, 'amount in cents should become a Decimal in dollars');
    }
}
