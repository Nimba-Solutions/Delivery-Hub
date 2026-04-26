/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for IntegrationProviderAdminController. Cannot insert
 *              IntegrationProvider__mdt records in test (CMT records are
 *              deploy-time only), so listProviders() may return zero rows in
 *              the test org — the test asserts the method runs without
 *              exception and returns a non-null list. probeProvider() tests
 *              the unknown-name path which is reachable without seed data.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
private class IntegrationProviderAdminControllerTest {

    @IsTest
    static void listProviders_returnsNonNullList() {
        Test.startTest();
        List<IntegrationProviderAdminController.ProviderRow> rows =
            IntegrationProviderAdminController.listProviders();
        Test.stopTest();
        System.assertNotEquals(null, rows, 'list should not be null');
    }

    @IsTest
    static void probeProvider_unknownDevName_throwsAuraHandled() {
        Boolean threw = false;
        Test.startTest();
        try {
            IntegrationProviderAdminController.probeProvider('NonexistentProvider_99999');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'probe should surface error as AuraHandledException');
    }
}
