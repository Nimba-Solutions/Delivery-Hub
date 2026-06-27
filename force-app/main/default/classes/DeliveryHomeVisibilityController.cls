/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Per-component visibility toggles for the Delivery Hub app Home page.
 *               Lets an admin hide individual home-page LWC widgets (so the Home page
 *               only surfaces what works) via the Settings tab, fully reversibly.
 *               Backed by inverted HideHome…DateTime__c fields on DeliveryHubSettings__c:
 *               null = SHOWN (safe default), non-null = HIDDEN. The map this returns is
 *               keyed by the LWC component name (e.g. 'deliveryBudgetSummary') so each
 *               home-page component can ask "am I hidden?" with a single cacheable wire.
 * @author       Cloud Nimbus LLC
 */
public with sharing class DeliveryHomeVisibilityController {

    // Map of LWC component name → the inverted "hide" DateTime field that gates it.
    // Order is the order the toggles render in the Settings card.
    private static final Map<String, String> COMPONENT_TO_FIELD = new Map<String, String>{
        'deliveryBudgetSummary'        => 'HideHomeBudgetSummaryDateTime__c',
        'deliveryExecutiveDashboard'   => 'HideHomeExecutiveDashboardDateTime__c',
        'deliveryFeatureApprovalInbox' => 'HideHomeFeatureApprovalInboxDateTime__c',
        'deliveryGettingStarted'       => 'HideHomeGettingStartedDateTime__c',
        'deliveryHubSetup'             => 'HideHomeHubSetupDateTime__c',
        'deliveryPacingForecast'       => 'HideHomePacingForecastDateTime__c'
    };

    /**
     * @description Returns which home-page components are currently hidden, keyed by
     *              the LWC component name. A component is hidden when its matching
     *              HideHome…DateTime__c field is non-null (inverted-default: null = shown).
     *              Reads the hierarchy custom setting via getInstance().
     * @return Map of component name → isHidden (true = hide on Home).
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getHiddenHomeComponents() {
        return buildHiddenMap(DeliveryHubSettings__c.getInstance());
    }

    /**
     * @description Persists the per-component Home visibility toggles. For each entry,
     *              true = HIDE (stamps the HideHome…DateTime__c with now() if not already
     *              set), false = SHOW (clears the field). Existing stamps are preserved so
     *              the "active since" timestamp does not churn. Writes to the org-default
     *              record. Returns the fresh hidden-map so the caller can refresh state
     *              without hitting the cacheable read's stale cache.
     * @param hidden Map of component name → desired isHidden state.
     * @return Map of component name → isHidden after the save.
     */
    @AuraEnabled
    public static Map<String, Boolean> setHiddenHomeComponents(Map<String, Boolean> hidden) {
        try {
            Map<String, Boolean> requested = hidden != null ? hidden : new Map<String, Boolean>();
            DeliveryHubSettings__c settings = getOrCreateSettings();

            for (String componentName : COMPONENT_TO_FIELD.keySet()) {
                if (!requested.containsKey(componentName)) {
                    continue;
                }
                String fieldApiName = COMPONENT_TO_FIELD.get(componentName);
                Boolean shouldHide = requested.get(componentName) == true;
                Datetime existing = (Datetime) settings.get(fieldApiName);
                settings.put(fieldApiName, shouldHide ? (existing != null ? existing : Datetime.now()) : null);
            }

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPSERTABLE, new List<DeliveryHubSettings__c>{ settings });
            upsert decision.getRecords();

            // Re-read from the org default so the returned map reflects what was persisted.
            return buildHiddenMap(DeliveryHubSettings__c.getOrgDefaults());
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Builds the component → isHidden map from a settings record.
     * @param settings The DeliveryHubSettings__c instance (may be a blank getInstance()).
     * @return Map of component name → isHidden.
     */
    private static Map<String, Boolean> buildHiddenMap(DeliveryHubSettings__c settings) {
        Map<String, Boolean> result = new Map<String, Boolean>();
        for (String componentName : COMPONENT_TO_FIELD.keySet()) {
            Boolean isHidden = false;
            if (settings != null) {
                isHidden = settings.get(COMPONENT_TO_FIELD.get(componentName)) != null;
            }
            result.put(componentName, isHidden);
        }
        return result;
    }

    /**
     * @description Helper to get existing org-default settings or create a new default instance.
     * @return DeliveryHubSettings__c settings record.
     */
    private static DeliveryHubSettings__c getOrCreateSettings() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        return settings;
    }
}
