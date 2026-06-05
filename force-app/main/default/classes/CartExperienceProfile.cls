/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Resolved Checkout Cart experience capabilities for the running org.
 *               The cart UI is a pure function of (cartData, profile): MF and a
 *               self-serve client run identical bytes — only this profile differs.
 *               Capabilities are orthogonal flags resolved from DeliveryHubSettings__c
 *               org defaults (DateTime != null => true; CheckoutModeTxt default 'Invoice'
 *               when blank). showDollars additionally requires a resolvable blended rate.
 *               Global so it can be returned across the @AuraEnabled boundary and
 *               reused as a return/param type by other global classes.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class CartExperienceProfile {

    /** @description Canonical checkout-mode value: stamp active + generate a proposal/agreement. */
    global static final String MODE_INVOICE = 'Invoice';
    /** @description Canonical checkout-mode value: stamp active + route through paid (Stripe) checkout. */
    global static final String MODE_STRIPE = 'Stripe';
    /** @description Canonical checkout-mode value: route through the approval rails first. */
    global static final String MODE_APPROVE = 'Approve';

    /** @description True when the cart should render dollar amounts (hours + $). */
    @AuraEnabled global Boolean showDollars { get; set; }

    /** @description True when clients self-serve the cart; false = admin assembles. */
    @AuraEnabled global Boolean selfServe { get; set; }

    /** @description One of Approve | Invoice | Stripe. Drives the checkout button + routing. */
    @AuraEnabled global String checkoutMode { get; set; }

    /** @description Single resolvable blended hourly rate, or null when ambiguous/absent. */
    @AuraEnabled global Decimal blendedRate { get; set; }

    /**
     * @description Resolves the experience profile from DeliveryHubSettings__c org
     *              defaults. DateTime fields map to Booleans (non-null => true);
     *              CheckoutModeTxt__c is validated against the three known modes and
     *              defaults to Invoice when blank/unrecognized. showDollars is gated on
     *              BOTH the EnableCartDollarsDateTime__c opt-in AND a resolvable blended
     *              rate (mirrors the pacing dollar gate — no rate => hours-only).
     * @return A fully populated CartExperienceProfile.
     */
    global static CartExperienceProfile resolve() {
        CartExperienceProfile profile = new CartExperienceProfile();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Boolean dollarsOptIn = settings != null && settings.EnableCartDollarsDateTime__c != null;
        profile.selfServe = settings != null && settings.EnableCartSelfServeDateTime__c != null;
        profile.checkoutMode = normalizeMode(settings == null ? null : settings.CheckoutModeTxt__c);

        profile.blendedRate = resolveBlendedRate();
        // Dollars require BOTH the opt-in AND a single resolvable rate.
        profile.showDollars = dollarsOptIn && profile.blendedRate != null && profile.blendedRate > 0;

        return profile;
    }

    /**
     * @description Validates a raw checkout-mode string against the three known modes.
     *              Case-insensitive; blank or unrecognized => Invoice (the default).
     * @param raw The raw CheckoutModeTxt__c value (may be null/blank).
     * @return One of MODE_APPROVE, MODE_INVOICE, MODE_STRIPE.
     */
    global static String normalizeMode(String raw) {
        if (String.isBlank(raw)) {
            return MODE_INVOICE;
        }
        String v = raw.trim().toLowerCase();
        if (v == 'approve') {
            return MODE_APPROVE;
        }
        if (v == 'stripe') {
            return MODE_STRIPE;
        }
        return MODE_INVOICE;
    }

    /**
     * @description Reads a single blended hourly rate when EXACTLY ONE active
     *              NetworkEntity carries a DefaultHourlyRateCurrency__c. Returns null
     *              when zero or many distinct rates exist (ambiguous — hours-only).
     *              Mirrors DeliveryHoursAnalyticsController.resolveBlendedRate. Field is
     *              referenced statically in the SOQL so it is compile-time guaranteed
     *              to exist (no namespace-unsafe describe guard).
     * @return The blended rate, or null.
     */
    global static Decimal resolveBlendedRate() {
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
