/**
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial "Handshake" to connect this org to the Mothership via Custom Metadata.
 * Refactored to prevent duplication using OrgIdTxt__c as a unique External ID.
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
                status.requiredRemoteSite = 'Invalid URL in Custom Metadata';
            }
        } else {
            status.requiredRemoteSite = 'Missing Metadata Configuration';
        }

        // 3. Check for Mothership Entity using Name or common identifiers
        // In a multi-vendor setup, we'd query by the specific Org ID of the Mothership
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
     * @description Initiates the handshake. Uses upsert on OrgIdTxt__c to prevent duplicates.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static void connectToDefaultMothership() {
        // 1. Get Endpoint from Metadata
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        
        if (config == null || String.isBlank(config.Cloud_Nimbus_LLC_Endpoint__c)) {
            throw new AuraHandledException('Metadata Error: Cloud Nimbus LLC Endpoint is not configured.');
        }

        String mothershipBase = config.Cloud_Nimbus_LLC_Endpoint__c.endsWith('/') 
            ? config.Cloud_Nimbus_LLC_Endpoint__c.removeEnd('/') 
            : config.Cloud_Nimbus_LLC_Endpoint__c;
        
        String intakeEndpoint = mothershipBase + '/intake';
        
        // 2. Build the Registration Packet
        String myUrl = Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/deliveryhub/v1';
        String myOrgId = UserInfo.getOrganizationId();
        String myName = UserInfo.getOrganizationName();

        Map<String, Object> packet = new Map<String, Object>{
            'companyName' => myName,
            'orgId' => myOrgId,
            'instanceUrl' => myUrl,
            'registeredBy' => UserInfo.getName(),
            'title' => 'New Org Connection',
            'type' => 'Task',
            'priority' => 'High'
        };

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
        String remoteEntityId = (String) responseMap.get('entityId'); // The ID the remote system assigned US
        String remoteOrgId = (String) responseMap.get('orgId');      // The actual Org ID of the Mothership

        // 5. UPSERT Mothership Entity using External ID (OrgIdTxt__c)
        // This ensures that even if the Name changes, we don't create a duplicate.
        Network_Entity__c mothership = new Network_Entity__c(
            OrgIdTxt__c = remoteOrgId, 
            Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = mothershipBase,
            RemoteExternalIdTxt__c = remoteEntityId
        );
        
        // Use the External ID field to handle the "Insert or Update" logic automatically
        upsert mothership OrgIdTxt__c;

        // 6. Initialize Settings & Sync Jobs
        initializeDefaultSettings();

        // 7. Prevent Duplicate Request/Ticket Links
        // We look for an existing connection for this specific "New Org Connection" title
        List<Ticket__c> existingTickets = [
            SELECT Id FROM Ticket__c 
            WHERE WorkItemNameTxt__c = 'New Org Connection' 
            ORDER BY CreatedDate DESC LIMIT 1
        ];

        Ticket__c regTicket;
        if (existingTickets.isEmpty()) {
            regTicket = new Ticket__c(
                WorkItemNameTxt__c = 'New Org Connection',
                BriefDescriptionTxt__c = 'Connection Established Successfully.',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'High'
            );
            insert regTicket;
        } else {
            regTicket = existingTickets[0];
        }

        // Link the Request ONLY if it doesn't already exist
        List<Request__c> existingReqs = [
            SELECT Id FROM Request__c 
            WHERE TicketId__c = :regTicket.Id 
            AND DeliveryEntityId__c = :mothership.Id 
            LIMIT 1
        ];

        if (existingReqs.isEmpty()) {
            Request__c regRequest = new Request__c(
                TicketId__c = regTicket.Id,           
                DeliveryEntityId__c = mothership.Id,  
                RemoteTicketIdTxt__c = remoteTicketId, 
                StatusPk__c = 'Open'
            );
            insert regRequest;
        }
        
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