/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Workflow Builder LWC. Provides CRUD operations
 *               for WorkflowType, WorkflowStage, and WorkflowPersonaView custom metadata.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidDebugStatements,PMD.CyclomaticComplexity')
global with sharing class DeliveryWorkflowBuilderController {

    // ── Query Methods ────────────────────────────────────────────────────

    /**
     * @description Gets all existing workflow types with their stage counts.
     * @return List of maps with: developerName, label, description, icon, stageCount, isDefault
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getWorkflowTypes() {
        List<WorkflowType__mdt> types = [
            SELECT DeveloperName, Label, DescriptionTxt__c, IconName__c,
                   SortOrderNumber__c, DefaultDateTime__c
            FROM WorkflowType__mdt
            ORDER BY SortOrderNumber__c ASC
        ];

        // Count stages per workflow type
        Map<String, Integer> stageCounts = new Map<String, Integer>();
        for (WorkflowStage__mdt stage : [
            SELECT WorkflowType__r.DeveloperName
            FROM WorkflowStage__mdt
        ]) {
            String typeName = stage.WorkflowType__r.DeveloperName;
            if (!stageCounts.containsKey(typeName)) {
                stageCounts.put(typeName, 0);
            }
            stageCounts.put(typeName, stageCounts.get(typeName) + 1);
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkflowType__mdt wt : types) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('developerName', wt.DeveloperName);
            m.put('label', wt.Label);
            m.put('description', wt.DescriptionTxt__c);
            m.put('icon', wt.IconName__c);
            m.put('stageCount', stageCounts.containsKey(wt.DeveloperName)
                ? stageCounts.get(wt.DeveloperName) : 0);
            m.put('isDefault', wt.DefaultDateTime__c != null);
            result.add(m);
        }
        return result;
    }

    /**
     * @description Gets all stages for a given workflow type, ordered by sort order.
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record.
     * @return List of maps with stage field values.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getWorkflowStages(String workflowTypeName) {
        List<WorkflowStage__mdt> stages = [
            SELECT DeveloperName, Label, ApiValueTxt__c, DisplayNameTxt__c,
                   SortOrderNumber__c, PhaseTxt__c, CardColorTxt__c,
                   HeaderBgColorTxt__c, HeaderTextColorTxt__c, OwnerPersonaTxt__c,
                   TerminalDateTime__c, BlockedStateDateTime__c, AttentionStateDateTime__c,
                   VisibleByDefaultDateTime__c, AllowedForwardTransitionsTxt__c,
                   AllowedBacktrackTransitionsTxt__c, EtaWeightNumber__c
            FROM WorkflowStage__mdt
            WHERE WorkflowType__r.DeveloperName = :workflowTypeName
            ORDER BY SortOrderNumber__c ASC
        ];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkflowStage__mdt s : stages) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('developerName', s.DeveloperName);
            m.put('label', s.Label);
            m.put('apiValue', s.ApiValueTxt__c);
            m.put('displayName', s.DisplayNameTxt__c);
            m.put('sortOrder', s.SortOrderNumber__c);
            m.put('phase', s.PhaseTxt__c);
            m.put('cardColor', s.CardColorTxt__c);
            m.put('headerBgColor', s.HeaderBgColorTxt__c);
            m.put('headerTextColor', s.HeaderTextColorTxt__c);
            m.put('ownerPersona', s.OwnerPersonaTxt__c);
            m.put('isTerminal', s.TerminalDateTime__c != null);
            m.put('isBlocked', s.BlockedStateDateTime__c != null);
            m.put('isAttention', s.AttentionStateDateTime__c != null);
            m.put('isVisibleByDefault', s.VisibleByDefaultDateTime__c != null);
            m.put('forwardTransitions', s.AllowedForwardTransitionsTxt__c);
            m.put('backtrackTransitions', s.AllowedBacktrackTransitionsTxt__c);
            m.put('etaWeight', s.EtaWeightNumber__c);
            result.add(m);
        }
        return result;
    }

    // ── Deploy Methods ───────────────────────────────────────────────────

    /**
     * @description Deploys a new workflow type with its stages via the Metadata API.
     * Uses Metadata.DeployContainer for transactional deployment.
     * @param workflowJson JSON string containing workflow type + stages configuration.
     * @return The deployment ID for tracking.
     */
    @AuraEnabled
    global static String deployWorkflow(String workflowJson) {
        Map<String, Object> workflow = (Map<String, Object>) JSON.deserializeUntyped(workflowJson);

        String typeName = (String) workflow.get('name');
        String typeLabel = (String) workflow.get('label');
        String typeDescription = (String) workflow.get('description');
        String typeIcon = (String) workflow.get('icon');
        List<Object> stages = (List<Object>) workflow.get('stages');

        Metadata.DeployContainer container = new Metadata.DeployContainer();

        // ── WorkflowType__mdt record ─────────────────────────────────────
        Metadata.CustomMetadata typeRecord = new Metadata.CustomMetadata();
        typeRecord.fullName = 'WorkflowType__mdt.' + typeName;
        typeRecord.label = typeLabel;

        addMetadataValue(typeRecord, 'DescriptionTxt__c', typeDescription);
        addMetadataValue(typeRecord, 'IconName__c', typeIcon);
        addMetadataValue(typeRecord, 'SortOrderNumber__c', 100);

        container.addMetadata(typeRecord);

        // ── WorkflowStage__mdt records ───────────────────────────────────
        Integer sortOrder = 10;
        for (Object stageObj : stages) {
            Map<String, Object> stage = (Map<String, Object>) stageObj;

            Metadata.CustomMetadata stageRecord = new Metadata.CustomMetadata();
            String stageName = (String) stage.get('name');
            String stageApiName = typeName + '_' + stageName.replaceAll('[^a-zA-Z0-9]', '_');
            stageRecord.fullName = 'WorkflowStage__mdt.' + stageApiName;
            stageRecord.label = (String) stage.get('label');

            addMetadataValue(stageRecord, 'ApiValueTxt__c', stage.get('label'));
            addMetadataValue(stageRecord, 'DisplayNameTxt__c', stage.get('label'));
            addMetadataValue(stageRecord, 'SortOrderNumber__c', sortOrder);
            addMetadataValue(stageRecord, 'PhaseTxt__c', stage.get('phase'));
            addMetadataValue(stageRecord, 'CardColorTxt__c',
                stage.containsKey('color') ? stage.get('color') : '#e2e8f0');
            addMetadataValue(stageRecord, 'TerminalDateTime__c', stage.get('isTerminal') == true ? Datetime.now() : null);
            addMetadataValue(stageRecord, 'BlockedStateDateTime__c', stage.get('isBlocked') == true ? Datetime.now() : null);
            addMetadataValue(stageRecord, 'AttentionStateDateTime__c', stage.get('isAttention') == true ? Datetime.now() : null);
            addMetadataValue(stageRecord, 'VisibleByDefaultDateTime__c', Datetime.now());
            addMetadataValue(stageRecord, 'OwnerPersonaTxt__c', 'Admin');
            addMetadataValue(stageRecord, 'WorkflowType__c', typeName);

            if (stage.containsKey('nextStages')) {
                addMetadataValue(stageRecord, 'AllowedForwardTransitionsTxt__c',
                    stage.get('nextStages'));
            }

            container.addMetadata(stageRecord);
            sortOrder += 10;
        }

        // ── Default Admin WorkflowPersonaView__mdt records ───────────────
        Integer viewSort = 1;
        for (Object stageObj : stages) {
            Map<String, Object> stage = (Map<String, Object>) stageObj;

            Metadata.CustomMetadata viewRecord = new Metadata.CustomMetadata();
            String stageName = (String) stage.get('name');
            String viewApiName = typeName + '_Admin_' +
                String.valueOf(viewSort).leftPad(2, '0') + '_' +
                stageName.replaceAll('[^a-zA-Z0-9]', '_');
            viewRecord.fullName = 'WorkflowPersonaView__mdt.' + viewApiName;
            viewRecord.label = typeName + ' - Admin - ' + stage.get('label');

            addMetadataValue(viewRecord, 'WorkflowType__c', typeName);
            addMetadataValue(viewRecord, 'PersonaNameTxt__c', 'Admin');
            addMetadataValue(viewRecord, 'ColumnNameTxt__c', stage.get('label'));
            addMetadataValue(viewRecord, 'StageApiValuesTxt__c', stage.get('label'));
            addMetadataValue(viewRecord, 'SortOrderNumber__c', viewSort);
            addMetadataValue(viewRecord, 'ExtendedColumnDateTime__c', null);

            container.addMetadata(viewRecord);
            viewSort++;
        }

        // ── Deploy ───────────────────────────────────────────────────────
        Id deploymentId = Metadata.Operations.enqueueDeployment(container, null);
        return String.valueOf(deploymentId);
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    /**
     * @description Adds a single field value to a CustomMetadata record if the value is non-null.
     * @param record The CustomMetadata record to add the value to.
     * @param fieldName The API name of the metadata field.
     * @param value The value to set.
     */
    private static void addMetadataValue(
        Metadata.CustomMetadata record, String fieldName, Object value
    ) {
        if (value == null) {
            return;
        }
        Metadata.CustomMetadataValue field = new Metadata.CustomMetadataValue();
        field.field = fieldName;
        field.value = value;
        record.values.add(field);
    }
}
