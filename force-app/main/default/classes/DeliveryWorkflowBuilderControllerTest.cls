/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWorkflowBuilderController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkflowBuilderControllerTest {

    // ── getWorkflowTypes ─────────────────────────────────────────────────

    @IsTest
    static void testGetWorkflowTypes() {
        // WorkflowType__mdt records exist in the org as custom metadata;
        // we can only verify the method executes without error and returns
        // the expected shape.
        Test.startTest();
        List<Map<String, Object>> types = DeliveryWorkflowBuilderController.getWorkflowTypes();
        Test.stopTest();

        System.assertNotEquals(null, types, 'Should return a non-null list');
        // Org should have at least one workflow type defined
        if (!types.isEmpty()) {
            Map<String, Object> first = types[0];
            System.assert(first.containsKey('developerName'), 'Map should contain developerName');
            System.assert(first.containsKey('label'), 'Map should contain label');
            System.assert(first.containsKey('stageCount'), 'Map should contain stageCount');
        }
    }

    // ── getWorkflowStages ────────────────────────────────────────────────

    @IsTest
    static void testGetWorkflowStages() {
        // Query for an existing workflow type to use
        List<WorkflowType__mdt> existingTypes = [
            SELECT DeveloperName FROM WorkflowType__mdt LIMIT 1
        ];
        String typeName = existingTypes.isEmpty() ? 'Software_Delivery' : existingTypes[0].DeveloperName;

        Test.startTest();
        List<Map<String, Object>> stages = DeliveryWorkflowBuilderController.getWorkflowStages(typeName);
        Test.stopTest();

        System.assertNotEquals(null, stages, 'Should return a non-null list');
        if (!stages.isEmpty()) {
            Map<String, Object> first = stages[0];
            System.assert(first.containsKey('apiValue'), 'Map should contain apiValue');
            System.assert(first.containsKey('phase'), 'Map should contain phase');
            System.assert(first.containsKey('sortOrder'), 'Map should contain sortOrder');
        }
    }

    @IsTest
    static void testGetWorkflowStagesNonExistent() {
        Test.startTest();
        List<Map<String, Object>> stages = DeliveryWorkflowBuilderController.getWorkflowStages(
            'Non_Existent_Type_XYZ'
        );
        Test.stopTest();

        System.assertNotEquals(null, stages, 'Should return a non-null list');
        System.assertEquals(0, stages.size(), 'Should return empty list for non-existent type');
    }

    // ── deployWorkflow ───────────────────────────────────────────────────

    @IsTest
    static void testDeployWorkflow() {
        Map<String, Object> workflow = new Map<String, Object>{
            'name' => 'Test_Workflow',
            'label' => 'Test Workflow',
            'description' => 'A test workflow for unit testing.',
            'icon' => 'utility:flow',
            'stages' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'Open',
                    'label' => 'Open',
                    'phase' => 'Planning',
                    'color' => '#e2e8f0',
                    'isTerminal' => false,
                    'isBlocked' => false,
                    'isAttention' => false,
                    'nextStages' => 'In Progress'
                },
                new Map<String, Object>{
                    'name' => 'In_Progress',
                    'label' => 'In Progress',
                    'phase' => 'Development',
                    'color' => '#bfdbfe',
                    'isTerminal' => false,
                    'isBlocked' => false,
                    'isAttention' => false,
                    'nextStages' => 'Done'
                },
                new Map<String, Object>{
                    'name' => 'Done',
                    'label' => 'Done',
                    'phase' => 'Deployment',
                    'color' => '#bbf7d0',
                    'isTerminal' => true,
                    'isBlocked' => false,
                    'isAttention' => false
                }
            }
        };

        Test.startTest();
        String deploymentId = DeliveryWorkflowBuilderController.deployWorkflow(
            JSON.serialize(workflow)
        );
        Test.stopTest();

        System.assertNotEquals(null, deploymentId, 'Should return a deployment ID');
        System.assert(String.isNotBlank(deploymentId), 'Deployment ID should not be blank');
    }
}
