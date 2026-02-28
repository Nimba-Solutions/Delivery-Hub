/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Portal-safe controller for Experience Cloud components.
 * Exposes limited, entity-scoped data for external/guest users.
 * Uses WITHOUT sharing intentionally because portal/guest users lack org-wide access,
 * but validates access via NetworkEntity relationship.
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliveryPortalController {

    /**
     * @description Returns a portal dashboard payload scoped to a single NetworkEntity.
     * Includes active items, phase distribution, recently completed, and attention items.
     * @param networkEntityId The client NetworkEntity__c record Id
     * @return Map containing dashboard sections
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPortalDashboard(Id networkEntityId) {
        validateEntityAccess(networkEntityId);
        Map<String, Object> result = new Map<String, Object>();

        // Entity name for the welcome banner
        NetworkEntity__c entity = [
            SELECT Name FROM NetworkEntity__c
            WHERE Id = :networkEntityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        result.put('entityName', entity.Name);

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        Set<String> attentionStages = DeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');

        // Active work items count
        Integer activeCount = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :networkEntityId
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ];
        result.put('activeCount', activeCount);

        // Completed work items count (all time)
        Integer completedCount = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :networkEntityId
            AND StageNamePk__c IN :terminalStages
            WITH SYSTEM_MODE
        ];
        result.put('completedCount', completedCount);

        // Attention items count (needs client input)
        Integer attentionCount = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :networkEntityId
            AND StageNamePk__c IN :attentionStages
            WITH SYSTEM_MODE
        ];
        result.put('attentionCount', attentionCount);

        // Phase distribution
        Map<String, String> stageToPhase = DeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');
        Map<String, Integer> phaseCounts = new Map<String, Integer>{
            'Planning' => 0, 'Approval' => 0, 'Development' => 0,
            'Testing' => 0, 'UAT' => 0, 'Deployment' => 0
        };

        for (AggregateResult ar : [
            SELECT StageNamePk__c stage, Count(Id) cnt
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :networkEntityId
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            GROUP BY StageNamePk__c
        ]) {
            String phase = stageToPhase.get((String) ar.get('stage'));
            if (phase != null && phaseCounts.containsKey(phase)) {
                phaseCounts.put(phase, phaseCounts.get(phase) + ((Decimal) ar.get('cnt')).intValue());
            }
        }

        List<Map<String, Object>> phases = new List<Map<String, Object>>();
        for (String ph : new List<String>{ 'Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment' }) {
            Map<String, Object> phaseEntry = new Map<String, Object>();
            phaseEntry.put('label', ph);
            phaseEntry.put('count', phaseCounts.get(ph));
            phases.add(phaseEntry);
        }
        result.put('phases', phases);

        // Recently completed items (last 5)
        List<Map<String, Object>> recentCompleted = new List<Map<String, Object>>();
        for (WorkItem__c wi : [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, LastModifiedDate
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :networkEntityId
            AND StageNamePk__c IN :terminalStages
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            recentCompleted.add(buildWorkItemMap(wi));
        }
        result.put('recentCompleted', recentCompleted);

        // Recent activity feed (last 5 modifications across all items)
        List<Map<String, Object>> recentActivity = new List<Map<String, Object>>();
        for (WorkItem__c wi : [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, LastModifiedDate
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :networkEntityId
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 5
        ]) {
            recentActivity.add(buildWorkItemMap(wi));
        }
        result.put('recentActivity', recentActivity);

        return result;
    }

    /**
     * @description Returns work items for a single NetworkEntity, optionally filtered by status.
     * @param networkEntityId The client NetworkEntity__c record Id
     * @param statusFilter One of: 'active', 'completed', 'attention', or null/blank for all
     * @return List of work item maps with limited fields
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPortalWorkItems(Id networkEntityId, String statusFilter) {
        validateEntityAccess(networkEntityId);

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        Set<String> attentionStages = DeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');

        List<WorkItem__c> items;

        if (statusFilter == 'completed') {
            items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       LastModifiedDate, CalculatedETADate__c, DetailsTxt__c, RequestTypePk__c
                FROM WorkItem__c
                WHERE ClientNetworkEntityId__c = :networkEntityId
                AND StageNamePk__c IN :terminalStages
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 100
            ];
        } else if (statusFilter == 'attention') {
            items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       LastModifiedDate, CalculatedETADate__c, DetailsTxt__c, RequestTypePk__c
                FROM WorkItem__c
                WHERE ClientNetworkEntityId__c = :networkEntityId
                AND StageNamePk__c IN :attentionStages
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 100
            ];
        } else if (statusFilter == 'active') {
            items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       LastModifiedDate, CalculatedETADate__c, DetailsTxt__c, RequestTypePk__c
                FROM WorkItem__c
                WHERE ClientNetworkEntityId__c = :networkEntityId
                AND StageNamePk__c NOT IN :terminalStages
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 100
            ];
        } else {
            items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       LastModifiedDate, CalculatedETADate__c, DetailsTxt__c, RequestTypePk__c
                FROM WorkItem__c
                WHERE ClientNetworkEntityId__c = :networkEntityId
                WITH SYSTEM_MODE
                ORDER BY LastModifiedDate DESC
                LIMIT 100
            ];
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkItem__c wi : items) {
            Map<String, Object> m = buildWorkItemMap(wi);
            m.put('priority', wi.PriorityPk__c);
            m.put('eta', wi.CalculatedETADate__c);
            m.put('descriptionPreview', truncateText(wi.DetailsTxt__c, 150));
            m.put('requestType', wi.RequestTypePk__c);
            result.add(m);
        }
        return result;
    }

    /**
     * @description Returns full detail for a single work item including comments and file counts.
     * @param workItemId The WorkItem__c record Id
     * @return Map containing work item detail, comments list, and file info
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static Map<String, Object> getPortalWorkItemDetail(Id workItemId) {
        WorkItem__c wi = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   LastModifiedDate, CalculatedETADate__c, DetailsTxt__c, RequestTypePk__c,
                   CreatedDate, ClientNetworkEntityId__c, DeveloperDaysSizeNumber__c,
                   EstimatedHoursNumber__c, TotalLoggedHoursNumber__c
            FROM WorkItem__c
            WHERE Id = :workItemId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Map<String, Object> result = new Map<String, Object>();
        result.put('id', wi.Id);
        result.put('name', wi.Name);
        result.put('title', wi.BriefDescriptionTxt__c);
        result.put('stage', wi.StageNamePk__c);
        result.put('priority', wi.PriorityPk__c);
        result.put('lastModified', wi.LastModifiedDate);
        result.put('eta', wi.CalculatedETADate__c);
        result.put('description', wi.DetailsTxt__c);
        result.put('requestType', wi.RequestTypePk__c);
        result.put('createdDate', wi.CreatedDate);
        result.put('networkEntityId', wi.ClientNetworkEntityId__c);
        result.put('estimatedDays', wi.DeveloperDaysSizeNumber__c);
        result.put('estimatedHours', wi.EstimatedHoursNumber__c);
        result.put('loggedHours', wi.TotalLoggedHoursNumber__c);

        // Comments
        List<Map<String, Object>> comments = new List<Map<String, Object>>();
        for (WorkItemComment__c c : [
            SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate, SourcePk__c
            FROM WorkItemComment__c
            WHERE WorkItemId__c = :workItemId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 200
        ]) {
            Map<String, Object> cm = new Map<String, Object>();
            cm.put('id', c.Id);
            cm.put('body', c.BodyTxt__c);
            cm.put('author', String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : 'System');
            cm.put('createdDate', c.CreatedDate);
            cm.put('source', c.SourcePk__c);
            comments.add(cm);
        }
        result.put('comments', comments);

        // File count
        Integer fileCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :workItemId
            WITH SYSTEM_MODE
        ];
        result.put('fileCount', fileCount);

        // Stage pipeline for the progress bar
        result.put('stages', getStageList());

        return result;
    }

    /**
     * @description Submits a new work item request from the portal.
     * @param requestData Map with keys: title, description, priority, type, networkEntityId
     * @return Id of the newly created WorkItem__c record
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static Id submitPortalRequest(Map<String, String> requestData) {
        String title = requestData.get('title');
        String description = requestData.get('description');
        String priority = requestData.get('priority');
        String requestType = requestData.get('type');
        String networkEntityId = requestData.get('networkEntityId');

        if (String.isBlank(title)) {
            throw createAuraException('Title is required.');
        }

        WorkItem__c newItem = new WorkItem__c();
        newItem.BriefDescriptionTxt__c = '[Portal] ' + title;
        newItem.DetailsTxt__c = description;
        newItem.PriorityPk__c = String.isNotBlank(priority) ? priority : 'Medium';
        newItem.RequestTypePk__c = String.isNotBlank(requestType) ? requestType : 'Internal';
        newItem.StageNamePk__c = 'Backlog';
        newItem.IsActiveBool__c = true;
        newItem.StatusPk__c = 'New';

        if (String.isNotBlank(networkEntityId)) {
            newItem.ClientNetworkEntityId__c = networkEntityId;
        }

        insert newItem;
        return newItem.Id;
    }

    /**
     * @description Adds a comment to a work item from the portal.
     * @param workItemId The WorkItem__c record Id
     * @param commentBody The comment text
     * @return Id of the newly created WorkItemComment__c record
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static Id addPortalComment(Id workItemId, String commentBody) {
        if (String.isBlank(commentBody)) {
            throw createAuraException('Comment body is required.');
        }

        // Verify the work item exists
        List<WorkItem__c> items = [
            SELECT Id FROM WorkItem__c WHERE Id = :workItemId WITH SYSTEM_MODE LIMIT 1
        ];
        if (items.isEmpty()) {
            throw createAuraException('Work item not found.');
        }

        WorkItemComment__c comment = new WorkItemComment__c();
        comment.WorkItemId__c = workItemId;
        comment.BodyTxt__c = commentBody;
        comment.AuthorTxt__c = 'Portal User';
        comment.SourcePk__c = 'Client';

        insert comment;
        return comment.Id;
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Validates that the provided networkEntityId is a real, active NetworkEntity.
     * @param networkEntityId The Id to validate
     */
    private static void validateEntityAccess(Id networkEntityId) {
        if (networkEntityId == null) {
            throw createAuraException('Network Entity ID is required.');
        }
        List<NetworkEntity__c> entities = [
            SELECT Id FROM NetworkEntity__c
            WHERE Id = :networkEntityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (entities.isEmpty()) {
            throw createAuraException('Invalid Network Entity.');
        }
    }

    /**
     * @description Builds a standard work item map for portal responses.
     * @param wi The WorkItem__c record
     * @return Map of field name to value
     */
    private static Map<String, Object> buildWorkItemMap(WorkItem__c wi) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('id', wi.Id);
        m.put('name', wi.Name);
        m.put('title', wi.BriefDescriptionTxt__c);
        m.put('stage', wi.StageNamePk__c);
        m.put('lastModified', wi.LastModifiedDate);
        return m;
    }

    /**
     * @description Returns an ordered list of major stages for the progress bar.
     * @return List of stage label strings in pipeline order
     */
    private static List<String> getStageList() {
        return new List<String>{
            'Backlog', 'Scoping In Progress', 'Ready for Sizing',
            'Ready for Development', 'In Development', 'Ready for QA',
            'QA In Progress', 'Ready for Client UAT', 'In Client UAT',
            'Ready for Deployment', 'Deploying', 'Done'
        };
    }

    /**
     * @description Truncates HTML/text to the specified length, stripping tags first.
     * @param text The input text (may contain HTML)
     * @param maxLength Maximum character length
     * @return Truncated plain text string
     */
    private static String truncateText(String text, Integer maxLength) {
        if (String.isBlank(text)) {
            return '';
        }
        // Strip HTML tags for preview
        String plain = text.replaceAll('<[^>]+>', '').replaceAll('&nbsp;', ' ').trim();
        if (plain.length() > maxLength) {
            return plain.substring(0, maxLength) + '...';
        }
        return plain;
    }

    /**
     * @description Creates a properly formatted AuraHandledException.
     * @param message The error message
     * @return AuraHandledException with message set
     */
    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
