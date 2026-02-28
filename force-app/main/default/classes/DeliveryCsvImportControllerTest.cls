/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryCsvImportController.
 * @author Cloud Nimbus LLC
 */
@isTest
public class DeliveryCsvImportControllerTest {

    // ── Namespace helpers ────────────────────────────────────────────

    /**
     * @description Returns the org namespace prefix (e.g. 'delivery__') or empty
     *              string if running in an unpackaged context. Used to prefix custom
     *              field API names in CSV row maps so they match the schema field map
     *              in namespaced package test runs.
     * @return Namespace prefix with trailing __ or empty string
     */
    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    /**
     * @description Prefixes a custom field API name with the org namespace when
     *              running in a namespaced context. Standard fields and already-
     *              prefixed names are not double-prefixed because custom fields in
     *              this package always have exactly one '__' suffix.
     * @param fieldName The bare field API name (e.g. 'BriefDescriptionTxt__c')
     * @return Namespace-qualified field name (e.g. 'delivery__BriefDescriptionTxt__c')
     */
    private static String ns(String fieldName) {
        return getNamespace() + fieldName;
    }

    // ── Single record import ─────────────────────────────────────────

    @isTest
    static void testImportSingleRecord() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();
        Map<String, String> row = new Map<String, String>();
        row.put(ns('BriefDescriptionTxt__c'), 'CSV Single Import');
        row.put(ns('PriorityPk__c'), 'High');
        row.put(ns('StageNamePk__c'), 'Backlog');
        records.add(row);

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('successCount'),
            'Expected 1 successful insert');
        System.assertEquals(0, (Integer) result.get('errorCount'),
            'Expected 0 errors');

        List<String> ids = (List<String>) result.get('createdIds');
        System.assertEquals(1, ids.size(), 'Expected 1 created Id');

        WorkItem__c wi = [
            SELECT BriefDescriptionTxt__c, PriorityPk__c, WorkflowTypeTxt__c, IsActiveBool__c
            FROM WorkItem__c
            WHERE Id = :ids[0]
            WITH SYSTEM_MODE
        ];
        System.assertEquals('CSV Single Import', wi.BriefDescriptionTxt__c);
        System.assertEquals('High', wi.PriorityPk__c);
        System.assertEquals('Software_Delivery', wi.WorkflowTypeTxt__c);
        System.assertEquals(true, wi.IsActiveBool__c);

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── Bulk import (10+ records) ────────────────────────────────────

    @isTest
    static void testImportBulkRecords() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();
        for (Integer i = 0; i < 15; i++) {
            Map<String, String> row = new Map<String, String>();
            row.put(ns('BriefDescriptionTxt__c'), 'Bulk Item ' + i);
            row.put(ns('PriorityPk__c'), 'Medium');
            row.put(ns('StageNamePk__c'), 'Backlog');
            records.add(row);
        }

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(15, (Integer) result.get('successCount'),
            'All 15 records should succeed');
        System.assertEquals(0, (Integer) result.get('errorCount'),
            'Expected 0 errors');

        Integer count = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE 'Bulk Item%'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(15, count, 'Database should contain 15 bulk items');

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── Partial failure handling ──────────────────────────────────────

    @isTest
    static void testImportPartialFailure() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();

        // Good record
        Map<String, String> good = new Map<String, String>();
        good.put(ns('BriefDescriptionTxt__c'), 'Good Record');
        good.put(ns('StageNamePk__c'), 'Backlog');
        records.add(good);

        // Bad record — BriefDescriptionTxt__c is Text(100); exceed that limit to cause an error
        Map<String, String> bad = new Map<String, String>();
        String longVal = '';
        for (Integer i = 0; i < 20; i++) {
            longVal += 'ABCDEFGHIJ'; // 200 chars total — over the 100 char limit
        }
        bad.put(ns('BriefDescriptionTxt__c'), longVal);
        bad.put(ns('StageNamePk__c'), 'Backlog');
        records.add(bad);

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('successCount'),
            'One record should succeed');
        System.assertEquals(1, (Integer) result.get('errorCount'),
            'One record should fail');

        List<Object> errors = (List<Object>) result.get('errors');
        System.assertEquals(1, errors.size(), 'Should have 1 error entry');

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── getWorkItemFields returns expected fields ─────────────────────

    @isTest
    static void testGetWorkItemFields() {
        Test.startTest();
        List<Map<String, String>> fields = DeliveryCsvImportController.getWorkItemFields();
        Test.stopTest();

        System.assert(fields.size() > 0, 'Should return at least one field');

        // Verify structure: every entry should have apiName, label, type
        for (Map<String, String> f : fields) {
            System.assert(f.containsKey('apiName'), 'Field entry missing apiName');
            System.assert(f.containsKey('label'), 'Field entry missing label');
            System.assert(f.containsKey('type'), 'Field entry missing type');
        }

        // BriefDescriptionTxt__c must be present (may be namespace-prefixed)
        Boolean found = false;
        for (Map<String, String> f : fields) {
            String apiName = f.get('apiName');
            if (apiName != null && apiName.endsWith('BriefDescriptionTxt__c')) {
                found = true;
                System.assertEquals('Brief Description', f.get('label'));
                break;
            }
        }
        System.assert(found, 'BriefDescriptionTxt__c should be in the returned fields');
    }

    // ── Different workflow types ──────────────────────────────────────

    @isTest
    static void testImportWithLoanApprovalWorkflow() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();
        Map<String, String> row = new Map<String, String>();
        row.put(ns('BriefDescriptionTxt__c'), 'Loan Work Item');
        row.put(ns('StageNamePk__c'), 'Backlog');
        records.add(row);

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, 'Loan_Approval');
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('successCount'));

        List<String> ids = (List<String>) result.get('createdIds');
        WorkItem__c wi = [
            SELECT WorkflowTypeTxt__c
            FROM WorkItem__c
            WHERE Id = :ids[0]
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Loan_Approval', wi.WorkflowTypeTxt__c,
            'Workflow type should be Loan_Approval');

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── Default workflow type when blank ──────────────────────────────

    @isTest
    static void testImportDefaultWorkflowType() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();
        Map<String, String> row = new Map<String, String>();
        row.put(ns('BriefDescriptionTxt__c'), 'Default WF Item');
        row.put(ns('StageNamePk__c'), 'Backlog');
        records.add(row);

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, '');
        Test.stopTest();

        List<String> ids = (List<String>) result.get('createdIds');
        WorkItem__c wi = [
            SELECT WorkflowTypeTxt__c
            FROM WorkItem__c
            WHERE Id = :ids[0]
            WITH SYSTEM_MODE
        ];
        System.assertEquals('Software_Delivery', wi.WorkflowTypeTxt__c,
            'Blank workflow type should default to Software_Delivery');

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── Empty records list ───────────────────────────────────────────

    @isTest
    static void testImportEmptyRecords() {
        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(
                new List<Map<String, String>>(), 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('successCount'));
        System.assertEquals(0, (Integer) result.get('errorCount'));
    }

    // ── Null records list ────────────────────────────────────────────

    @isTest
    static void testImportNullRecords() {
        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(null, 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('successCount'));
        System.assertEquals(0, (Integer) result.get('errorCount'));
    }

    // ── Numeric field coercion ───────────────────────────────────────

    @isTest
    static void testImportWithNumericFields() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();
        Map<String, String> row = new Map<String, String>();
        row.put(ns('BriefDescriptionTxt__c'), 'Numeric Fields Test');
        row.put(ns('EstimatedHoursNumber__c'), '24.5');
        row.put(ns('DeveloperDaysSizeNumber__c'), '3');
        row.put(ns('SortOrderNumber__c'), '5');
        row.put(ns('StageNamePk__c'), 'Backlog');
        records.add(row);

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('successCount'));

        List<String> ids = (List<String>) result.get('createdIds');
        WorkItem__c wi = [
            SELECT EstimatedHoursNumber__c, DeveloperDaysSizeNumber__c, SortOrderNumber__c
            FROM WorkItem__c
            WHERE Id = :ids[0]
            WITH SYSTEM_MODE
        ];
        System.assertEquals(24.5, wi.EstimatedHoursNumber__c);
        System.assertEquals(3, wi.DeveloperDaysSizeNumber__c);
        System.assertEquals(5, wi.SortOrderNumber__c);

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── Unknown fields are gracefully skipped ────────────────────────

    @isTest
    static void testImportIgnoresUnknownFields() {
        DeliveryTriggerControl.disableAfterLogic();

        List<Map<String, String>> records = new List<Map<String, String>>();
        Map<String, String> row = new Map<String, String>();
        row.put(ns('BriefDescriptionTxt__c'), 'Unknown Field Test');
        row.put('TotallyFakeField__c', 'should be ignored');
        row.put(ns('StageNamePk__c'), 'Backlog');
        records.add(row);

        Test.startTest();
        Map<String, Object> result =
            DeliveryCsvImportController.importWorkItems(records, 'Software_Delivery');
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('successCount'),
            'Unknown fields should be silently skipped');

        DeliveryTriggerControl.enableAfterLogic();
    }
}
