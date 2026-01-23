/**
 * @description Controller for the Delivery Hub Setup Wizard.
 */
public with sharing class DeliveryHubSetupController {

    private static final String DEFAULT_MOTHERSHIP_URL = 'https://orgfarm-8e4cff452b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/deliveryhub/v1/intake/';
    private static final String ENTITY_NAME = 'Nimba Solutions (Dev Team)';

    /**
     * @description Checks if the org is already connected to a Mothership.
     * @return Map<String, Object> Status map.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSetupStatus() {
        Map<String, Object> result = new Map<String, Object>();
        
        // REMOVED WITH USER_MODE to prevent package build failures
        List<Network_Entity__c> entities = [
            SELECT Id, Name, IntegrationEndpointUrlTxt__c, StatusPk__c 
            FROM Network_Entity__c 
            WHERE EntityTypePk__c = 'Vendor'
            AND StatusPk__c = 'Active'
            LIMIT 1
        ];

        if (!entities.isEmpty()) {
            result.put('isConnected', true);
            result.put('entity', entities[0]);
        } else {
            result.put('isConnected', false);
        }
        
        result.put('requiredRemoteSite', 'https://orgfarm-8e4cff452b-dev-ed.develop.my.salesforce-sites.com');
        return result;
    }

    /**
     * @description One-click configuration.
     * @return String The ID of the created Network_Entity__c.
     */
    @AuraEnabled
    public static String connectToDefaultMothership() {
        try {
            // REMOVED WITH USER_MODE to prevent package build failures
            List<Network_Entity__c> existing = [
                SELECT Id FROM Network_Entity__c 
                WHERE IntegrationEndpointUrlTxt__c = :DEFAULT_MOTHERSHIP_URL 
                LIMIT 1
            ];
            
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }

            Network_Entity__c entity = new Network_Entity__c(
                Name = ENTITY_NAME,
                EntityTypePk__c = 'Vendor',
                StatusPk__c = 'Active',
                IntegrationEndpointUrlTxt__c = DEFAULT_MOTHERSHIP_URL
            );
            
            // Explicitly allow insert in System Mode for setup
            insert entity;
            return entity.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Setup Failed: ' + e.getMessage());
        }
    }
}