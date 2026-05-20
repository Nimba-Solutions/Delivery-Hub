/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only catalog controller for the Feature Cockpit (Layer 4).
 *               Left-joins package-shipped FeatureDefinition__mdt with per-tenant
 *               Feature__c runtime state and returns one DTO per definition,
 *               ordered by SortOrderNumber__c. PR 1 is read-only — PR 2 wires
 *               the toggle / settings-field sync layer.
 *
 *               Global by intent: PR 8 may expose this surface via REST so the
 *               external onboarding portal can read the catalog without an LWC.
 *               All inner classes used in the return signature are global per
 *               CLAUDE.md (`When making Apex classes global, ALL inner classes
 *               used as return/param types must also be global`).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier')
global with sharing class DeliveryFeatureCatalogController {

    /**
     * @description Per-feature card payload for the cockpit LWC. Mirrors the
     *              FeatureDefinition__mdt shape with the runtime fields
     *              (isActive, enabled/disabled stamps) folded in from the
     *              matched Feature__c row when one exists.
     */
    global class FeatureCardDTO {
        @AuraEnabled public Id featureId;
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String category;
        @AuraEnabled public String maturity;
        @AuraEnabled public String icon;
        @AuraEnabled public Decimal sortOrder;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public DateTime enabledDateTime;
        @AuraEnabled public DateTime disabledDateTime;
        @AuraEnabled public String settingsFieldApiName;
        @AuraEnabled public String docsUrl;
    }

    /**
     * @description Returns the feature catalog as a list of card DTOs.
     *              Order is by SortOrderNumber__c ASC, then DeveloperName ASC
     *              as a deterministic tie-breaker. Cacheable so the LWC can
     *              `@wire` it without re-querying on every render.
     * @return List<FeatureCardDTO> one DTO per FeatureDefinition__mdt row.
     */
    @AuraEnabled(cacheable=true)
    global static List<FeatureCardDTO> getCatalog() {
        List<FeatureCardDTO> cards = new List<FeatureCardDTO>();
        try {
            List<FeatureDefinition__mdt> defs = [
                SELECT DeveloperName, LabelTxt__c, DescriptionTxt__c,
                       CategoryPk__c, MaturityPk__c, IconNameTxt__c,
                       SortOrderNumber__c, SettingsFieldApiNameTxt__c, DocsUrl__c
                FROM FeatureDefinition__mdt
                WITH SYSTEM_MODE
                ORDER BY SortOrderNumber__c ASC NULLS LAST, DeveloperName ASC
            ];
            if (defs.isEmpty()) {
                return cards;
            }

            Set<String> defNames = new Set<String>();
            for (FeatureDefinition__mdt fd : defs) {
                defNames.add(fd.DeveloperName);
            }

            Map<String, Feature__c> byDefName = new Map<String, Feature__c>();
            for (Feature__c f : [
                SELECT Id, Name, FeatureDefinitionTxt__c,
                       EnabledDateTime__c, DisabledDateTime__c, ActiveSinceDateTime__c
                FROM Feature__c
                WHERE FeatureDefinitionTxt__c IN :defNames
                WITH SYSTEM_MODE
            ]) {
                byDefName.put(f.FeatureDefinitionTxt__c, f);
            }

            for (FeatureDefinition__mdt fd : defs) {
                FeatureCardDTO dto = new FeatureCardDTO();
                dto.name = fd.DeveloperName;
                dto.label = fd.LabelTxt__c;
                dto.description = fd.DescriptionTxt__c;
                dto.category = fd.CategoryPk__c;
                dto.maturity = fd.MaturityPk__c;
                dto.icon = fd.IconNameTxt__c;
                dto.sortOrder = fd.SortOrderNumber__c;
                dto.settingsFieldApiName = fd.SettingsFieldApiNameTxt__c;
                dto.docsUrl = fd.DocsUrl__c;

                Feature__c runtime = byDefName.get(fd.DeveloperName);
                if (runtime != null) {
                    dto.featureId = runtime.Id;
                    dto.enabledDateTime = runtime.EnabledDateTime__c;
                    dto.disabledDateTime = runtime.DisabledDateTime__c;
                    dto.isActive = runtime.ActiveSinceDateTime__c != null;
                } else {
                    dto.isActive = false;
                }
                cards.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureCatalogController.getCatalog] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to load feature catalog.');
        }
        return cards;
    }

    /**
     * @description Admin-gated toggle for a single Feature__c. Sets the
     *              enable/disable DateTime stamps + LastToggledBy lookup,
     *              then lets the trigger handler take care of the
     *              settings-mirror + audit-row cascade. Throws an
     *              AuraHandledException when the calling user is not a
     *              Delivery Hub admin (PSG-gated, namespace-safe).
     * @param featureId  The Feature__c row whose toggle should flip.
     * @param enable     True to enable (sets Enabled, clears Disabled).
     *                   False to disable (sets Disabled, leaves Enabled
     *                   in place so the historical activation stamp is
     *                   preserved; ActiveSinceDateTime__c formula is
     *                   re-evaluated by the platform).
     */
    @AuraEnabled
    global static void toggleFeature(Id featureId, Boolean enable) {
        if (!isAdmin()) {
            throw new AuraHandledException(
                'You must be a Delivery Hub admin to toggle features.');
        }
        if (featureId == null) {
            throw new AuraHandledException('featureId is required.');
        }

        List<Feature__c> existing = [
            SELECT Id, EnabledDateTime__c, DisabledDateTime__c, LastToggledByUserLookup__c
            FROM Feature__c
            WHERE Id = :featureId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            throw new AuraHandledException('Feature not found.');
        }
        Feature__c f = existing.get(0);
        DateTime now = DateTime.now();
        if (enable == true) {
            f.EnabledDateTime__c = now;
            f.DisabledDateTime__c = null;
        } else {
            f.DisabledDateTime__c = now;
        }
        f.LastToggledByUserLookup__c = UserInfo.getUserId();
        try {
            update f;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureCatalogController.toggleFeature] update failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to update the feature.');
        }
    }

    /**
     * @description Whether the calling user is a Delivery Hub admin (i.e.
     *              has the DeliveryHubAdmin PermissionSetGroup). Used by
     *              the cockpit LWC to gate visibility of the Enable /
     *              Disable buttons. PSG DeveloperName is namespace-
     *              prefixed (`delivery__DeliveryHubAdmin`) on subscriber
     *              installs and bare (`DeliveryHubAdmin`) in dev — accept
     *              both (same pattern as
     *              DeliveryHubDashboardController.isAdminUser).
     * @return True when the current user has DeliveryHubAdmin PSG.
     */
    @AuraEnabled(cacheable=true)
    global static Boolean isAdmin() {
        return ![
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSetGroup.DeveloperName IN
                  ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')
            WITH SYSTEM_MODE
            LIMIT 1
        ].isEmpty();
    }
}
