/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Canonical blended-rate resolver: surfaces a single blended
 *               hourly rate when EXACTLY ONE active NetworkEntity__c carries
 *               a DefaultHourlyRateCurrency__c, and null when zero or many
 *               rated entities exist (ambiguous — consumers fall back to
 *               hours-only display). Extracted from the identical private
 *               copies in DeliveryHoursAnalyticsController and
 *               DeliveryBillingPreviewController (generalizability audit
 *               2026-06); CartExperienceProfile.resolveBlendedRate delegates
 *               here too, so the pacing card, billing preview, and cart can
 *               never disagree on the rate. SOQL is WITH SYSTEM_MODE per
 *               CLAUDE.md (WITH USER_MODE breaks in namespaced package test
 *               context).
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryRateService {

    /**
     * @description Reads a single blended hourly rate when EXACTLY ONE active
     *              NetworkEntity carries a DefaultHourlyRateCurrency__c.
     *              No describe guard: the field is referenced statically in
     *              the SOQL below, so it is compile-time guaranteed to exist.
     *              A fields.getMap().containsKey(...) guard is also
     *              namespace-UNSAFE — in the packaging org the map key is
     *              prefixed, so the unprefixed containsKey returns false and
     *              the method would return null in managed contexts
     *              (upload-beta only).
     * @return The single blended rate, or null when ambiguous/absent.
     */
    public static Decimal resolveBlendedRate() {
        List<NetworkEntity__c> rated = [
            SELECT DefaultHourlyRateCurrency__c
            FROM NetworkEntity__c
            WHERE DefaultHourlyRateCurrency__c != NULL
              AND DefaultHourlyRateCurrency__c > 0
              AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 2
        ];
        if (rated.size() == 1) {
            return rated[0].DefaultHourlyRateCurrency__c;
        }
        return null;
    }
}
