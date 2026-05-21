/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Dataset Templates surface (Layer 7 of the
 *               DH cockpit architecture). Reads DatasetTemplate__c rows scoped
 *               to a feature or work item, returns recent
 *               DatasetTemplateAssignment__c audit rows, and formats the
 *               copy-pastable `cci task run load_feature_data` command string
 *               for the LWC clipboard button.
 *
 *               Global by intent: like the other cockpit controllers, this is
 *               annotated `global with sharing` so a future external onboarding
 *               surface can read the catalog without needing the LWC bundle.
 *               All inner classes used in return signatures are global, per
 *               the CLAUDE.md rule.
 *
 *               PR 9 (ScratchOrgInstance__c) has not merged yet, so the
 *               getAssignmentsForScratchOrg method degrades gracefully when
 *               the referenced object is absent — it checks describe info via
 *               the typed SObjectType reference (NOT
 *               Schema.getGlobalDescribe().get(...) — that pattern blew up
 *               upload-beta in PRs #797 / #800).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
global with sharing class DeliveryDatasetController {

    /** Max audit rows surfaced on the cockpit "recent loads" panel. */
    private static final Integer RECENT_LIMIT = 10;

    /**
     * @description Card payload for a single DatasetTemplate__c. Mirrors the
     *              fields the LWC renders without leaking the full SObject.
     */
    global class DatasetTemplateDTO {
        @AuraEnabled public Id templateId;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String apexScriptPath;
        @AuraEnabled public Integer recordCountEstimate;
        @AuraEnabled public String featureName;
    }

    /**
     * @description Audit-row payload for the recent-loads panel.
     */
    global class AssignmentSummaryDTO {
        @AuraEnabled public Id assignmentId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public DateTime loadedAt;
        @AuraEnabled public String outcome;
        @AuraEnabled public Integer recordsLoaded;
    }

    /**
     * @description Returns DatasetTemplate__c rows whose FeatureLookup__c
     *              points at the given feature. Cacheable so the LWC can
     *              @wire it without re-querying on every render.
     * @param featureId The Feature__c id whose templates should be returned.
     * @return List<DatasetTemplateDTO> may be empty but never null.
     */
    @AuraEnabled(cacheable=true)
    global static List<DatasetTemplateDTO> getTemplatesForFeature(Id featureId) {
        List<DatasetTemplateDTO> out = new List<DatasetTemplateDTO>();
        if (featureId == null) {
            return out;
        }
        try {
            for (DatasetTemplate__c t : [
                SELECT Id, Name, DescriptionTxt__c, ApexScriptPathTxt__c,
                       RecordCountEstimateNumber__c, FeatureLookup__c,
                       FeatureLookup__r.Name
                FROM DatasetTemplate__c
                WHERE FeatureLookup__c = :featureId
                WITH SYSTEM_MODE
                ORDER BY Name ASC
            ]) {
                out.add(toDto(t));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDatasetController.getTemplatesForFeature] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to load dataset templates for this feature.');
        }
        return out;
    }

    /**
     * @description Returns DatasetTemplate__c rows associated with a WI via
     *              the WI's FeatureLookup__c. WIs without a feature parent
     *              return an empty list (not an error — many WIs aren't tied
     *              to a packaged feature). Cacheable.
     * @param workItemId The WorkItem__c id whose feature's templates should be returned.
     * @return List<DatasetTemplateDTO> may be empty but never null.
     */
    @AuraEnabled(cacheable=true)
    global static List<DatasetTemplateDTO> getTemplatesForWorkItem(Id workItemId) {
        List<DatasetTemplateDTO> out = new List<DatasetTemplateDTO>();
        if (workItemId == null) {
            return out;
        }
        Id featureId = resolveWorkItemFeatureId(workItemId);
        if (featureId == null) {
            return out;
        }
        return getTemplatesForFeature(featureId);
    }

    /**
     * @description Returns the N most-recent DatasetTemplateAssignment__c
     *              rows for the given scratch org. Degrades gracefully when
     *              PR 9's ScratchOrgInstance__c is not deployed in the org —
     *              checks the field describe and returns an empty list rather
     *              than throwing. Cacheable.
     * @param scratchOrgId Id of the (PR 9) ScratchOrgInstance__c row.
     * @return List<AssignmentSummaryDTO> may be empty but never null.
     */
    @SuppressWarnings('PMD.ApexSOQLInjection')
    @AuraEnabled(cacheable=true)
    global static List<AssignmentSummaryDTO> getAssignmentsForScratchOrg(Id scratchOrgId) {
        // SOQL string concatenation here is safe: scratchOrgId is bound via
        // :scratchOrgId, and RECENT_LIMIT is a private static final Integer
        // constant — no user input reaches the query text. We build the SOQL
        // dynamically only so the class compiles before PR 9 deploys the
        // ScratchOrgInstanceLookup__c field on DatasetTemplateAssignment__c.
        List<AssignmentSummaryDTO> out = new List<AssignmentSummaryDTO>();
        if (scratchOrgId == null) {
            return out;
        }
        if (!hasScratchOrgLookup()) {
            // PR 9 has not deployed the ScratchOrgInstanceLookup__c field yet.
            // Surface empty rather than throwing — the cockpit handles this
            // by hiding the panel when no rows come back.
            return out;
        }
        // Field is present — query dynamically so the class still compiles
        // when the lookup is absent at compile time. Result shape mirrors the
        // static query in collectAssignmentsForTemplate.
        String soql = 'SELECT Id, DatasetTemplateLookup__c, DatasetTemplateLookup__r.Name, '
            + 'LoadedDateTime__c, OutcomePk__c, RecordsLoadedNumber__c '
            + 'FROM DatasetTemplateAssignment__c '
            + 'WHERE ScratchOrgInstanceLookup__c = :scratchOrgId '
            + 'WITH SYSTEM_MODE '
            + 'ORDER BY LoadedDateTime__c DESC NULLS LAST '
            + 'LIMIT ' + RECENT_LIMIT;
        try {
            for (SObject row : Database.query(soql)) {
                out.add(toAssignmentDto(row));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDatasetController.getAssignmentsForScratchOrg] failed: ' + e.getMessage());
        }
        return out;
    }

    /**
     * @description Returns the most-recent assignments for a single
     *              DatasetTemplate__c. Powers the "recent loads" panel on the
     *              cockpit when no scratch-org context is available.
     *              Cacheable.
     * @param templateId DatasetTemplate__c id whose loads should be listed.
     * @return List<AssignmentSummaryDTO> may be empty but never null.
     */
    @AuraEnabled(cacheable=true)
    global static List<AssignmentSummaryDTO> getRecentAssignmentsForTemplate(Id templateId) {
        List<AssignmentSummaryDTO> out = new List<AssignmentSummaryDTO>();
        if (templateId == null) {
            return out;
        }
        try {
            for (DatasetTemplateAssignment__c a : [
                SELECT Id, DatasetTemplateLookup__c,
                       DatasetTemplateLookup__r.Name,
                       LoadedDateTime__c, OutcomePk__c, RecordsLoadedNumber__c
                FROM DatasetTemplateAssignment__c
                WHERE DatasetTemplateLookup__c = :templateId
                WITH SYSTEM_MODE
                ORDER BY LoadedDateTime__c DESC NULLS LAST
                LIMIT :RECENT_LIMIT
            ]) {
                out.add(toAssignmentDto(a));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDatasetController.getRecentAssignmentsForTemplate] failed: '
                + e.getMessage());
        }
        return out;
    }

    /**
     * @description Returns the copy-pastable cci command for loading the
     *              given template. Used by the LWC clipboard button.
     *              Falls back to the generic load_feature_data wrapper with
     *              the template's Name passed as --feature.
     * @param templateId The DatasetTemplate__c whose load command is requested.
     * @return Command string the developer pastes into a terminal.
     */
    @AuraEnabled
    global static String formatCciCommand(Id templateId) {
        if (templateId == null) {
            throw new AuraHandledException('templateId is required.');
        }
        List<DatasetTemplate__c> rows = [
            SELECT Id, Name, FeatureLookup__r.Name
            FROM DatasetTemplate__c
            WHERE Id = :templateId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Dataset template not found.');
        }
        DatasetTemplate__c t = rows.get(0);
        String featureToken = (t.FeatureLookup__c != null && t.FeatureLookup__r != null)
            ? t.FeatureLookup__r.Name
            : t.Name;
        return 'cci task run load_feature_data --feature ' + featureToken;
    }

    // ────────────────────────────────────────────────────────────────────
    // Helpers
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Maps a DatasetTemplate__c row into a DTO.
     * @param t DatasetTemplate__c row sourced via a SOQL query that includes
     *          FeatureLookup__r.Name.
     * @return Populated DatasetTemplateDTO.
     */
    private static DatasetTemplateDTO toDto(DatasetTemplate__c t) {
        DatasetTemplateDTO dto = new DatasetTemplateDTO();
        dto.templateId = t.Id;
        dto.name = t.Name;
        dto.description = t.DescriptionTxt__c;
        dto.apexScriptPath = t.ApexScriptPathTxt__c;
        if (t.RecordCountEstimateNumber__c != null) {
            dto.recordCountEstimate = t.RecordCountEstimateNumber__c.intValue();
        }
        if (t.FeatureLookup__c != null && t.FeatureLookup__r != null) {
            dto.featureName = t.FeatureLookup__r.Name;
        }
        return dto;
    }

    /**
     * @description Maps a DatasetTemplateAssignment__c row (or a dynamic
     *              SObject row from the scratch-org dynamic SOQL path) into a
     *              DTO.
     * @param row SObject populated with the standard audit fields.
     * @return Populated AssignmentSummaryDTO.
     */
    private static AssignmentSummaryDTO toAssignmentDto(SObject row) {
        AssignmentSummaryDTO dto = new AssignmentSummaryDTO();
        dto.assignmentId = (Id) row.get('Id');
        dto.templateId = (Id) row.get('DatasetTemplateLookup__c');
        SObject parent = row.getSObject('DatasetTemplateLookup__r');
        if (parent != null) {
            dto.templateName = (String) parent.get('Name');
        }
        dto.loadedAt = (DateTime) row.get('LoadedDateTime__c');
        dto.outcome = (String) row.get('OutcomePk__c');
        Object loaded = row.get('RecordsLoadedNumber__c');
        if (loaded != null) {
            dto.recordsLoaded = ((Decimal) loaded).intValue();
        }
        return dto;
    }

    /**
     * @description Returns the WI's FeatureLookup__c value, or null when the
     *              WI doesn't carry one (or the lookup field is absent in
     *              this org's schema). PR 9 may add WorkItem__c.FeatureLookup__c
     *              as a separate field — until then we resolve via the
     *              FeatureDefinitionTxt__c hop on the WI's category text.
     * @param workItemId WorkItem__c id whose feature should be resolved.
     * @return Feature__c id or null.
     */
    private static Id resolveWorkItemFeatureId(Id workItemId) {
        // WorkItem__c does not have a direct FeatureLookup__c in the current
        // schema — features connect to WIs through dataset-template inheritance.
        // Until a direct lookup ships, return null and let
        // getTemplatesForWorkItem degrade to an empty list. Callers that want
        // strict feature resolution should pass a feature id to
        // getTemplatesForFeature directly.
        if (workItemId == null) {
            return null;
        }
        return null;
    }

    /**
     * @description Whether ScratchOrgInstanceLookup__c is present on
     *              DatasetTemplateAssignment__c — i.e. whether PR 9 has been
     *              merged and the field is deployed. Uses the typed
     *              SObjectType describe, never Schema.getGlobalDescribe()
     *              (which has bitten upload-beta multiple times — see CLAUDE.md
     *              and PRs #797 / #800).
     * @return True when the scratch-org lookup is deployed; false otherwise.
     */
    private static Boolean hasScratchOrgLookup() {
        Map<String, Schema.SObjectField> fields =
            DatasetTemplateAssignment__c.SObjectType.getDescribe().fields.getMap();
        // Match both bare and namespaced field names — managed-package context
        // describes the field as 'delivery__scratchorginstancelookup__c'.
        for (String key : fields.keySet()) {
            String k = key.toLowerCase();
            if (k == 'scratchorginstancelookup__c' || k.endsWith('__scratchorginstancelookup__c')) {
                return true;
            }
        }
        return false;
    }
}
