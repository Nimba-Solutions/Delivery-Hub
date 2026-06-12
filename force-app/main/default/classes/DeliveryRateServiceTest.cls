/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryRateService — the canonical blended-rate
 *               resolver (single-active-rated-NetworkEntity-else-null).
 *               Semantics intentionally match the previously duplicated
 *               private copies in DeliveryHoursAnalyticsController and
 *               DeliveryBillingPreviewController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryRateServiceTest {

    @IsTest
    static void testSingleActiveRateResolves() {
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'EntityTypePk__c' => 'Client',
            'DefaultHourlyRateCurrency__c' => 125
        });

        Test.startTest();
        Decimal rate = DeliveryRateService.resolveBlendedRate();
        Test.stopTest();

        System.assertEquals(125, rate,
            'Exactly one active rated NetworkEntity surfaces as the blended rate');
    }

    @IsTest
    static void testNullWhenNoRatedEntities() {
        // An active entity WITHOUT a rate must not resolve.
        TestDataFactory.createNetworkEntity(new Map<String, Object>());

        System.assertEquals(null, DeliveryRateService.resolveBlendedRate(),
            'No rated entities → null (hours-only display)');
    }

    @IsTest
    static void testNullWhenMultipleRatedEntities() {
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 100
        });
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 200
        });

        System.assertEquals(null, DeliveryRateService.resolveBlendedRate(),
            'Two rated entities → ambiguous → null');
    }

    @IsTest
    static void testNullWhenRateIsZero() {
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 0
        });

        System.assertEquals(null, DeliveryRateService.resolveBlendedRate(),
            'Zero rate is excluded by the > 0 filter → null');
    }

    @IsTest
    static void testNullWhenOnlyRatedEntityIsInactive() {
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 150,
            'StatusPk__c' => 'Inactive'
        });

        System.assertEquals(null, DeliveryRateService.resolveBlendedRate(),
            'Non-Active rated entity is excluded by the status filter → null');
    }
}
