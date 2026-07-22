/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Per-tab visibility toggles for the Delivery Hub workspace ("Delivery") tab.
 *               Lets an admin hide individual non-admin sub-tabs of deliveryHubWorkspace
 *               (so the workspace only surfaces what an org uses) via the Settings tab,
 *               fully reversibly. Backed by inverted HideTab…DateTime__c fields on
 *               DeliveryHubSettings__c: null = SHOWN (safe default), non-null = HIDDEN. The
 *               map this returns is keyed by the tab value (e.g. 'board') so the workspace
 *               can ask "is this tab hidden?" with a single cacheable wire. The 5 admin-only
 *               tabs (Templates/Analytics/Velocity/Settings/Workflows) are gated by isAdmin
 *               and are intentionally NOT toggleable here.
 * @author       Cloud Nimbus LLC
 */
public with sharing class DeliveryTabVisibilityController {

    // Map of workspace tab value → the inverted "hide" DateTime field that gates it.
    // Order is the order the toggles render in the Settings card.
    private static final Map<String, String> TAB_TO_FIELD = new Map<String, String>{
        'intake'     => 'HideTabIntakeDateTime__c',
        'board'      => 'HideTabBoardDateTime__c',
        'huddle'     => 'HideTabHuddleDateTime__c',
        'newRequest' => 'HideTabNewRequestDateTime__c',
        'timeline'   => 'HideTabTimelineDateTime__c',
        'activity'   => 'HideTabActivityDateTime__c',
        'documents'  => 'HideTabDocumentsDateTime__c',
        'guide'      => 'HideTabGuideDateTime__c',
        'approvals'  => 'HideTabApprovalsDateTime__c',
        'closeouts'  => 'HideTabCloseoutsDateTime__c',
        'forecast'   => 'HideTabForecastDateTime__c'
    };

    /**
     * @description Returns which workspace sub-tabs are currently hidden, keyed by the tab
     *              value. A tab is hidden when its matching HideTab…DateTime__c field is
     *              non-null (inverted-default: null = shown). Reads the hierarchy custom
     *              setting via getInstance().
     * @return Map of tab value → isHidden (true = hide in the Delivery workspace).
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getHiddenWorkspaceTabs() {
        return buildHiddenMap(DeliveryHubSettings__c.getInstance());
    }

    /**
     * @description Persists the per-tab workspace visibility toggles. For each entry,
     *              true = HIDE (stamps the HideTab…DateTime__c with now() if not already
     *              set), false = SHOW (clears the field). Existing stamps are preserved so
     *              the "active since" timestamp does not churn. Writes to the org-default
     *              record. Returns the fresh hidden-map so the caller can refresh state
     *              without hitting the cacheable read's stale cache.
     * @param hidden Map of tab value → desired isHidden state.
     * @return Map of tab value → isHidden after the save.
     */
    @AuraEnabled
    public static Map<String, Boolean> setHiddenWorkspaceTabs(Map<String, Boolean> hidden) {
        try {
            Map<String, Boolean> requested = hidden != null ? hidden : new Map<String, Boolean>();
            DeliveryHubSettings__c settings = getOrCreateSettings();

            for (String tabValue : TAB_TO_FIELD.keySet()) {
                if (!requested.containsKey(tabValue)) {
                    continue;
                }
                String fieldApiName = TAB_TO_FIELD.get(tabValue);
                Boolean shouldHide = requested.get(tabValue) == true;
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
     * @description Builds the tab value → isHidden map from a settings record.
     * @param settings The DeliveryHubSettings__c instance (may be a blank getInstance()).
     * @return Map of tab value → isHidden.
     */
    private static Map<String, Boolean> buildHiddenMap(DeliveryHubSettings__c settings) {
        Map<String, Boolean> result = new Map<String, Boolean>();
        for (String tabValue : TAB_TO_FIELD.keySet()) {
            Boolean isHidden = false;
            if (settings != null) {
                isHidden = settings.get(TAB_TO_FIELD.get(tabValue)) != null;
            }
            result.put(tabValue, isHidden);
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
