/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for User. Filters eligible users (active,
 *               non-guest, internal) and delegates auto-assignment to
 *               DeliveryUserAutoAssignService. Uses @future to avoid mixed-DML
 *               errors when User insert is followed by PermissionSetAssignment
 *               insert in the same transaction.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryUserTriggerHandler {

    /**
     * @description Handles after-insert: applies auto-assign rules to newly
     *              created Users (filters to active, non-guest, internal Users).
     * @param newRecords List of newly inserted User records.
     */
    public static void onAfterInsert(List<User> newRecords) {
        applyRulesAsync(filterEligible(newRecords));
    }

    /**
     * @description Handles after-update: applies auto-assign rules when a User
     *              transitions to active or changes Profile.
     * @param newRecords List of updated User records.
     * @param oldMap Map of pre-update User records.
     */
    public static void onAfterUpdate(List<User> newRecords, Map<Id, User> oldMap) {
        List<User> reactivated = new List<User>();
        for (User u : newRecords) {
            if (becameEligible(u, oldMap.get(u.Id))) {
                reactivated.add(u);
            }
        }
        applyRulesAsync(reactivated);
    }

    /**
     * @description Backfill entry point — assigns PermissionSets to ALL active
     *              internal Users per current UserAutoAssignConfig__mdt rules.
     *              Called by DeliveryHubInstallHandler on package install/upgrade
     *              so existing tenants who missed the User trigger get caught up.
     */
    public static void assignAllActiveUsers() {
        List<User> activeUsers = [
            SELECT Id FROM User
            WHERE IsActive = true AND UserType = 'Standard'
            WITH SYSTEM_MODE
            LIMIT 10000
        ];
        Set<Id> ids = new Set<Id>();
        for (User u : activeUsers) {
            ids.add(u.Id);
        }
        applyRulesAsyncFromIds(ids);
    }

    @TestVisible
    private static List<User> filterEligible(List<User> records) {
        List<User> eligible = new List<User>();
        for (User u : records) {
            if (u.IsActive == true && u.UserType == 'Standard') {
                eligible.add(u);
            }
        }
        return eligible;
    }

    @TestVisible
    private static Boolean becameEligible(User current, User prior) {
        if (current.IsActive != true || current.UserType != 'Standard') {
            return false;
        }
        if (prior == null) {
            return true;
        }
        Boolean wasEligible = prior.IsActive == true
            && prior.UserType == 'Standard'
            && prior.ProfileId == current.ProfileId;
        return !wasEligible;
    }

    private static void applyRulesAsync(List<User> users) {
        if (users == null || users.isEmpty()) {
            return;
        }
        Set<Id> userIds = new Set<Id>();
        for (User u : users) {
            userIds.add(u.Id);
        }
        applyRulesAsyncFromIds(userIds);
    }

    private static void applyRulesAsyncFromIds(Set<Id> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }
        // Future call avoids mixed-DML when User insert is followed by
        // PermissionSetAssignment insert in the same transaction.
        if (System.isFuture() || System.isBatch() || System.isQueueable() || Test.isRunningTest()) {
            DeliveryUserAutoAssignService.applyRules(userIds);
        } else {
            applyRulesFuture(userIds);
        }
    }

    @future
    private static void applyRulesFuture(Set<Id> userIds) {
        DeliveryUserAutoAssignService.applyRules(userIds);
    }
}
