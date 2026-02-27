/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial handshake with the Mothership and manages connection status.
 * @author Cloud Nimbus LLC
 */
// without sharing: Required so any user (including Standard Users without sharing rules)
// can read/write NetworkEntity__c and DeliveryHubSettings__c during initial org setup.
@SuppressWarnings('PMD.ApexSharingViolations')
public without sharing class DeliveryHubSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public Boolean isMothership;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public NetworkEntity__c entity;
    }

    @AuraEnabled(cacheable=true)
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        CloudNimbusGlobalSettings__mdt config = CloudNimbusGlobalSettings__mdt.getInstance('Default');

        if (config != null && String.isNotBlank(config.EndpointUrlTxt__c)) {
            status.requiredRemoteSite = config.EndpointUrlTxt__c.removeEnd('/');
        } else {
            status.requiredRemoteSite = '';
        }

        // Dynamically detect if this org IS the mothership by comparing the
        // org's domain prefix against the configured endpoint URL.
        String orgHost = Url.getOrgDomainUrl().getHost();
        String orgPrefix = orgHost.split('\\.')[0];
        status.isMothership = String.isNotBlank(status.requiredRemoteSite) &&
                              status.requiredRemoteSite.contains(orgPrefix);

        List<NetworkEntity__c> entities = [
            SELECT Id, Name, StatusPk__c, IntegrationEndpointUrlTxt__c, OrgIdTxt__c
            FROM NetworkEntity__c
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
    public static NetworkEntity__c prepareLocalEntity() {
        List<NetworkEntity__c> existingEntities = [
            SELECT Id, Name FROM NetworkEntity__c 
            WHERE Name LIKE 'Cloud Nimbus LLC%' 
            LIMIT 1
        ];

        NetworkEntity__c mothership = !existingEntities.isEmpty() ? existingEntities[0] : new NetworkEntity__c();
        
        if (mothership.Id == null) {
            mothership.Name = 'Cloud Nimbus LLC';
            mothership.EntityTypePk__c = 'Vendor';
        }
        
        CloudNimbusGlobalSettings__mdt config = CloudNimbusGlobalSettings__mdt.getInstance('Default');
        if (config != null && String.isNotBlank(config.EndpointUrlTxt__c)) {
            mothership.IntegrationEndpointUrlTxt__c = config.EndpointUrlTxt__c.removeEnd('/');
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

        CloudNimbusGlobalSettings__mdt config = CloudNimbusGlobalSettings__mdt.getInstance('Default');
        String intakeEndpoint = config.EndpointUrlTxt__c.removeEnd('/') + '/sync/NetworkEntity__c';

        Map<String, Object> packet = new Map<String, Object>{
            'SourceId' => localEntityId,
            'RemoteExternalIdTxt__c' => localEntityId,
            'Name' => buildOrgDisplayName(),
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

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String remoteEntityId = (String) responseMap.get('processedId');
        String remoteOrgId = (String) responseMap.get('orgId');
        
        if (String.isNotBlank(remoteEntityId) || String.isNotBlank(remoteOrgId)) {
            NetworkEntity__c mothershipToUpdate = new NetworkEntity__c(
                Id = localEntityId,
                OrgIdTxt__c = remoteOrgId,
                RemoteExternalIdTxt__c = remoteEntityId
            );
            update mothershipToUpdate;
        }

        initializeDefaultSettings();
        
        List<WorkItem__c> existingWorkItems = [
            SELECT Id FROM WorkItem__c 
            WHERE BriefDescriptionTxt__c = 'Connection Established Successfully.' 
            LIMIT 1
        ];

        if (existingWorkItems.isEmpty()) {
            WorkItem__c newWorkItem = new WorkItem__c(
                BriefDescriptionTxt__c = 'Connection Established Successfully.',
                StageNamePk__c = 'Backlog'
            );
            
            insert newWorkItem;
        }

        scheduleSyncJobs();
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static String buildOrgDisplayName() {
        List<Organization> orgs = [SELECT IsSandbox FROM Organization LIMIT 1];
        String baseName = UserInfo.getOrganizationName();
        return (!orgs.isEmpty() && orgs[0].IsSandbox) ? baseName + ' (Sandbox)' : baseName;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void initializeDefaultSettings() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings.Id == null) {
            settings = new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                EnableNotificationsBool__c = true,
                AutoCreateWorkRequestBool__c = true,
                AutoSyncNetworkEntityBool__c = true,
                AISuggestionsEnabledBool__c = true,
                AutoGenerateDescriptionsBool__c = true,
                AIEstimationEnabledBool__c = true,
                EmailNotificationsEnabledBool__c = false,
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