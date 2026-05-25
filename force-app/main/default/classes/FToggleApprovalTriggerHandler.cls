/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Before-insert handler for FeatureToggleApproval__c. Resolves
 *               an approver from the ApprovalRouting__mdt rule table and
 *               stamps ApproverUserLookup__c so admins do not have to open
 *               every approval row to assign a person manually. Closes Flow 4
 *               #2 from docs/audits/e2e-walkthrough-2026-05-21.md.
 *
 *               Resolution algorithm:
 *                 - Build the set of FeatureLookup__c ids referenced by the
 *                   incoming rows that don't already have an approver.
 *                 - One SOQL: load those Feature__c rows + their parent
 *                   request action so we know the (FeatureDefinitionTxt, Action)
 *                   key per approval row.
 *                 - One SOQL: load every ApprovalRouting__mdt row ordered
 *                   by SortOrderNumber__c ASC.
 *                 - For each approval, pick the FIRST routing row whose
 *                   (FeatureDefinitionTxt__c IN [featureDef, __DEFAULT__]
 *                    AND ActionPk__c IN [action, Any]) wins.
 *                 - Stamp the matched ApproverUserIdTxt__c onto the approval
 *                   row. If no rule matches, leave null (admin assigns
 *                   manually — same behaviour as before this handler shipped).
 *
 *               Bulk-safe: 4 SOQL regardless of incoming row count
 *               (Feature__c, FeatureToggleRequest__c, ApprovalRouting__mdt,
 *               User), no DML — we mutate the in-memory Trigger.new rows in
 *               a before-insert context.
 *
 *               Class name is intentionally trimmed from
 *               "FeatureToggleApprovalTriggerHandler" to fit comfortably
 *               under the 40-char Apex identifier cap once the "Test"
 *               suffix is appended (29 + 4 = 33 chars).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.ExcessiveParameterList')
