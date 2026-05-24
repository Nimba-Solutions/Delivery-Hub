/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Inline dependency-editor controller for the Feature__c record page.
 *               Wraps the FeatureDependency__c junction object with three admin-gated
 *               operations so the deliveryFeatureDependencyEditor LWC can host a
 *               "current deps + add new + delete" UI directly on the parent Feature
 *               record page (closes the Flow 5 gap from the 2026-05-21 E2E audit).
 *
 *               This is intentionally a NEW surface — DeliveryFeatureCatalogController
 *               is read-only / toggle-only, and DeliveryFeatureGraphService is the
 *               cascade BFS. Neither was the right place for record-page CRUD on
 *               the junction.
 *
 *               Admin gating reuses the same DeliveryHubAdmin PermissionSetGroup
 *               check that DeliveryFeatureCatalogController.isAdmin uses (both
 *               namespaced + bare forms accepted, per CLAUDE.md namespace rules).
 *               Non-admins are refused mutations. Read-side (getDependencies) is
 *               cacheable and not admin-gated so the LWC can still render an
 *               "ask an admin" empty state if a non-admin lands on the record page.
 *
 *               @SuppressWarnings list mirrors DeliveryFeatureCatalogController —
 *               PMD's CRUD rule fires on WITH SYSTEM_MODE queries even though the
 *               admin gate already enforces access; cyclomatic budget is held by
 *               keeping the helpers below short and single-purpose.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity')
