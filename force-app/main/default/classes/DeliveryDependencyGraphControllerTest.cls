/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryDependencyGraphController.
 *              Covers empty graph, linear chain, branching, circular dependencies,
 *              and project-wide graph queries.
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliveryDependencyGraphControllerTest {

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(BriefDescriptionTxt__c = 'Alpha', StageNamePk__c = 'Backlog', PriorityPk__c = 'High', SortOrderNumber__c = 1, IsActiveBool__c = true, WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Bravo', StageNamePk__c = 'In Progress', PriorityPk__c = 'Medium', SortOrderNumber__c = 2, IsActiveBool__c = true, WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Charlie', StageNamePk__c = 'Open', PriorityPk__c = 'Low', SortOrderNumber__c = 3, IsActiveBool__c = true, WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Delta', StageNamePk__c = 'Open', PriorityPk__c = 'High', SortOrderNumber__c = 4, IsActiveBool__c = true, WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Echo Isolated', StageNamePk__c = 'Open', PriorityPk__c = 'Medium', SortOrderNumber__c = 5, IsActiveBool__c = true, WorkflowTypeTxt__c = 'Software_Delivery'),
            new WorkItem__c(BriefDescriptionTxt__c = 'Done Item', StageNamePk__c = 'Done', PriorityPk__c = 'Low', SortOrderNumber__c = 6, IsActiveBool__c = true, WorkflowTypeTxt__c = 'Software_Delivery')
        };
        insert workItems;

        // Linear chain: Alpha blocks Bravo, Bravo blocks Charlie
        List<WorkItemDependency__c> deps = new List<WorkItemDependency__c>{
            new WorkItemDependency__c(BlockingWorkItemId__c = workItems[0].Id, BlockedWorkItemId__c = workItems[1].Id, TypePk__c = 'Blocks'),
            new WorkItemDependency__c(BlockingWorkItemId__c = workItems[1].Id, BlockedWorkItemId__c = workItems[2].Id, TypePk__c = 'Blocks'),
            // Branch: Alpha also blocks Delta
            new WorkItemDependency__c(BlockingWorkItemId__c = workItems[0].Id, BlockedWorkItemId__c = workItems[3].Id, TypePk__c = 'Blocks'),
            // Circular: Charlie blocks Alpha (creates A->B->C->A cycle)
            new WorkItemDependency__c(BlockingWorkItemId__c = workItems[2].Id, BlockedWorkItemId__c = workItems[0].Id, TypePk__c = 'Blocks')
        };
        insert deps;

        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testSingleItemNoDependencies() {
        WorkItem__c isolated = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Echo Isolated' LIMIT 1];

        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(isolated.Id);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        List<Object> edges = (List<Object>) graph.get('edges');

        // Isolated item should return just itself with no edges
        System.assertEquals(1, nodes.size(), 'Isolated item should have exactly 1 node');
        System.assertEquals(0, edges.size(), 'Isolated item should have 0 edges');

        Map<String, Object> node = (Map<String, Object>) nodes[0];
        System.assertEquals(true, node.get('isCurrentItem'), 'Node should be marked as current item');
    }

    @IsTest
    static void testLinearChain() {
        WorkItem__c bravo = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Bravo' LIMIT 1];

        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(bravo.Id);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        List<Object> edges = (List<Object>) graph.get('edges');

        // Starting from Bravo, BFS should find the entire connected component:
        // Alpha, Bravo, Charlie, Delta (all connected)
        System.assertEquals(4, nodes.size(), 'Should find 4 connected nodes');
        System.assert(edges.size() >= 3, 'Should find at least 3 edges in connected component');
    }

    @IsTest
    static void testBranching() {
        WorkItem__c alpha = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Alpha' LIMIT 1];

        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(alpha.Id);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');

        // Alpha blocks Bravo and Delta directly; Bravo blocks Charlie; Charlie blocks Alpha (cycle)
        // All 4 items should be in the connected component
        System.assertEquals(4, nodes.size(), 'Should find all 4 connected items from Alpha');

        // Verify current item flag
        Boolean foundCurrent = false;
        for (Object nodeObj : nodes) {
            Map<String, Object> node = (Map<String, Object>) nodeObj;
            if ((Boolean) node.get('isCurrentItem')) {
                System.assertEquals(alpha.Id, (Id) node.get('id'), 'Current item should be Alpha');
                foundCurrent = true;
            }
        }
        System.assert(foundCurrent, 'Should find the current item in the graph');
    }

    @IsTest
    static void testCircularDependencies() {
        // The cycle is Alpha -> Bravo -> Charlie -> Alpha
        // Verify BFS terminates and does not infinite loop
        WorkItem__c charlie = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Charlie' LIMIT 1];

        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(charlie.Id);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        List<Object> edges = (List<Object>) graph.get('edges');

        // Should still return the full component without blowing up
        System.assertEquals(4, nodes.size(), 'Circular graph should still return all 4 nodes');
        System.assertEquals(4, edges.size(), 'Should have 4 edges (A->B, B->C, A->D, C->A)');
    }

    @IsTest
    static void testNullWorkItemId() {
        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(null);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        List<Object> edges = (List<Object>) graph.get('edges');

        System.assertEquals(0, nodes.size(), 'Null ID should return empty nodes');
        System.assertEquals(0, edges.size(), 'Null ID should return empty edges');
    }

    @IsTest
    static void testProjectDependencyGraph() {
        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getProjectDependencyGraph('Software_Delivery');
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        List<Object> edges = (List<Object>) graph.get('edges');

        // Should include all connected non-terminal items
        // Alpha, Bravo, Charlie, Delta are connected and non-terminal
        // Echo Isolated has no deps, should be excluded
        // Done Item is terminal, should be excluded
        System.assert(nodes.size() >= 4, 'Project graph should include at least 4 connected non-terminal items');
        System.assert(edges.size() >= 3, 'Project graph should include at least 3 edges');
    }

    @IsTest
    static void testProjectDependencyGraphDefaultWorkflowType() {
        Test.startTest();
        // Passing null should default to Software_Delivery
        Map<String, Object> graph = DeliveryDependencyGraphController.getProjectDependencyGraph(null);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        // Should still return results using the default workflow type
        System.assertNotEquals(null, nodes, 'Should return nodes list even with null workflow type');
    }

    @IsTest
    static void testProjectDependencyGraphEmptyWorkflowType() {
        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getProjectDependencyGraph('Nonexistent_Type');
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        List<Object> edges = (List<Object>) graph.get('edges');

        // Non-existent type should return empty results
        System.assertEquals(0, nodes.size(), 'Unknown workflow type should return empty nodes');
        System.assertEquals(0, edges.size(), 'Unknown workflow type should return empty edges');
    }

    @IsTest
    static void testNodeDataStructure() {
        WorkItem__c alpha = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Alpha' LIMIT 1];

        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(alpha.Id);
        Test.stopTest();

        List<Object> nodes = (List<Object>) graph.get('nodes');
        // Find the Alpha node and verify its structure
        for (Object nodeObj : nodes) {
            Map<String, Object> node = (Map<String, Object>) nodeObj;
            if ((Boolean) node.get('isCurrentItem')) {
                System.assertNotEquals(null, node.get('id'), 'Node should have id');
                System.assertNotEquals(null, node.get('name'), 'Node should have name');
                System.assertEquals('Alpha', node.get('title'), 'Node title should match');
                System.assertEquals('Backlog', node.get('stage'), 'Node stage should match');
                System.assertEquals('High', node.get('priority'), 'Node priority should match');
                System.assertNotEquals(null, node.get('owner'), 'Node should have owner');
                break;
            }
        }
    }

    @IsTest
    static void testEdgeDataStructure() {
        WorkItem__c alpha = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Alpha' LIMIT 1];
        WorkItem__c bravo = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Bravo' LIMIT 1];

        Test.startTest();
        Map<String, Object> graph = DeliveryDependencyGraphController.getDependencyGraph(alpha.Id);
        Test.stopTest();

        List<Object> edges = (List<Object>) graph.get('edges');
        // Find the Alpha -> Bravo edge
        Boolean foundEdge = false;
        for (Object edgeObj : edges) {
            Map<String, Object> edge = (Map<String, Object>) edgeObj;
            if (edge.get('source') == String.valueOf(alpha.Id) && edge.get('target') == String.valueOf(bravo.Id)) {
                System.assertEquals('Blocks', edge.get('type'), 'Edge type should be Blocks');
                foundEdge = true;
                break;
            }
        }
        System.assert(foundEdge, 'Should find the Alpha->Bravo edge');
    }
}
