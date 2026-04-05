/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Payment and accounts receivable logic for DeliveryDocument__c records.
 *               Extracted from DeliveryDocumentController to reduce class size.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ExcessiveParameterList')
public with sharing class DocumentPaymentService {

    /**
     * @description Records a payment against a document by creating a DeliveryTransaction__c
     *              record. Auto-transitions the document status to 'Paid' when total
     *              payments meet or exceed the document total.
     * @param documentId The DeliveryDocument__c Id.
     * @param amount The payment amount received.
     * @param paymentDate The date the payment was received.
     * @param note Optional reference number, check number, or note.
     */
    public static void recordPayment(Id documentId, Decimal amount, Date paymentDate, String note) {
        if (documentId == null || amount == null || amount <= 0) {
            throw new AuraHandledException('A valid document ID and positive payment amount are required.');
        }

        DeliveryTransaction__c txn = new DeliveryTransaction__c(
            DocumentId__c = documentId,
            TypePk__c = 'Payment',
            AmountCurrency__c = amount,
            TransactionDateDate__c = paymentDate,
            NoteTxt__c = String.isNotBlank(note) ? note : null
        );
        Database.insert(txn, AccessLevel.SYSTEM_MODE);

        // Check if total payments now cover the document total -> auto-mark Paid
        DeliveryDocument__c doc = [
            SELECT Id, TotalCurrency__c, StatusPk__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Decimal docTotal = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
        Decimal totalPaid = DocumentQueryService.getTotalPaid(documentId);
        if (totalPaid >= docTotal) {
            doc.StatusPk__c = 'Paid';
            Database.update(doc, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Calculates the outstanding balance from all prior unpaid invoices
     *              for the given entity. Queries unpaid invoices and aggregates
     *              DeliveryTransaction__c amounts per document to compute paid totals.
     * @param entityId The NetworkEntity__c Id.
     * @param currentPeriodStart Only includes invoices with periods before this date.
     * @return The total unpaid prior balance.
     */
    @TestVisible
    public static Decimal calculatePriorBalance(Id entityId, Date currentPeriodStart) {
        List<DeliveryDocument__c> unpaidDocs = [
            SELECT Id, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE NetworkEntityId__c = :entityId
            AND TemplatePk__c = 'Invoice'
            AND StatusPk__c != 'Paid'
            AND StatusPk__c != 'Superseded'
            AND PeriodStartDate__c < :currentPeriodStart
            WITH SYSTEM_MODE
        ];
        if (unpaidDocs.isEmpty()) {
            return 0;
        }

        Set<Id> docIds = new Map<Id, DeliveryDocument__c>(unpaidDocs).keySet();
        Map<Id, Decimal> paidByDoc = aggregatePaidByDocument(docIds);

        Decimal balance = 0;
        for (DeliveryDocument__c doc : unpaidDocs) {
            Decimal docTotal = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
            Decimal docPaid = paidByDoc.containsKey(doc.Id) ? paidByDoc.get(doc.Id) : 0;
            balance += (docTotal - docPaid);
        }
        return balance;
    }

    /**
     * @description Builds a summary list of all unpaid invoices for the entity.
     *              Aggregates DeliveryTransaction__c amounts per document for paid totals.
     * @param entityId The NetworkEntity__c Id to query unpaid invoices for.
     * @return List of maps containing name, period, total, paid, outstanding, and status keys.
     */
    public static List<Map<String, Object>> buildUnpaidInvoicesSummary(Id entityId) {
        List<DeliveryDocument__c> unpaidDocs = [
            SELECT Id, Name, PeriodStartDate__c, PeriodEndDate__c,
                   TotalCurrency__c, StatusPk__c, SentDateTime__c
            FROM DeliveryDocument__c
            WHERE NetworkEntityId__c = :entityId
            AND TemplatePk__c = 'Invoice'
            AND StatusPk__c != 'Paid'
            AND StatusPk__c != 'Superseded'
            WITH SYSTEM_MODE
            ORDER BY PeriodStartDate__c ASC
        ];
        if (unpaidDocs.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        Set<Id> docIds = new Map<Id, DeliveryDocument__c>(unpaidDocs).keySet();
        Map<Id, Decimal> paidByDoc = aggregatePaidByDocument(docIds);

        List<Map<String, Object>> summary = new List<Map<String, Object>>();
        for (DeliveryDocument__c doc : unpaidDocs) {
            Decimal total = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
            Decimal paid = paidByDoc.containsKey(doc.Id) ? paidByDoc.get(doc.Id) : 0;
            Decimal outstanding = total - paid;
            if (outstanding <= 0) {
                continue;
            }
            Map<String, Object> item = new Map<String, Object>();
            item.put('name', doc.Name);
            item.put('periodStart', String.valueOf(doc.PeriodStartDate__c));
            item.put('periodEnd', String.valueOf(doc.PeriodEndDate__c));
            item.put('total', total);
            item.put('paid', paid);
            item.put('outstanding', outstanding);
            item.put('status', doc.StatusPk__c);
            summary.add(item);
        }
        return summary;
    }

    /**
     * @description Aggregates paid amounts across multiple documents. Returns a map
     *              of document Id to total paid amount from DeliveryTransaction__c records.
     * @param docIds The set of DeliveryDocument__c Ids to aggregate.
     * @return Map of document Id to total paid Decimal.
     */
    public static Map<Id, Decimal> aggregatePaidByDocument(Set<Id> docIds) {
        Map<Id, Decimal> paidByDoc = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT DocumentId__c docId, SUM(AmountCurrency__c) totalPaid
            FROM DeliveryTransaction__c
            WHERE DocumentId__c IN :docIds
            WITH SYSTEM_MODE
            GROUP BY DocumentId__c
        ]) {
            Id dId = (Id) ar.get('docId');
            Decimal paid = ar.get('totalPaid') != null ? (Decimal) ar.get('totalPaid') : 0;
            paidByDoc.put(dId, paid);
        }
        return paidByDoc;
    }
}
