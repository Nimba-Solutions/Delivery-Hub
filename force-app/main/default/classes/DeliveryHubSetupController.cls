public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        // NOTE: This URL must match the Site URL of the Mothership
        status.requiredRemoteSite = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com';

        List<Network_Entity__c> entities = [SELECT Id, Name, StatusPk__c, IntegrationEndpointUrlTxt__c FROM Network_Entity__c WHERE Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)' LIMIT 1];

        if (!entities.isEmpty()) {
            status.isConnected = true;
            status.entity = entities[0];
        } else {
            status.isConnected = false;
        }
        return status;
    }

    /**
     * @description Robust Connection: Sends a standard Ticket Packet that INCLUDES self-healing connection data.
     * Uses the standard Intake endpoint so the Mothership processes it exactly like any other ticket.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static void connectToDefaultMothership() {
        // 1. DEFINE ENDPOINTS
        // We append '/intake' because that is where DeliveryHubIntakeService lives
        String mothershipBase = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/delivery/deliveryhub/v1';
        String intakeEndpoint = mothershipBase + '/intake';
        
        String myUrl = Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/deliveryhub/v1';
        String myOrgId = UserInfo.getOrganizationId();
        String myName = UserInfo.getOrganizationName();

        // 2. CONSTRUCT THE "SELF-HEALING" PACKET
        // This matches the 'InboundPacket' class in the Mothership's IntakeService
        Map<String, Object> packet = new Map<String, Object>();
        
        // --- A. Connection Identity (The Self-Healing Parts) ---
        packet.put('companyName', myName); 
        packet.put('orgId', myOrgId);       
        packet.put('instanceUrl', myUrl);   
        packet.put('registeredBy', UserInfo.getName());

        // --- B. Ticket Content ---
        packet.put('title', 'New Org Connection');
        packet.put('briefSummary', 'Initial connection established from ' + myName);
        packet.put('detailedContent', 'Automatic registration via Delivery Hub Setup.\n\nOrg ID: ' + myOrgId + '\nCallback URL: ' + myUrl);
        packet.put('type', 'Task');
        packet.put('priority', 'High');

        // 3. SEND TO MOTHERSHIP (HTTP CALLOUT)
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

        // 4. PROCESS RESPONSE
        // The Mothership returns the new Ticket ID and the Entity ID
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String remoteTicketId = (String) responseMap.get('ticketId');
        
        // ---------------------------------------------------------
        // 5. SAVE LOCAL RECORDS (Mirroring what happened in Mothership)
        // ---------------------------------------------------------
        
        // A. Ensure Local "Vendor" Entity Exists
        List<Network_Entity__c> existing = [SELECT Id FROM Network_Entity__c WHERE Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)' LIMIT 1];
        Network_Entity__c mothership;
        
        if (existing.isEmpty()) {
            mothership = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = mothershipBase // Base URL for future calls
            );
            if (Schema.sObjectType.Network_Entity__c.isCreateable()) insert mothership;
        } else {
            mothership = existing[0];
        }

        // B. Initialize Settings
        initializeDefaultSettings();

        // C. Create Local Ticket (Parent)
        Ticket__c regTicket = new Ticket__c(
            WorkItemNameTxt__c = 'New Org Connection',
            BriefDescriptionTxt__c = 'Connection Established Successfully.',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'High'
        );

        if (Schema.sObjectType.Ticket__c.isCreateable()) {
            insert regTicket;
        }

        // D. Create Request (Child) - THE KEY LINK
        // This stores the Remote Ticket ID so we are linked immediately
        Request__c regRequest = new Request__c(
            TicketId__c = regTicket.Id,           
            DeliveryEntityId__c = mothership.Id,  
            RemoteTicketIdTxt__c = remoteTicketId, 
            StatusPk__c = 'Open'
        );

        if (Schema.sObjectType.Request__c.isCreateable()) {
            insert regRequest;
        }
        
        // E. Start Sync
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
            if (Schema.sObjectType.Delivery_Hub_Settings__c.isCreateable()) insert settings;
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