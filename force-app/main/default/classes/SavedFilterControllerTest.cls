/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for SavedFilterController. Covers CRUD operations,
 *              default-toggle behaviour, and error paths.
 * @author Cloud Nimbus LLC
 */
@isTest
public class SavedFilterControllerTest {

    private static final String WORKFLOW = 'Software_Delivery';
    private static final String SAMPLE_JSON = '{"persona":"Client","overallFilter":"all"}';

    @isTest
    static void testGetSavedFiltersEmpty() {
        Test.startTest();
        List<SavedFilter__c> results = SavedFilterController.getSavedFilters(WORKFLOW);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when no filters exist');
    }

    @isTest
    static void testGetSavedFiltersDefaultWorkflowType() {
        insert new SavedFilter__c(
            LabelTxt__c = 'Test',
            FilterJsonTxt__c = SAMPLE_JSON,
            WorkflowTypeTxt__c = 'Software_Delivery'
        );

        Test.startTest();
        List<SavedFilter__c> results = SavedFilterController.getSavedFilters(null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Null workflow should default to Software_Delivery');
    }

    @isTest
    static void testGetSavedFiltersReturnOwnedOnly() {
        insert new SavedFilter__c(
            LabelTxt__c = 'My Filter',
            FilterJsonTxt__c = SAMPLE_JSON,
            WorkflowTypeTxt__c = WORKFLOW
        );

        Test.startTest();
        List<SavedFilter__c> results = SavedFilterController.getSavedFilters(WORKFLOW);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('My Filter', results[0].LabelTxt__c);
    }

    @isTest
    static void testSaveBoardFilterCreate() {
        Test.startTest();
        SavedFilter__c created = SavedFilterController.saveBoardFilter(
            null, 'New Filter', SAMPLE_JSON, false, WORKFLOW
        );
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Should return a created record with an Id');
        System.assertEquals('New Filter', created.LabelTxt__c);
    }

    @isTest
    static void testSaveBoardFilterCreateWithDefault() {
        Test.startTest();
        SavedFilter__c first = SavedFilterController.saveBoardFilter(
            null, 'First Default', SAMPLE_JSON, true, WORKFLOW
        );
        Test.stopTest();

        SavedFilter__c reQueried = [
            SELECT IsDefaultBool__c FROM SavedFilter__c WHERE Id = :first.Id
        ];
        System.assertEquals(true, reQueried.IsDefaultBool__c, 'Should be marked as default');
    }

    @isTest
    static void testSaveBoardFilterUpdate() {
        SavedFilter__c existing = new SavedFilter__c(
            LabelTxt__c = 'Old Name',
            FilterJsonTxt__c = SAMPLE_JSON,
            WorkflowTypeTxt__c = WORKFLOW
        );
        insert existing;

        String updatedJson = '{"persona":"Developer","overallFilter":"indev"}';

        Test.startTest();
        SavedFilter__c updated = SavedFilterController.saveBoardFilter(
            existing.Id, 'Renamed', updatedJson, false, WORKFLOW
        );
        Test.stopTest();

        SavedFilter__c reQueried = [
            SELECT LabelTxt__c, FilterJsonTxt__c FROM SavedFilter__c WHERE Id = :updated.Id
        ];
        System.assertEquals('Renamed', reQueried.LabelTxt__c);
        System.assertEquals(updatedJson, reQueried.FilterJsonTxt__c);
    }

    @isTest
    static void testSaveBoardFilterDefaultClearsPrevious() {
        SavedFilter__c first = new SavedFilter__c(
            LabelTxt__c = 'First',
            FilterJsonTxt__c = SAMPLE_JSON,
            IsDefaultBool__c = true,
            WorkflowTypeTxt__c = WORKFLOW
        );
        insert first;

        Test.startTest();
        SavedFilterController.saveBoardFilter(
            null, 'Second Default', SAMPLE_JSON, true, WORKFLOW
        );
        Test.stopTest();

        SavedFilter__c firstReQueried = [
            SELECT IsDefaultBool__c FROM SavedFilter__c WHERE Id = :first.Id
        ];
        System.assertEquals(false, firstReQueried.IsDefaultBool__c, 'Previous default should be cleared');
    }

    @isTest
    static void testSaveBoardFilterBlankLabel() {
        try {
            Test.startTest();
            SavedFilterController.saveBoardFilter(null, '', SAMPLE_JSON, false, WORKFLOW);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest
    static void testSaveBoardFilterBlankJson() {
        try {
            Test.startTest();
            SavedFilterController.saveBoardFilter(null, 'Name', '', false, WORKFLOW);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest
    static void testSaveBoardFilterNullWorkflowDefaults() {
        Test.startTest();
        SavedFilter__c created = SavedFilterController.saveBoardFilter(
            null, 'Null WF', SAMPLE_JSON, false, null
        );
        Test.stopTest();

        SavedFilter__c reQueried = [
            SELECT WorkflowTypeTxt__c FROM SavedFilter__c WHERE Id = :created.Id
        ];
        System.assertEquals('Software_Delivery', reQueried.WorkflowTypeTxt__c);
    }

    @isTest
    static void testDeleteSavedFilter() {
        SavedFilter__c sf = new SavedFilter__c(
            LabelTxt__c = 'Doomed',
            FilterJsonTxt__c = SAMPLE_JSON,
            WorkflowTypeTxt__c = WORKFLOW
        );
        insert sf;

        Test.startTest();
        SavedFilterController.deleteSavedFilter(sf.Id);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM SavedFilter__c WHERE Id = :sf.Id];
        System.assertEquals(0, count, 'Filter should be deleted');
    }

    @isTest
    static void testDeleteSavedFilterNullId() {
        try {
            Test.startTest();
            SavedFilterController.deleteSavedFilter(null);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }

    @isTest
    static void testDeleteSavedFilterNotFound() {
        Id fakeId = SavedFilter__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        try {
            Test.startTest();
            SavedFilterController.deleteSavedFilter(fakeId);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
    }
}
