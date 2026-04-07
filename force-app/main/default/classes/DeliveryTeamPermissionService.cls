/**
 * @description Service for team-based visibility and granular portal permissions.
 *              Provides team lookup, permission checking, and default permission mapping.
 */
public with sharing class DeliveryTeamPermissionService {

    // Default permissions for each portal role
    private static final Map<String, List<String>> ROLE_DEFAULTS = new Map<String, List<String>>{
        'Admin' => new List<String>{
            'view_work_items', 'submit_requests', 'approve_work_logs',
            'view_documents', 'manage_portal_users', 'view_reports'
        },
        'Member' => new List<String>{
            'view_work_items', 'submit_requests', 'view_documents'
        }
    };

    /**
     * @description Returns active teams from DeliveryTeam__mdt, ordered by SortOrder.
     */
    public static List<Map<String, Object>> getActiveTeams() {
        List<Map<String, Object>> teams = new List<Map<String, Object>>();
        for (DeliveryTeam__mdt t : [
            SELECT DeveloperName, Label, TeamNameTxt__c, SortOrderNumber__c
            FROM DeliveryTeam__mdt
            WHERE ActiveDateTime__c != null
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC
        ]) {
            teams.add(new Map<String, Object>{
                'name' => t.TeamNameTxt__c,
                'label' => t.Label,
                'developerName' => t.DeveloperName
            });
        }
        return teams;
    }

    /**
     * @description Checks whether a portal user has a specific permission.
     *              Checks PermissionsTxt__c first; falls back to role defaults.
     */
    public static Boolean hasPermission(String email, Id entityId, String permission) {
        if (String.isBlank(email) || entityId == null || String.isBlank(permission)) {
            return false;
        }
        List<PortalAccess__c> accesses = [
            SELECT RolePk__c, PermissionsTxt__c
            FROM PortalAccess__c
            WHERE EmailTxt__c = :email
            AND NetworkEntityLookup__c = :entityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (accesses.isEmpty()) {
            return false;
        }
        PortalAccess__c access = accesses[0];

        // Check granular permissions first
        if (String.isNotBlank(access.PermissionsTxt__c)) {
            List<Object> perms = (List<Object>) JSON.deserializeUntyped(access.PermissionsTxt__c);
            for (Object p : perms) {
                if (permission.equals((String) p)) {
                    return true;
                }
            }
            return false;
        }

        // Fall back to role-based defaults
        List<String> defaults = ROLE_DEFAULTS.get(access.RolePk__c);
        return defaults != null && defaults.contains(permission);
    }

    /**
     * @description Returns the default permissions for a given role.
     */
    public static List<String> getDefaultPermissionsForRole(String role) {
        return ROLE_DEFAULTS.containsKey(role) ? ROLE_DEFAULTS.get(role) : new List<String>();
    }

    /**
     * @description Returns all permissions for a portal user (from PermissionsTxt__c or role defaults).
     */
    public static List<String> getPermissions(String email, Id entityId) {
        if (String.isBlank(email) || entityId == null) {
            return new List<String>();
        }
        List<PortalAccess__c> accesses = [
            SELECT RolePk__c, PermissionsTxt__c
            FROM PortalAccess__c
            WHERE EmailTxt__c = :email
            AND NetworkEntityLookup__c = :entityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (accesses.isEmpty()) {
            return new List<String>();
        }
        PortalAccess__c access = accesses[0];
        if (String.isNotBlank(access.PermissionsTxt__c)) {
            List<String> perms = new List<String>();
            for (Object p : (List<Object>) JSON.deserializeUntyped(access.PermissionsTxt__c)) {
                perms.add((String) p);
            }
            return perms;
        }
        return getDefaultPermissionsForRole(access.RolePk__c);
    }
}
