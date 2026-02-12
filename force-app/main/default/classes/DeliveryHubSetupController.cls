/**
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial handshake with the Mothership, upserts the Vendor entity,
 * and schedules the recurring synchronization jobs.
 */
public without sharing class DeliveryHubSetupController {

    /**
     * @description Wrapper class to communicate connection status to the LWC.
     */
    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    /**
     * @description Checks if a connection to the Mothership already exists.
     * @return SetupStatus containing connection details and the required Remote Site URL.
     */
    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        
        // This URL must be added to Remote Site Settings for callouts to work
        status.requiredRemoteSite = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com';

        // Look for an existing Vendor record that matches our primary partner
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
     * @description Initiates the POST request to the Mothership 'intake' endpoint.
     * Registers this Org and creates the local Request/Ticket bridge.
     */
    @AuraEnabled
    public static void connectToDefaultMothership() {
        // 1. LOAD CONFIGURATION
        // Fetches the endpoint from Custom Metadata to avoid hardcoding URLs
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        if (config == null || String.isBlank(config.CloudNimbusLlcEndpointTxt__c)) {
            throw new AuraHandledException('Configuration Missing: Please populate CloudNimbusLlcEndpointTxt__c in Custom Metadata.');
        }

        String mothershipBase = config.CloudNimbusLlcEndpointTxt__c.removeEnd('/');
        String intakeEndpoint = mothershipBase + '/intake';
        
        // 2. PREPARE HANDSHAKE PACKET
        // We send our Org ID and Instance URL so the Mothership knows where to send updates back
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

        // 3. EXECUTE CALLOUT
        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() >= 400) {
            throw new AuraHandledException('Mothership rejected connection: ' + res.getBody());
        }

        // 4. PROCESS RESPONSE
        // The Mothership returns IDs that we must store to maintain the link
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String remoteTicketId = (String) responseMap.get('ticketId');
        String remoteEntityId = (String) responseMap.get('entityId');
        String remoteOrgId = (String) responseMap.get('orgId');

        // 5. UPSERT VENDOR ENTITY
        // Uses OrgIdTxt__c as the external ID to prevent duplicate Vendor records
        Network_Entity__c mothership = new Network_Entity__c(
            OrgIdTxt__c = remoteOrgId, 
            Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = mothershipBase,
            RemoteExternalIdTxt__c = remoteEntityId
        );
        upsert mothership OrgIdTxt__c;

        // 6. INITIALIZE SETTINGS & DATA BRIDGE
        initializeDefaultSettings();

        // Create a 'Welcome Ticket' if one doesn't exist to represent the connection
        List<Ticket__c> existingTickets = [SELECT Id FROM Ticket__c WHERE WorkItemNameTxt__c = 'New Org Connection' LIMIT 1];
        Id finalTicketId;

        if (existingTickets.isEmpty()) {
            Ticket__c newTicket = new Ticket__c(
                WorkItemNameTxt__c = 'New Org Connection',
                BriefDescriptionTxt__c = 'Initial connection ticket created during setup.',
                StageNamePk__c = 'Backlog'
            );
            insert newTicket;
            finalTicketId = newTicket.Id;
        } else {
            finalTicketId = existingTickets[0].Id;
        }

        // Create the Request record which acts as the 'Mapping' between local and remote tickets
        List<Request__c> existingReqs = [SELECT Id FROM Request__c WHERE TicketId__c = :finalTicketId AND DeliveryEntityId__c = :mothership.Id LIMIT 1];
        if (existingReqs.isEmpty()) {
            insert new Request__c(
                TicketId__c = finalTicketId,           
                DeliveryEntityId__c = mothership.Id,  
                RemoteTicketIdTxt__c = remoteTicketId, 
                StatusPk__c = 'Open'
            );
        }
        
        // 7. FINALIZE
        scheduleSyncJobs();
    }

    /**
     * @description Sets default Org-Wide settings for the Delivery Hub.
     */
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

    /**
     * @description Schedules the sync poller to run every 15 minutes.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void scheduleSyncJobs() {
        // Only schedule if the jobs don't already exist to avoid 'Duplicate Job' errors
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync%'];
        if (jobs.isEmpty()) {
            System.schedule('Delivery Hub Sync - :00', '0 0 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :15', '0 15 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :30', '0 30 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :45', '0 45 * * * ?', new DeliveryHubScheduler());
        }
    }
}