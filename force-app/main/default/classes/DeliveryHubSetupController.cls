public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        status.requiredRemoteSite = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com';

        // 1. GET SAFE NAMES FROM SCHEMA
        String tableName = Schema.SObjectType.Network_Entity__c.getName();
        String statusField = Schema.SObjectType.Network_Entity__c.fields.StatusPk__c.getName();
        String urlField = Schema.SObjectType.Network_Entity__c.fields.IntegrationEndpointUrlTxt__c.getName();
        
        // 2. BUILD DYNAMIC QUERY
        String query = 'SELECT Id, Name, ' + statusField + ', ' + urlField + ' ' +
                       'FROM ' + tableName + ' ' +
                       'WHERE Name = \'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)\' ' +
                       'WITH USER_MODE ' +
                       'LIMIT 1';

        List<SObject> entities = Database.query(query);

        if (!entities.isEmpty()) {
            status.isConnected = true;
            status.entity = (Network_Entity__c)entities[0];
        } else {
            status.isConnected = false;
        }
        return status;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexSOQLInjection')
    @AuraEnabled
    public static void connectToDefaultMothership() {
        String mothershipBase = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com/services/apexrest/delivery/deliveryhub/v1';
        String intakeEndpoint = mothershipBase + '/intake';
        
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

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String remoteTicketId = (String) responseMap.get('ticketId');
        String remoteEntityId = (String) responseMap.get('entityId'); 

        // 3. GET SAFE NAMES FOR DML/QUERY
        String tableName = Schema.SObjectType.Network_Entity__c.getName();
        String remoteIdField = Schema.SObjectType.Network_Entity__c.fields.RemoteExternalIdTxt__c.getName();
        String statusField = Schema.SObjectType.Network_Entity__c.fields.StatusPk__c.getName();
        String typeField = Schema.SObjectType.Network_Entity__c.fields.EntityTypePk__c.getName();
        String urlField = Schema.SObjectType.Network_Entity__c.fields.IntegrationEndpointUrlTxt__c.getName();

        String entityQuery = 'SELECT Id, ' + remoteIdField + ' ' +
                             'FROM ' + tableName + ' ' +
                             'WHERE Name = \'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)\' ' +
                             'LIMIT 1';
        
        List<SObject> existing = Database.query(entityQuery);
        Network_Entity__c mothership;
        
        if (existing.isEmpty()) {
            mothership = new Network_Entity__c();
            mothership.Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)';
            
            // USE SAFE NAMES IN .put()
            mothership.put(statusField, 'Active');
            mothership.put(typeField, 'Vendor');
            mothership.put(urlField, mothershipBase);
            mothership.put(remoteIdField, remoteEntityId);
            
            insert mothership;
        } else {
            mothership = (Network_Entity__c)existing[0];
            String currentRemoteId = (String) mothership.get(remoteIdField);
            
            if (currentRemoteId != remoteEntityId) {
                 mothership.put(remoteIdField, remoteEntityId);
                 update mothership;
            }
        }

        initializeDefaultSettings();

        // 4. SAFE NAMES FOR TICKET
        String tName = Schema.SObjectType.Ticket__c.fields.WorkItemNameTxt__c.getName();
        String tDesc = Schema.SObjectType.Ticket__c.fields.BriefDescriptionTxt__c.getName();
        String tStage = Schema.SObjectType.Ticket__c.fields.StageNamePk__c.getName();
        String tPriority = Schema.SObjectType.Ticket__c.fields.PriorityPk__c.getName();

        Ticket__c regTicket = new Ticket__c();
        regTicket.put(tName, 'New Org Connection');
        regTicket.put(tDesc, 'Connection Established Successfully.');
        regTicket.put(tStage, 'Backlog');
        regTicket.put(tPriority, 'High');
        insert regTicket;

        // 5. SAFE NAMES FOR REQUEST
        String rTicketId = Schema.SObjectType.Request__c.fields.TicketId__c.getName();
        String rEntityId = Schema.SObjectType.Request__c.fields.DeliveryEntityId__c.getName();
        String rRemoteId = Schema.SObjectType.Request__c.fields.RemoteTicketIdTxt__c.getName();
        String rStatus = Schema.SObjectType.Request__c.fields.StatusPk__c.getName();

        Request__c regRequest = new Request__c();
        regRequest.put(rTicketId, regTicket.Id);
        regRequest.put(rEntityId, mothership.Id);
        regRequest.put(rRemoteId, remoteTicketId);
        regRequest.put(rStatus, 'Open');
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