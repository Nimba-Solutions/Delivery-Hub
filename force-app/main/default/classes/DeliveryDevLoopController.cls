/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Layer 6 of the cockpit — Dev-Loop Mirror controller. Resolves
 *               the matching DevLoopGuide__mdt for a WorkItem__c and returns
 *               its checklist + scratch-org summary so the deliveryDevLoopGuide
 *               LWC can render dev-loop guidance on the WI / Feature record
 *               page.
 *
 *               DH does NOT shell out to cci. Subscriber installs don&apos;t
 *               have CCI; the recipe + state are stored here as a mirror, and
 *               GH Actions POSTs/PATCHes state into the new
 *               /deliveryhub/v1/api/scratch-orgs route (see
 *               DeliveryPublicApiService).
 *
 *               Global by intent — PR 10 may pull this surface into the
 *               external onboarding portal so non-Salesforce devs can read
 *               the guidance without an LWC. Per CLAUDE.md, every inner
 *               class used as a return/param type is also global.
 *
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
global with sharing class DeliveryDevLoopController {

    /** Internal hint — the running install's namespace prefix. Blank in dev orgs, &quot;delivery&quot; on subscriber installs. */
    private static final String PUBLISHER_NAMESPACE = 'delivery';

    /** @description Resolved guide payload for a single WorkItem__c. */
    global class DevLoopGuideDTO {
        @AuraEnabled public String recommendedCciFlow;
        @AuraEnabled public String seedDataset;
        @AuraEnabled public List<String> requiredPermsets;
        @AuraEnabled public String scratchOrgConfig;
        @AuraEnabled public List<ChecklistStepDTO> setupChecklist;
        @AuraEnabled public String docsUrl;
        @AuraEnabled public Boolean isSubscriberOrg;
    }

    /** @description One row in a guide&apos;s ordered setup checklist. */
    global class ChecklistStepDTO {
        @AuraEnabled public Integer step;
        @AuraEnabled public String label;
        @AuraEnabled public String command;
        @AuraEnabled public String docsUrl;
    }

    /** @description Compact summary of a ScratchOrgInstance__c for the LWC. */
    global class ScratchOrgSummaryDTO {
        @AuraEnabled public Id scratchOrgId;
        @AuraEnabled public String branch;
        @AuraEnabled public String state;
        @AuraEnabled public String loginUrl;
        @AuraEnabled public DateTime expiresAt;
        @AuraEnabled public DateTime lastSyncAt;
    }

    /**
     * @description Returns the DevLoopGuide__mdt that matches the WI&apos;s
     *              WorkflowTypeTxt__c x linked Feature&apos;s CategoryPk__c.
     *              Falls back to (WorkflowType only) match, then a degraded
     *              empty DTO. On subscriber installs the DTO is returned with
     *              isSubscriberOrg=true and an empty checklist so the LWC can
     *              render a one-line &quot;dev-loop guidance is for package
     *              developers&quot; badge.
     * @param workItemId WorkItem__c id whose guide should be resolved.
     * @return Populated DTO when a match is found, otherwise a DTO carrying
     *         only isSubscriberOrg and empty lists.
     */
    @AuraEnabled(cacheable=true)
    global static DevLoopGuideDTO getGuideForWorkItem(Id workItemId) {
        DevLoopGuideDTO dto = new DevLoopGuideDTO();
        dto.requiredPermsets = new List<String>();
        dto.setupChecklist = new List<ChecklistStepDTO>();
        dto.isSubscriberOrg = isSubscriberOrg();
        if (workItemId == null) {
            return dto;
        }
        if (dto.isSubscriberOrg) {
            // Subscriber orgs intentionally get an empty DTO. The LWC reads
            // isSubscriberOrg and renders the "this is for package devs"
            // badge instead of the checklist. We still return the flag so
            // the client knows the empty list is by design (not a wire fail).
            return dto;
        }
        String workflowType = resolveWorkflowType(workItemId);
        String featureCategory = resolveFeatureCategory(workItemId);
        DevLoopGuide__mdt guide = findMatchingGuide(workflowType, featureCategory);
        if (guide == null) {
            return dto;
        }
        populateGuideDto(dto, guide);
        return dto;
    }

    /**
     * @description Returns the ScratchOrgInstance__c rows linked to a WI,
     *              newest first. Up to 25 — older orgs are typically Deleted
     *              and not interesting in the LWC.
     * @param workItemId WorkItem__c id whose scratch orgs should be listed.
     * @return Newest-first list of summary DTOs. Empty when none link.
     */
    @AuraEnabled(cacheable=true)
    global static List<ScratchOrgSummaryDTO> getScratchOrgsForWorkItem(Id workItemId) {
        List<ScratchOrgSummaryDTO> out = new List<ScratchOrgSummaryDTO>();
        if (workItemId == null) {
            return out;
        }
        for (ScratchOrgInstance__c soi : [
            SELECT Id, BranchTxt__c, StatePk__c, LoginUrl__c,
                   ExpiresDateTime__c, LastSyncDateTime__c
            FROM ScratchOrgInstance__c
            WHERE WorkItemLookup__c = :workItemId
            WITH SYSTEM_MODE
            ORDER BY LastSyncDateTime__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 25
        ]) {
            out.add(toSummary(soi));
        }
        return out;
    }

    // ── helpers ────────────────────────────────────────────────────────

    /**
     * @description Detects whether this is a subscriber install by checking
     *              the running org&apos;s namespace prefix against the
     *              publisher namespace literal &quot;delivery&quot;. Cheaper
     *              than the typed describe round-trip and stable across orgs.
     * @return True on subscriber installs, false in unpackaged dev orgs.
     */
    private static Boolean isSubscriberOrg() {
        try {
            List<Organization> orgs = [SELECT NamespacePrefix FROM Organization LIMIT 1];
            if (orgs.isEmpty()) {
                return false;
            }
            String prefix = orgs.get(0).NamespacePrefix;
            return String.isNotBlank(prefix) && prefix.equalsIgnoreCase(PUBLISHER_NAMESPACE);
        } catch (Exception e) {
            // Defensive — never block the LWC over an Organization probe.
            return false;
        }
    }

    /**
     * @description Returns the WI&apos;s WorkflowTypeTxt__c or empty string.
     * @param workItemId WI id to probe.
     * @return Workflow type literal, or '' when blank.
     */
    private static String resolveWorkflowType(Id workItemId) {
        List<WorkItem__c> wis = [
            SELECT WorkflowTypeTxt__c
            FROM WorkItem__c
            WHERE Id = :workItemId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (wis.isEmpty() || String.isBlank(wis.get(0).WorkflowTypeTxt__c)) {
            return '';
        }
        return wis.get(0).WorkflowTypeTxt__c;
    }

    /**
     * @description Returns the matching FeatureDefinition__mdt.CategoryPk__c
     *              for any Feature__c rows that share the WI&apos;s feature
     *              context, or '' when none can be resolved.
     *
     *              PR 9 doesn&apos;t add a Feature lookup on WorkItem__c.
     *              Resolution intentionally limited to ScratchOrgInstance__c
     *              rows already linked to this WI — if any of them point at a
     *              Feature, we use that. Otherwise category resolution
     *              degrades gracefully to '' and the matcher falls back to
     *              workflow-type-only.
     * @param workItemId WI id whose feature context should be probed.
     * @return Category literal (e.g. &quot;Core&quot;) or ''.
     */
    private static String resolveFeatureCategory(Id workItemId) {
        Set<Id> featureIds = new Set<Id>();
        for (ScratchOrgInstance__c soi : [
            SELECT FeatureLookup__c
            FROM ScratchOrgInstance__c
            WHERE WorkItemLookup__c = :workItemId AND FeatureLookup__c != null
            WITH SYSTEM_MODE
            LIMIT 50
        ]) {
            featureIds.add(soi.FeatureLookup__c);
        }
        if (featureIds.isEmpty()) {
            return '';
        }
        Set<String> defNames = new Set<String>();
        for (Feature__c f : [
            SELECT FeatureDefinitionTxt__c
            FROM Feature__c
            WHERE Id IN :featureIds AND FeatureDefinitionTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            defNames.add(f.FeatureDefinitionTxt__c);
        }
        if (defNames.isEmpty()) {
            return '';
        }
        List<FeatureDefinition__mdt> defs = [
            SELECT CategoryPk__c
            FROM FeatureDefinition__mdt
            WHERE DeveloperName IN :defNames AND CategoryPk__c != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return defs.isEmpty() ? '' : defs.get(0).CategoryPk__c;
    }

    /**
     * @description Two-pass match — first try (WorkflowType x Category),
     *              then fall back to WorkflowType-only.
     * @param workflowType WI workflow type literal.
     * @param featureCategory Optional category literal.
     * @return Best matching guide, or null when neither pass finds one.
     */
    private static DevLoopGuide__mdt findMatchingGuide(String workflowType, String featureCategory) {
        if (String.isBlank(workflowType)) {
            return null;
        }
        if (String.isNotBlank(featureCategory)) {
            List<DevLoopGuide__mdt> exact = [
                SELECT WorkflowTypeTxt__c, FeatureCategoryTxt__c,
                       RecommendedCciFlowTxt__c, SeedDatasetTxt__c,
                       RequiredPermsetsTxt__c, ScratchOrgConfigTxt__c,
                       SetupChecklistJsonTxt__c, DocsUrl__c
                FROM DevLoopGuide__mdt
                WHERE WorkflowTypeTxt__c = :workflowType
                  AND FeatureCategoryTxt__c = :featureCategory
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!exact.isEmpty()) {
                return exact.get(0);
            }
        }
        List<DevLoopGuide__mdt> fallback = [
            SELECT WorkflowTypeTxt__c, FeatureCategoryTxt__c,
                   RecommendedCciFlowTxt__c, SeedDatasetTxt__c,
                   RequiredPermsetsTxt__c, ScratchOrgConfigTxt__c,
                   SetupChecklistJsonTxt__c, DocsUrl__c
            FROM DevLoopGuide__mdt
            WHERE WorkflowTypeTxt__c = :workflowType
            WITH SYSTEM_MODE
            ORDER BY DeveloperName ASC
            LIMIT 1
        ];
        return fallback.isEmpty() ? null : fallback.get(0);
    }

    /**
     * @description Populates a DTO from a resolved guide row, including
     *              comma-split permsets + JSON-deserialized checklist.
     * @param dto Mutable DTO to populate.
     * @param guide Resolved DevLoopGuide__mdt row.
     */
    private static void populateGuideDto(DevLoopGuideDTO dto, DevLoopGuide__mdt guide) {
        dto.recommendedCciFlow = guide.RecommendedCciFlowTxt__c;
        dto.seedDataset = guide.SeedDatasetTxt__c;
        dto.scratchOrgConfig = guide.ScratchOrgConfigTxt__c;
        dto.docsUrl = guide.DocsUrl__c;
        dto.requiredPermsets = splitPermsets(guide.RequiredPermsetsTxt__c);
        dto.setupChecklist = parseChecklist(guide.SetupChecklistJsonTxt__c);
    }

    /**
     * @description Splits the comma-separated permset list, trimming blanks.
     * @param raw Comma-delimited literal from the mdt row.
     * @return Cleaned list. Empty when raw is blank.
     */
    private static List<String> splitPermsets(String raw) {
        List<String> out = new List<String>();
        if (String.isBlank(raw)) {
            return out;
        }
        for (String piece : raw.split(',')) {
            String trimmed = piece == null ? '' : piece.trim();
            if (String.isNotBlank(trimmed)) {
                out.add(trimmed);
            }
        }
        return out;
    }

    /**
     * @description Deserializes the JSON checklist into typed DTOs. Returns
     *              empty list on parse failure (we never want a malformed
     *              checklist to break the LWC wire).
     * @param raw JSON literal from the mdt row.
     * @return Ordered checklist. Empty on blank/parse failure.
     */
    private static List<ChecklistStepDTO> parseChecklist(String raw) {
        List<ChecklistStepDTO> out = new List<ChecklistStepDTO>();
        if (String.isBlank(raw)) {
            return out;
        }
        try {
            List<Object> rows = (List<Object>) JSON.deserializeUntyped(raw);
            for (Object o : rows) {
                Map<String, Object> row = (Map<String, Object>) o;
                ChecklistStepDTO step = new ChecklistStepDTO();
                step.step = row.get('step') == null ? null : Integer.valueOf(row.get('step'));
                step.label = (String) row.get('label');
                step.command = (String) row.get('command');
                step.docsUrl = (String) row.get('docsUrl');
                out.add(step);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDevLoopController.parseChecklist] JSON parse failed: '
                + e.getMessage());
        }
        return out;
    }

    /**
     * @description Converts a ScratchOrgInstance__c row to its summary DTO.
     * @param soi Source row.
     * @return Populated DTO.
     */
    private static ScratchOrgSummaryDTO toSummary(ScratchOrgInstance__c soi) {
        ScratchOrgSummaryDTO summary = new ScratchOrgSummaryDTO();
        summary.scratchOrgId = soi.Id;
        summary.branch = soi.BranchTxt__c;
        summary.state = soi.StatePk__c;
        summary.loginUrl = soi.LoginUrl__c;
        summary.expiresAt = soi.ExpiresDateTime__c;
        summary.lastSyncAt = soi.LastSyncDateTime__c;
        return summary;
    }
}
