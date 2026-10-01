/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Server-side role checks for the mutating @AuraEnabled entry
 *               points (approvals, work-log decisions, settings saves, repair).
 *               Every LWC action is reachable outside the component (Aura
 *               endpoint, anonymous Apex), so the component hiding a button is
 *               not a control. Two roles:
 *
 *               isAdmin()           — the running user holds Customize
 *                 Application or Modify All Data (profile or permission set),
 *                 or the DeliveryHubAdmin_App permission set, or the
 *                 DeliveryHubAdmin permission set group.
 *               isApproverOrAdmin() — isAdmin(), or the running user is the
 *                 configured approver / backup approver
 *                 (DeliveryHubSettings__c.ApproverUserIdTxt__c /
 *                 ApproverBackupUserIdTxt__c).
 *
 *               Permission-set checks go through PermissionSetAssignment: a
 *               profile's permissions surface there as the profile-owned
 *               permission set, and a group assignment surfaces as the group's
 *               aggregate permission set (PermissionSetGroupId), so one query
 *               covers all three routes. PermissionSet.Name and
 *               PermissionSetGroup.DeveloperName carry no namespace prefix, so
 *               the literals are install-safe. Results are cached per
 *               transaction.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryAccessService {

    /** Admin permission set shipped by the package. */
    @TestVisible
    private static final String ADMIN_PERMISSION_SET = 'DeliveryHubAdmin_App';

    /** Admin permission set group shipped by the package. */
    @TestVisible
    private static final String ADMIN_PERMISSION_SET_GROUP = 'DeliveryHubAdmin';

    /** Per-transaction cache keyed by user (System.runAs can switch users mid-transaction). */
    private static Map<Id, Boolean> adminByUser = new Map<Id, Boolean>();

    /**
     * @description Test seam: forces isAdmin() to a fixed answer so a test can
     *              exercise the denied path without building a restricted user
     *              (and the guarded code path without one). Null = real check.
     */
    @TestVisible
    private static Boolean adminOverride;

    /**
     * @description True when the running user administers the org or the
     *              package (Customize Application, Modify All Data, the
     *              DeliveryHubAdmin_App permission set, or the DeliveryHubAdmin
     *              permission set group).
     * @return Whether the running user is an admin.
     */
    public static Boolean isAdmin() {
        if (adminOverride != null) {
            return adminOverride;
        }
        Id userId = UserInfo.getUserId();
        if (!adminByUser.containsKey(userId)) {
            adminByUser.put(userId, queryIsAdmin(userId));
        }
        return adminByUser.get(userId);
    }

    /**
     * @description True when the running user is an admin (isAdmin) or the
     *              configured primary / backup approver in DeliveryHubSettings__c.
     * @return Whether the running user may make approval decisions.
     */
    public static Boolean isApproverOrAdmin() {
        return isConfiguredApprover(UserInfo.getUserId()) || isAdmin();
    }

    /**
     * @description Throws when the running user is not an admin.
     * @param action Short verb phrase for the error ("change Delivery Hub settings").
     */
    public static void requireAdmin(String action) {
        if (!isAdmin()) {
            throw new AuraHandledException(
                'Only a Delivery Hub admin can ' + action + '.');
        }
    }

    /**
     * @description Throws when the running user is neither the configured
     *              approver nor an admin.
     * @param action Short verb phrase for the error ("approve hours").
     */
    public static void requireApproverOrAdmin(String action) {
        if (!isApproverOrAdmin()) {
            throw new AuraHandledException(
                'Only the Delivery Hub approver or an admin can ' + action + '.');
        }
    }

    /**
     * @description Whether the given user is the configured primary or backup
     *              approver. Malformed ids in settings are ignored.
     * @param userId User to test.
     * @return true when userId matches ApproverUserIdTxt__c or ApproverBackupUserIdTxt__c.
     */
    public static Boolean isConfiguredApprover(Id userId) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || userId == null) {
            return false;
        }
        return sameUser(settings.ApproverUserIdTxt__c, userId)
            || sameUser(settings.ApproverBackupUserIdTxt__c, userId);
    }

    private static Boolean sameUser(String configured, Id userId) {
        if (String.isBlank(configured)) {
            return false;
        }
        try {
            return Id.valueOf(configured.trim()) == userId;
        } catch (Exception e) {
            return false;
        }
    }

    private static Boolean queryIsAdmin(Id userId) {
        Integer hits = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND (PermissionSet.PermissionsModifyAllData = true
                   OR PermissionSet.PermissionsCustomizeApplication = true
                   OR PermissionSet.Name = :ADMIN_PERMISSION_SET
                   OR PermissionSetGroup.DeveloperName = :ADMIN_PERMISSION_SET_GROUP)
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return hits > 0;
    }
}
