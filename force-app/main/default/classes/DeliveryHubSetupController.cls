/**
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial handshake with the Mothership and manages connection status.
 */
@SuppressWarnings('PMD.ApexSharingViolations')
public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

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

    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
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

    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation')
    @AuraEnabled
    public static void performHandshake(Id localEntityId) {
        if (localEntityId == null) {
            throw new AuraHandledException('Setup Error: Local Entity ID missing.');
        }

        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
<<<<<<< HEAD
        String intakeEndpoint = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/') + '/sync/Network_Entity__c';

        Map<String, Object> packet = new Map<String, Object>{
            'SourceId' => localEntityId, 
            'Name' => UserInfo.getOrganizationName(), 
=======
        
        String intakeEndpoint = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/') + '/sync/Network_Entity__c';

        // --- FIX: Construct Packet using standard Ingestor formatting ---
        Map<String, Object> packet = new Map<String, Object>{
            'SourceId' => localEntityId, // Required by Ingestor
            'Name' => UserInfo.getOrganizationName(), // Standard Field
>>>>>>> 81a01aa12810e94d7ae4a5251a15c2176655fee0
            'OrgIdTxt__c' => UserInfo.getOrganizationId(),
            'IntegrationEndpointUrlTxt__c' => Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/sync',
            'EntityTypePk__c' => 'Client',
            'StatusPk__c' => 'Active'
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
            throw new AuraHandledException('Connection Failed (' + res.getStatusCode() + '): ' + res.getBody());
        }

<<<<<<< HEAD
        // --- NEW BEHAVIOR: We no longer expect synchronous IDs in the response. 
        // We just verify it was successful, initialize settings, and create the Ticket. ---

        initializeDefaultSettings();
        
=======
        // 1. EXTRACT DATA FROM RESPONSE
        // Because the Vendor uses the generic Ingestor now, it just returns {"status":"Success"}.
        // It DOES NOT return the remoteTicketId anymore! We must generate a generic Ticket.
        
        // 2. CREATE LOCAL TICKET & REQUEST (The Ledger Bridge)
        // Since we don't have the Vendor's Ticket ID yet, we leave it blank. 
        // The Vendor will receive the new Ticket we create below via the standard SyncEngine!
>>>>>>> 81a01aa12810e94d7ae4a5251a15c2176655fee0
        List<Ticket__c> existingTickets = [
            SELECT Id FROM Ticket__c 
            WHERE BriefDescriptionTxt__c = 'Connection Established Successfully.' 
            LIMIT 1
        ];

        if (existingTickets.isEmpty()) {
            Ticket__c newTicket = new Ticket__c(
                BriefDescriptionTxt__c = 'Connection Established Successfully.',
                StageNamePk__c = 'Backlog'
            );
            
<<<<<<< HEAD
            insert newTicket;

=======
            // We DO NOT disable the trigger here anymore! 
            // We WANT the SyncEngine to fire and push this Ticket to the Vendor.
            insert newTicket;

            // 3. CREATE REQUEST BRIDGE
>>>>>>> 81a01aa12810e94d7ae4a5251a15c2176655fee0
            Request__c newRequest = new Request__c(
                TicketId__c = newTicket.Id,
                DeliveryEntityId__c = localEntityId, 
                StatusPk__c = 'Active'
<<<<<<< HEAD
=======
                // RemoteTicketIdTxt__c is left blank. The Vendor will receive the ticket, 
                // insert it, and send an update back with its ID later.
>>>>>>> 81a01aa12810e94d7ae4a5251a15c2176655fee0
            );
            insert newRequest;
        }

<<<<<<< HEAD
=======
        initializeDefaultSettings();
>>>>>>> 81a01aa12810e94d7ae4a5251a15c2176655fee0
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