/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Phase 4: Certificate of Completion service. Builds the audit-trail
 *               payload for a fully signed DeliveryDocument__c — document hash,
 *               per-signer rows (name, email, IP, UA, timestamps, chain hash),
 *               and a chain validation result. Used by the viewer LWC's audit
 *               trail UI and (eventually) by a standalone PDF certificate page.
 *
 *               Public-but-not-global so the surface stays inside the package
 *               namespace and we can refactor freely.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class DeliveryDocCertificateService {

    /**
     * @description Builds the certificate payload for the given document. The
     *              document does NOT have to be fully signed — partial certificates
     *              are useful for the in-progress audit trail UI. The map shape
     *              matches what `deliveryDocumentSignatureBlock` consumes when
     *              rendering the audit trail section.
     *
     *              Map shape:
     *                documentId       : Id
     *                documentName     : String
     *                documentHash     : String (SHA-256 of frozen snapshot)
     *                templateType     : String (e.g. Client_Agreement)
     *                generatedAt      : Datetime
     *                allSigned        : Boolean (true when no Pending slots remain)
     *                signers          : List<Map> (one per completed slot, ordered)
     *                pendingCount     : Integer (slots still awaiting signature)
     *                chainHead        : String (hash of the most recent signed slot)
     *
     *              Each signer map:
     *                actionId         : Id
     *                slotLabel        : String
     *                signerName       : String
     *                signerEmail      : String
     *                signedAt         : Datetime
     *                consentAt        : Datetime
     *                ipAddress        : String
     *                userAgent        : String
     *                signatureType    : String
     *                priorHash        : String (chain hash at moment of signing)
     *                activityLogId    : Id
     *
     * @param documentId The DeliveryDocument__c Id.
     * @return The certificate payload map.
     */
    public static Map<String, Object> buildCertificate(Id documentId) {
        if (documentId == null) {
            throw new AuraHandledException('Document Id is required.');
        }

        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, DocumentHashTxt__c, StatusPk__c, CreatedDate
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }
        DeliveryDocument__c doc = docs[0];

        List<DocumentAction__c> actions = [
            SELECT Id, ActionLabelTxt__c, StatusPk__c, SortOrderNumber__c,
                   SignerNameTxt__c, SignerEmail__c, SignatureTypePk__c,
                   CompletedDateTime__c, ElectronicConsentDateTime__c,
                   IpAddressTxt__c, UserAgentTxt__c,
                   PriorHashTxt__c, ActivityLogLookup__c
            FROM DocumentAction__c
            WHERE DocumentId__c = :documentId
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, CompletedDateTime__c ASC NULLS LAST
        ];

        List<Map<String, Object>> signers = new List<Map<String, Object>>();
        Integer pendingCount = 0;
        String chainHead = null;
        for (DocumentAction__c a : actions) {
            if (a.StatusPk__c != 'Completed') {
                pendingCount++;
                continue;
            }
            signers.add(serializeSigner(a));
            if (String.isNotBlank(a.PriorHashTxt__c)) {
                chainHead = a.PriorHashTxt__c;
            }
        }

        return new Map<String, Object>{
            'documentId'   => doc.Id,
            'documentName' => doc.Name,
            'templateType' => doc.TemplatePk__c,
            'documentHash' => doc.DocumentHashTxt__c,
            'generatedAt'  => doc.CreatedDate,
            'allSigned'    => pendingCount == 0 && !signers.isEmpty(),
            'pendingCount' => pendingCount,
            'signers'      => signers,
            'chainHead'    => chainHead
        };
    }

    /**
     * @description Reshapes a completed DocumentAction__c into a portable map.
     *              Excluded from the public API surface — call buildCertificate.
     */
    private static Map<String, Object> serializeSigner(DocumentAction__c a) {
        return new Map<String, Object>{
            'actionId'        => a.Id,
            'slotLabel'       => a.ActionLabelTxt__c,
            'signerName'      => a.SignerNameTxt__c,
            'signerEmail'     => a.SignerEmail__c,
            'signedAt'        => a.CompletedDateTime__c,
            'consentAt'       => a.ElectronicConsentDateTime__c,
            'ipAddress'       => a.IpAddressTxt__c,
            'userAgent'       => a.UserAgentTxt__c,
            'signatureType'   => a.SignatureTypePk__c,
            'priorHash'       => a.PriorHashTxt__c,
            'activityLogId'   => a.ActivityLogLookup__c
        };
    }
}
