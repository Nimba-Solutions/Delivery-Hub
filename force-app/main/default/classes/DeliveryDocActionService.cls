/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Document signing/actioning service for DocumentAction__c records.
 *               Phase 1: slot creation from DocumentTemplateSlot__mdt configuration
 *               at document generation time. Subsequent phases add the signing
 *               flow, hash chain materialization, and image-based signatures.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
public with sharing class DeliveryDocActionService {

    // Cache template lookups within a transaction so multi-doc generation does not re-query.
    private static Map<String, Boolean> templateRequiresSigningCache = new Map<String, Boolean>();
    private static Map<String, List<DocumentTemplateSlot__mdt>> slotConfigCache = new Map<String, List<DocumentTemplateSlot__mdt>>();

    /**
     * @description Returns true when the given template type has signature slots configured.
     *              Reads the RequiresSigningCheckbox__c field on DocumentTemplate__mdt.
     * @param templateType The template DeveloperName (e.g., 'Client_Agreement').
     * @return True if signing is required, false otherwise.
     */
    public static Boolean templateRequiresSigning(String templateType) {
        if (String.isBlank(templateType)) {
            return false;
        }
        if (templateRequiresSigningCache.containsKey(templateType)) {
            return templateRequiresSigningCache.get(templateType);
        }
        Boolean result = false;
        List<DocumentTemplate__mdt> templates = [
            SELECT DeveloperName, RequiresSigningCheckbox__c
            FROM DocumentTemplate__mdt
            WHERE DeveloperName = :templateType
            LIMIT 1
        ];
        if (!templates.isEmpty() && templates[0].RequiresSigningCheckbox__c == true) {
            result = true;
        }
        templateRequiresSigningCache.put(templateType, result);
        return result;
    }

    /**
     * @description Creates DocumentAction__c child records for the given document based on
     *              the slot configuration in DocumentTemplateSlot__mdt for the template type.
     *              Auto-assigns AssignedEntityId__c based on the slot's AutoAssignTxt__c hint:
     *                - 'vendor'   → DeliveryHubSettings__c.DefaultBillingEntityIdTxt__c
     *                - 'customer' → the document's NetworkEntityId__c (from the snapshot)
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
            DocumentAction__c action = new DocumentAction__c(
                DocumentId__c       = documentId,
                ActionLabelTxt__c   = slot.ActionLabelTxt__c,
                SortOrder__c        = slot.SortOrder__c,
                StatusPk__c         = 'Pending',
                SignatureTypePk__c  = 'Text',
                SignerTokenTxt__c   = generateSignerToken()
            );
            String autoAssign = slot.AutoAssignTxt__c != null ? slot.AutoAssignTxt__c.toLowerCase() : null;
            if (autoAssign == 'vendor' && vendorEntityId != null) {
                action.AssignedEntityId__c = vendorEntityId;
            } else if (autoAssign == 'customer' && customerEntityId != null) {
                action.AssignedEntityId__c = customerEntityId;
            }
            toInsert.add(action);
        }

        if (!toInsert.isEmpty()) {
            Database.insert(toInsert, AccessLevel.SYSTEM_MODE);
        }
        return toInsert;
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
            SELECT Id, Name, DocumentId__c, ActionLabelTxt__c, AssignedEntityId__c,
                   AssignedEntityId__r.Name, StatusPk__c, CompletedDateTime__c,
                   SignatureTypePk__c, SignatureDataTxt__c, SignerNameTxt__c,
                   SignerEmailTxt__c, SortOrder__c, SignerTokenTxt__c,
                   IpAddressTxt__c, ElectronicConsentDateTime__c
            FROM DocumentAction__c
            WHERE DocumentId__c = :documentId
            WITH SYSTEM_MODE
            ORDER BY SortOrder__c ASC NULLS LAST, CreatedDate ASC
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
                   SortOrder__c, AutoAssignTxt__c
            FROM DocumentTemplateSlot__mdt
            WHERE TemplateTypeTxt__c = :templateType
            ORDER BY SortOrder__c ASC NULLS LAST
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
}