public with sharing class FToggleApprovalTriggerHandler {

    /** Sentinel FeatureDefinitionTxt value that matches any feature. */
    @TestVisible
    private static final String DEFAULT_FEATURE_KEY = '__DEFAULT__';

    /** ActionPk value that matches any toggle direction. */
    @TestVisible
    private static final String ANY_ACTION_KEY = 'Any';

    /**
     * Test-only override for the routing list. When set (in @IsTest context),
     * queryRoutings returns this list instead of the SOQL. Lets the handler
     * test simulate "no rules at all" / "only specific rules" / etc. without
     * deleting deployed customMetadata seed rows.
     */
    @TestVisible
    private static List<ApprovalRouting__mdt> testRoutingsOverride;

    /**
     * @description Before-insert entry point. Stamps ApproverUserLookup__c on
     *              every row that doesn't already have an approver assigned,
     *              using the ApprovalRouting__mdt rule table. No-op when the
     *              incoming list is empty or every row already has an approver.
     * @param newRows Trigger.new — the list of approval rows about to be inserted.
     */
    public void onBeforeInsert(List<FeatureToggleApproval__c> newRows) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }
        List<FeatureToggleApproval__c> rowsNeedingApprover = collectRowsNeedingApprover(newRows);
        if (rowsNeedingApprover.isEmpty()) {
            return;
        }
        Set<Id> featureIds = collectFeatureIds(rowsNeedingApprover);
        if (featureIds.isEmpty()) {
            return;
        }
        Map<Id, String> featureDefByFeatureId = queryFeatureDefinitions(featureIds);
        Map<Id, String> actionByRequestId = queryRequestActions(rowsNeedingApprover);
        List<ApprovalRouting__mdt> routings = queryRoutings();
        if (routings.isEmpty()) {
            return;
        }
        Set<Id> validApproverIds = validateApproverUserIds(routings);
        stampApprovers(rowsNeedingApprover, featureDefByFeatureId, actionByRequestId,
            routings, validApproverIds);
    }

    /**
     * @description Validates that each ApprovalRouting__mdt's ApproverUserIdTxt__c
     *              resolves to a real User. Subscribers ship with placeholder
     *              Ids in the seed (005000000000000AAA) until they edit the
     *              routing rules — stamping a placeholder Id onto an approval
     *              row would cause INVALID_CROSS_REFERENCE_KEY on insert, so
     *              we filter the placeholders out here and treat them as
     *              "no rule match" instead of blowing up the user's submit.
     *              One SOQL against the User table for the unique candidate Ids.
     * @param routings All loaded routings.
     * @return Set of Ids that resolve to a real, accessible User row.
     */
    private Set<Id> validateApproverUserIds(List<ApprovalRouting__mdt> routings) {
        Set<Id> candidates = new Set<Id>();
        for (ApprovalRouting__mdt r : routings) {
            if (String.isBlank(r.ApproverUserIdTxt__c)) {
                continue;
            }
            try {
                candidates.add((Id) r.ApproverUserIdTxt__c);
            } catch (System.StringException ignored) {
                // Mal-formed Id string — skip silently. The placeholder
                // 005000000000000AAA is structurally valid so it parses;
                // free-text values that aren't valid Ids land here. The
                // handler leaves ApproverUserLookup__c unassigned and the
                // admin reassigns manually — same fallback as no-rule-match.
            }
        }
        if (candidates.isEmpty()) {
            return new Set<Id>();
        }
        Set<Id> valid = new Set<Id>();
        for (User u : [
            SELECT Id FROM User WHERE Id IN :candidates AND IsActive = true
            WITH SYSTEM_MODE
        ]) {
            valid.add(u.Id);
        }
        return valid;
    }

    /**
     * @description Filters out rows that already have an explicit approver —
     *              the approval service may pre-populate the row in some
     *              flows (REST submit with explicit approverId) and we must
     *              never overwrite an explicit assignment.
     * @param newRows Trigger.new.
     * @return Subset of rows whose ApproverUserLookup__c is null.
     */
    private List<FeatureToggleApproval__c> collectRowsNeedingApprover(
        List<FeatureToggleApproval__c> newRows
    ) {
        List<FeatureToggleApproval__c> out = new List<FeatureToggleApproval__c>();
        for (FeatureToggleApproval__c row : newRows) {
            if (row.ApproverUserLookup__c == null) {
                out.add(row);
            }
        }
        return out;
    }

    /**
     * @description Collects the Feature__c ids referenced by the rows that
     *              still need an approver. Rows missing FeatureLookup__c are
     *              skipped (they cannot be resolved).
     * @param rows Rows needing an approver.
     * @return Set of Feature__c ids to look up.
     */
    private Set<Id> collectFeatureIds(List<FeatureToggleApproval__c> rows) {
        Set<Id> ids = new Set<Id>();
        for (FeatureToggleApproval__c row : rows) {
            if (row.FeatureLookup__c != null) {
                ids.add(row.FeatureLookup__c);
            }
        }
        return ids;
    }

    /**
     * @description One SOQL on Feature__c. Returns a map Id -> FeatureDefinitionTxt
     *              so the per-row resolver can build the routing key without
     *              re-querying per row.
     * @param featureIds Feature__c ids to load.
     * @return Map keyed by Feature.Id with the FeatureDefinitionTxt value.
     */
    private Map<Id, String> queryFeatureDefinitions(Set<Id> featureIds) {
        Map<Id, String> out = new Map<Id, String>();
        for (Feature__c f : [
            SELECT Id, FeatureDefinitionTxt__c
            FROM Feature__c
            WHERE Id IN :featureIds
            WITH SYSTEM_MODE
        ]) {
            out.put(f.Id, f.FeatureDefinitionTxt__c);
        }
        return out;
    }

    /**
     * @description One SOQL on FeatureToggleRequest__c for the rows that
     *              carry a RequestLookup__c. Returns a map of request.Id ->
     *              ActionPk__c so the resolver can match against the routing
     *              ActionPk filter.
     * @param rows Rows needing an approver.
     * @return Map keyed by request.Id with the ActionPk value.
     */
    private Map<Id, String> queryRequestActions(List<FeatureToggleApproval__c> rows) {
        Set<Id> requestIds = new Set<Id>();
        for (FeatureToggleApproval__c row : rows) {
            if (row.RequestLookup__c != null) {
                requestIds.add(row.RequestLookup__c);
            }
        }
        Map<Id, String> out = new Map<Id, String>();
        if (requestIds.isEmpty()) {
            return out;
        }
        for (FeatureToggleRequest__c req : [
            SELECT Id, ActionPk__c
            FROM FeatureToggleRequest__c
            WHERE Id IN :requestIds
            WITH SYSTEM_MODE
        ]) {
            out.put(req.Id, req.ActionPk__c);
        }
        return out;
    }

    /**
     * @description One SOQL on ApprovalRouting__mdt. Returns every active
     *              routing row ordered by SortOrderNumber__c ASC so the
     *              per-row resolver can pick the lowest-sort matching rule.
     * @return Ordered list of routing rows (lowest sort first).
     */
    private List<ApprovalRouting__mdt> queryRoutings() {
        if (Test.isRunningTest() && testRoutingsOverride != null) {
            return testRoutingsOverride;
        }
        return [
            SELECT DeveloperName, FeatureDefinitionTxt__c, ActionPk__c,
                   ApproverUserIdTxt__c, SortOrderNumber__c
            FROM ApprovalRouting__mdt
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST, DeveloperName ASC
        ];
    }

    /**
     * @description Per-row resolution loop. For each row needing an approver,
     *              walks the routing list (already sorted) and picks the
     *              first row whose FeatureDefinitionTxt and ActionPk both
     *              match the row's (featureDef, action) pair — with
     *              __DEFAULT__ / Any acting as wildcards. When a match is
     *              found, the row's ApproverUserLookup__c is stamped to the
     *              matched ApproverUserIdTxt__c. When no match is found, the
     *              row is left null (admin assigns manually, same as before).
     * @param rows Rows needing an approver.
     * @param featureDefByFeatureId Map from queryFeatureDefinitions.
     * @param actionByRequestId Map from queryRequestActions.
     * @param routings Ordered list of routings from queryRoutings.
     * @param validApproverIds Set of Ids that resolve to a real active User.
     */
    private void stampApprovers(
        List<FeatureToggleApproval__c> rows,
        Map<Id, String> featureDefByFeatureId,
        Map<Id, String> actionByRequestId,
        List<ApprovalRouting__mdt> routings,
        Set<Id> validApproverIds
    ) {
        for (FeatureToggleApproval__c row : rows) {
            String featureDef = featureDefByFeatureId.get(row.FeatureLookup__c);
            String action = actionByRequestId.get(row.RequestLookup__c);
            ApprovalRouting__mdt match = findRoutingMatch(routings, featureDef, action,
                validApproverIds);
            if (match != null) {
                row.ApproverUserLookup__c = (Id) match.ApproverUserIdTxt__c;
            }
        }
    }

    /**
     * @description Picks the first routing in the sorted list whose feature
     *              key matches (specific FeatureDefinitionTxt or __DEFAULT__)
     *              AND whose action key matches (specific ActionPk or Any).
     * @param routings Pre-sorted routing list.
     * @param featureDef The approval row's FeatureDefinitionTxt value
     *                   (resolved from Feature__c). May be null.
     * @param action The approval row's ActionPk value (resolved from the
     *               parent request). May be null.
     * @param validApproverIds Set of Ids that resolve to a real active User.
     * @return First matching routing, or null when nothing matches.
     */
    private ApprovalRouting__mdt findRoutingMatch(
        List<ApprovalRouting__mdt> routings,
        String featureDef,
        String action,
        Set<Id> validApproverIds
    ) {
        for (ApprovalRouting__mdt r : routings) {
            if (!matchesFeatureKey(r.FeatureDefinitionTxt__c, featureDef)) {
                continue;
            }
            if (!matchesActionKey(r.ActionPk__c, action)) {
                continue;
            }
            // Skip rules whose approver Id is not a real, active User. Falls
            // through to the next-priority rule (or null if none match) so
            // the placeholder seed never poisons a real submit.
            if (!isApproverValid(r.ApproverUserIdTxt__c, validApproverIds)) {
                continue;
            }
            return r;
        }
        return null;
    }

    private Boolean isApproverValid(String approverIdTxt, Set<Id> validApproverIds) {
        if (String.isBlank(approverIdTxt)) {
            return false;
        }
        try {
            return validApproverIds.contains((Id) approverIdTxt);
        } catch (System.StringException ignored) {
            return false;
        }
    }

    private Boolean matchesFeatureKey(String ruleKey, String featureDef) {
        if (String.isBlank(ruleKey)) {
            return false;
        }
        if (ruleKey == DEFAULT_FEATURE_KEY) {
            return true;
        }
        return featureDef != null && ruleKey == featureDef;
    }

    private Boolean matchesActionKey(String ruleAction, String action) {
        if (String.isBlank(ruleAction)) {
            return false;
        }
        if (ruleAction == ANY_ACTION_KEY) {
            return true;
        }
        return action != null && ruleAction == action;
    }
}
