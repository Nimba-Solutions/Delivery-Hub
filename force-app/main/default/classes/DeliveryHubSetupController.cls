/**
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial handshake with the Mothership.
 */
@SuppressWarnings('PMD.ApexSharingViolations')
public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    /**
     * @description Checks connection status.
     */
    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        if (config != null && String.isNotBlank(config.CloudNimbusLlcEndpointTxt__c)) {
            status.requiredRemoteSite = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/');
        } else {
            status.requiredRemoteSite = ''; 
        }

        List<Network_Entity__c> entities = [
            SELECT Id, Name, StatusPk__c, IntegrationEndpointUrlTxt__c, OrgIdTxt__c 
            FROM Network_Entity__c 
            WHERE Name LIKE 'Cloud Nimbus LLC%' 
            LIMIT 1
        ];

        if (!entities.isEmpty()) {
            status.isConnected = true;
            status.entity = entities[0];
        } else {
            status.isConnected = false;
        }
        return status;
    }

    /**
     * STEP 1: Create or Retrieve the Local Entity record.
     * This MUST happen in its own transaction so the ID is committed 
     * before we attempt a callout in the next step.
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation') // Added to satisfy PMD
    public static Network_Entity__c prepareLocalEntity() {
        List<Network_Entity__c> existingEntities = [
            SELECT Id, Name FROM Network_Entity__c 
            WHERE Name LIKE 'Cloud Nimbus LLC%' 
            LIMIT 1
        ];

        Network_Entity__c mothership = !existingEntities.isEmpty() ? existingEntities[0] : new Network_Entity__c();
        
        if (mothership.Id == null) {
            mothership.Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)';
            mothership.EntityTypePk__c = 'Vendor';
        }
        
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        if (config != null && String.isNotBlank(config.CloudNimbusLlcEndpointTxt__c)) {
            mothership.IntegrationEndpointUrlTxt__c = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/');
        }

        mothership.StatusPk__c = 'Active';
        Database.upsert(mothership, AccessLevel.SYSTEM_MODE);
        
        return mothership;
    }

    /**
     * STEP 2: Perform the Handshake Callout.
     * Takes the ID from Step 1, sends it to Mothership, and processes the return.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation')
    @AuraEnabled
    public static void performHandshake(Id localEntityId) {
        if (localEntityId == null) {
            throw new AuraHandledException('Setup Error: Local Entity ID missing.');
        }

        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        String intakeEndpoint = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/') + '/intake';

        // Construct Packet - entityId is now definitely populated
        Map<String, Object> packet = new Map<String, Object>{
            'companyName' => UserInfo.getOrganizationName(),
            'orgId' => UserInfo.getOrganizationId(),
            'instanceUrl' => Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/deliveryhub/v1',
            'registeredBy' => UserInfo.getName(),
            'title' => 'New Org Connection',
            'briefSummary' => 'Connection Established Successfully.',
            'entityId' => localEntityId 
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(intakeEndpoint); 
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(packet));
        req.setTimeout(60000); 

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 400) {
            throw new AuraHandledException('Connection Failed: ' + res.getBody());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        
        // Update record with Mothership's returned IDs
        Network_Entity__c mothership = new Network_Entity__c(
            Id = localEntityId,
            OrgIdTxt__c = (String) responseMap.get('orgId'),
            RemoteExternalIdTxt__c = (String) responseMap.get('entityId')
        );
        update mothership;

        initializeDefaultSettings();
        
        // Only create the success ticket if this was a brand new connection
        // (Checking if we already had a remote ID before this update)
        List<Ticket__c> existingTickets = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Connection Established Successfully.' LIMIT 1];
        if (existingTickets.isEmpty()) {
            Ticket__c newTicket = new Ticket__c(
                BriefDescriptionTxt__c = 'Connection Established Successfully.',
                StageNamePk__c = 'Backlog'
            );
            
            Boolean originalState = TicketTriggerHandler.triggerDisabled;
            TicketTriggerHandler.triggerDisabled = true;
            try {
                insert newTicket;
            } finally {
                TicketTriggerHandler.triggerDisabled = originalState;
            }
        }
        
        scheduleSyncJobs();
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void initializeDefaultSettings() {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new Delivery_Hub_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                EnableNotificationsBool__c = true,
                AutoCreateRequestFromTicketBool__c = true,
                AutoSyncNetworkEntityBool__c = true,
                AISuggestionsEnabledBool__c = true,
                AutoGenerateDescriptionsBool__c = true,
                AIEstimationEnabledBool__c = true,
                StagesToAutoShareWithDevTeamTxt__c = 'All'
            );
            insert settings; 
        }
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void scheduleSyncJobs() {
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync%'];
        if (jobs.isEmpty()) {
            System.schedule('Delivery Hub Sync - :00', '0 0 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :15', '0 15 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :30', '0 30 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :45', '0 45 * * * ?', new DeliveryHubScheduler());
        }
    }
}