/**
 * @description Reads WorkflowType__mdt, WorkflowStage__mdt, and WorkflowPersonaView__mdt
 * Custom Metadata to return board configuration to LWC components. Replaces all hardcoded
 * color maps, transition maps, and persona column maps in deliveryHubBoard.js.
 * @author Cloud Nimbus LLC
 */
public with sharing class WorkflowConfigService {

    // -------------------------------------------------------------------------
    // AuraEnabled — called by board / gantt / dashboard LWC components
    // -------------------------------------------------------------------------

    /**
     * @description Returns a summary list of all workflow types for the mode toggle.
     * Each entry includes developerName, label, sortOrder, iconName, and isDefault.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getWorkflowTypes() {
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (WorkflowType__mdt wt : [
            SELECT DeveloperName, Label, SortOrder__c, IconName__c, IsDefault__c, UseSimplifiedView__c
            FROM WorkflowType__mdt
            ORDER BY SortOrder__c ASC NULLS LAST, Label ASC
        ]) {
            Map<String,Object> m = new Map<String,Object>();
            m.put('developerName', wt.DeveloperName);
            m.put('label',         wt.Label);
            m.put('sortOrder',     wt.SortOrder__c);
            m.put('iconName',      wt.IconName__c);
            m.put('isDefault',     wt.IsDefault__c);
            m.put('useSimplifiedView', wt.UseSimplifiedView__c);
            result.add(m);
        }
        return result;
    }

    /**
     * @description Returns full board configuration for one workflow type including
     * all stages (with colors, transitions, phase, flags) and persona column groupings.
     *
     * Return shape:
     * {
     *   type: { developerName, label, useSimplifiedView },
     *   stages: [{ apiValue, displayName, cardColor, headerBgColor, headerTextColor,
     *              ownerPersona, phase, isTerminal, isBlockedState, isAttentionState,
     *              isVisibleByDefault, forwardTransitions:[], backtrackTransitions:[] }],
     *   personaViews: {
     *     Client: [{ columnName, stages:[], isExtended, sortOrder }],
     *     Consultant: [...], Developer: [...], QA: [...]
     *   }
     * }
     */
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getWorkflowConfig(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) {
            workflowTypeName = 'Software_Delivery';
        }

        // --- Load type record ---
        WorkflowType__mdt typeRec;
        List<WorkflowType__mdt> types = [
            SELECT DeveloperName, Label, UseSimplifiedView__c
            FROM WorkflowType__mdt
            WHERE DeveloperName = :workflowTypeName
            LIMIT 1
        ];
        if (types.isEmpty()) {
            throw new AuraHandledException('Unknown workflow type: ' + workflowTypeName);
        }
        typeRec = types[0];

        // --- Load stages ---
        List<Map<String,Object>> stages = new List<Map<String,Object>>();
        for (WorkflowStage__mdt s : [
            SELECT DeveloperName, ApiValue__c, DisplayName__c, SortOrder__c,
                   CardColor__c, HeaderBgColor__c, HeaderTextColor__c,
                   OwnerPersona__c, Phase__c,
                   IsTerminal__c, IsBlockedState__c, IsAttentionState__c, IsVisibleByDefault__c,
                   AllowedForwardTransitions__c, AllowedBacktrackTransitions__c,
                   WorkflowType__r.DeveloperName
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowTypeName
            ORDER BY SortOrder__c ASC NULLS LAST
        ]) {
            Map<String,Object> sm = new Map<String,Object>();
            sm.put('apiValue',            s.ApiValue__c);
            sm.put('displayName',         String.isNotBlank(s.DisplayName__c) ? s.DisplayName__c : s.ApiValue__c);
            sm.put('cardColor',           s.CardColor__c);
            sm.put('headerBgColor',       s.HeaderBgColor__c);
            sm.put('headerTextColor',     s.HeaderTextColor__c);
            sm.put('ownerPersona',        s.OwnerPersona__c);
            sm.put('phase',               s.Phase__c);
            sm.put('isTerminal',          s.IsTerminal__c);
            sm.put('isBlockedState',      s.IsBlockedState__c);
            sm.put('isAttentionState',    s.IsAttentionState__c);
            sm.put('isVisibleByDefault',  s.IsVisibleByDefault__c);
            sm.put('forwardTransitions',  parseCommaSep(s.AllowedForwardTransitions__c));
            sm.put('backtrackTransitions',parseCommaSep(s.AllowedBacktrackTransitions__c));
            stages.add(sm);
        }

        // --- Load persona views ---
        Map<String,List<Map<String,Object>>> personaViews = new Map<String,List<Map<String,Object>>>();
        for (WorkflowPersonaView__mdt pv : [
            SELECT PersonaName__c, ColumnName__c, StageApiValues__c, SortOrder__c, IsExtendedColumn__c
            FROM WorkflowPersonaView__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowTypeName
            ORDER BY PersonaName__c ASC, SortOrder__c ASC NULLS LAST
        ]) {
            String persona = pv.PersonaName__c;
            if (!personaViews.containsKey(persona)) {
                personaViews.put(persona, new List<Map<String,Object>>());
            }
            Map<String,Object> col = new Map<String,Object>();
            col.put('columnName',  pv.ColumnName__c);
            col.put('stages',      parseCommaSep(pv.StageApiValues__c));
            col.put('isExtended',  pv.IsExtendedColumn__c);
            col.put('sortOrder',   pv.SortOrder__c);
            personaViews.get(persona).add(col);
        }

        // --- Assemble result ---
        Map<String,Object> typeMap = new Map<String,Object>{
            'developerName'      => typeRec.DeveloperName,
            'label'              => typeRec.Label,
            'useSimplifiedView'  => typeRec.UseSimplifiedView__c
        };

        Map<String,Object> result = new Map<String,Object>();
        result.put('type',         typeMap);
        result.put('stages',       stages);
        result.put('personaViews', personaViews);
        return result;
    }

    // -------------------------------------------------------------------------
    // Internal helpers — called by other Apex classes
    // -------------------------------------------------------------------------

    /**
     * @description Returns the set of terminal stage ApiValues for a workflow type.
     * Used by BoardController.searchForPotentialBlockers to exclude terminal stages.
     */
    public static Set<String> getTerminalStageValues(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) { workflowTypeName = 'Software_Delivery'; }
        Set<String> result = new Set<String>();
        for (WorkflowStage__mdt s : [
            SELECT ApiValue__c
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowTypeName
            AND IsTerminal__c = TRUE
        ]) {
            result.add(s.ApiValue__c);
        }
        // Defensive: if CMT is empty (e.g. scratch org first deploy), default to 'Done'
        if (result.isEmpty()) {
            result.add('Done');
            result.add('Cancelled');
        }
        return result;
    }

    /**
     * @description Returns the set of attention stage ApiValues for a workflow type.
     * Used by DashboardController to build the Needs Attention section.
     */
    public static Set<String> getAttentionStageValues(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) { workflowTypeName = 'Software_Delivery'; }
        Set<String> result = new Set<String>();
        for (WorkflowStage__mdt s : [
            SELECT ApiValue__c
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowTypeName
            AND IsAttentionState__c = TRUE
        ]) {
            result.add(s.ApiValue__c);
        }
        // Defensive default
        if (result.isEmpty()) {
            result.addAll(new Set<String>{
                'Ready for Client Approval', 'In Client Approval',
                'Ready for Client UAT', 'In Client UAT', 'Ready for UAT Sign-off'
            });
        }
        return result;
    }

    /**
     * @description Returns a Map<ApiValue, Phase> for a workflow type.
     * Used by DashboardController to build the phase counts bar.
     */
    public static Map<String,String> getStagePhaseMap(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) { workflowTypeName = 'Software_Delivery'; }
        Map<String,String> result = new Map<String,String>();
        for (WorkflowStage__mdt s : [
            SELECT ApiValue__c, Phase__c
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowTypeName
            AND IsTerminal__c = FALSE
            AND Phase__c != null
        ]) {
            result.put(s.ApiValue__c, s.Phase__c);
        }
        return result;
    }

    // -------------------------------------------------------------------------
    // Private utility
    // -------------------------------------------------------------------------

    private static List<String> parseCommaSep(String raw) {
        List<String> result = new List<String>();
        if (String.isBlank(raw)) { return result; }
        for (String part : raw.split(',')) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }
}