public with sharing class DeliveryFeatureDependencyEditorController {

    /** Hard-coded GVS-backed picklist values mirrored from FeatureDependencyType. */
    private static final Set<String> ALLOWED_DEP_TYPES = new Set<String>{
        'Hard', 'Soft', 'Optional'
    };

    /** Max length of the LongTextArea NotesTxt__c field; defensive trim. */
    private static final Integer NOTES_MAX_LENGTH = 1024;

    /**
     * @description Returns every FeatureDependency__c row where the given Feature__c
     *              is the BLOCKED side (i.e. dependencies of THIS feature — the
     *              things that must be enabled first). Returned newest first so
     *              admin edits surface at the top of the editor table.
     *
     *              cacheable=true so the LWC can @wire it and refreshApex on
     *              mutation. SYSTEM_MODE per CLAUDE.md (subscriber-namespace-safe).
     * @param parentFeatureId Feature__c whose dependencies should be returned.
     * @return Matching FeatureDependency__c rows; never null.
     */
    @AuraEnabled(cacheable=true)
    public static List<FeatureDependency__c> getDependencies(Id parentFeatureId) {
        if (parentFeatureId == null) {
            return new List<FeatureDependency__c>();
        }
        try {
            return [
                SELECT Id, Name,
                       BlockingFeatureLookup__c, BlockingFeatureLookup__r.Name,
                       BlockedFeatureLookup__c, BlockedFeatureLookup__r.Name,
                       TypePk__c, CascadeDirectionPk__c, NotesTxt__c,
                       CreatedDate
                FROM FeatureDependency__c
                WHERE BlockedFeatureLookup__c = :parentFeatureId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureDependencyEditorController.getDependencies] failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to load dependencies.');
        }
    }

    /**
     * @description Creates one FeatureDependency__c row with the given parent
     *              (blocked side), child (blocking side), type, and notes. Admin-
     *              gated. Validates that:
     *                - parent != child (self-edges are nonsensical and would
     *                  produce trivial cycles in the BFS cascade)
     *                - depType is one of the allowed GVS values
     *                - no existing row already wires the same (parent, child) pair
     *
     *              Returns the inserted row so the LWC can stash it locally
     *              (the @wire refreshApex below picks up the same row).
     * @param parentFeatureId  The Feature__c that depends on something (Blocked side).
     * @param childFeatureId   The Feature__c that must be enabled first (Blocking side).
     * @param depType          One of 'Hard' | 'Soft' | 'Optional'. Defaults to 'Hard' when blank.
     * @param notes            Optional admin notes for the cascade-preview tooltip.
     * @return Inserted FeatureDependency__c.
     */
    @AuraEnabled
    public static FeatureDependency__c createDependency(
        Id parentFeatureId,
        Id childFeatureId,
        String depType,
        String notes
    ) {
        assertAdminOrThrow();
        assertCreateInputsOrThrow(parentFeatureId, childFeatureId, depType);
        assertNoDuplicateOrThrow(parentFeatureId, childFeatureId);

        FeatureDependency__c dep = new FeatureDependency__c(
            BlockedFeatureLookup__c = parentFeatureId,
            BlockingFeatureLookup__c = childFeatureId,
            TypePk__c = String.isBlank(depType) ? 'Hard' : depType,
            CascadeDirectionPk__c = 'Both',
            NotesTxt__c = sanitizeNotes(notes)
        );
        try {
            insert dep;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureDependencyEditorController.createDependency] insert failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to create dependency.');
        }
        return dep;
    }

    /**
     * @description Deletes a single FeatureDependency__c row by Id. Admin-gated.
     *              Throws when the id is null or no matching row exists.
     * @param dependencyId FeatureDependency__c Id to delete.
     */
    @AuraEnabled
    public static void deleteDependency(Id dependencyId) {
        assertAdminOrThrow();
        if (dependencyId == null) {
            throw new AuraHandledException('Dependency Id is required.');
        }
        List<FeatureDependency__c> existing = [
            SELECT Id FROM FeatureDependency__c
            WHERE Id = :dependencyId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            throw new AuraHandledException('Dependency not found.');
        }
        try {
            delete existing;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureDependencyEditorController.deleteDependency] delete failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to delete dependency.');
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // Private helpers
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Throws an AuraHandledException when the running user is not
     *              a DH admin. Reuses the same PermissionSetGroup gate as
     *              DeliveryFeatureCatalogController.isAdmin (both namespaced
     *              + bare DeveloperName forms accepted per the
     *              namespace-safe pattern in MEMORY.md).
     */
    private static void assertAdminOrThrow() {
        Boolean isAdmin = ![
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSetGroup.DeveloperName IN
                  ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')
            WITH SYSTEM_MODE
            LIMIT 1
        ].isEmpty();
        if (!isAdmin) {
            throw new AuraHandledException('Only Delivery Hub admins can edit feature dependencies.');
        }
    }

    /**
     * @description Validates the create() inputs and throws on any problem
     *              the LWC's reactive form should also catch — defense in
     *              depth, since REST calls can bypass the LWC entirely.
     * @param parentFeatureId Blocked-side Feature__c id.
     * @param childFeatureId  Blocking-side Feature__c id.
     * @param depType         Picklist value — Hard / Soft / Optional.
     */
    private static void assertCreateInputsOrThrow(
        Id parentFeatureId,
        Id childFeatureId,
        String depType
    ) {
        if (parentFeatureId == null) {
            throw new AuraHandledException('Parent feature Id is required.');
        }
        if (childFeatureId == null) {
            throw new AuraHandledException('Child feature Id is required.');
        }
        if (parentFeatureId == childFeatureId) {
            throw new AuraHandledException('A feature cannot depend on itself.');
        }
        if (String.isNotBlank(depType) && !ALLOWED_DEP_TYPES.contains(depType)) {
            throw new AuraHandledException('Dependency type must be Hard, Soft, or Optional.');
        }
    }

    /**
     * @description Refuses inserts that would duplicate an existing
     *              (parent, child) edge. Direction-aware: an edge in the
     *              opposite direction is a distinct dependency and is
     *              allowed (callers can still mark either Hard or Soft).
     * @param parentFeatureId Blocked-side Feature__c id.
     * @param childFeatureId  Blocking-side Feature__c id.
     */
    private static void assertNoDuplicateOrThrow(Id parentFeatureId, Id childFeatureId) {
        Integer existingCount = [
            SELECT COUNT()
            FROM FeatureDependency__c
            WHERE BlockedFeatureLookup__c = :parentFeatureId
              AND BlockingFeatureLookup__c = :childFeatureId
            WITH SYSTEM_MODE
        ];
        if (existingCount > 0) {
            throw new AuraHandledException('This dependency already exists.');
        }
    }

    /**
     * @description Trims and truncates the admin-supplied notes string to fit
     *              the FeatureDependency__c.NotesTxt__c LongTextArea(1024) cap.
     * @param notes Raw notes from the LWC (may be null / whitespace).
     * @return Sanitized notes, or null when blank.
     */
    private static String sanitizeNotes(String notes) {
        if (String.isBlank(notes)) {
            return null;
        }
        String trimmed = notes.trim();
        if (trimmed.length() > NOTES_MAX_LENGTH) {
            return trimmed.substring(0, NOTES_MAX_LENGTH);
        }
        return trimmed;
    }
}
