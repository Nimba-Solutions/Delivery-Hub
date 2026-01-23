/**
 * @description Controller for the Delivery Hub Setup Wizard.
 * Allows any org to instantly configure itself as a Client Node in the Delivery Network.
 */
public with sharing class DeliveryHubSetupController {

    // MARKETING CONFIGURATION:
    // This is the default endpoint for your campaign.
    // Anyone who clicks "Connect" will point to YOU.
    private static final String DEFAULT_MOTHERSHIP_URL = 'https://orgfarm-8e4cff452b-dev-ed.develop.my.salesforce-sites.com/services/apexrest/deliveryhub/v1/intake/';
    private static final String ENTITY_NAME = 'Nimba Solutions (Dev Team)';

    /**
     * @description Checks if the org is already connected to a Mothership.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSetupStatus() {
        Map<String, Object> result = new Map<String, Object>();
        
        // Check for ANY active vendor connection
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
        
        // Helper for the UI to show the user what Remote Site they need
        // Note: We strip the path to just get the domain
        result.put('requiredRemoteSite', 'https://orgfarm-8e4cff452b-dev-ed.develop.my.salesforce-sites.com');
        
        return result;
    }

    /**
     * @description One-click configuration. Creates the Network Entity pointing to Nimba.
     */
    @AuraEnabled
    public static String connectToDefaultMothership() {
        try {
            // 1. Duplicate Check
            List<Network_Entity__c> existing = [
                SELECT Id FROM Network_Entity__c 
                WHERE IntegrationEndpointUrlTxt__c = :DEFAULT_MOTHERSHIP_URL 
                LIMIT 1
            ];
            
            if (!existing.isEmpty()) {
                return existing[0].Id;
            }

            // 2. Create the Node Connection
            Network_Entity__c entity = new Network_Entity__c(
                Name = ENTITY_NAME,
                EntityTypePk__c = 'Vendor',
                StatusPk__c = 'Active',
                IntegrationEndpointUrlTxt__c = DEFAULT_MOTHERSHIP_URL
            );
            
            // Check for CRUD/FLS permissions
            if (Schema.sObjectType.Network_Entity__c.isCreateable()) {
                insert entity;
                return entity.Id;
            } else {
                throw new AuraHandledException('Insufficient permissions to create Network Entity.');
            }

        } catch (Exception e) {
            throw new AuraHandledException('Setup Failed: ' + e.getMessage());
        }
    }
}