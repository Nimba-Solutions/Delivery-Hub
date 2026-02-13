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
        
        // Get Endpoint from Custom Metadata
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        if (config != null && String.isNotBlank(config.CloudNimbusLlcEndpointTxt__c)) {
            status.requiredRemoteSite = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/');
        } else {
            status.requiredRemoteSite = ''; 
        }

        // Check for existing entity (Display purposes only)
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
     * @description Initiates handshake. Prevents duplicates by checking IDs only.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation')
    @AuraEnabled
    public static void connectToDefaultMothership() {
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        if (config == null || String.isBlank(config.CloudNimbusLlcEndpointTxt__c)) {
            throw new AuraHandledException('Metadata Error: Endpoint not configured.');
        }

        String mothershipBase = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/');
        String intakeEndpoint = mothershipBase + '/intake';
        
        Map<String, Object> packet = new Map<String, Object>{
            'companyName' => UserInfo.getOrganizationName(),
            'orgId' => UserInfo.getOrganizationId(),
            'instanceUrl' => Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/deliveryhub/v1',
            'registeredBy' => UserInfo.getName(),
            'title' => 'New Org Connection'
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
        String remoteTicketId = (String) responseMap.get('ticketId');
        String remoteEntityId = (String) responseMap.get('entityId');
        String remoteOrgId = (String) responseMap.get('orgId');

        // --- 1. STRICT ID MATCHING ---
        // Match on Org ID OR the Remote Record ID. Do NOT match by Name.
        List<Network_Entity__c> existingEntities = [
            SELECT Id, OrgIdTxt__c, RemoteExternalIdTxt__c 
            FROM Network_Entity__c 
            WHERE (OrgIdTxt__c != null AND OrgIdTxt__c = :remoteOrgId)
               OR (RemoteExternalIdTxt__c != null AND RemoteExternalIdTxt__c = :remoteEntityId)
            LIMIT 1
        ];

        Network_Entity__c mothership;
        if (!existingEntities.isEmpty()) {
            mothership = existingEntities[0];
        } else {
            mothership = new Network_Entity__c();
            mothership.Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)';
            mothership.EntityTypePk__c = 'Vendor';
        }

        // Update Fields
        mothership.OrgIdTxt__c = remoteOrgId;
        mothership.StatusPk__c = 'Active';
        mothership.IntegrationEndpointUrlTxt__c = mothershipBase;
        mothership.RemoteExternalIdTxt__c = remoteEntityId;
        
        // Save using upsert/update (Safer than upsert on non-unique fields)
        Database.upsert(mothership, AccessLevel.SYSTEM_MODE);

        initializeDefaultSettings();

        // --- 2. TICKET CREATION ---

        Ticket__c newTicket = new Ticket__c(
            BriefDescriptionTxt__c = 'Connection Established Successfully.',
            StageNamePk__c = 'Backlog'
        );
        Database.insert(newTicket, AccessLevel.SYSTEM_MODE);

        Request__c newReq = new Request__c(
            TicketId__c = newTicket.Id,           
            DeliveryEntityId__c = mothership.Id,  
            RemoteTicketIdTxt__c = remoteTicketId, 
            StatusPk__c = 'Open for Bids'
        );
        Database.insert(newReq, AccessLevel.SYSTEM_MODE);

        
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