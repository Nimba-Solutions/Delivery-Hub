/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Service class for multi-tenant portal access control.
 * Validates that a portal user (identified by email) has PortalAccess__c
 * to a given NetworkEntity__c, and returns the list of entities they can access.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryPortalAccessService {

    /**
     * @description Returns the list of NetworkEntities that the given email has access to,
     * along with each entity's name and the user's role.
     * @param email The portal user's email address
     * @return List of maps with keys: id, name, role
     */
    public static List<Map<String, Object>> getEntitiesForEmail(String email) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        if (String.isBlank(email)) {
            return results;
        }

        for (PortalAccess__c pa : [
            SELECT NetworkEntityId__c, NetworkEntityId__r.Name, RolePk__c
            FROM PortalAccess__c
            WHERE EmailTxt__c = :email
            WITH SYSTEM_MODE
            ORDER BY NetworkEntityId__r.Name ASC
        ]) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('id', pa.NetworkEntityId__c);
            entry.put('name', pa.NetworkEntityId__r.Name);
            entry.put('role', pa.RolePk__c);
            results.add(entry);
        }

        return results;
    }

    /**
     * @description Returns all portal users grouped by entity, for entities
     * that the requesting admin email has Admin access to.
     * @param adminEmail The admin user's email address
     * @return List of maps with keys: entityId, entityName, users (list of {email, role})
     */
    public static List<Map<String, Object>> getPortalUsersByEntity(String adminEmail) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        if (String.isBlank(adminEmail)) {
            return results;
        }

        // Get entity IDs where this user is Admin
        Set<Id> adminEntityIds = new Set<Id>();
        for (PortalAccess__c pa : [
            SELECT NetworkEntityId__c
            FROM PortalAccess__c
            WHERE EmailTxt__c = :adminEmail
            AND RolePk__c = 'Admin'
            WITH SYSTEM_MODE
        ]) {
            adminEntityIds.add(pa.NetworkEntityId__c);
        }

        if (adminEntityIds.isEmpty()) {
            return results;
        }

        // Get all users for those entities, grouped by entity
        Map<Id, Map<String, Object>> entityMap = new Map<Id, Map<String, Object>>();
        for (PortalAccess__c pa : [
            SELECT NetworkEntityId__c, NetworkEntityId__r.Name, EmailTxt__c, RolePk__c
            FROM PortalAccess__c
            WHERE NetworkEntityId__c IN :adminEntityIds
            WITH SYSTEM_MODE
            ORDER BY NetworkEntityId__r.Name ASC, EmailTxt__c ASC
        ]) {
            if (!entityMap.containsKey(pa.NetworkEntityId__c)) {
                Map<String, Object> entry = new Map<String, Object>();
                entry.put('entityId', pa.NetworkEntityId__c);
                entry.put('entityName', pa.NetworkEntityId__r.Name);
                entry.put('users', new List<Map<String, Object>>());
                entityMap.put(pa.NetworkEntityId__c, entry);
            }
            List<Map<String, Object>> users = (List<Map<String, Object>>) entityMap.get(pa.NetworkEntityId__c).get('users');
            Map<String, Object> user = new Map<String, Object>();
            user.put('email', pa.EmailTxt__c);
            user.put('role', pa.RolePk__c);
            users.add(user);
        }

        results.addAll(entityMap.values());
        return results;
    }

    /**
     * @description Validates that the given email has a PortalAccess__c record
     * for the specified NetworkEntity__c.
     * @param email The portal user's email address
     * @param networkEntityId The NetworkEntity__c Id to check access for
     * @return true if the email has access to the entity, false otherwise
     */
    public static Boolean validateAccess(String email, Id networkEntityId) {
        if (String.isBlank(email) || networkEntityId == null) {
            return false;
        }

        Integer count = [
            SELECT COUNT()
            FROM PortalAccess__c
            WHERE EmailTxt__c = :email
            AND NetworkEntityId__c = :networkEntityId
            WITH SYSTEM_MODE
        ];

        return count > 0;
    }
}
