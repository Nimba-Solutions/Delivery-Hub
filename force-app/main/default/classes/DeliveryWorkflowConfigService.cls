/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Reads WorkflowType__mdt, WorkflowStage__mdt, and WorkflowPersonaView__mdt
 * Custom Metadata to return board configuration to LWC components. Replaces all hardcoded
 * color maps, transition maps, and persona column maps in deliveryHubBoard.js.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
global with sharing class DeliveryWorkflowConfigService {

    // -------------------------------------------------------------------------
    // AuraEnabled — called by board / gantt / dashboard LWC components
    // -------------------------------------------------------------------------

    /**
     * @description Returns a summary list of all workflow types for the mode toggle.
     * Each entry includes developerName, label, sortOrder, iconName, and isDefault.
     * @return List of Maps, each representing one WorkflowType__mdt record.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String,Object>> getWorkflowTypes() {
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (WorkflowType__mdt wt : [
            SELECT DeveloperName, Label, SortOrderNumber__c, IconNameTxt__c, DefaultDateTime__c, UseSimplifiedViewDateTime__c
            FROM WorkflowType__mdt
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, Label ASC
        ]) {
            Map<String,Object> m = new Map<String,Object>();
            m.put('developerName', wt.DeveloperName);
            m.put('label',         wt.Label);
            m.put('sortOrder',     wt.SortOrderNumber__c);
            m.put('iconName',      wt.IconNameTxt__c);
            m.put('isDefault',     wt.DefaultDateTime__c != null);
            m.put('useSimplifiedView', wt.UseSimplifiedViewDateTime__c != null);
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
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record (e.g. 'Software_Delivery').
     *                         Defaults to 'Software_Delivery' when blank.
     * @return Map containing 'type', 'stages', and 'personaViews' keys.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String,Object> getWorkflowConfig(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) {
            workflowTypeName = 'Software_Delivery';
        }

        // --- Load type record ---
        WorkflowType__mdt typeRec;
        List<WorkflowType__mdt> types = [
            SELECT DeveloperName, Label, UseSimplifiedViewDateTime__c
            FROM WorkflowType__mdt
            WHERE DeveloperName = :workflowTypeName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (types.isEmpty()) {
            throw new AuraHandledException('Unknown workflow type: ' + workflowTypeName);
        }
        typeRec = types[0];

        // --- Load stages ---
        List<Map<String,Object>> stages = new List<Map<String,Object>>();
        for (WorkflowStage__mdt s : [
            SELECT DeveloperName, ApiValueTxt__c, DisplayNameTxt__c, SortOrderNumber__c,
                   CardColorTxt__c, HeaderBgColorTxt__c, HeaderTextColorTxt__c,
                   OwnerPersonaTxt__c, PhaseTxt__c,
                   TerminalDateTime__c, BlockedStateDateTime__c, AttentionStateDateTime__c, VisibleByDefaultDateTime__c,
                   AllowedForwardTransitionsTxt__c, AllowedBacktrackTransitionsTxt__c,
                   WorkflowTypeMdt__r.DeveloperName
            FROM WorkflowStage__mdt
            WHERE WorkflowTypeMdt__r.DeveloperName = :workflowTypeName
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ]) {
            Map<String,Object> sm = new Map<String,Object>();
            sm.put('apiValue',            s.ApiValueTxt__c);
            sm.put('displayName',         String.isNotBlank(s.DisplayNameTxt__c) ? s.DisplayNameTxt__c : s.ApiValueTxt__c);
            sm.put('cardColor',           s.CardColorTxt__c);
            sm.put('headerBgColor',       s.HeaderBgColorTxt__c);
            sm.put('headerTextColor',     s.HeaderTextColorTxt__c);
            sm.put('ownerPersona',        s.OwnerPersonaTxt__c);
            sm.put('phase',               s.PhaseTxt__c);
            sm.put('isTerminal',          s.TerminalDateTime__c != null);
            sm.put('isBlockedState',      s.BlockedStateDateTime__c != null);
            sm.put('isAttentionState',    s.AttentionStateDateTime__c != null);
            sm.put('isVisibleByDefault',  s.VisibleByDefaultDateTime__c != null);
            sm.put('forwardTransitions',  parseCommaSep(s.AllowedForwardTransitionsTxt__c));
            sm.put('backtrackTransitions',parseCommaSep(s.AllowedBacktrackTransitionsTxt__c));
            stages.add(sm);
        }

        // --- Load persona views ---
        Map<String,List<Map<String,Object>>> personaViews = new Map<String,List<Map<String,Object>>>();
        for (WorkflowPersonaView__mdt pv : [
            SELECT PersonaNameTxt__c, ColumnNameTxt__c, StageApiValuesTxt__c, SortOrderNumber__c, ExtendedColumnDateTime__c
            FROM WorkflowPersonaView__mdt
            WHERE WorkflowTypeMdt__r.DeveloperName = :workflowTypeName
            WITH SYSTEM_MODE
            ORDER BY PersonaNameTxt__c ASC, SortOrderNumber__c ASC NULLS LAST
        ]) {
            String persona = pv.PersonaNameTxt__c;
            if (!personaViews.containsKey(persona)) {
                personaViews.put(persona, new List<Map<String,Object>>());
            }
            Map<String,Object> col = new Map<String,Object>();
            col.put('columnName',  pv.ColumnNameTxt__c);
            col.put('stages',      parseCommaSep(pv.StageApiValuesTxt__c));
            col.put('isExtended',  pv.ExtendedColumnDateTime__c != null);
            col.put('sortOrder',   pv.SortOrderNumber__c);
            personaViews.get(persona).add(col);
        }

        // --- Assemble result ---
        Map<String,Object> typeMap = new Map<String,Object>{
            'developerName'      => typeRec.DeveloperName,
            'label'              => typeRec.Label,
            'useSimplifiedView'  => typeRec.UseSimplifiedViewDateTime__c != null
        };

        Map<String,Object> result = new Map<String,Object>();
        result.put('type',         typeMap);
        result.put('stages',       stages);
        result.put('personaViews', personaViews);
        return result;
    }

    /**
     * @description Returns enriched workflow template data for the template picker UI.
     * Each entry includes developerName, label, description, iconName, stageCount,
     * personas list, and stage color previews for the mini-pipeline visualization.
     * @return List of Maps, each representing one WorkflowType__mdt with enriched data.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String,Object>> getWorkflowTemplates() {
        // Load all types
        List<WorkflowType__mdt> types = [
            SELECT DeveloperName, Label, DescriptionTxt__c, IconNameTxt__c,
                   SortOrderNumber__c, DefaultDateTime__c, UseSimplifiedViewDateTime__c
            FROM WorkflowType__mdt
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, Label ASC
        ];

        // Collect stage counts and colors per type
        Map<String,List<String>> stageColorsByType = new Map<String,List<String>>();
        Map<String,Integer> stageCountByType = new Map<String,Integer>();
        for (WorkflowStage__mdt s : [
            SELECT WorkflowTypeMdt__r.DeveloperName, CardColorTxt__c
            FROM WorkflowStage__mdt
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ]) {
            String typeName = s.WorkflowTypeMdt__r.DeveloperName;
            if (!stageColorsByType.containsKey(typeName)) {
                stageColorsByType.put(typeName, new List<String>());
                stageCountByType.put(typeName, 0);
            }
            stageColorsByType.get(typeName).add(s.CardColorTxt__c);
            stageCountByType.put(typeName, stageCountByType.get(typeName) + 1);
        }

        // Collect unique persona names per type
        Map<String,Set<String>> personasByType = new Map<String,Set<String>>();
        for (WorkflowPersonaView__mdt pv : [
            SELECT WorkflowTypeMdt__r.DeveloperName, PersonaNameTxt__c
            FROM WorkflowPersonaView__mdt
            WITH SYSTEM_MODE
        ]) {
            String typeName = pv.WorkflowTypeMdt__r.DeveloperName;
            if (!personasByType.containsKey(typeName)) {
                personasByType.put(typeName, new Set<String>());
            }
            personasByType.get(typeName).add(pv.PersonaNameTxt__c);
        }

        // Collect unique, ordered phases per type
        Map<String,List<String>> phasesByType = new Map<String,List<String>>();
        for (WorkflowStage__mdt s : [
            SELECT WorkflowTypeMdt__r.DeveloperName, PhaseTxt__c
            FROM WorkflowStage__mdt
            WHERE PhaseTxt__c != null AND TerminalDateTime__c = null
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ]) {
            String typeName = s.WorkflowTypeMdt__r.DeveloperName;
            if (!phasesByType.containsKey(typeName)) {
                phasesByType.put(typeName, new List<String>());
            }
            List<String> phases = phasesByType.get(typeName);
            if (!phases.contains(s.PhaseTxt__c)) {
                phases.add(s.PhaseTxt__c);
            }
        }

        // Build result
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (WorkflowType__mdt wt : types) {
            Map<String,Object> m = new Map<String,Object>();
            m.put('developerName',     wt.DeveloperName);
            m.put('label',             wt.Label);
            m.put('description',       wt.DescriptionTxt__c);
            m.put('iconName',          wt.IconNameTxt__c);
            m.put('sortOrder',         wt.SortOrderNumber__c);
            m.put('isDefault',         wt.DefaultDateTime__c != null);
            m.put('useSimplifiedView', wt.UseSimplifiedViewDateTime__c != null);
            m.put('stageCount',        stageCountByType.containsKey(wt.DeveloperName)
                                        ? stageCountByType.get(wt.DeveloperName) : 0);
            m.put('stageColors',       stageColorsByType.containsKey(wt.DeveloperName)
                                        ? stageColorsByType.get(wt.DeveloperName) : new List<String>());
            m.put('personas',          personasByType.containsKey(wt.DeveloperName)
                                        ? new List<String>(personasByType.get(wt.DeveloperName)) : new List<String>());
            m.put('phases',            phasesByType.containsKey(wt.DeveloperName)
                                        ? phasesByType.get(wt.DeveloperName) : new List<String>());
            result.add(m);
        }
        return result;
    }

    // -------------------------------------------------------------------------
    // Internal helpers — called by other Apex classes
    // -------------------------------------------------------------------------

    /**
     * @description Returns the set of terminal stage ApiValues for a workflow type.
     * Used by BoardController.searchForPotentialBlockers to exclude terminal stages.
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record.
     * @return Set of ApiValue strings for all terminal stages (defaults to 'Done','Cancelled' if CMT empty).
     */
    public static Set<String> getTerminalStageValues(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) { workflowTypeName = 'Software_Delivery'; }
        Set<String> result = new Set<String>();
        for (WorkflowStage__mdt s : [
            SELECT ApiValueTxt__c
            FROM WorkflowStage__mdt
            WHERE WorkflowTypeMdt__r.DeveloperName = :workflowTypeName
            AND TerminalDateTime__c != null
            WITH SYSTEM_MODE
        ]) {
            result.add(s.ApiValueTxt__c);
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
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record.
     * @return Set of ApiValue strings for all attention stages.
     */
    public static Set<String> getAttentionStageValues(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) { workflowTypeName = 'Software_Delivery'; }
        Set<String> result = new Set<String>();
        for (WorkflowStage__mdt s : [
            SELECT ApiValueTxt__c
            FROM WorkflowStage__mdt
            WHERE WorkflowTypeMdt__r.DeveloperName = :workflowTypeName
            AND AttentionStateDateTime__c != null
            WITH SYSTEM_MODE
        ]) {
            result.add(s.ApiValueTxt__c);
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
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record.
     * @return Map from stage ApiValue to phase string for all non-terminal stages.
     */
    public static Map<String,String> getStagePhaseMap(String workflowTypeName) {
        if (String.isBlank(workflowTypeName)) { workflowTypeName = 'Software_Delivery'; }
        Map<String,String> result = new Map<String,String>();
        for (WorkflowStage__mdt s : [
            SELECT ApiValueTxt__c, PhaseTxt__c
            FROM WorkflowStage__mdt
            WHERE WorkflowTypeMdt__r.DeveloperName = :workflowTypeName
            AND TerminalDateTime__c = null
            AND PhaseTxt__c != null
            WITH SYSTEM_MODE
        ]) {
            result.put(s.ApiValueTxt__c, s.PhaseTxt__c);
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
