/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Public LWC-facing facade for document actioning + signatures.
 *               Phase 2 surface: getActionsForDocument, signActionAdmin, updateAssignedEntity.
 *               Public (not global) — uses primitives + Map<String, Object> to keep
 *               namespace surface area minimal and avoid the global-inner-class trap.
 *               Phase 3 will add public-token signing methods (getDocumentForSigner,
 *               signActionPublic) for the guest portal flow.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class DeliveryDocActionController {

    /**
     * @description Returns all signature slots for a document, shaped for LWC consumption.
     *              Used by the embedded document viewer to render the signature block.
     * @param documentId The DeliveryDocument__c Id.
     * @return List of action maps with id, label, status, sortOrder, signer info, etc.
     */
    @AuraEnabled
    public static List<Map<String, Object>> getActionsForDocument(Id documentId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (DocumentAction__c a : DeliveryDocActionService.getActionsForDocument(documentId)) {
            result.add(serializeAction(a));
        }
        return result;
    }

    /**
     * @description Admin-side sign action used inside the org. Stamps the slot with
     *              "<signerName> (digitally signed Apr 6, 2026)" and advances the document
     *              status if all slots are completed and the doc is past Draft.
     *              Gated behind the EnableAdminSigningDateTime__c feature flag — admin-on-
     *              behalf signing is legally questionable for real signing and disabled by
     *              default. Use the public portal flow for real signers.
     * @param actionId     The DocumentAction__c Id.
     * @param signerName   Name to stamp.
     * @param signerEmail  Email; falls back to UserInfo.getUserEmail() if blank.
     * @param consentGiven Must be true.
     * @return Map with actionId, status, documentStatus.
     */
    @AuraEnabled
    public static Map<String, Object> signActionAdmin(Id actionId, String signerName, String signerEmail, Boolean consentGiven) {
        if (!DeliveryDocActionService.isAdminSigningEnabled()) {
            throw new AuraHandledException(
                'Admin signing is disabled. Set EnableAdminSigningDateTime__c on Delivery Hub Settings to enable.'
            );
        }
        String stamp = DeliveryDocActionService.formatTextSignatureStamp(signerName, Datetime.now());
        DeliveryDocActionService.SignContext ctx = new DeliveryDocActionService.SignContext();
        ctx.actionId = actionId;
        ctx.signerName = signerName;
        ctx.signerEmail = String.isNotBlank(signerEmail) ? signerEmail : UserInfo.getUserEmail();
        ctx.signatureType = 'Text';
        ctx.signatureData = stamp;
        ctx.consentGiven = consentGiven;
        return DeliveryDocActionService.signActionInternal(ctx);
    }

    /**
     * @description Updates the AssignedEntityId__c on a slot. Used by the embedded viewer
     *              to let admins assign unassigned slots (e.g., the lessor in a lease)
     *              before sending the document.
     * @param actionId        The DocumentAction__c Id.
     * @param networkEntityId The NetworkEntity__c Id to assign, or null to clear.
     * @return Map with actionId, assignedEntityId, assignedEntityName.
     */
    @AuraEnabled
    public static Map<String, Object> updateAssignedEntity(Id actionId, Id networkEntityId) {
        if (actionId == null) {
            throw new AuraHandledException('Action Id is required.');
        }
        List<DocumentAction__c> actions = [
            SELECT Id, AssignedEntityId__c, StatusPk__c
            FROM DocumentAction__c
            WHERE Id = :actionId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (actions.isEmpty()) {
            throw new AuraHandledException('Signature slot not found.');
        }
        DocumentAction__c action = actions[0];
        if (action.StatusPk__c != 'Pending') {
            throw new AuraHandledException('Cannot reassign a slot that has already been actioned.');
        }
        action.AssignedEntityId__c = networkEntityId;
        Database.update(action, AccessLevel.SYSTEM_MODE);

        String entityName = null;
        if (networkEntityId != null) {
            List<NetworkEntity__c> entities = [
                SELECT Id, Name FROM NetworkEntity__c WHERE Id = :networkEntityId
                WITH SYSTEM_MODE LIMIT 1
            ];
            if (!entities.isEmpty()) {
                entityName = entities[0].Name;
            }
        }
        return new Map<String, Object>{
            'actionId'           => action.Id,
            'assignedEntityId'   => networkEntityId,
            'assignedEntityName' => entityName
        };
    }

    /**
     * @description Reshapes a DocumentAction__c into the LWC-friendly map format.
     */
    private static Map<String, Object> serializeAction(DocumentAction__c a) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('id', a.Id);
        m.put('label', a.ActionLabelTxt__c);
        m.put('status', a.StatusPk__c);
        m.put('sortOrder', a.SortOrder__c);
        m.put('signatureType', a.SignatureTypePk__c);
        m.put('signatureData', a.SignatureDataTxt__c);
        m.put('signerName', a.SignerNameTxt__c);
        m.put('signerEmail', a.SignerEmailTxt__c);
        m.put('completedAt', a.CompletedDateTime__c);
        m.put('signerToken', a.SignerTokenTxt__c);
        m.put('assignedEntityId', a.AssignedEntityId__c);
        m.put('assignedEntityName', a.AssignedEntityId__r != null ? a.AssignedEntityId__r.Name : null);
        m.put('isPending', a.StatusPk__c == 'Pending');
        m.put('isCompleted', a.StatusPk__c == 'Completed');
        return m;
    }
}
