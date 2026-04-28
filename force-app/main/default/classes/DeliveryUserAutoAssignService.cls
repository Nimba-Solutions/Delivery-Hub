/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Idempotent PermissionSet assignment engine driven by
 *               UserAutoAssignConfig__mdt. Used by DeliveryUserTriggerHandler
 *               (per-record on User insert/update) and DeliveryHubInstallHandler
 *               (bulk backfill on package install/upgrade).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryUserAutoAssignService {

    /**
     * @description Apply auto-assignment rules to the supplied user IDs.
     *              Loads enabled config rows, resolves each PermissionSet by
     *              namespaced + un-namespaced name, filters target Users by
     *              Profile if specified, and inserts only the assignments that
     *              don't already exist.
     * @param userIds Users to evaluate.
     */
    public static void applyRules(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }
        List<UserAutoAssignConfig__mdt> rules = loadEnabledRules();
        if (rules.isEmpty()) {
            return;
        }
        Map<String, Id> permSetByName = buildPermSetMap(rules);
        if (permSetByName.isEmpty()) {
            return;
        }
        Map<Id, User> targetUsers = loadUsers(userIds);
        Set<String> existingKeys = loadExistingAssignmentKeys(userIds, permSetByName.values());
        List<PermissionSetAssignment> toInsert = buildAssignments(
            targetUsers, rules, permSetByName, existingKeys);
        insertAssignments(toInsert);
    }

    @TestVisible
    private static List<UserAutoAssignConfig__mdt> loadEnabledRules() {
        return [
            SELECT PermissionSetDeveloperNameTxt__c, ProfileNameFilterTxt__c
            FROM UserAutoAssignConfig__mdt
            WHERE EnabledDateTime__c != null
            WITH SYSTEM_MODE
        ];
    }

    @TestVisible
    private static Map<String, Id> buildPermSetMap(List<UserAutoAssignConfig__mdt> rules) {
        Set<String> names = new Set<String>();
        for (UserAutoAssignConfig__mdt r : rules) {
            if (String.isNotBlank(r.PermissionSetDeveloperNameTxt__c)) {
                names.add(r.PermissionSetDeveloperNameTxt__c);
                names.add('delivery__' + r.PermissionSetDeveloperNameTxt__c);
            }
        }
        Map<String, Id> byName = new Map<String, Id>();
        for (PermissionSet ps : [
            SELECT Id, Name FROM PermissionSet
            WHERE Name IN :names
            WITH SYSTEM_MODE
        ]) {
            byName.put(ps.Name, ps.Id);
            byName.put(ps.Name.replace('delivery__', ''), ps.Id);
        }
        return byName;
    }

    private static Map<Id, User> loadUsers(Set<Id> userIds) {
        return new Map<Id, User>([
            SELECT Id, Profile.Name FROM User
            WHERE Id IN :userIds
            WITH SYSTEM_MODE
        ]);
    }

    private static Set<String> loadExistingAssignmentKeys(Set<Id> userIds, List<Id> permSetIds) {
        Set<String> keys = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId, PermissionSetId FROM PermissionSetAssignment
            WHERE AssigneeId IN :userIds AND PermissionSetId IN :permSetIds
            WITH SYSTEM_MODE
        ]) {
            keys.add(psa.AssigneeId + '|' + psa.PermissionSetId);
        }
        return keys;
    }

    @TestVisible
    private static List<PermissionSetAssignment> buildAssignments(
        Map<Id, User> targetUsers,
        List<UserAutoAssignConfig__mdt> rules,
        Map<String, Id> permSetByName,
        Set<String> existingKeys
    ) {
        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (User u : targetUsers.values()) {
            for (UserAutoAssignConfig__mdt r : rules) {
                PermissionSetAssignment candidate = candidateFor(u, r, permSetByName, existingKeys);
                if (candidate != null) {
                    toInsert.add(candidate);
                    existingKeys.add(candidate.AssigneeId + '|' + candidate.PermissionSetId);
                }
            }
        }
        return toInsert;
    }

    private static PermissionSetAssignment candidateFor(
        User u,
        UserAutoAssignConfig__mdt r,
        Map<String, Id> permSetByName,
        Set<String> existingKeys
    ) {
        String userProfile = u.Profile == null ? '' : u.Profile.Name;
        if (!matchesProfile(userProfile, r.ProfileNameFilterTxt__c)) {
            return null;
        }
        Id permSetId = permSetByName.get(r.PermissionSetDeveloperNameTxt__c);
        if (permSetId == null) {
            return null;
        }
        if (existingKeys.contains(u.Id + '|' + permSetId)) {
            return null;
        }
        return new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = permSetId
        );
    }

    @TestVisible
    private static Boolean matchesProfile(String userProfileName, String filterCsv) {
        if (String.isBlank(filterCsv)) {
            return true;
        }
        if (String.isBlank(userProfileName)) {
            return false;
        }
        for (String name : filterCsv.split(',')) {
            if (name.trim().equalsIgnoreCase(userProfileName)) {
                return true;
            }
        }
        return false;
    }

    private static void insertAssignments(List<PermissionSetAssignment> toInsert) {
        if (toInsert.isEmpty()) {
            return;
        }
        try {
            insert toInsert;
        } catch (DmlException e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryUserAutoAssignService] PermissionSetAssignment insert failed: '
                + e.getMessage());
        }
    }
}
