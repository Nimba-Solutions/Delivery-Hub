/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Service class for multi-tenant portal access control.
 * Validates that a portal user (identified by email) has PortalAccess__c
 * to a given NetworkEntity__c, and returns the list of entities they can access.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
global without sharing class DeliveryPortalAccessService {

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
            SELECT NetworkEntityLookup__c, NetworkEntityLookup__r.Name, RolePk__c
            FROM PortalAccess__c
            WHERE EmailTxt__c = :email
            WITH SYSTEM_MODE
            ORDER BY NetworkEntityLookup__r.Name ASC
        ]) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('id', pa.NetworkEntityLookup__c);
            entry.put('name', pa.NetworkEntityLookup__r.Name);
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
            SELECT NetworkEntityLookup__c
            FROM PortalAccess__c
            WHERE EmailTxt__c = :adminEmail
            AND RolePk__c = 'Admin'
            WITH SYSTEM_MODE
        ]) {
            adminEntityIds.add(pa.NetworkEntityLookup__c);
        }

        if (adminEntityIds.isEmpty()) {
            return results;
        }

        // Get all users for those entities, grouped by entity
        Map<Id, Map<String, Object>> entityMap = new Map<Id, Map<String, Object>>();
        for (PortalAccess__c pa : [
            SELECT NetworkEntityLookup__c, NetworkEntityLookup__r.Name, EmailTxt__c, RolePk__c
            FROM PortalAccess__c
            WHERE NetworkEntityLookup__c IN :adminEntityIds
            WITH SYSTEM_MODE
            ORDER BY NetworkEntityLookup__r.Name ASC, EmailTxt__c ASC
        ]) {
            if (!entityMap.containsKey(pa.NetworkEntityLookup__c)) {
                Map<String, Object> entry = new Map<String, Object>();
                entry.put('entityId', pa.NetworkEntityLookup__c);
                entry.put('entityName', pa.NetworkEntityLookup__r.Name);
                entry.put('users', new List<Map<String, Object>>());
                entityMap.put(pa.NetworkEntityLookup__c, entry);
            }
            List<Map<String, Object>> users = (List<Map<String, Object>>) entityMap.get(pa.NetworkEntityLookup__c).get('users');
            Map<String, Object> user = new Map<String, Object>();
            user.put('email', pa.EmailTxt__c);
            user.put('role', pa.RolePk__c);
            users.add(user);
        }

        results.addAll(entityMap.values());
        return results;
    }

    /**
     * @description Auto-generates a portal access record with a random UUID-style
     *              token for a given entity and email. Used by the self-service
     *              onboarding flow to provision portal credentials.
     * @param entityId The NetworkEntity__c Id to grant access to.
     * @param email The portal user's email address.
     * @param role The portal role (Admin or Member). Defaults to Member if blank.
     * @return PortalAccess__c The created access record with the generated token.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity')
    @AuraEnabled
    global static PortalAccess__c generatePortalAccess(Id entityId, String email, String role) {
        if (entityId == null) {
            AuraHandledException ex = new AuraHandledException('Entity Id is required.');
            ex.setMessage('Entity Id is required.');
            throw ex;
        }
        if (String.isBlank(email)) {
            AuraHandledException ex = new AuraHandledException('Email is required.');
            ex.setMessage('Email is required.');
            throw ex;
        }

        // Verify entity exists
        List<NetworkEntity__c> entities = [
            SELECT Id FROM NetworkEntity__c
            WHERE Id = :entityId
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (entities.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('Network Entity not found.');
            ex.setMessage('Network Entity not found.');
            throw ex;
        }

        // Check for existing access to avoid duplicates
        List<PortalAccess__c> existing = [
            SELECT Id, AccessTokenTxt__c, RolePk__c
            FROM PortalAccess__c
            WHERE NetworkEntityLookup__c = :entityId
            AND EmailTxt__c = :email
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            // Update role and regenerate token if already exists
            PortalAccess__c pa = existing[0];
            pa.RolePk__c = String.isNotBlank(role) ? role : 'Member';
            pa.AccessTokenTxt__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
            Database.update(pa, AccessLevel.SYSTEM_MODE);
            return pa;
        }

        String token = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        PortalAccess__c pa = new PortalAccess__c(
            NetworkEntityLookup__c = entityId,
            EmailTxt__c = email,
            RolePk__c = String.isNotBlank(role) ? role : 'Member',
            AccessTokenTxt__c = token
        );
        Database.insert(pa, AccessLevel.SYSTEM_MODE);
        return pa;
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
            AND NetworkEntityLookup__c = :networkEntityId
            WITH SYSTEM_MODE
        ];

        return count > 0;
    }
}
