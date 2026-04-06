/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Portal approval and dispute logic for DeliveryDocument__c records.
 *               Extracted from DeliveryDocumentController to reduce class size.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDocApprovalService {

    /**
     * @description Approves a document identified by its public token.
     *              Sets status to Approved, creates an Approval transaction,
     *              and logs a Document_Action activity entry.
     *              Only documents in Sent or Viewed status can be approved.
     * @param publicToken The 64-char hex public access token.
     * @return Map with document id and new status.
     */
    public static Map<String, Object> approveDocumentByToken(String publicToken) {
        DeliveryDocument__c doc = queryDocumentByToken(publicToken);
        validateApprovableStatus(doc);

        doc.StatusPk__c = 'Approved';
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        DeliveryTransaction__c txn = new DeliveryTransaction__c(
            DocumentId__c          = doc.Id,
            TypePk__c              = 'Approval',
            AmountCurrency__c      = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0,
            TransactionDateDate__c = Date.today(),
            NoteTxt__c             = 'Approved by client via portal'
        );
        Database.insert(txn, AccessLevel.SYSTEM_MODE);

        logDocumentAction(doc.Id, 'approve', null);

        return new Map<String, Object>{
            'id'     => doc.Id,
            'status' => 'Approved'
        };
    }

    /**
     * @description Disputes a document identified by its public token.
     *              Sets status to Disputed, stores the dispute reason,
     *              and logs a Document_Action activity entry.
     *              Only documents in Sent or Viewed status can be disputed.
     * @param publicToken The 64-char hex public access token.
     * @param reason The client-provided reason for the dispute.
     * @return Map with document id and new status.
     */
    public static Map<String, Object> disputeDocumentByToken(String publicToken, String reason) {
        DeliveryDocument__c doc = queryDocumentByToken(publicToken);
        validateApprovableStatus(doc);

        doc.StatusPk__c = 'Disputed';
        doc.DisputeReasonTxt__c = String.isNotBlank(reason) ? reason.left(5000) : null;
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        logDocumentAction(doc.Id, 'dispute', reason);

        return new Map<String, Object>{
            'id'     => doc.Id,
            'status' => 'Disputed'
        };
    }

    /**
     * @description Queries a document by its public token. Throws if not found.
     * @param publicToken The public access token.
     * @return The DeliveryDocument__c record.
     */
    @TestVisible
    public static DeliveryDocument__c queryDocumentByToken(String publicToken) {
        if (String.isBlank(publicToken)) {
            throw new AuraHandledException('Public token is required.');
        }
        List<DeliveryDocument__c> docs = [
            SELECT Id, StatusPk__c, TotalCurrency__c, NetworkEntityId__c,
                   TemplatePk__c, NetworkEntityId__r.Name
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = :publicToken
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }
        return docs[0];
    }

    /**
     * @description Validates that a document is in an approvable status (Sent or Viewed).
     * @param doc The document to validate.
     */
    @TestVisible
    public static void validateApprovableStatus(DeliveryDocument__c doc) {
        Set<String> approvable = new Set<String>{ 'Sent', 'Viewed' };
        if (!approvable.contains(doc.StatusPk__c)) {
            throw new AuraHandledException(
                'Document cannot be approved or disputed in its current status: ' + doc.StatusPk__c
            );
        }
    }

    /**
     * @description Creates an ActivityLog__c entry for a document approval action.
     * @param documentId The DeliveryDocument__c Id.
     * @param action The action performed (approve or dispute).
     * @param reason Optional dispute reason.
     */
    private static void logDocumentAction(Id documentId, String action, String reason) {
        Map<String, Object> contextData = new Map<String, Object>{
            'action'     => action,
            'documentId' => documentId
        };
        if (String.isNotBlank(reason)) {
            contextData.put('reason', reason.left(500));
        }
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c    = 'Document_Action',
            RecordIdTxt__c     = documentId,
            ContextDataTxt__c  = JSON.serialize(contextData)
        );
        Database.insert(log, AccessLevel.SYSTEM_MODE);
    }
}
