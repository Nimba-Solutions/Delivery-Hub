/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Document signing/actioning service for DocumentAction__c records.
 *               Phase 1: slot creation from DocumentTemplateSlot__mdt configuration
 *               at document generation time. Subsequent phases add the signing
 *               flow, hash chain materialization, and image-based signatures.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc, PMD.CyclomaticComplexity')
public with sharing class DeliveryDocActionService {

    // Cache template lookups within a transaction so multi-doc generation does not re-query.
    // Stores the RequireSigningDateTime__c value (null = signing not required).
    // Sentinel values: TRANSACTION_NULL marks "queried, returned null" so cache hits work for either case.
    private static final Datetime TRANSACTION_NULL = Datetime.newInstance(0L);
    private static Map<String, Datetime> templateSigningRequiredCache = new Map<String, Datetime>();
    private static Map<String, List<DocumentTemplateSlot__mdt>> slotConfigCache = new Map<String, List<DocumentTemplateSlot__mdt>>();

    /**
     * @description Returns the timestamp at which the given template type was flagged
     *              as requiring signatures, or null if signing is not required.
     *              Reads the RequireSigningDateTime__c field on DocumentTemplate__mdt.
     * @param templateType The template DeveloperName (e.g., 'Client_Agreement').
     * @return The DateTime the requirement was set, or null if signing is not required.
     */
    public static Datetime templateSigningRequiredAt(String templateType) {
        if (String.isBlank(templateType)) {
            return null;
        }
        if (templateSigningRequiredCache.containsKey(templateType)) {
            Datetime cached = templateSigningRequiredCache.get(templateType);
            return cached == TRANSACTION_NULL ? null : cached;
        }
        Datetime result = null;
        List<DocumentTemplate__mdt> templates = [
            SELECT DeveloperName, RequireSigningDateTime__c
            FROM DocumentTemplate__mdt
            WHERE DeveloperName = :templateType
            LIMIT 1
        ];
        if (!templates.isEmpty() && templates[0].RequireSigningDateTime__c != null) {
            result = templates[0].RequireSigningDateTime__c;
        }
        templateSigningRequiredCache.put(templateType, result == null ? TRANSACTION_NULL : result);
        return result;
    }

    /**
     * @description Convenience boolean wrapper for templateSigningRequiredAt.
     * @param templateType The template DeveloperName.
     * @return True if the template requires signing (i.e. RequireSigningDateTime__c is non-null).
     */
    public static Boolean templateRequiresSigning(String templateType) {
        return templateSigningRequiredAt(templateType) != null;
    }

    /**
     * @description Creates DocumentAction__c child records for the given document based on
     *              the slot configuration in DocumentTemplateSlot__mdt for the template type.
     *              Auto-assigns AssignedEntityLookup__c based on the slot's AutoAssignTxt__c hint:
     *                - 'vendor'   → DeliveryHubSettings__c.DefaultBillingEntityIdTxt__c
     *                - 'customer' → the document's NetworkEntityLookup__c (from the snapshot)
     *                - any other  → unassigned
     *              Returns the inserted records. Returns an empty list if the template has
     *              no slots configured (i.e., does not require signing).
     * @param documentId   The DeliveryDocument__c Id to attach slots to.
     * @param templateType The template DeveloperName.
     * @param snapshot     The frozen snapshot used to resolve customer auto-assign.
     * @return The inserted DocumentAction__c records.
     */
    public static List<DocumentAction__c> createSlotsForTemplate(Id documentId, String templateType, Map<String, Object> snapshot) {
        if (documentId == null || String.isBlank(templateType)) {
            return new List<DocumentAction__c>();
        }
        List<DocumentTemplateSlot__mdt> slots = loadSlotConfigForTemplate(templateType);
        if (slots.isEmpty()) {
            return new List<DocumentAction__c>();
        }

        Id vendorEntityId = resolveVendorEntityId();
        Id customerEntityId = resolveCustomerEntityId(snapshot);

        List<DocumentAction__c> toInsert = new List<DocumentAction__c>();
        for (DocumentTemplateSlot__mdt slot : slots) {
            toInsert.add(buildSlotRecord(documentId, slot, vendorEntityId, customerEntityId));
        }

        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, AccessLevel.SYSTEM_MODE);
        }
        return toInsert;
    }

    /**
     * @description Builds a single DocumentAction__c record for a slot config row,
     *              applying the auto-assignment hint when present.
     */
    private static DocumentAction__c buildSlotRecord(
        Id documentId,
        DocumentTemplateSlot__mdt slot,
        Id vendorEntityId,
        Id customerEntityId
    ) {
        DocumentAction__c action = new DocumentAction__c(
            DocumentLookup__c       = documentId,
            ActionLabelTxt__c   = slot.ActionLabelTxt__c,
            SortOrderNumber__c  = slot.SortOrderNumber__c,
            StatusPk__c         = 'Pending',
            SignatureTypePk__c  = 'Text',
            SignerTokenTxt__c   = generateSignerToken()
        );
        action.AssignedEntityLookup__c = resolveAutoAssignEntityId(slot, vendorEntityId, customerEntityId);
        return action;
    }

    /**
     * @description Returns the auto-assigned entity Id for a slot, or null if no match.
     *              Branches on the slot's AutoAssignTxt__c hint ('vendor' / 'customer').
     */
    private static Id resolveAutoAssignEntityId(
        DocumentTemplateSlot__mdt slot,
        Id vendorEntityId,
        Id customerEntityId
    ) {
        String autoAssign = slot.AutoAssignTxt__c != null ? slot.AutoAssignTxt__c.toLowerCase() : null;
        if (autoAssign == 'vendor') {
            return vendorEntityId;
        }
        if (autoAssign == 'customer') {
            return customerEntityId;
        }
        return null;
    }

    /**
     * @description Returns all DocumentAction__c records for a document, ordered by SortOrder.
     * @param documentId The DeliveryDocument__c Id.
     * @return List of action records ordered by SortOrder ascending.
     */
    public static List<DocumentAction__c> getActionsForDocument(Id documentId) {
        if (documentId == null) {
            return new List<DocumentAction__c>();
        }
        return [
            SELECT Id, Name, DocumentLookup__c, ActionLabelTxt__c, AssignedEntityLookup__c,
                   AssignedEntityLookup__r.Name, StatusPk__c, CompletedDateTime__c,
                   SignatureTypePk__c, SignatureDataTxt__c, SignerNameTxt__c,
                   SignerEmail__c, SortOrderNumber__c, SignerTokenTxt__c,
                   IpAddressTxt__c, ElectronicConsentDateTime__c
            FROM DocumentAction__c
            WHERE DocumentLookup__c = :documentId
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, CreatedDate ASC
        ];
    }

    /**
     * @description Generates a unique 64-char hex token for a signer's portal access URL.
     *              Delegates to DeliveryDocGenerationService.generateToken() to keep the
     *              cryptographic primitive in one place.
     * @return A 64-character hex string.
     */
    public static String generateSignerToken() {
        return DeliveryDocGenerationService.generateToken();
    }

    /**
     * @description Loads slot configuration records for a template type, ordered by SortOrder.
     *              Cached per-transaction to avoid repeated SOQL during bulk generation.
     * @param templateType The template DeveloperName.
     * @return Slot config records ordered by SortOrder ascending.
     */
    @TestVisible
    private static List<DocumentTemplateSlot__mdt> loadSlotConfigForTemplate(String templateType) {
        if (slotConfigCache.containsKey(templateType)) {
            return slotConfigCache.get(templateType);
        }
        List<DocumentTemplateSlot__mdt> slots = [
            SELECT DeveloperName, TemplateTypeTxt__c, ActionLabelTxt__c, RoleTxt__c,
                   SortOrderNumber__c, AutoAssignTxt__c
            FROM DocumentTemplateSlot__mdt
            WHERE TemplateTypeTxt__c = :templateType
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ];
        slotConfigCache.put(templateType, slots);
        return slots;
    }

    /**
     * @description Resolves the vendor (issuing) entity Id from org settings.
     * @return The DefaultBillingEntityIdTxt__c value as an Id, or null.
     */
    @TestVisible
    private static Id resolveVendorEntityId() {
        String idStr = DeliveryDocQueryService.getDefaultBillingEntityId();
        if (String.isBlank(idStr)) {
            return null;
        }
        try {
            return (Id) idStr;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Resolves the customer entity Id from the document snapshot.
     * @param snapshot The frozen JSON snapshot map.
     * @return The entity Id from snapshot.entity.id, or null.
     */
    @TestVisible
    private static Id resolveCustomerEntityId(Map<String, Object> snapshot) {
        if (snapshot == null) {
            return null;
        }
        Object entityObj = snapshot.get('entity');
        if (!(entityObj instanceof Map<String, Object>)) {
            return null;
        }
        Map<String, Object> entity = (Map<String, Object>) entityObj;
        Object idObj = entity.get('id');
        if (idObj == null) {
            return null;
        }
        try {
            return (Id) String.valueOf(idObj);
        } catch (Exception e) {
            return null;
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  PHASE 2: SIGNING FLOW
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Bundles signing inputs to keep the public sign API to one parameter.
     *              Used by both admin and public sign flows so the surface stays consistent.
     */
    public class SignContext {
        public Id actionId;
        public String signerName;
        public String signerEmail;
        public String signatureType;
        public String signatureData;
        public Boolean consentGiven;
        public String ipAddress;
        public String userAgent;
    }

    /**
     * @description Internal sign-action handler used by both admin and public sign flows.
     *              Validates consent, updates the action record with signature details,
     *              records an ActivityLog__c audit entry (the existing trigger writes the
     *              chain hash), materializes that hash on the action, and conditionally
     *              advances the parent document status.
     * @param ctx The SignContext bundle (see inner class).
     * @return Map with actionId, status, documentStatus.
     */
    public static Map<String, Object> signActionInternal(SignContext ctx) {
        validateSignContext(ctx);
        DocumentAction__c action = loadPendingAction(ctx.actionId);

        applySignatureToAction(action, ctx);
        Database.update(action, AccessLevel.SYSTEM_MODE);

        Id activityLogId = recordSignatureAuditLog(action, ctx);
        action.ActivityLogLookup__c = activityLogId;
        Database.update(action, AccessLevel.SYSTEM_MODE);

        String newDocStatus = maybeAdvanceDocumentStatus(action.DocumentLookup__c);

        return new Map<String, Object>{
            'actionId'       => action.Id,
            'status'         => 'Completed',
            'documentStatus' => newDocStatus
        };
    }

    /**
     * @description Throws if the sign context is missing required inputs (consent, name, id).
     */
    private static void validateSignContext(SignContext ctx) {
        if (ctx == null || ctx.consentGiven != true) {
            throw new AuraHandledException('Electronic signature consent is required.');
        }
        if (String.isBlank(ctx.signerName)) {
            throw new AuraHandledException('Signer name is required.');
        }
        if (ctx.actionId == null) {
            throw new AuraHandledException('Action Id is required.');
        }
    }

    /**
     * @description Loads the action by id and asserts it is in Pending status.
     */
    private static DocumentAction__c loadPendingAction(Id actionId) {
        List<DocumentAction__c> actions = [
            SELECT Id, DocumentLookup__c, ActionLabelTxt__c, StatusPk__c, SortOrderNumber__c
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
            throw new AuraHandledException('This signature slot has already been actioned.');
        }
        return action;
    }

    /**
     * @description Mutates the action record in place with the signature payload.
     *              Caller is responsible for the DML.
     */
    private static void applySignatureToAction(DocumentAction__c action, SignContext ctx) {
        Datetime now = Datetime.now();
        action.StatusPk__c = 'Completed';
        action.CompletedDateTime__c = now;
        action.ElectronicConsentDateTime__c = now;
        action.SignatureTypePk__c = String.isNotBlank(ctx.signatureType) ? ctx.signatureType : 'Text';
        action.SignatureDataTxt__c = ctx.signatureData;
        action.SignerNameTxt__c = ctx.signerName;
        action.SignerEmail__c = ctx.signerEmail;
        action.IpAddressTxt__c = ctx.ipAddress;
        action.UserAgentTxt__c = ctx.userAgent;
    }

    /**
     * @description Inserts an ActivityLog__c row for the sign event.
     *              The before-insert trigger (DeliveryAuditChainService) populates the
     *              tamper-evident HashChainTxt__c automatically.
     * @return The inserted ActivityLog__c Id (for materialization on the action).
     */
    private static Id recordSignatureAuditLog(DocumentAction__c action, SignContext ctx) {
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c = 'Document_Action',
            RecordIdTxt__c = action.DocumentLookup__c,
            ContextDataTxt__c = JSON.serialize(new Map<String, Object>{
                'action'        => 'sign',
                'actionId'      => action.Id,
                'documentId'    => action.DocumentLookup__c,
                'signerName'    => ctx.signerName,
                'signatureType' => action.SignatureTypePk__c,
                'slotLabel'     => action.ActionLabelTxt__c
            })
        );
        Database.insert(log, AccessLevel.SYSTEM_MODE);
        return log.Id;
    }

    /**
     * @description Checks whether all signature slots for a document are completed,
     *              and if so, advances the parent document to Approved (only when its
     *              current status is in {Sent, Viewed, Awaiting_Signatures}). Also creates
     *              a DeliveryTransaction__c approval row mirroring the legacy approval flow.
     *              Returns the new document status, or null if no advance happened.
     *              Documents in Draft status are NOT advanced — admin pre-signing is allowed
     *              but does not finalize the document.
     * @param documentId The DeliveryDocument__c Id.
     * @return The new status string, or null.
     */
    public static String maybeAdvanceDocumentStatus(Id documentId) {
        if (documentId == null) {
            return null;
        }
        Integer pendingCount = [
            SELECT COUNT()
            FROM DocumentAction__c
            WHERE DocumentLookup__c = :documentId AND StatusPk__c = 'Pending'
            WITH SYSTEM_MODE
        ];
        if (pendingCount > 0) {
            return null;
        }

        List<DeliveryDocument__c> docs = [
            SELECT Id, StatusPk__c, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (docs.isEmpty()) {
            return null;
        }
        DeliveryDocument__c doc = docs[0];

        Set<String> advanceableStatuses = new Set<String>{ 'Sent', 'Viewed', 'Awaiting_Signatures' };
        if (!advanceableStatuses.contains(doc.StatusPk__c)) {
            return null;
        }

        doc.StatusPk__c = 'Approved';
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        DeliveryTransaction__c txn = new DeliveryTransaction__c(
            DocumentLookup__c          = doc.Id,
            TypePk__c              = 'Approval',
            AmountCurrency__c      = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0,
            TransactionDateDate__c = Date.today(),
            NoteTxt__c             = 'Approved via signature completion'
        );
        Database.insert(txn, AccessLevel.SYSTEM_MODE);

        return 'Approved';
    }

    /**
     * @description Returns true when admin-side signing is enabled in org settings.
     *              Reads the EnableAdminSigningDateTime__c feature flag on
     *              DeliveryHubSettings__c using the standard non-null = enabled pattern.
     */
    public static Boolean isAdminSigningEnabled() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings != null && settings.EnableAdminSigningDateTime__c != null;
    }

    /**
     * @description Builds the standard text-stamp signature string in the GSU
     *              AutomatedDocuments format: "<Name> (digitally signed Apr 6, 2026)".
     * @param signerName The printed name to embed.
     * @param signedAt The signing timestamp.
     * @return The formatted stamp string.
     */
    public static String formatTextSignatureStamp(String signerName, Datetime signedAt) {
        String dateStr = signedAt.format('MMM d, yyyy');
        return signerName + ' (digitally signed ' + dateStr + ')';
    }

    // ═══════════════════════════════════════════════════════════
    //  PHASE 3: PUBLIC PORTAL SIGNING (TOKEN-BASED)
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Resolves a per-signer access token to a single DocumentAction__c
     *              record + its parent document + sibling actions, all in one call.
     *              Used by the public portal LWC and the REST endpoint to render the
     *              sign page for an unauthenticated signer.
     * @param signerToken The 64-char hex token from the slot's SignerTokenTxt__c field.
     * @return Map: { document: {...}, signerActionId, signerSlotLabel, actions: [...] }
     *         or throws AuraHandledException if the token does not match a slot.
     */
    public static Map<String, Object> getDocumentBundleForSignerToken(String signerToken) {
        DocumentAction__c signerAction = findActionBySignerToken(signerToken);
        DeliveryDocument__c doc = loadDocumentForPortal(signerAction.DocumentLookup__c);
        Map<String, Object> docMap = serializeDocumentForPortal(doc);
        List<Map<String, Object>> actions = serializeActionsForPortal(signerAction.DocumentLookup__c);

        return new Map<String, Object>{
            'document'         => docMap,
            'signerActionId'   => signerAction.Id,
            'signerSlotLabel'  => signerAction.ActionLabelTxt__c,
            'signerStatus'     => signerAction.StatusPk__c,
            'actions'          => actions
        };
    }

    /**
     * @description Signs an action using a per-signer token instead of an action Id.
     *              Verifies the token resolves to the slot identified in the context's
     *              actionId field (defense in depth — REST endpoint passes both).
     *              Delegates to signActionInternal once validated.
     * @param signerToken The token presented by the signer.
     * @param ctx The SignContext bundle (actionId may be null and will be filled in).
     * @return Same shape as signActionInternal.
     */
    public static Map<String, Object> signActionByToken(String signerToken, SignContext ctx) {
        DocumentAction__c slot = findActionBySignerToken(signerToken);
        if (ctx == null) {
            throw new AuraHandledException('Sign payload is required.');
        }
        if (ctx.actionId != null && ctx.actionId != slot.Id) {
            throw new AuraHandledException('Token does not match the requested signature slot.');
        }
        ctx.actionId = slot.Id;
        return signActionInternal(ctx);
    }

    /**
     * @description Looks up a DocumentAction__c by its per-signer token.
     *              Throws an AuraHandledException with a generic message on miss to
     *              avoid token enumeration attacks.
     */
    private static DocumentAction__c findActionBySignerToken(String signerToken) {
        if (String.isBlank(signerToken) || signerToken.length() != 64) {
            throw new AuraHandledException('Invalid signer link.');
        }
        List<DocumentAction__c> actions = [
            SELECT Id, DocumentLookup__c, ActionLabelTxt__c, StatusPk__c, SignerTokenTxt__c
            FROM DocumentAction__c
            WHERE SignerTokenTxt__c = :signerToken
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (actions.isEmpty()) {
            throw new AuraHandledException('Invalid signer link.');
        }
        return actions[0];
    }

    /**
     * @description Loads a DeliveryDocument__c with the fields needed for the portal.
     */
    private static DeliveryDocument__c loadDocumentForPortal(Id documentId) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, StatusPk__c, TemplatePk__c, SnapshotTxt__c,
                   RequireSigningDateTime__c, TotalCurrency__c, NetworkEntityLookup__c,
                   NetworkEntityLookup__r.Name, PublicTokenTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }
        return docs[0];
    }

    /**
     * @description Reshapes a document into a portal-friendly map. Keeps the surface
     *              minimal — the LWC only needs identifying info, status, snapshot,
     *              and the consent text.
     */
    private static Map<String, Object> serializeDocumentForPortal(DeliveryDocument__c doc) {
        String consentText = resolveConsentText(doc.TemplatePk__c);
        return new Map<String, Object>{
            'id'              => doc.Id,
            'name'            => doc.Name,
            'status'          => doc.StatusPk__c,
            'template'        => doc.TemplatePk__c,
            'snapshot'        => doc.SnapshotTxt__c,
            'requiresSigning' => doc.RequireSigningDateTime__c != null,
            'requireSigningDateTime' => doc.RequireSigningDateTime__c,
            'entityName'      => doc.NetworkEntityLookup__r != null ? doc.NetworkEntityLookup__r.Name : null,
            'consentText'     => consentText
        };
    }

    /**
     * @description Reshapes the actions list into the LWC-friendly map format.
     *              Same shape as DeliveryDocActionController.serializeAction so the
     *              portal LWC and the embedded viewer share the same child component.
     */
    private static List<Map<String, Object>> serializeActionsForPortal(Id documentId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (DocumentAction__c a : getActionsForDocument(documentId)) {
            result.add(new Map<String, Object>{
                'id'                 => a.Id,
                'label'              => a.ActionLabelTxt__c,
                'status'             => a.StatusPk__c,
                'sortOrder'          => a.SortOrderNumber__c,
                'signatureType'      => a.SignatureTypePk__c,
                'signatureData'      => a.SignatureDataTxt__c,
                'signerName'         => a.SignerNameTxt__c,
                'completedAt'        => a.CompletedDateTime__c,
                'assignedEntityName' => a.AssignedEntityLookup__r != null ? a.AssignedEntityLookup__r.Name : null,
                'isPending'          => a.StatusPk__c == 'Pending',
                'isCompleted'        => a.StatusPk__c == 'Completed'
            });
        }
        return result;
    }

    /**
     * @description Returns the ESIGN consent disclosure text configured on the
     *              DocumentTemplate__mdt for the given template type, or a hardcoded
     *              fallback if blank.
     */
    private static String resolveConsentText(String templateType) {
        if (String.isBlank(templateType)) {
            return defaultConsentText();
        }
        List<DocumentTemplate__mdt> templates = [
            SELECT DeveloperName, ElectronicConsentTextTxt__c
            FROM DocumentTemplate__mdt
            WHERE DeveloperName = :templateType
            LIMIT 1
        ];
        if (templates.isEmpty() || String.isBlank(templates[0].ElectronicConsentTextTxt__c)) {
            return defaultConsentText();
        }
        return templates[0].ElectronicConsentTextTxt__c;
    }

    /**
     * @description Hardcoded ESIGN/UETA fallback consent disclosure used when the
     *              template does not have one configured. Mirrors the disclosure on
     *              the seeded agreement templates.
     */
    private static String defaultConsentText() {
        return 'By checking the box below and clicking Sign, you agree that your electronic '
            + 'signature is the legal equivalent of your manual signature on this document. '
            + 'You consent to be legally bound by its terms and you affirm that you have had '
            + 'a reasonable opportunity to review the document before signing.';
    }
}
