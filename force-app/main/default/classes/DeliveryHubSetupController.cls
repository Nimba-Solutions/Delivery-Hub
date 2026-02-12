public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        status.requiredRemoteSite = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com';

        // REFACTOR: Use Static SOQL. The compiler handles the namespace automatically.
        // We use 'WITH USER_MODE' to satisfy security scanners if possible, or stripInaccessible if needed.
        // Since we are in 'without sharing', we can just run the query.
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
    public static void connectToDefaultMothership() {
        Cloud_Nimbus_LLC_Marketing__mdt config = Cloud_Nimbus_LLC_Marketing__mdt.getInstance('Cloud_Nimbus_LLC_Marketing_Enabled');
        if (config == null || String.isBlank(config.Cloud_Nimbus_LLC_Endpoint__c)) {
            throw new AuraHandledException('Metadata Error: Endpoint not configured.');
        }

        String mothershipBase = config.Cloud_Nimbus_LLC_Endpoint__c.removeEnd('/');
        String intakeEndpoint = mothershipBase + '/intake';
        
        // Build Packet
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

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 400) {
            throw new AuraHandledException('Connection Failed: ' + res.getBody());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String remoteTicketId = (String) responseMap.get('ticketId');
        String remoteEntityId = (String) responseMap.get('entityId');
        String remoteOrgId = (String) responseMap.get('orgId');

        // UPSERT Network Entity
        Network_Entity__c mothership = new Network_Entity__c(
            OrgIdTxt__c = remoteOrgId, 
            Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = mothershipBase,
            RemoteExternalIdTxt__c = remoteEntityId
        );
        upsert mothership OrgIdTxt__c;

        initializeDefaultSettings();

        // FIX: Scope handling for regTicket
        List<Ticket__c> existingTickets = [SELECT Id FROM Ticket__c WHERE WorkItemNameTxt__c = 'New Org Connection' LIMIT 1];
        Id finalTicketId;

        if (existingTickets.isEmpty()) {
            Ticket__c newTicket = new Ticket__c(
                WorkItemNameTxt__c = 'New Org Connection',
                BriefDescriptionTxt__c = 'Connection Established Successfully.',
                StageNamePk__c = 'Backlog'
            );
            insert newTicket;
            finalTicketId = newTicket.Id;
        } else {
            finalTicketId = existingTickets[0].Id;
        }

        // Link Request
        List<Request__c> existingReqs = [SELECT Id FROM Request__c WHERE TicketId__c = :finalTicketId AND DeliveryEntityId__c = :mothership.Id LIMIT 1];
        if (existingReqs.isEmpty()) {
            insert new Request__c(
                TicketId__c = finalTicketId,           
                DeliveryEntityId__c = mothership.Id,  
                RemoteTicketIdTxt__c = remoteTicketId, 
                StatusPk__c = 'Open'
            );
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