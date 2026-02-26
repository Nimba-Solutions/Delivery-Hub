/**
 * @description Tests for DeliveryDeliveryWorkflowConfigService.
 * @author Cloud Nimbus LLC
 */
@isTest
private class WorkflowConfigServiceTest {

    @isTest
    static void testGetWorkflowTypes() {
        List<Map<String,Object>> types = DeliveryDeliveryWorkflowConfigService.getWorkflowTypes();
        // Must have at least the two built-in workflow types
        System.assert(types.size() >= 2, 'Expected at least 2 workflow types, got ' + types.size());

        // Verify structure of each returned map
        for (Map<String,Object> t : types) {
            System.assertNotEquals(null, t.get('developerName'), 'developerName must be present');
            System.assertNotEquals(null, t.get('label'), 'label must be present');
        }

        // At least one default type should exist
        Boolean hasDefault = false;
        for (Map<String,Object> t : types) {
            if ((Boolean)t.get('isDefault') == true) { hasDefault = true; }
        }
        System.assert(hasDefault, 'At least one WorkflowType must be marked IsDefault');
    }

    @isTest
    static void testGetWorkflowConfigSoftwareDelivery() {
        Map<String,Object> config = DeliveryDeliveryWorkflowConfigService.getWorkflowConfig('Software_Delivery');

        System.assertNotEquals(null, config, 'Config must not be null');

        // Verify type metadata
        Map<String,Object> typeMap = (Map<String,Object>) config.get('type');
        System.assertEquals('Software_Delivery', typeMap.get('developerName'), 'developerName must be Software_Delivery');
        System.assertEquals(false, typeMap.get('useSimplifiedView'), 'Software_Delivery uses persona views (not simplified)');

        // Verify stages
        List<Object> stages = (List<Object>) config.get('stages');
        System.assert(stages.size() >= 36, 'Software_Delivery must have at least 36 stages, got ' + stages.size());

        // Verify each stage has required fields and parseable transitions
        for (Object stageObj : stages) {
            Map<String,Object> s = (Map<String,Object>) stageObj;
            System.assertNotEquals(null, s.get('apiValue'), 'apiValue must be set');
            System.assertNotEquals(null, s.get('cardColor'), 'cardColor must be set for ' + s.get('apiValue'));
            System.assertNotEquals(null, s.get('ownerPersona'), 'ownerPersona must be set for ' + s.get('apiValue'));
            // forwardTransitions must be a List (possibly empty)
            System.assertNotEquals(null, s.get('forwardTransitions'), 'forwardTransitions must not be null');
        }

        // Verify persona views exist for all 4 personas
        Map<String,Object> personaViews = (Map<String,Object>) config.get('personaViews');
        System.assert(personaViews.containsKey('Client'), 'Client persona view required');
        System.assert(personaViews.containsKey('Consultant'), 'Consultant persona view required');
        System.assert(personaViews.containsKey('Developer'), 'Developer persona view required');
        System.assert(personaViews.containsKey('QA'), 'QA persona view required');
    }

    @isTest
    static void testGetWorkflowConfigLoanApproval() {
        Map<String,Object> config = DeliveryDeliveryWorkflowConfigService.getWorkflowConfig('Loan_Approval');
        System.assertNotEquals(null, config, 'Loan_Approval config must not be null');

        Map<String,Object> typeMap = (Map<String,Object>) config.get('type');
        System.assertEquals('Loan_Approval', typeMap.get('developerName'), 'developerName must be Loan_Approval');
        System.assertEquals(true, typeMap.get('useSimplifiedView'), 'Loan_Approval uses simplified view');

        List<Object> stages = (List<Object>) config.get('stages');
        System.assertEquals(8, stages.size(), 'Loan_Approval must have exactly 8 stages');
    }

    @isTest
    static void testGetWorkflowConfigBlankDefaultsToSoftwareDelivery() {
        Map<String,Object> configBlank = DeliveryDeliveryWorkflowConfigService.getWorkflowConfig('');
        Map<String,Object> configNull  = DeliveryDeliveryWorkflowConfigService.getWorkflowConfig(null);

        Map<String,Object> typeBlank = (Map<String,Object>) configBlank.get('type');
        Map<String,Object> typeNull  = (Map<String,Object>) configNull.get('type');

        System.assertEquals('Software_Delivery', typeBlank.get('developerName'), 'Blank name must default to Software_Delivery');
        System.assertEquals('Software_Delivery', typeNull.get('developerName'), 'Null name must default to Software_Delivery');
    }

    @isTest
    static void testGetTerminalStageValues() {
        Set<String> terminals = DeliveryDeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        System.assert(!terminals.isEmpty(), 'Terminal stages must not be empty');
        System.assert(terminals.contains('Done'), 'Done must be terminal for Software_Delivery');
        System.assert(terminals.contains('Cancelled'), 'Cancelled must be terminal for Software_Delivery');
    }

    @isTest
    static void testGetAttentionStageValues() {
        Set<String> attention = DeliveryDeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');
        System.assert(!attention.isEmpty(), 'Attention stages must not be empty');
        System.assert(attention.contains('Ready for Client Approval'), 'Ready for Client Approval must be an attention stage');
        System.assert(attention.contains('In Client UAT'), 'In Client UAT must be an attention stage');
    }

    @isTest
    static void testGetStagePhaseMap() {
        Map<String,String> phaseMap = DeliveryDeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');
        System.assert(!phaseMap.isEmpty(), 'Phase map must not be empty');
        System.assertEquals('Planning', phaseMap.get('Backlog'), 'Backlog must map to Planning');
        System.assertEquals('Development', phaseMap.get('In Development'), 'In Development must map to Development');
        System.assertEquals('UAT', phaseMap.get('In Client UAT'), 'In Client UAT must map to UAT');
        System.assertEquals('Deployment', phaseMap.get('Deploying'), 'Deploying must map to Deployment');

        // Terminal stages should NOT be in the phase map (IsTerminal=true excluded)
        System.assertEquals(null, phaseMap.get('Done'), 'Done (terminal) must not be in phase map');
        System.assertEquals(null, phaseMap.get('Cancelled'), 'Cancelled (terminal) must not be in phase map');
    }

    @isTest
    static void testGetWorkflowConfigUnknownTypeThrows() {
        Boolean threw = false;
        try {
            DeliveryDeliveryWorkflowConfigService.getWorkflowConfig('Does_Not_Exist_XYZ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Unknown workflow type should throw AuraHandledException');
    }
}
