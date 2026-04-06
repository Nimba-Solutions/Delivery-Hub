/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Data Lineage LWC. Queries NetworkEntity__c
 *               records and SyncItem__c health metrics to build a visual
 *               representation of the sync chain.
 * @author Cloud Nimbus LLC
 */
global with sharing class DeliveryDataLineageController {

    /**
     * @description Returns all active NetworkEntity records with sync health metrics
     *              and the local org identity for the lineage visualization.
     * @return Map containing localOrgName, localOrgId, and entities list.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getNetworkEntities() {
        Map<String, Object> result = new Map<String, Object>();
        result.put('localOrgName', buildOrgDisplayName());
        result.put('localOrgId', UserInfo.getOrganizationId());

        List<NetworkEntity__c> entities = [
            SELECT Id, Name, EntityTypePk__c, StatusPk__c, ConnectionStatusPk__c,
                   IntegrationEndpointUrlTxt__c, OrgIdTxt__c, LastInboundSyncDateTime__c,
                   EnableVendorPushDateTime__c
            FROM NetworkEntity__c
            WHERE StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY EntityTypePk__c, Name
        ];

        // Get sync health per entity
        Map<Id, Map<String, Integer>> healthByEntity = getSyncHealthByEntity();

        List<Map<String, Object>> entityMaps = new List<Map<String, Object>>();
        for (NetworkEntity__c e : entities) {
            Map<String, Integer> health = healthByEntity.get(e.Id);
            Integer succeeded = health != null ? (health.containsKey('Synced') ? health.get('Synced') : 0) : 0;
            Integer failed = health != null ? (health.containsKey('Failed') ? health.get('Failed') : 0) : 0;
            Integer total = succeeded + failed;
            Integer healthPct = total > 0 ? (succeeded * 100) / total : null;

            String lastSync = e.LastInboundSyncDateTime__c != null
                ? e.LastInboundSyncDateTime__c.format('MMM d, h:mm a')
                : null;

            entityMaps.add(new Map<String, Object>{
                'id' => e.Id,
                'name' => e.Name,
                'entityType' => e.EntityTypePk__c,
                'connectionStatus' => e.ConnectionStatusPk__c,
                'endpoint' => e.IntegrationEndpointUrlTxt__c,
                'orgId' => e.OrgIdTxt__c,
                'vendorPush' => e.EnableVendorPushDateTime__c,
                'healthPct' => healthPct,
                'syncedCount' => succeeded,
                'failedCount' => failed,
                'lastSync' => lastSync
            });
        }

        result.put('entities', entityMaps);
        return result;
    }

    /**
     * @description Returns sync health summary grouped by WorkItem's ClientNetworkEntityId.
     * @return Map of entity health with synced/failed counts.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getSyncHealth() {
        Map<Id, Map<String, Integer>> healthByEntity = getSyncHealthByEntity();
        Map<String, Object> result = new Map<String, Object>();
        for (Id entityId : healthByEntity.keySet()) {
            result.put(String.valueOf(entityId), healthByEntity.get(entityId));
        }
        return result;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Map<Id, Map<String, Integer>> getSyncHealthByEntity() {
        Map<Id, Map<String, Integer>> healthMap = new Map<Id, Map<String, Integer>>();

        for (AggregateResult ar : [
            SELECT WorkItemId__r.ClientNetworkEntityId__c entityId,
                   StatusPk__c status, COUNT(Id) cnt
            FROM SyncItem__c
            WHERE WorkItemId__r.ClientNetworkEntityId__c != null
            GROUP BY WorkItemId__r.ClientNetworkEntityId__c, StatusPk__c
        ]) {
            Id entityId = (Id) ar.get('entityId');
            String status = (String) ar.get('status');
            Integer cnt = (Integer) ar.get('cnt');

            if (!healthMap.containsKey(entityId)) {
                healthMap.put(entityId, new Map<String, Integer>());
            }
            healthMap.get(entityId).put(status, cnt);
        }

        return healthMap;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static String buildOrgDisplayName() {
        List<Organization> orgs = [SELECT IsSandbox, Name FROM Organization LIMIT 1];
        if (orgs.isEmpty()) {
            return UserInfo.getOrganizationName();
        }
        return orgs[0].IsSandbox ? orgs[0].Name + ' (Sandbox)' : orgs[0].Name;
    }
}
