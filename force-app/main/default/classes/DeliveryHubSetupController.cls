/**
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial "Handshake" to connect this org to the Mothership via Custom Metadata.
 */
public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    /**
     * @description Checks if the org is already connected and returns the required Remote Site URL from Metadata.
     */
    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        
        // 1. Fetch Configuration from Custom Metadata
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        // 2. Determine Required Remote Site (Base Domain only)
        if (config != null && String.isNotBlank(config.Cloud_Nimbus_LLC_Endpoint__c)) {
            try {
                System.Url endpointUrl = new System.Url(config.Cloud_Nimbus_LLC_Endpoint__c);
                status.requiredRemoteSite = endpointUrl.getProtocol() + '://' + endpointUrl.getHost();
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Invalid Metadata URL: ' + e.getMessage());
                status.requiredRemoteSite = 'Invalid URL in Custom Metadata';
            }
        } else {
            status.requiredRemoteSite = 'Missing Metadata Configuration';
        }

        // 3. Check if we already have the Mothership Entity created locally
        // We use 'WITH SYSTEM_MODE' or standard query since we are in "without sharing" to see system records.
        List<Network_Entity__c> entities = [
            SELECT Id, Name, StatusPk__c, IntegrationEndpointUrlTxt__c 
            FROM Network_Entity__c 
            WHERE Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)' 
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
     * @description Initiates the handshake. Sends a registration packet to the Mothership defined in Metadata.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static void connectToDefaultMothership() {
        // 1. Get Endpoint from Metadata
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        if (config == null || String.isBlank(config.Cloud_Nimbus_LLC_Endpoint__c)) {
            throw new AuraHandledException('Configuration Error: Cloud Nimbus LLC Marketing Metadata is missing or the Endpoint is blank.');
        }

        String mothershipBase = config.Cloud_Nimbus_LLC_Endpoint__c;
        // Ensure no double slashes if the metadata has one
        if (mothershipBase.endsWith('/')) {
            mothershipBase = mothershipBase.removeEnd('/');
        }
        
        String intakeEndpoint = mothershipBase + '/intake';
        
        // 2. Build the Registration Packet
        String myUrl = Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/deliveryhub/v1';
        String myOrgId = UserInfo.getOrganizationId();
        String myName = UserInfo.getOrganizationName();

        Map<String, Object> packet = new Map<String, Object>();
        packet.put('companyName', myName); 
        packet.put('orgId', myOrgId);       
        packet.put('instanceUrl', myUrl);   
        packet.put('registeredBy', UserInfo.getName());
        packet.put('title', 'New Org Connection');
        packet.put('briefSummary', 'Initial connection established from ' + myName);
        packet.put('detailedContent', 'Automatic registration via Delivery Hub Setup.\n\nOrg ID: ' + myOrgId + '\nCallback URL: ' + myUrl);
        packet.put('type', 'Task');
        packet.put('priority', 'High');

        // 3. Send Request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(intakeEndpoint); 
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(packet));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 400) {
            throw new AuraHandledException('Connection Failed (' + res.getStatusCode() + '): ' + res.getBody());
        }

        // 4. Parse Response
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String remoteTicketId = (String) responseMap.get('ticketId');
        String remoteEntityId = (String) responseMap.get('entityId'); 

        // 5. Create or Update Local Mothership Entity
        List<Network_Entity__c> existing = [
            SELECT Id, RemoteExternalIdTxt__c 
            FROM Network_Entity__c 
            WHERE Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)' 
            LIMIT 1
        ];
        
        Network_Entity__c mothership;
        
        if (existing.isEmpty()) {
            mothership = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = mothershipBase,
                RemoteExternalIdTxt__c = remoteEntityId
            );
            insert mothership;
        } else {
            mothership = existing[0];
            // Ensure endpoint and ID are up to date
            mothership.IntegrationEndpointUrlTxt__c = mothershipBase;
            if (mothership.RemoteExternalIdTxt__c != remoteEntityId) {
                 mothership.RemoteExternalIdTxt__c = remoteEntityId;
            }
            update mothership;
        }

        // 6. Initialize Settings & Sync Jobs
        initializeDefaultSettings();

        // 7. Create Confirmation Ticket & Link Request
        Ticket__c regTicket = new Ticket__c(
            WorkItemNameTxt__c = 'New Org Connection',
            BriefDescriptionTxt__c = 'Connection Established Successfully.',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'High'
        );
        insert regTicket;

        Request__c regRequest = new Request__c(
            TicketId__c = regTicket.Id,           
            DeliveryEntityId__c = mothership.Id,  
            RemoteTicketIdTxt__c = remoteTicketId, 
            StatusPk__c = 'Open'
        );
        insert regRequest;
        
        scheduleSyncJobs();
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void initializeDefaultSettings() {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new Delivery_Hub_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
            settings.EnableNotificationsBool__c = true;
            settings.AutoCreateRequestFromTicketBool__c = true; 
            settings.AutoSyncNetworkEntityBool__c = true;       
            settings.AISuggestionsEnabledBool__c = true; 
            settings.AutoGenerateDescriptionsBool__c = true;
            settings.AIEstimationEnabledBool__c = true;
            settings.StagesToAutoShareWithDevTeamTxt__c = 'All';
            insert settings;
        }
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void scheduleSyncJobs() {
        Integer jobCount = [SELECT Count() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync%'];
        if (jobCount == 0) {
            System.schedule('Delivery Hub Sync - :00', '0 0 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :15', '0 15 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :30', '0 30 * * * ?', new DeliveryHubScheduler());
            System.schedule('Delivery Hub Sync - :45', '0 45 * * * ?', new DeliveryHubScheduler());
        }
    }
}