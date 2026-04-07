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
     *              "<signerName> (digitally signed Apr 6, 2026)" or — when the
     *              payload includes drawn signature bytes — saves them as a
     *              ContentVersion and stores the new ContentVersion Id on the slot.
     *              Advances the document status if all slots are completed and the
     *              doc is past Draft. Gated behind the EnableAdminSigningDateTime__c
     *              feature flag — admin-on-behalf signing is legally questionable for
     *              real signing and is disabled by default. Use the public portal
     *              flow for real signers.
     *
     *              Expected payload keys (matches signActionPublic for symmetry):
     *                signerName       (String, required)
     *                signerEmail      (String, optional — defaults to UserInfo.getUserEmail())
     *                consentGiven     (Boolean, must be true)
     *                signatureType    (String, optional — 'Text' or 'Image', defaults to 'Text')
     *                drawnSignature   (String, optional — base64 PNG bytes when signatureType='Image')
     *
     * @param actionId The DocumentAction__c Id.
     * @param payload  Map with the signing inputs.
     * @return Map with actionId, status, documentStatus.
     */
    @AuraEnabled
    public static Map<String, Object> signActionAdmin(Id actionId, Map<String, Object> payload) {
        if (!DeliveryDocActionService.isAdminSigningEnabled()) {
            throw new AuraHandledException(
                'Admin signing is disabled. Set EnableAdminSigningDateTime__c on Delivery Hub Settings to enable.'
            );
        }
        DeliveryDocActionService.SignContext ctx = new DeliveryDocActionService.SignContext();
        ctx.actionId = actionId;
        if (payload != null) {
            ctx.signerName  = (String) payload.get('signerName');
            String email    = (String) payload.get('signerEmail');
            ctx.signerEmail = String.isNotBlank(email) ? email : UserInfo.getUserEmail();
            Object consent  = payload.get('consentGiven');
            ctx.consentGiven = consent instanceof Boolean ? (Boolean) consent : false;
            String type     = (String) payload.get('signatureType');
            ctx.signatureType = String.isNotBlank(type) ? type : 'Text';
            ctx.drawnSignature = (String) payload.get('drawnSignature');
        }
        if (ctx.signatureType != 'Image') {
            ctx.signatureData = DeliveryDocActionService.formatTextSignatureStamp(ctx.signerName, Datetime.now());
        }
        return DeliveryDocActionService.signActionInternal(ctx);
    }

    /**
     * @description Updates the AssignedEntityLookup__c on a slot. Used by the embedded viewer
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
            SELECT Id, AssignedEntityLookup__c, StatusPk__c
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
        action.AssignedEntityLookup__c = networkEntityId;
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

    // ═══════════════════════════════════════════════════════════
    //  PHASE 3: PUBLIC PORTAL SIGNING (TOKEN-BASED)
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Returns the document bundle for an unauthenticated signer presenting
     *              their per-signer access token. Used by the portal LWC to render the
     *              sign page. Cacheable so guest users can hit Salesforce's edge cache.
     * @param signerToken The 64-char hex token from the slot's SignerTokenTxt__c field.
     * @return Map shaped for the portal LWC. See DeliveryDocActionService.getDocumentBundleForSignerToken.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDocumentForSigner(String signerToken) {
        return DeliveryDocActionService.getDocumentBundleForSignerToken(signerToken);
    }

    /**
     * @description Public-facing sign action for unauthenticated signers. Resolves the
     *              signer token to the slot, builds a SignContext from the payload map,
     *              and delegates to the service layer. IP capture happens via the REST
     *              endpoint (DeliveryDocActionRestApi) — when the LWC calls this Aura
     *              method directly, IP is null. The payload map keeps the parameter
     *              count low and matches the project rule of `primitives + Map<String, Object>`.
     *
     *              Expected payload keys:
     *                signerName   (String, required)
     *                signerEmail  (String, optional)
     *                consentGiven (Boolean, must be true)
     *                userAgent    (String, optional)
     *
     * @param signerToken The signer's per-slot token.
     * @param payload     Map with signerName / signerEmail / consentGiven / userAgent.
     * @return Map with actionId, status, documentStatus.
     */
    @AuraEnabled
    public static Map<String, Object> signActionPublic(String signerToken, Map<String, Object> payload) {
        DeliveryDocActionService.SignContext ctx = new DeliveryDocActionService.SignContext();
        if (payload != null) {
            ctx.signerName  = (String) payload.get('signerName');
            ctx.signerEmail = (String) payload.get('signerEmail');
            Object consent  = payload.get('consentGiven');
            ctx.consentGiven = consent instanceof Boolean ? (Boolean) consent : false;
            ctx.userAgent   = (String) payload.get('userAgent');
            // Phase 5: optional drawn signature payload
            String type     = (String) payload.get('signatureType');
            ctx.signatureType = String.isNotBlank(type) ? type : 'Text';
            ctx.drawnSignature = (String) payload.get('drawnSignature');
        }
        if (ctx.signatureType != 'Image') {
            ctx.signatureType = 'Text';
            ctx.signatureData = DeliveryDocActionService.formatTextSignatureStamp(ctx.signerName, Datetime.now());
        }
        return DeliveryDocActionService.signActionByToken(signerToken, ctx);
    }

    // ═══════════════════════════════════════════════════════════
    //  PHASE 4: CERTIFICATE OF COMPLETION
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Returns the Certificate of Completion payload for a document.
     *              Used by the viewer LWC's audit-trail UI; surfaces the document
     *              hash, per-signer rows (name, email, IP, UA, timestamps, chain
     *              hash), and a chain head value. Cacheable so the viewer can
     *              refresh without an Apex round-trip when nothing has changed.
     * @param documentId The DeliveryDocument__c Id.
     * @return The certificate map. See DeliveryDocCertificateService.buildCertificate.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCertificateOfCompletion(Id documentId) {
        return DeliveryDocCertificateService.buildCertificate(documentId);
    }

    /**
     * @description Reshapes a DocumentAction__c into the LWC-friendly map format.
     *              For Image-type completed slots, the SignatureDataTxt__c holds
     *              a ContentVersion Id; we surface a sfc/servlet URL the LWC can
     *              drop straight into an <img src> attribute.
     */
    private static Map<String, Object> serializeAction(DocumentAction__c a) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('id', a.Id);
        m.put('label', a.ActionLabelTxt__c);
        m.put('status', a.StatusPk__c);
        m.put('sortOrder', a.SortOrderNumber__c);
        m.put('signatureType', a.SignatureTypePk__c);
        m.put('signatureData', a.SignatureDataTxt__c);
        m.put('signerName', a.SignerNameTxt__c);
        m.put('signerEmail', a.SignerEmail__c);
        m.put('completedAt', a.CompletedDateTime__c);
        m.put('signerToken', a.SignerTokenTxt__c);
        m.put('assignedEntityId', a.AssignedEntityLookup__c);
        m.put('assignedEntityName', a.AssignedEntityLookup__r != null ? a.AssignedEntityLookup__r.Name : null);
        m.put('isPending', a.StatusPk__c == 'Pending');
        m.put('isCompleted', a.StatusPk__c == 'Completed');
        // Phase 5: image URL for drawn signatures
        if (a.SignatureTypePk__c == 'Image' && String.isNotBlank(a.SignatureDataTxt__c)) {
            m.put('signatureImageUrl', '/sfc/servlet.shepherd/version/download/' + a.SignatureDataTxt__c);
        }
        return m;
    }
}
