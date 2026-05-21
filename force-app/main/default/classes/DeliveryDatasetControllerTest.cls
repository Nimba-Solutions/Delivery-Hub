/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDatasetController. Covers:
 *                 - getTemplatesForFeature happy + null + no-match
 *                 - getTemplatesForWorkItem null + (degrades to empty)
 *                 - getRecentAssignmentsForTemplate ordering + null guard
 *                 - getAssignmentsForScratchOrg degrades when PR 9 schema absent
 *                 - formatCciCommand returns expected shape + rejects null
 *
 *               Anchors all date assertions on Datetime.now() to keep
 *               rolling-window math stable across week boundaries (per
 *               feedback_anchor_rolling_window_tests_on_today.md).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDatasetControllerTest {

    @IsTest
    static void testGetTemplatesForFeatureReturnsRows() {
        Feature__c f = TestDataFactory.createFeature(null);
        DatasetTemplate__c t = TestDataFactory.createDatasetTemplate(
            new Map<String, Object>{ 'FeatureLookup__c' => f.Id }
        );

        Test.startTest();
        List<DeliveryDatasetController.DatasetTemplateDTO> dtos =
            DeliveryDatasetController.getTemplatesForFeature(f.Id);
        Test.stopTest();

        System.assertEquals(1, dtos.size(), 'Should surface one template for the feature.');
        System.assertEquals(t.Id, dtos.get(0).templateId, 'Template id should round-trip.');
        System.assertEquals(t.Name, dtos.get(0).name, 'Template name should round-trip.');
    }

    @IsTest
    static void testGetTemplatesForFeatureNullReturnsEmpty() {
        Test.startTest();
        List<DeliveryDatasetController.DatasetTemplateDTO> dtos =
            DeliveryDatasetController.getTemplatesForFeature(null);
        Test.stopTest();

        System.assertNotEquals(null, dtos, 'Null id should return empty list, not null.');
        System.assertEquals(0, dtos.size(), 'Null id should return zero rows.');
    }

    @IsTest
    static void testGetTemplatesForWorkItemDegradesToEmpty() {
        // WorkItem__c does not carry a FeatureLookup__c in the current schema,
        // so this method must degrade to an empty list rather than throwing.
        WorkItem__c wi = TestDataFactory.createWorkItem(null);

        Test.startTest();
        List<DeliveryDatasetController.DatasetTemplateDTO> dtos =
            DeliveryDatasetController.getTemplatesForWorkItem(wi.Id);
        Test.stopTest();

        System.assertNotEquals(null, dtos, 'WI with no feature should return empty, not null.');
        System.assertEquals(0, dtos.size(),
            'WI without a direct FeatureLookup__c yields zero templates.');
    }

    @IsTest
    static void testGetRecentAssignmentsForTemplateReturnsRowsOrderedNewestFirst() {
        DatasetTemplate__c t = TestDataFactory.newDatasetTemplate();

        DatasetTemplateAssignment__c older = TestDataFactory.buildDatasetTemplateAssignment(
            t.Id, new Map<String, Object>{
                'LoadedDateTime__c' => Datetime.now().addHours(-2),
                'RecordsLoadedNumber__c' => 4
            }
        );
        DatasetTemplateAssignment__c newer = TestDataFactory.buildDatasetTemplateAssignment(
            t.Id, new Map<String, Object>{
                'LoadedDateTime__c' => Datetime.now().addMinutes(-5),
                'RecordsLoadedNumber__c' => 7
            }
        );
        insert new List<DatasetTemplateAssignment__c>{ older, newer };

        Test.startTest();
        List<DeliveryDatasetController.AssignmentSummaryDTO> dtos =
            DeliveryDatasetController.getRecentAssignmentsForTemplate(t.Id);
        Test.stopTest();

        System.assertEquals(2, dtos.size(), 'Both assignments should surface.');
        System.assertEquals(newer.Id, dtos.get(0).assignmentId,
            'Newest assignment must be first (DESC NULLS LAST on LoadedDateTime__c).');
        System.assertEquals(7, dtos.get(0).recordsLoaded,
            'recordsLoaded should match the inserted RecordsLoadedNumber__c value.');
    }

    @IsTest
    static void testGetRecentAssignmentsForTemplateNullReturnsEmpty() {
        Test.startTest();
        List<DeliveryDatasetController.AssignmentSummaryDTO> dtos =
            DeliveryDatasetController.getRecentAssignmentsForTemplate(null);
        Test.stopTest();
        System.assertEquals(0, dtos.size(), 'Null templateId returns empty list.');
    }

    @IsTest
    static void testGetAssignmentsForScratchOrgDegradesWhenPr9Absent() {
        // PR 9 has not merged at the time this test class ships — the
        // ScratchOrgInstanceLookup__c field is not present on
        // DatasetTemplateAssignment__c, so this method must return an
        // empty list (never throw).
        Id fakeScratchOrgId = '001000000000000AAA'; // shape is fine; field is absent
        Test.startTest();
        List<DeliveryDatasetController.AssignmentSummaryDTO> dtos =
            DeliveryDatasetController.getAssignmentsForScratchOrg(fakeScratchOrgId);
        Test.stopTest();
        System.assertNotEquals(null, dtos, 'Must return empty list when PR 9 schema is absent.');
        System.assertEquals(0, dtos.size(),
            'Must return zero rows when ScratchOrgInstanceLookup__c is not deployed.');
    }

    @IsTest
    static void testFormatCciCommandReturnsExpectedShape() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => 'Invoice_Generation'
        });
        DatasetTemplate__c t = TestDataFactory.createDatasetTemplate(
            new Map<String, Object>{
                'FeatureLookup__c' => f.Id,
                'Name' => 'Invoice Generation Demo'
            }
        );

        Test.startTest();
        String cmd = DeliveryDatasetController.formatCciCommand(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, cmd, 'Command string must not be null.');
        System.assert(cmd.startsWith('cci task run load_feature_data'),
            'Command should target the load_feature_data task. Got: ' + cmd);
        System.assert(cmd.contains('--feature'),
            'Command should include the --feature flag. Got: ' + cmd);
        // Prefers the linked feature's Name over the template's Name when present.
        System.assert(cmd.endsWith('Invoice_Generation'),
            'Command should end with the linked feature Name. Got: ' + cmd);
    }

    @IsTest
    static void testFormatCciCommandRejectsNull() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DeliveryDatasetController.formatCciCommand(null);
        } catch (AuraHandledException e) {
            thrown = true;
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Null templateId must produce an exception.');
    }
}
