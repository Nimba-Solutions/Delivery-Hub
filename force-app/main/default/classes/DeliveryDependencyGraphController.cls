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

        if (workItemId == null) {
            result.put('nodes', new List<Map<String, Object>>());
            result.put('edges', new List<Map<String, Object>>());
            return result;
        }

        // BFS to find all connected work item IDs and dependency records
        Set<Id> visited = new Set<Id>{ workItemId };
        List<WorkItemDependency__c> allDeps = traverseDependencies(visited);

        // Build response
        result.put('nodes', buildNodes(visited, workItemId));
        result.put('edges', buildEdges(allDeps));
        return result;
    }

    /**
     * @description BFS traversal that discovers the full connected component of dependencies.
     * Modifies the visited set in place to accumulate all connected work item IDs.
     * @param visited Set of IDs seeded with the starting work item; expanded during traversal.
     * @return All unique WorkItemDependency__c records found during traversal.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<WorkItemDependency__c> traverseDependencies(Set<Id> visited) {
        Set<String> edgeKeys = new Set<String>();
        List<WorkItemDependency__c> allDeps = new List<WorkItemDependency__c>();
        List<Id> queue = new List<Id>(visited);

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
                enqueueIfUnvisited(dep.BlockedWorkItemId__c, visited, queue);
                enqueueIfUnvisited(dep.BlockingWorkItemId__c, visited, queue);
            }
        }
        return allDeps;
    }

    /**
     * @description Adds a work item ID to the BFS queue if it has not yet been visited.
     * @param itemId The work item ID to check.
     * @param visited The set of already-visited IDs (modified in place).
     * @param queue The BFS queue (modified in place).
     */
    private static void enqueueIfUnvisited(Id itemId, Set<Id> visited, List<Id> queue) {
        if (!visited.contains(itemId)) {
            visited.add(itemId);
            queue.add(itemId);
        }
    }

    /**
     * @description Queries work item details and builds the node list for the graph response.
     * @param workItemIds The set of work item IDs to include as nodes.
     * @param currentItemId The ID of the starting work item (marked with isCurrentItem=true).
     * @return List of node maps with id, name, title, stage, priority, owner, and isCurrentItem.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<Map<String, Object>> buildNodes(Set<Id> workItemIds, Id currentItemId) {
        List<Map<String, Object>> nodes = new List<Map<String, Object>>();
        for (WorkItem__c wi : [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   WorkflowTypeTxt__c, OwnerId, Owner.Name
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
            ORDER BY Name ASC
        ]) {
            nodes.add(buildNodeMap(wi, wi.Id == currentItemId));
        }
        return nodes;
    }

    /**
     * @description Creates a single node map from a WorkItem__c record.
     * @param wi The work item record.
     * @param isCurrentItem Whether this node is the starting item for the graph.
     * @return Map with node properties for the LWC graph component.
     */
    private static Map<String, Object> buildNodeMap(WorkItem__c wi, Boolean isCurrentItem) {
        Map<String, Object> node = new Map<String, Object>();
        node.put('id', wi.Id);
        node.put('name', wi.Name);
        node.put('title', wi.BriefDescriptionTxt__c);
        node.put('stage', wi.StageNamePk__c);
        node.put('priority', wi.PriorityPk__c);
        node.put('owner', wi.Owner.Name);
        node.put('isCurrentItem', isCurrentItem);
        return node;
    }

    /**
     * @description Converts dependency records into edge maps for the graph response.
     * @param deps The list of WorkItemDependency__c records.
     * @return List of edge maps with source, target, and type.
     */
    private static List<Map<String, Object>> buildEdges(List<WorkItemDependency__c> deps) {
        List<Map<String, Object>> edges = new List<Map<String, Object>>();
        for (WorkItemDependency__c dep : deps) {
            Map<String, Object> edge = new Map<String, Object>();
            edge.put('source', (String) dep.BlockingWorkItemId__c);
            edge.put('target', (String) dep.BlockedWorkItemId__c);
            edge.put('type', dep.TypePk__c);
            edges.add(edge);
        }
        return edges;
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
            result.put('nodes', new List<Map<String, Object>>());
            result.put('edges', new List<Map<String, Object>>());
            return result;
        }

        // Load all dependencies and determine connected nodes
        Set<Id> workItemIds = workItemMap.keySet();
        List<WorkItemDependency__c> deps = queryProjectDependencies(workItemIds);
        Set<Id> connectedIds = findConnectedIds(deps, workItemIds);

        // Build response
        result.put('nodes', buildProjectNodes(connectedIds, workItemMap));
        result.put('edges', buildFilteredEdges(deps, connectedIds));
        return result;
    }

    /**
     * @description Queries all dependency records for a set of work item IDs.
     * @param workItemIds The set of work item IDs to query dependencies for.
     * @return List of WorkItemDependency__c records where either side matches the set.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static List<WorkItemDependency__c> queryProjectDependencies(Set<Id> workItemIds) {
        return [
            SELECT Id, BlockedWorkItemId__c, BlockingWorkItemId__c, TypePk__c
            FROM WorkItemDependency__c
            WHERE BlockedWorkItemId__c IN :workItemIds
               OR BlockingWorkItemId__c IN :workItemIds
            WITH SYSTEM_MODE
            LIMIT 500
        ];
    }

    /**
     * @description Identifies work item IDs that have at least one dependency connection
     * within the provided scope.
     * @param deps The dependency records to scan.
     * @param scopeIds The set of work item IDs considered in scope.
     * @return Set of IDs that appear in at least one dependency within scope.
     */
    private static Set<Id> findConnectedIds(List<WorkItemDependency__c> deps, Set<Id> scopeIds) {
        Set<Id> connectedIds = new Set<Id>();
        for (WorkItemDependency__c dep : deps) {
            if (scopeIds.contains(dep.BlockedWorkItemId__c)) {
                connectedIds.add(dep.BlockedWorkItemId__c);
            }
            if (scopeIds.contains(dep.BlockingWorkItemId__c)) {
                connectedIds.add(dep.BlockingWorkItemId__c);
            }
        }
        return connectedIds;
    }

    /**
     * @description Builds node maps for connected work items from a pre-loaded map.
     * @param connectedIds The IDs of connected work items to include.
     * @param workItemMap The map of all queried work items.
     * @return List of node maps for connected items.
     */
    private static List<Map<String, Object>> buildProjectNodes(Set<Id> connectedIds, Map<Id, WorkItem__c> workItemMap) {
        List<Map<String, Object>> nodes = new List<Map<String, Object>>();
        for (Id wiId : connectedIds) {
            WorkItem__c wi = workItemMap.get(wiId);
            if (wi != null) {
                nodes.add(buildNodeMap(wi, false));
            }
        }
        return nodes;
    }

    /**
     * @description Builds edge maps filtered to only include edges where both endpoints
     * are in the connected set.
     * @param deps The full list of dependency records.
     * @param connectedIds The set of connected work item IDs.
     * @return List of edge maps for dependencies between connected items.
     */
    private static List<Map<String, Object>> buildFilteredEdges(List<WorkItemDependency__c> deps, Set<Id> connectedIds) {
        List<Map<String, Object>> edges = new List<Map<String, Object>>();
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
        return edges;
    }
}
