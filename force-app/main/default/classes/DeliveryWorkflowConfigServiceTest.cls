/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkflowConfigService.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryWorkflowConfigServiceTest {

    @isTest
    static void testGetWorkflowTypes() {
        List<Map<String,Object>> types = DeliveryWorkflowConfigService.getWorkflowTypes();
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
        Map<String,Object> config = DeliveryWorkflowConfigService.getWorkflowConfig('Software_Delivery');

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
        Map<String,Object> config = DeliveryWorkflowConfigService.getWorkflowConfig('Loan_Approval');
        System.assertNotEquals(null, config, 'Loan_Approval config must not be null');

        Map<String,Object> typeMap = (Map<String,Object>) config.get('type');
        System.assertEquals('Loan_Approval', typeMap.get('developerName'), 'developerName must be Loan_Approval');
        System.assertEquals(false, typeMap.get('useSimplifiedView'), 'Loan_Approval uses persona views');

        List<Object> stages = (List<Object>) config.get('stages');
        System.assertEquals(8, stages.size(), 'Loan_Approval must have exactly 8 stages');
    }

    @isTest
    static void testGetWorkflowConfigBlankDefaultsToSoftwareDelivery() {
        Map<String,Object> configBlank = DeliveryWorkflowConfigService.getWorkflowConfig('');
        Map<String,Object> configNull  = DeliveryWorkflowConfigService.getWorkflowConfig(null);

        Map<String,Object> typeBlank = (Map<String,Object>) configBlank.get('type');
        Map<String,Object> typeNull  = (Map<String,Object>) configNull.get('type');

        System.assertEquals('Software_Delivery', typeBlank.get('developerName'), 'Blank name must default to Software_Delivery');
        System.assertEquals('Software_Delivery', typeNull.get('developerName'), 'Null name must default to Software_Delivery');
    }

    @isTest
    static void testGetTerminalStageValues() {
        Set<String> terminals = DeliveryWorkflowConfigService.getTerminalStageValues('Software_Delivery');
        System.assert(!terminals.isEmpty(), 'Terminal stages must not be empty');
        System.assert(terminals.contains('Done'), 'Done must be terminal for Software_Delivery');
        System.assert(terminals.contains('Cancelled'), 'Cancelled must be terminal for Software_Delivery');
    }

    @isTest
    static void testGetAttentionStageValues() {
        Set<String> attention = DeliveryWorkflowConfigService.getAttentionStageValues('Software_Delivery');
        System.assert(!attention.isEmpty(), 'Attention stages must not be empty');
        System.assert(attention.contains('Ready for Client Approval'), 'Ready for Client Approval must be an attention stage');
        System.assert(attention.contains('In Client UAT'), 'In Client UAT must be an attention stage');
    }

    @isTest
    static void testGetStagePhaseMap() {
        Map<String,String> phaseMap = DeliveryWorkflowConfigService.getStagePhaseMap('Software_Delivery');
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
            DeliveryWorkflowConfigService.getWorkflowConfig('Does_Not_Exist_XYZ');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Unknown workflow type should throw AuraHandledException');
    }

    @isTest
    static void testGetWorkflowTemplates() {
        List<Map<String,Object>> templates = DeliveryWorkflowConfigService.getWorkflowTemplates();
        // Must have at least the 5 built-in workflow types
        System.assert(templates.size() >= 5, 'Expected at least 5 workflow templates, got ' + templates.size());

        // Verify enriched structure of each returned map
        Set<String> expectedTypes = new Set<String>{
            'Software_Delivery', 'Loan_Approval', 'Implementation_Project', 'Support_Triage', 'Onboarding_Checklist'
        };
        Set<String> foundTypes = new Set<String>();
        for (Map<String,Object> t : templates) {
            System.assertNotEquals(null, t.get('developerName'), 'developerName must be present');
            System.assertNotEquals(null, t.get('label'), 'label must be present');
            System.assertNotEquals(null, t.get('description'), 'description must be present');
            System.assertNotEquals(null, t.get('iconName'), 'iconName must be present');
            System.assertNotEquals(null, t.get('stageCount'), 'stageCount must be present');
            System.assertNotEquals(null, t.get('stageColors'), 'stageColors must be present');
            System.assertNotEquals(null, t.get('personas'), 'personas must be present');

            // stageCount must be > 0 for known types
            Integer stageCount = (Integer) t.get('stageCount');
            System.assert(stageCount > 0, 'stageCount must be > 0 for ' + t.get('developerName'));

            foundTypes.add((String) t.get('developerName'));
        }
        // All expected types must be present
        for (String expected : expectedTypes) {
            System.assert(foundTypes.contains(expected), expected + ' must be in the template list');
        }
    }

    @isTest
    static void testGetWorkflowTemplatesEnrichedData() {
        List<Map<String,Object>> templates = DeliveryWorkflowConfigService.getWorkflowTemplates();

        // Find Implementation_Project and verify its enriched data
        Map<String,Object> ipTemplate;
        for (Map<String,Object> t : templates) {
            if (t.get('developerName') == 'Implementation_Project') {
                ipTemplate = t;
                break;
            }
        }
        System.assertNotEquals(null, ipTemplate, 'Implementation_Project template must exist');
        System.assertEquals(11, (Integer) ipTemplate.get('stageCount'), 'Implementation_Project must have 11 stages');

        List<Object> personas = (List<Object>) ipTemplate.get('personas');
        System.assert(personas.size() >= 3, 'Implementation_Project must have at least 3 personas');

        List<Object> stageColors = (List<Object>) ipTemplate.get('stageColors');
        System.assertEquals(11, stageColors.size(), 'Implementation_Project must have 11 stage colors');
    }

    @isTest
    static void testGetWorkflowConfigImplementationProject() {
        Map<String,Object> config = DeliveryWorkflowConfigService.getWorkflowConfig('Implementation_Project');
        System.assertNotEquals(null, config, 'Implementation_Project config must not be null');

        List<Object> stages = (List<Object>) config.get('stages');
        System.assertEquals(11, stages.size(), 'Implementation_Project must have exactly 11 stages');

        Map<String,Object> personaViews = (Map<String,Object>) config.get('personaViews');
        System.assert(personaViews.containsKey('Project_Manager'), 'Project_Manager persona view required');
        System.assert(personaViews.containsKey('Consultant'), 'Consultant persona view required');
        System.assert(personaViews.containsKey('Client_Stakeholder'), 'Client_Stakeholder persona view required');
    }

    @isTest
    static void testGetWorkflowConfigSupportTriage() {
        Map<String,Object> config = DeliveryWorkflowConfigService.getWorkflowConfig('Support_Triage');
        System.assertNotEquals(null, config, 'Support_Triage config must not be null');

        List<Object> stages = (List<Object>) config.get('stages');
        System.assertEquals(8, stages.size(), 'Support_Triage must have exactly 8 stages');

        Map<String,Object> personaViews = (Map<String,Object>) config.get('personaViews');
        System.assert(personaViews.containsKey('Support_Agent'), 'Support_Agent persona view required');
        System.assert(personaViews.containsKey('Engineering'), 'Engineering persona view required');
        System.assert(personaViews.containsKey('Customer'), 'Customer persona view required');
    }

    @isTest
    static void testGetWorkflowConfigOnboardingChecklist() {
        Map<String,Object> config = DeliveryWorkflowConfigService.getWorkflowConfig('Onboarding_Checklist');
        System.assertNotEquals(null, config, 'Onboarding_Checklist config must not be null');

        List<Object> stages = (List<Object>) config.get('stages');
        System.assertEquals(7, stages.size(), 'Onboarding_Checklist must have exactly 7 stages');

        Map<String,Object> personaViews = (Map<String,Object>) config.get('personaViews');
        System.assert(personaViews.containsKey('HR_Admin'), 'HR_Admin persona view required');
        System.assert(personaViews.containsKey('Manager'), 'Manager persona view required');
        System.assert(personaViews.containsKey('New_Hire'), 'New_Hire persona view required');
    }
}
