public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public Network_Entity__c entity;
    }

    // Helper: Detect Namespace Prefix (e.g., 'delivery__')
    private static String getNamespace() {
        String ns = [SELECT NamespacePrefix FROM Organization].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        status.requiredRemoteSite = 'https://orgfarm-928a77dfd6-dev-ed.develop.my.salesforce-sites.com';

        String ns = getNamespace();
        // FIX: Dynamic SOQL to handle namespaced environments
        String query = 'SELECT Id, Name, ' + ns + 'StatusPk__c, ' + ns + 'IntegrationEndpointUrlTxt__c ' +
                       'FROM ' + ns + 'Network_Entity__c ' +
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

        // 1. CONSTRUCT PACKET
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

        // 2. SEND TO MOTHERSHIP
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

        // 3. SAVE LOCAL RECORDS
        String ns = getNamespace();
        
        // A. Create/Update Vendor Entity (Dynamic SOQL)
        String entityQuery = 'SELECT Id, ' + ns + 'RemoteExternalIdTxt__c ' +
                             'FROM ' + ns + 'Network_Entity__c ' +
                             'WHERE Name = \'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)\' ' +
                             'LIMIT 1';
        
        List<SObject> existing = Database.query(entityQuery);
        Network_Entity__c mothership;
        
        if (existing.isEmpty()) {
            mothership = new Network_Entity__c();
            mothership.Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)';
            mothership.put(ns + 'StatusPk__c', 'Active');
            mothership.put(ns + 'EntityTypePk__c', 'Vendor');
            mothership.put(ns + 'IntegrationEndpointUrlTxt__c', mothershipBase);
            mothership.put(ns + 'RemoteExternalIdTxt__c', remoteEntityId);
            
            if (Schema.sObjectType.Network_Entity__c.isCreateable()) {
                insert mothership;
            }
        } else {
            mothership = (Network_Entity__c)existing[0];
            String currentRemoteId = (String) mothership.get(ns + 'RemoteExternalIdTxt__c');
            
            if (currentRemoteId != remoteEntityId) {
                 mothership.put(ns + 'RemoteExternalIdTxt__c', remoteEntityId);
                 if (Schema.sObjectType.Network_Entity__c.isUpdateable()) {
                     update mothership;
                 }
            }
        }

        // B. Initialize Settings
        initializeDefaultSettings();

        // C. Create Local Ticket (Using Dynamic Fields to be safe)
        Ticket__c regTicket = new Ticket__c();
        regTicket.put(ns + 'WorkItemNameTxt__c', 'New Org Connection');
        regTicket.put(ns + 'BriefDescriptionTxt__c', 'Connection Established Successfully.');
        regTicket.put(ns + 'StageNamePk__c', 'Backlog');
        regTicket.put(ns + 'PriorityPk__c', 'High');

        if (Schema.sObjectType.Ticket__c.isCreateable()) {
            insert regTicket;
        }

        // D. Create Request (Link Ticket to Mothership)
        Request__c regRequest = new Request__c();
        regRequest.put(ns + 'TicketId__c', regTicket.Id);
        regRequest.put(ns + 'DeliveryEntityId__c', mothership.Id);
        regRequest.put(ns + 'RemoteTicketIdTxt__c', remoteTicketId);
        regRequest.put(ns + 'StatusPk__c', 'Open');

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
            if (Schema.sObjectType.Delivery_Hub_Settings__c.isCreateable()) {
                insert settings;
            }
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