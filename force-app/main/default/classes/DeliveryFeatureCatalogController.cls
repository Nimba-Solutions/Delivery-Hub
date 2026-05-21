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
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
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
     * @description Gated toggle for a single Feature__c. Admins can always flip.
     *              Non-admins can flip ONLY when (a) the matching
     *              FeatureDefinition__mdt has no RequiresOnboardingTrackTxt__c
     *              set, OR (b) the requested operation is a disable, OR (c) the
     *              user has finished the onboarding track for that feature. Sets
     *              the enable/disable DateTime stamps + LastToggledBy lookup; the
     *              trigger handler takes care of the settings-mirror + audit-row
     *              cascade.
     *
     *              Disable is intentionally NOT gated on track completion — a
     *              non-admin who can't enable a feature can still undo their
     *              own enable. Matches the standard "you can undo your own
     *              work but you can't unilaterally start it" pattern.
     * @param featureId  The Feature__c row whose toggle should flip.
     * @param enable     True to enable (sets Enabled, clears Disabled).
     *                   False to disable (sets Disabled, leaves Enabled
     *                   in place so the historical activation stamp is
     *                   preserved; ActiveSinceDateTime__c formula is
     *                   re-evaluated by the platform).
     */
    @AuraEnabled
    global static void toggleFeature(Id featureId, Boolean enable) {
        if (featureId == null) {
            throw new AuraHandledException('featureId is required.');
        }
        Feature__c f = loadFeatureOrThrow(featureId);
        Boolean enableFlag = enable == true;
        assertCanToggle(f, enableFlag);
        enforceCascadeOrThrow(featureId, enableFlag);
        applyToggleFields(f, enableFlag);
        persistToggle(f);
    }

    /**
     * @description Loads the cascade tree via DeliveryFeatureGraphService and
     *              refuses the toggle when any Hard child violates the rule:
     *                - Enable path: a Hard blocker is inactive (must be enabled first).
     *                - Disable path: a Hard dependent is active (must be disabled first).
     *              Soft / Optional edges are informational only — logged at INFO
     *              and never block. No-op when no cascade tree exists.
     * @param featureId The feature about to be toggled.
     * @param enable    True for Enable, false for Disable.
     */
    private static void enforceCascadeOrThrow(Id featureId, Boolean enable) {
        String action = enable
            ? DeliveryFeatureGraphService.ACTION_ENABLE
            : DeliveryFeatureGraphService.ACTION_DISABLE;
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            DeliveryFeatureGraphService.computeCascade(featureId, action);
        if (root == null || root.children == null || root.children.isEmpty()) {
            return;
        }
        List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> violations =
            collectHardViolations(root, enable);
        if (violations.isEmpty()) {
            return;
        }
        throw new AuraHandledException(formatViolationMessage(violations, enable));
    }

    /**
     * @description Flattens the cascade tree (BFS, excluding the root) and
     *              returns the subset of nodes that violate the Hard-dependency
     *              rule for the requested action. Soft / Optional edges are
     *              logged at INFO level and excluded from the returned list.
     * @param root   Root cascade node (ignored — only its descendants are checked).
     * @param enable True for Enable, false for Disable.
     * @return Hard-violating descendant nodes, in BFS order.
     */
    private static List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> collectHardViolations(
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root,
        Boolean enable
    ) {
        List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> violations =
            new List<DeliveryFeatureGraphService.FeatureGraphNodeDTO>();
        if (root == null || root.children == null) {
            return violations;
        }
        List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> queue =
            new List<DeliveryFeatureGraphService.FeatureGraphNodeDTO>();
        queue.addAll(root.children);
        while (!queue.isEmpty()) {
            DeliveryFeatureGraphService.FeatureGraphNodeDTO node = queue.remove(0);
            if (node == null) {
                continue;
            }
            classifyCascadeNode(node, enable, violations);
            if (node.children != null && !node.children.isEmpty()) {
                queue.addAll(node.children);
            }
        }
        return violations;
    }

    /**
     * @description Classifies a single cascade descendant against the Hard rule.
     *              Hard + blocking-condition → appended to violations. Soft /
     *              Optional → debug log only. Hard but condition satisfied → no-op.
     * @param node       Cascade tree node (a descendant — never the root).
     * @param enable     True for Enable, false for Disable.
     * @param violations Out-list — appended when this node violates.
     */
    private static void classifyCascadeNode(
        DeliveryFeatureGraphService.FeatureGraphNodeDTO node,
        Boolean enable,
        List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> violations
    ) {
        String depType = node.dependencyType;
        Boolean isHard = (depType == 'Hard');
        if (!isHard) {
            System.debug(LoggingLevel.INFO,
                '[DeliveryFeatureCatalogController.enforceCascadeOrThrow] non-Hard edge ('
                + depType + ') to ' + node.name + ' — informational only.');
            return;
        }
        Boolean childActive = node.isActive == true;
        // Enable path: child is a feature THIS feature depends on. Block if inactive.
        // Disable path: child is a feature that depends on THIS feature. Block if active.
        Boolean blocks = enable ? !childActive : childActive;
        if (blocks) {
            violations.add(node);
        }
    }

    /**
     * @description Builds the user-facing AuraHandledException message for one
     *              or more Hard violations. Uses the first violation's label so
     *              the user sees the concrete blocker; suffixes "(+N more)" when
     *              multiple Hard violations surfaced in the same cascade.
     * @param violations Non-empty list of Hard-violating cascade nodes.
     * @param enable     True for Enable, false for Disable.
     * @return Formatted message ready to hand to AuraHandledException.
     */
    private static String formatViolationMessage(
        List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> violations,
        Boolean enable
    ) {
        DeliveryFeatureGraphService.FeatureGraphNodeDTO first = violations.get(0);
        String displayName = String.isBlank(first.label) ? first.name : first.label;
        String more = violations.size() > 1
            ? ' (+' + (violations.size() - 1) + ' more)'
            : '';
        if (enable) {
            return 'Cannot enable: depends on inactive feature "' + displayName + '" (Hard).' + more;
        }
        return 'Cannot disable: blocked by active dependent "' + displayName + '" (Hard).' + more;
    }

    /**
     * @description Throws AuraHandledException when the running user is not
     *              allowed to perform the requested toggle. Admins always
     *              pass. Non-admins pass on disable. Non-admins on enable
     *              pass only when the linked onboarding track is complete
     *              (or no track is required).
     * @param f The feature row about to be toggled.
     * @param enable True if the requested operation is enable; false for disable.
     */
    private static void assertCanToggle(Feature__c f, Boolean enable) {
        if (isAdmin()) {
            return;
        }
        if (!enable) {
            // Non-admin disable is allowed — undoing a previously enabled
            // feature does not require completing the onboarding track.
            return;
        }
        FeatureDefinition__mdt def = resolveDefinitionFor(f);
        String trackName = def == null ? null : def.RequiresOnboardingTrackTxt__c;
        if (String.isBlank(trackName)) {
            // No track required at the definition level — non-admins are
            // allowed (admin-only gating already passed above). PR 5+ can
            // tighten this further if business policy demands it.
            return;
        }
        Boolean done = DeliveryOnboardingService.isTrackComplete(trackName, UserInfo.getUserId());
        if (!done) {
            String trackLabel = resolveTrackLabelFor(trackName);
            throw new AuraHandledException(
                'Complete the ' + trackLabel + ' onboarding track before enabling this feature.');
        }
    }

    /**
     * @description Returns the FeatureDefinition__mdt that the given
     *              Feature__c maps to via FeatureDefinitionTxt__c, or null
     *              when no mapping exists.
     * @param f Feature__c row whose definition should be resolved.
     * @return Matching FeatureDefinition__mdt row, or null when none matches.
     */
    private static FeatureDefinition__mdt resolveDefinitionFor(Feature__c f) {
        if (f == null || String.isBlank(f.FeatureDefinitionTxt__c)) {
            return null;
        }
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName, RequiresOnboardingTrackTxt__c
            FROM FeatureDefinition__mdt
            WHERE DeveloperName = :f.FeatureDefinitionTxt__c
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return defs.isEmpty() ? null : defs.get(0);
    }

    /**
     * @description Returns the human label for the named OnboardingTrack__mdt.
     *              Falls back to the DeveloperName when LabelTxt__c is blank
     *              or the row is missing.
     * @param trackDeveloperName DeveloperName of the OnboardingTrack__mdt.
     * @return Human label (LabelTxt__c) when available, otherwise the
     *         DeveloperName itself.
     */
    private static String resolveTrackLabelFor(String trackDeveloperName) {
        if (String.isBlank(trackDeveloperName)) {
            return '';
        }
        List<OnboardingTrack__mdt> tracks = [
            SELECT DeveloperName, LabelTxt__c
            FROM OnboardingTrack__mdt
            WHERE DeveloperName = :trackDeveloperName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (tracks.isEmpty()) {
            return trackDeveloperName;
        }
        return String.isBlank(tracks.get(0).LabelTxt__c) ? trackDeveloperName : tracks.get(0).LabelTxt__c;
    }

    private static Feature__c loadFeatureOrThrow(Id featureId) {
        List<Feature__c> existing = [
            SELECT Id, FeatureDefinitionTxt__c,
                   EnabledDateTime__c, DisabledDateTime__c, LastToggledByUserLookup__c
            FROM Feature__c
            WHERE Id = :featureId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            throw new AuraHandledException('Feature not found.');
        }
        return existing.get(0);
    }

    private static void applyToggleFields(Feature__c f, Boolean enable) {
        DateTime now = DateTime.now();
        if (enable) {
            f.EnabledDateTime__c = now;
            f.DisabledDateTime__c = null;
        } else {
            f.DisabledDateTime__c = now;
        }
        f.LastToggledByUserLookup__c = UserInfo.getUserId();
    }

    private static void persistToggle(Feature__c f) {
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
