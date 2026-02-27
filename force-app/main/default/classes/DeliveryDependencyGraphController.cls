/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliveryDependencyGraph LWC.
 *              Provides BFS graph traversal to return the full connected component
 *              of work item dependencies for visualization.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryDependencyGraphController {

    /**
     * @description Returns the full connected dependency graph starting from a single work item.
     * Uses BFS to traverse all connections (both blocking and blocked-by) and returns the complete
     * connected component. Handles circular dependencies gracefully via a visited set.
     * @param workItemId The starting WorkItem__c record Id.
     * @return Map with 'nodes' (List of node maps) and 'edges' (List of edge maps).
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Map<String, Object> getDependencyGraph(Id workItemId) {
        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> nodes = new List<Map<String, Object>>();
        List<Map<String, Object>> edges = new List<Map<String, Object>>();

        if (workItemId == null) {
            result.put('nodes', nodes);
            result.put('edges', edges);
            return result;
        }

        // BFS to find all connected work item IDs
        Set<Id> visited = new Set<Id>();
        List<Id> queue = new List<Id>();
        queue.add(workItemId);
        visited.add(workItemId);

        // Collect all edges as we traverse
        Set<String> edgeKeys = new Set<String>();
        List<WorkItemDependency__c> allDeps = new List<WorkItemDependency__c>();

        // BFS loop — limit iterations to prevent runaway on very large graphs
        Integer maxIterations = 10;
        Integer iteration = 0;
        while (!queue.isEmpty() && iteration < maxIterations) {
            iteration++;
            List<Id> currentBatch = new List<Id>(queue);
            queue.clear();

            // Find all dependencies where any current batch item appears on either side
            List<WorkItemDependency__c> deps = [
                SELECT Id, BlockedWorkItemId__c, BlockingWorkItemId__c, TypePk__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__c IN :currentBatch
                   OR BlockingWorkItemId__c IN :currentBatch
                WITH SYSTEM_MODE
                LIMIT 200
            ];

            for (WorkItemDependency__c dep : deps) {
                String edgeKey = dep.BlockingWorkItemId__c + '->' + dep.BlockedWorkItemId__c;
                if (!edgeKeys.contains(edgeKey)) {
                    edgeKeys.add(edgeKey);
                    allDeps.add(dep);
                }

                // Queue unvisited neighbors
                if (!visited.contains(dep.BlockedWorkItemId__c)) {
                    visited.add(dep.BlockedWorkItemId__c);
                    queue.add(dep.BlockedWorkItemId__c);
                }
                if (!visited.contains(dep.BlockingWorkItemId__c)) {
                    visited.add(dep.BlockingWorkItemId__c);
                    queue.add(dep.BlockingWorkItemId__c);
                }
            }
        }

        // Load work item details for all visited nodes
        if (!visited.isEmpty()) {
            for (WorkItem__c wi : [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       WorkflowTypeTxt__c, OwnerId, Owner.Name
                FROM WorkItem__c
                WHERE Id IN :visited
                WITH SYSTEM_MODE
                ORDER BY Name ASC
            ]) {
                Map<String, Object> node = new Map<String, Object>();
                node.put('id', wi.Id);
                node.put('name', wi.Name);
                node.put('title', wi.BriefDescriptionTxt__c);
                node.put('stage', wi.StageNamePk__c);
                node.put('priority', wi.PriorityPk__c);
                node.put('owner', wi.Owner.Name);
                node.put('isCurrentItem', wi.Id == workItemId);
                nodes.add(node);
            }
        }

        // Build edge list
        for (WorkItemDependency__c dep : allDeps) {
            Map<String, Object> edge = new Map<String, Object>();
            edge.put('source', (String) dep.BlockingWorkItemId__c);
            edge.put('target', (String) dep.BlockedWorkItemId__c);
            edge.put('type', dep.TypePk__c);
            edges.add(edge);
        }

        result.put('nodes', nodes);
        result.put('edges', edges);
        return result;
    }

    /**
     * @description Returns the full dependency graph for all active (non-terminal) work items
     * within a given workflow type. Useful for a project-wide dependency view.
     * @param workflowType DeveloperName of the WorkflowType__mdt (e.g. 'Software_Delivery').
     * @return Map with 'nodes' and 'edges' keys.
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Map<String, Object> getProjectDependencyGraph(String workflowType) {
        Map<String, Object> result = new Map<String, Object>();
        List<Map<String, Object>> nodes = new List<Map<String, Object>>();
        List<Map<String, Object>> edges = new List<Map<String, Object>>();

        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }

        // Get terminal stages to exclude completed items
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);

        // Load all active non-terminal work items for this workflow type
        Map<Id, WorkItem__c> workItemMap = new Map<Id, WorkItem__c>([
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   WorkflowTypeTxt__c, OwnerId, Owner.Name
            FROM WorkItem__c
            WHERE IsActiveBool__c = true
            AND WorkflowTypeTxt__c = :workflowType
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            ORDER BY Name ASC
            LIMIT 200
        ]);

        if (workItemMap.isEmpty()) {
            result.put('nodes', nodes);
            result.put('edges', edges);
            return result;
        }

        // Load all dependencies between these work items
        Set<Id> workItemIds = workItemMap.keySet();
        List<WorkItemDependency__c> deps = [
            SELECT Id, BlockedWorkItemId__c, BlockingWorkItemId__c, TypePk__c
            FROM WorkItemDependency__c
            WHERE BlockedWorkItemId__c IN :workItemIds
               OR BlockingWorkItemId__c IN :workItemIds
            WITH SYSTEM_MODE
            LIMIT 500
        ];

        // Only include nodes that have at least one dependency connection
        Set<Id> connectedIds = new Set<Id>();
        for (WorkItemDependency__c dep : deps) {
            if (workItemIds.contains(dep.BlockedWorkItemId__c)) {
                connectedIds.add(dep.BlockedWorkItemId__c);
            }
            if (workItemIds.contains(dep.BlockingWorkItemId__c)) {
                connectedIds.add(dep.BlockingWorkItemId__c);
            }
        }

        // Build nodes from connected work items only
        for (Id wiId : connectedIds) {
            WorkItem__c wi = workItemMap.get(wiId);
            if (wi != null) {
                Map<String, Object> node = new Map<String, Object>();
                node.put('id', wi.Id);
                node.put('name', wi.Name);
                node.put('title', wi.BriefDescriptionTxt__c);
                node.put('stage', wi.StageNamePk__c);
                node.put('priority', wi.PriorityPk__c);
                node.put('owner', wi.Owner.Name);
                node.put('isCurrentItem', false);
                nodes.add(node);
            }
        }

        // Build edges (only between items in our set)
        for (WorkItemDependency__c dep : deps) {
            if (connectedIds.contains(dep.BlockedWorkItemId__c)
                && connectedIds.contains(dep.BlockingWorkItemId__c)) {
                Map<String, Object> edge = new Map<String, Object>();
                edge.put('source', (String) dep.BlockingWorkItemId__c);
                edge.put('target', (String) dep.BlockedWorkItemId__c);
                edge.put('type', dep.TypePk__c);
                edges.add(edge);
            }
        }

        result.put('nodes', nodes);
        result.put('edges', edges);
        return result;
    }
}
