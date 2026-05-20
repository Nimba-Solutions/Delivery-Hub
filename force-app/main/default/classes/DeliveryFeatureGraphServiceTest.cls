/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryFeatureGraphService.computeCascade.
 *               Covers: empty graph, linear chain, diamond (visited guard),
 *               cycle (depth cap), CascadeDirection respect (UpOnly vs DownOnly).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFeatureGraphServiceTest {

    @IsTest
    static void testNullFeatureIdReturnsNull() {
        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO result =
            DeliveryFeatureGraphService.computeCascade(null, 'Enable');
        Test.stopTest();
        System.assertEquals(null, result, 'Null featureId should return null');
    }

    @IsTest
    static void testEmptyGraphReturnsSingleNodeRoot() {
        Feature__c only = TestDataFactory.createFeature(null);

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(only.Id, 'Enable');
        Test.stopTest();

        System.assertNotEquals(null, root, 'Root should not be null');
        System.assertEquals(only.Id, root.featureId, 'Root featureId matches input');
        System.assertEquals(0, root.depth, 'Root depth is 0');
        System.assertEquals(0, root.children.size(), 'Empty graph yields zero children');
    }

    @IsTest
    static void testLinearChainEnableWalksDownward() {
        // A -> B -> C (A depends on B depends on C). Starting at A with Enable
        // should walk to B then C.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });
        Feature__c featC = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'C' });

        // B blocks A (A is the blocked one) → enabling A requires B first
        TestDataFactory.newFeatureDependency(featB.Id, featA.Id);
        // C blocks B (B is the blocked one) → enabling B requires C first
        TestDataFactory.newFeatureDependency(featC.Id, featB.Id);

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featA.Id, 'Enable');
        Test.stopTest();

        System.assertEquals(featA.Id, root.featureId, 'Root is A');
        System.assertEquals(1, root.children.size(), 'A has 1 dependency (B)');
        DeliveryFeatureGraphService.FeatureGraphNodeDTO bNode = root.children[0];
        System.assertEquals(featB.Id, bNode.featureId, 'First hop is B');
        System.assertEquals(1, bNode.depth, 'B is at depth 1');
        System.assertEquals(1, bNode.children.size(), 'B has 1 dependency (C)');
        DeliveryFeatureGraphService.FeatureGraphNodeDTO cNode = bNode.children[0];
        System.assertEquals(featC.Id, cNode.featureId, 'Second hop is C');
        System.assertEquals(2, cNode.depth, 'C is at depth 2');
    }

    @IsTest
    static void testDiamondGraphVisitsEachNodeOnce() {
        // Diamond: A depends on B and C; both B and C depend on D.
        // Enable A → BFS should reach D exactly once (visited guard).
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });
        Feature__c featC = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'C' });
        Feature__c featD = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'D' });

        TestDataFactory.newFeatureDependency(featB.Id, featA.Id); // B blocks A
        TestDataFactory.newFeatureDependency(featC.Id, featA.Id); // C blocks A
        TestDataFactory.newFeatureDependency(featD.Id, featB.Id); // D blocks B
        TestDataFactory.newFeatureDependency(featD.Id, featC.Id); // D blocks C

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featA.Id, 'Enable');
        Test.stopTest();

        Integer dCount = countOccurrences(root, featD.Id);
        System.assertEquals(1, dCount, 'D should appear exactly once across the tree');
        // root has 2 direct children
        System.assertEquals(2, root.children.size(), 'A has 2 direct dependencies');
    }

    @IsTest
    static void testCycleTerminatesAtDepthCap() {
        // A <-> B cycle. computeCascade must not infinite loop.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });

        TestDataFactory.newFeatureDependency(featB.Id, featA.Id); // B blocks A
        TestDataFactory.newFeatureDependency(featA.Id, featB.Id); // A blocks B (cycle)

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featA.Id, 'Enable');
        Test.stopTest();

        // Visited-guard means each feature appears once. We expect A → B and stop.
        System.assertEquals(featA.Id, root.featureId, 'Root is A');
        System.assertEquals(1, root.children.size(), 'Visited guard prevents revisit');
        System.assertEquals(featB.Id, root.children[0].featureId, 'First (only) hop is B');
        System.assertEquals(0, root.children[0].children.size(), 'B does not re-traverse to A');
    }

    @IsTest
    static void testUpOnlyEdgeInvisibleToEnable() {
        // B blocks A with CascadeDirection=UpOnly. Enable on A should NOT walk to B.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });

        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'CascadeDirectionPk__c' => 'UpOnly' });

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featA.Id, 'Enable');
        Test.stopTest();

        System.assertEquals(0, root.children.size(),
            'UpOnly edge should be invisible to Enable action');
    }

    @IsTest
    static void testUpOnlyEdgeVisibleToDisable() {
        // B blocks A with CascadeDirection=UpOnly. Disable on B should walk to A
        // (downstream consumers must disable first).
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });

        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'CascadeDirectionPk__c' => 'UpOnly' });

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featB.Id, 'Disable');
        Test.stopTest();

        System.assertEquals(1, root.children.size(),
            'UpOnly edge should be visible to Disable action');
        System.assertEquals(featA.Id, root.children[0].featureId, 'Reached A from B');
    }

    @IsTest
    static void testDownOnlyEdgeInvisibleToDisable() {
        // B blocks A with CascadeDirection=DownOnly. Disable on B should NOT walk to A.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });

        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'CascadeDirectionPk__c' => 'DownOnly' });

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featB.Id, 'Disable');
        Test.stopTest();

        System.assertEquals(0, root.children.size(),
            'DownOnly edge should be invisible to Disable action');
    }

    @IsTest
    static void testDependencyTypePropagatedToChild() {
        // Confirm the edge's TypePk shows up on the surfaced child node.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'A' });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{ 'Name' => 'B' });

        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'TypePk__c' => 'Soft' });

        Test.startTest();
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featA.Id, 'Enable');
        Test.stopTest();

        System.assertEquals(1, root.children.size(), 'Reached B');
        System.assertEquals('Soft', root.children[0].dependencyType,
            'Child node carries the edge TypePk');
    }

    /**
     * @description Walk the tree and count how many times a given featureId appears.
     *              Used to verify the visited-guard behavior.
     */
    private static Integer countOccurrences(DeliveryFeatureGraphService.FeatureGraphNodeDTO node, Id targetId) {
        if (node == null) {
            return 0;
        }
        Integer total = (node.featureId == targetId) ? 1 : 0;
        for (DeliveryFeatureGraphService.FeatureGraphNodeDTO child : node.children) {
            total += countOccurrences(child, targetId);
        }
        return total;
    }
}
