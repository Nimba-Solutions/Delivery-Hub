/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliverySavedFilterController. Covers the
 *               JSON-backed CRUD operations against
 *               DeliveryHubSettings__c.SavedFiltersJsonTxt__c after the
 *               cap-recovery rewrite away from the per-record
 *               DeliverySavedFilter__c custom object.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
public class DeliverySavedFilterControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

    private static final String WORKFLOW = 'Software_Delivery';
    private static final String OTHER_WORKFLOW = 'Cashflow_2_0';
    private static final String SAMPLE_JSON = '{"persona":"Client","overallFilter":"all"}';

    @IsTest
    static void testGetSavedFiltersEmpty() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliverySavedFilterController.FilterRow> results =
                DeliverySavedFilterController.getSavedFilters(WORKFLOW);
            Test.stopTest();
            System.assertEquals(0, results.size(),
                'A user with no saved filters should get back an empty list');
        }
    }

    @IsTest
    static void testSaveBoardFilterCreatesNewWithSyntheticId() {
        System.runAs(testUser) {
            Test.startTest();
            DeliverySavedFilterController.FilterRow saved =
                DeliverySavedFilterController.saveBoardFilter(
                    null, 'My Filter', SAMPLE_JSON, false, WORKFLOW);
            Test.stopTest();
            System.assertNotEquals(null, saved.id, 'New filter should get a synthetic id');
            System.assertEquals('My Filter', saved.label);
            System.assertEquals(SAMPLE_JSON, saved.filterJson);
            System.assertEquals(false, saved.defaultSet);
            System.assertEquals(WORKFLOW, saved.workflowType);
        }
    }

    @IsTest
    static void testSaveBoardFilterUpdatesExisting() {
        System.runAs(testUser) {
            DeliverySavedFilterController.FilterRow first =
                DeliverySavedFilterController.saveBoardFilter(
                    null, 'Original', SAMPLE_JSON, false, WORKFLOW);

            Test.startTest();
            DeliverySavedFilterController.FilterRow updated =
                DeliverySavedFilterController.saveBoardFilter(
                    first.id, 'Renamed', SAMPLE_JSON, true, WORKFLOW);
            Test.stopTest();

            System.assertEquals(first.id, updated.id, 'Update should keep the same id');
            System.assertEquals('Renamed', updated.label);
            System.assertEquals(true, updated.defaultSet);
        }
    }

    @IsTest
    static void testSaveBoardFilterDefaultClearsOthersInSameWorkflow() {
        System.runAs(testUser) {
            DeliverySavedFilterController.saveBoardFilter(
                null, 'A', SAMPLE_JSON, true, WORKFLOW);
            Test.startTest();
            DeliverySavedFilterController.saveBoardFilter(
                null, 'B', SAMPLE_JSON, true, WORKFLOW);
            Test.stopTest();

            List<DeliverySavedFilterController.FilterRow> all =
                DeliverySavedFilterController.getSavedFilters(WORKFLOW);
            Integer defaultCount = 0;
            for (DeliverySavedFilterController.FilterRow r : all) {
                if (r.defaultSet == true) { defaultCount++; }
            }
            System.assertEquals(1, defaultCount,
                'Setting a new default should un-default any other default in the same workflow');
        }
    }

    @IsTest
    static void testSaveBoardFilterDefaultDoesNotAffectOtherWorkflow() {
        System.runAs(testUser) {
            DeliverySavedFilterController.saveBoardFilter(
                null, 'SD-Default', SAMPLE_JSON, true, WORKFLOW);
            Test.startTest();
            DeliverySavedFilterController.saveBoardFilter(
                null, 'CF-Default', SAMPLE_JSON, true, OTHER_WORKFLOW);
            Test.stopTest();

            List<DeliverySavedFilterController.FilterRow> sd =
                DeliverySavedFilterController.getSavedFilters(WORKFLOW);
            System.assertEquals(true, sd[0].defaultSet,
                'Other-workflow defaults should be untouched');
        }
    }

    @IsTest
    static void testSaveBoardFilterRequiresLabel() {
        System.runAs(testUser) {
            Boolean threw = false;
            try {
                DeliverySavedFilterController.saveBoardFilter(
                    null, null, SAMPLE_JSON, false, WORKFLOW);
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw, 'Blank label should throw');
        }
    }

    @IsTest
    static void testSaveBoardFilterRequiresJson() {
        System.runAs(testUser) {
            Boolean threw = false;
            try {
                DeliverySavedFilterController.saveBoardFilter(
                    null, 'L', null, false, WORKFLOW);
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw, 'Blank filterJson should throw');
        }
    }

    @IsTest
    static void testDeleteSavedFilterRemoves() {
        System.runAs(testUser) {
            DeliverySavedFilterController.FilterRow saved =
                DeliverySavedFilterController.saveBoardFilter(
                    null, 'Doomed', SAMPLE_JSON, false, WORKFLOW);

            Test.startTest();
            DeliverySavedFilterController.deleteSavedFilter(saved.id);
            Test.stopTest();

            List<DeliverySavedFilterController.FilterRow> remaining =
                DeliverySavedFilterController.getSavedFilters(WORKFLOW);
            System.assertEquals(0, remaining.size(),
                'Filter should be gone after delete');
        }
    }

    @IsTest
    static void testDeleteSavedFilterRequiresId() {
        System.runAs(testUser) {
            Boolean threw = false;
            try {
                DeliverySavedFilterController.deleteSavedFilter(null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw);
        }
    }

    @IsTest
    static void testDeleteUnknownFilterThrows() {
        System.runAs(testUser) {
            Boolean threw = false;
            try {
                DeliverySavedFilterController.deleteSavedFilter('sf_doesnotexist');
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw);
        }
    }

    @IsTest
    static void testGetSavedFiltersWorkflowDefault() {
        System.runAs(testUser) {
            DeliverySavedFilterController.saveBoardFilter(
                null, 'X', SAMPLE_JSON, false, null);
            Test.startTest();
            List<DeliverySavedFilterController.FilterRow> results =
                DeliverySavedFilterController.getSavedFilters(null);
            Test.stopTest();
            System.assertEquals(1, results.size(),
                'Blank workflow defaults to Software_Delivery and should match');
        }
    }
}
