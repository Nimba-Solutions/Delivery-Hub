/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  BFS graph traversal for Feature__c dependency cascades.
 *               Drives the cockpit cascade-preview LWC (PR 5 — informational
 *               only). PR 6+ wires enforcement and approval on top of this
 *               surface, so the DTO + method signatures are designed to be
 *               additive (no shape changes expected when enforcement lands).
 *
 *               Adapted from DeliveryDependencyGraphController.traverseDependencies —
 *               same governor-safe pattern: a single upfront SOQL for all
 *               FeatureDependency__c rows, then BFS in memory with a visited
 *               guard. Cycle protection is bounded by a depth cap of 10.
 *
 *               Global because PR 8 may expose this surface via REST for the
 *               external onboarding portal. All inner classes used in the
 *               return signature are global per CLAUDE.md.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier')
global with sharing class DeliveryFeatureGraphService {

    /** Cap on BFS depth; protects against cycles and pathological graphs. */
    @TestVisible
    private static final Integer MAX_DEPTH = 10;

    /** Enable action — walks downward via BlockingFeatureLookup__c (what this feature depends on). */
    public static final String ACTION_ENABLE = 'Enable';

    /** Disable action — walks upward via BlockedFeatureLookup__c (what depends on this feature). */
    public static final String ACTION_DISABLE = 'Disable';

    /**
     * @description One node in the cascade tree. Mirrors a Feature__c row with
     *              the depth + edge-attributes that surfaced it. Children are
     *              the next BFS layer for that branch.
     */
    global class FeatureGraphNodeDTO {
        @AuraEnabled public Id featureId;
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Integer depth;
        @AuraEnabled public String dependencyType;
        @AuraEnabled public String cascadeDirection;
        @AuraEnabled public List<FeatureGraphNodeDTO> children;
    }

    /**
     * @description Returns the cascade tree rooted at featureId for the given action.
     *              'Enable' walks the dependency graph downward (BlockingFeatureLookup__c —
     *              the things THIS feature requires). 'Disable' walks upward
     *              (BlockedFeatureLookup__c — the things that require THIS feature).
     *              CascadeDirectionPk__c on each edge filters which direction the edge
     *              participates in. Cycle-safe via a visited set + depth cap.
     * @param featureId The starting Feature__c record Id.
     * @param action 'Enable' or 'Disable'. Anything else is treated as 'Enable'.
     * @return Root FeatureGraphNodeDTO with nested children, or a single-node tree if
     *         no dependencies exist. Returns null if featureId is null.
     */
    @AuraEnabled(cacheable=true)
    global static FeatureGraphNodeDTO computeCascade(Id featureId, String action) {
        if (featureId == null) {
            return null;
        }
        String resolvedAction = (action == ACTION_DISABLE) ? ACTION_DISABLE : ACTION_ENABLE;

        // Load all dependency records upfront — single SOQL, no loops
        List<FeatureDependency__c> allDeps = [
            SELECT Id, BlockingFeatureLookup__c, BlockedFeatureLookup__c,
                   TypePk__c, CascadeDirectionPk__c
            FROM FeatureDependency__c
            WITH SYSTEM_MODE
            LIMIT 2000
        ];

        // Build a directional adjacency for the requested action
        Map<Id, List<FeatureDependency__c>> adjacency = buildDirectionalAdjacency(allDeps, resolvedAction);

        // BFS walk, collecting per-feature edge info as we go
        Set<Id> visited = new Set<Id>{ featureId };
        Map<Id, FeatureGraphNodeDTO> nodesById = new Map<Id, FeatureGraphNodeDTO>();
        Map<Id, List<Id>> childrenByParent = new Map<Id, List<Id>>();
        Map<Id, FeatureDependency__c> edgeByChild = new Map<Id, FeatureDependency__c>();

        FeatureGraphNodeDTO root = newNode(featureId, 0, null);
        nodesById.put(featureId, root);

        List<Id> currentLayer = new List<Id>{ featureId };
        Integer depth = 0;
        while (!currentLayer.isEmpty() && depth < MAX_DEPTH) {
            List<Id> nextLayer = new List<Id>();
            for (Id parentId : currentLayer) {
                List<FeatureDependency__c> edges = adjacency.get(parentId);
                if (edges == null) {
                    continue;
                }
                for (FeatureDependency__c dep : edges) {
                    Id childId = childIdFor(dep, resolvedAction);
                    if (childId == null || visited.contains(childId)) {
                        continue;
                    }
                    visited.add(childId);
                    nextLayer.add(childId);
                    edgeByChild.put(childId, dep);
                    if (!childrenByParent.containsKey(parentId)) {
                        childrenByParent.put(parentId, new List<Id>());
                    }
                    childrenByParent.get(parentId).add(childId);
                }
            }
            depth++;
            currentLayer = nextLayer;
        }
        if (depth >= MAX_DEPTH && !currentLayer.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureGraphService.computeCascade] depth cap hit at '
                + MAX_DEPTH + ' for featureId=' + featureId);
        }

        // Hydrate node DTOs with Feature__c label/name/isActive in one bulk query
        hydrateNodes(visited, nodesById, edgeByChild, featureId);

        // Stitch children references onto each parent DTO
        attachChildren(nodesById, childrenByParent);
        return nodesById.get(featureId);
    }

    /**
     * @description Bulk-loads Feature__c details for all visited IDs and replaces
     *              the placeholder DTOs in nodesById with hydrated versions.
     *              The root keeps its existing dependency-type/direction nulls;
     *              child nodes pull their edge attributes from edgeByChild.
     * @param visited All Feature__c ids the BFS reached.
     * @param nodesById In/out — DTO map keyed by Feature__c id.
     * @param edgeByChild The FeatureDependency__c row that surfaced each child.
     * @param rootId The starting feature; gets isCurrentItem-equivalent treatment.
     */
    private static void hydrateNodes(
        Set<Id> visited,
        Map<Id, FeatureGraphNodeDTO> nodesById,
        Map<Id, FeatureDependency__c> edgeByChild,
        Id rootId
    ) {
        Map<Id, Feature__c> byId = new Map<Id, Feature__c>([
            SELECT Id, Name, FeatureDefinitionTxt__c, ActiveSinceDateTime__c
            FROM Feature__c
            WHERE Id IN :visited
            WITH SYSTEM_MODE
        ]);
        for (Id fid : visited) {
            FeatureGraphNodeDTO placeholder = nodesById.get(fid);
            Feature__c feature = byId.get(fid);
            if (feature != null) {
                placeholder.name = feature.Name;
                placeholder.label = feature.FeatureDefinitionTxt__c != null
                    ? feature.FeatureDefinitionTxt__c
                    : feature.Name;
                placeholder.isActive = feature.ActiveSinceDateTime__c != null;
            }
            FeatureDependency__c edge = edgeByChild.get(fid);
            if (edge != null) {
                placeholder.dependencyType = edge.TypePk__c;
                placeholder.cascadeDirection = edge.CascadeDirectionPk__c;
            }
        }
    }

    /**
     * @description Attaches child DTO lists in depth order using the per-parent
     *              child-id map collected during BFS.
     * @param nodesById All hydrated node DTOs keyed by Feature__c id.
     * @param childrenByParent BFS-collected parent-to-child id list.
     */
    private static void attachChildren(
        Map<Id, FeatureGraphNodeDTO> nodesById,
        Map<Id, List<Id>> childrenByParent
    ) {
        for (Id parentId : childrenByParent.keySet()) {
            FeatureGraphNodeDTO parent = nodesById.get(parentId);
            List<Id> kids = childrenByParent.get(parentId);
            for (Id kidId : kids) {
                FeatureGraphNodeDTO kidNode = nodesById.get(kidId);
                if (kidNode != null) {
                    if (kidNode.depth == 0) {
                        kidNode.depth = parent.depth + 1;
                    }
                    parent.children.add(kidNode);
                }
            }
        }
    }

    /**
     * @description Creates a fresh placeholder DTO with depth + empty children list.
     *              Label/name/isActive land later via hydrateNodes.
     * @param fid Feature__c id this node represents.
     * @param depth Distance from the root (0 for the root itself).
     * @param edge The FeatureDependency__c that surfaced this node, or null for the root.
     * @return A new FeatureGraphNodeDTO ready to be inserted into nodesById.
     */
    private static FeatureGraphNodeDTO newNode(Id fid, Integer depth, FeatureDependency__c edge) {
        FeatureGraphNodeDTO node = new FeatureGraphNodeDTO();
        node.featureId = fid;
        node.depth = depth;
        node.children = new List<FeatureGraphNodeDTO>();
        if (edge != null) {
            node.dependencyType = edge.TypePk__c;
            node.cascadeDirection = edge.CascadeDirectionPk__c;
        }
        return node;
    }

    /**
     * @description Builds a directional adjacency map respecting CascadeDirectionPk__c.
     *              For 'Enable' the parent side is BlockedFeatureLookup__c (you are
     *              the blocked one; we walk to your blockers). For 'Disable' the
     *              parent side is BlockingFeatureLookup__c (you are the blocker;
     *              we walk to your blocked dependents). CascadeDirection filters:
     *              DownOnly edges only show on Enable; UpOnly only on Disable; Both
     *              shows on both.
     * @param deps All FeatureDependency__c rows in the org.
     * @param action 'Enable' or 'Disable'.
     * @return Map keyed by the parent-side feature id; values are the edges out from it.
     */
    private static Map<Id, List<FeatureDependency__c>> buildDirectionalAdjacency(
        List<FeatureDependency__c> deps, String action
    ) {
        Map<Id, List<FeatureDependency__c>> adjacency = new Map<Id, List<FeatureDependency__c>>();
        for (FeatureDependency__c dep : deps) {
            if (!isEdgeVisible(dep.CascadeDirectionPk__c, action)) {
                continue;
            }
            Id parentSide = (action == ACTION_ENABLE)
                ? dep.BlockedFeatureLookup__c
                : dep.BlockingFeatureLookup__c;
            if (parentSide == null) {
                continue;
            }
            if (!adjacency.containsKey(parentSide)) {
                adjacency.put(parentSide, new List<FeatureDependency__c>());
            }
            adjacency.get(parentSide).add(dep);
        }
        return adjacency;
    }

    /**
     * @description Resolves the child-side feature id for an edge given the action direction.
     * @param dep The dependency row.
     * @param action 'Enable' or 'Disable'.
     * @return The feature id BFS should traverse to next.
     */
    private static Id childIdFor(FeatureDependency__c dep, String action) {
        return (action == ACTION_ENABLE)
            ? dep.BlockingFeatureLookup__c
            : dep.BlockedFeatureLookup__c;
    }

    /**
     * @description Whether a dependency edge participates in the given cascade direction.
     *              Null cascadeDirection is treated as 'Both' (defensive — picklist default
     *              should always be Both, but old test data may pass null).
     * @param cascadeDirection The edge's CascadeDirectionPk__c value.
     * @param action 'Enable' or 'Disable'.
     * @return true if the edge surfaces in this direction.
     */
    private static Boolean isEdgeVisible(String cascadeDirection, String action) {
        if (cascadeDirection == null || cascadeDirection == 'Both') {
            return true;
        }
        if (cascadeDirection == 'UpOnly') {
            return action == ACTION_DISABLE;
        }
        if (cascadeDirection == 'DownOnly') {
            return action == ACTION_ENABLE;
        }
        return true;
    }

    /**
     * @description Helper retained for potential reuse / readability — bulk fetch of
     *              direct dependencies for a set of feature ids in one of the two
     *              edge directions. Not used by computeCascade (which uses a single
     *              upfront query) but exposed for callers that only need one hop.
     * @param featureIds Parent-side feature ids to fetch edges for.
     * @param direction 'Enable' (parent = BlockedFeatureLookup__c) or
     *                  'Disable' (parent = BlockingFeatureLookup__c).
     * @return All matching FeatureDependency__c rows.
     */
    private static List<FeatureDependency__c> getDirectDependencies(Set<Id> featureIds, String direction) {
        if (direction == ACTION_ENABLE) {
            return [
                SELECT Id, BlockingFeatureLookup__c, BlockedFeatureLookup__c,
                       TypePk__c, CascadeDirectionPk__c
                FROM FeatureDependency__c
                WHERE BlockedFeatureLookup__c IN :featureIds
                WITH SYSTEM_MODE
                LIMIT 500
            ];
        }
        return [
            SELECT Id, BlockingFeatureLookup__c, BlockedFeatureLookup__c,
                   TypePk__c, CascadeDirectionPk__c
            FROM FeatureDependency__c
            WHERE BlockingFeatureLookup__c IN :featureIds
            WITH SYSTEM_MODE
            LIMIT 500
        ];
    }
}
