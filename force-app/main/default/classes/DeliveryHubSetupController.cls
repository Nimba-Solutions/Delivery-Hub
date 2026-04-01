/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Hub Setup LWC.
 * Handles the initial handshake with the Mothership and manages connection status.
 * @author Cloud Nimbus LLC
 */
// without sharing: Required so any user (including Standard Users without sharing rules)
// can read/write NetworkEntity__c and DeliveryHubSettings__c during initial org setup.
@SuppressWarnings('PMD.ApexSharingViolations, PMD.CyclomaticComplexity')
global without sharing class DeliveryHubSetupController {

    /** @description DTO holding the org's Delivery Hub connection status for the setup LWC. */
    global class SetupStatus {
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public Boolean isMothership;
        @AuraEnabled public String requiredRemoteSite;
        @AuraEnabled public NetworkEntity__c entity;
    }

    /** @description DTO holding prerequisite check results for the setup wizard. */
    global class PrerequisiteStatus {
        @AuraEnabled public Boolean siteExists;
        @AuraEnabled public Boolean siteActive;
        @AuraEnabled public Boolean guestUserConfigured;
        @AuraEnabled public Boolean remoteSiteReachable;
        @AuraEnabled public String remoteSiteUrl;
        @AuraEnabled public String orgDomain;
        @AuraEnabled public String siteSetupUrl;
        @AuraEnabled public String remoteSiteSetupUrl;
        @AuraEnabled public Boolean allPassed;
    }

    /**
     * @description Retrieves the current Delivery Hub setup status including connection state,
     * mothership detection, and the required Remote Site URL.
     * @return SetupStatus containing connection info and the local NetworkEntity__c record if found
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static SetupStatus getSetupStatus() {
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

    /**
     * @description Creates or updates the local Cloud Nimbus LLC NetworkEntity__c record
     * with the endpoint URL from CloudNimbusGlobalSettings__mdt and sets it to Active.
     * @return NetworkEntity__c the upserted mothership entity record
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static NetworkEntity__c prepareLocalEntity() {
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

    /**
     * @description Performs the initial handshake with the Cloud Nimbus Mothership.
     * Sends the local org's identity to the vendor endpoint, stores the returned remote
     * entity ID, initializes default settings, and schedules recurring sync jobs.
     * @param localEntityId The Id of the local NetworkEntity__c representing the mothership
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred, PMD.ApexCRUDViolation')
    @AuraEnabled
    global static void performHandshake(Id localEntityId) {
        if (localEntityId == null) {
            throw new AuraHandledException('Setup Error: Local Entity ID missing.');
        }

        CloudNimbusGlobalSettings__mdt config = CloudNimbusGlobalSettings__mdt.getInstance('Default');
        String intakeEndpoint = config.EndpointUrlTxt__c.removeEnd('/') + '/sync/NetworkEntity__c';

        // Generate a shared API key for bidirectional authentication
        String sharedApiKey = EncodingUtil.convertToHex(Crypto.generateAesKey(256));

        Map<String, Object> packet = new Map<String, Object>{
            'SourceId' => localEntityId,
            'RemoteExternalIdTxt__c' => localEntityId,
            'Name' => buildOrgDisplayName(),
            'OrgIdTxt__c' => UserInfo.getOrganizationId(),
            'IntegrationEndpointUrlTxt__c' => Url.getOrgDomainUrl().toExternalForm() + '/services/apexrest/delivery/sync',
            'EntityTypePk__c' => 'Client',
            'StatusPk__c' => 'Active',
            'ApiKeyTxt__c' => sharedApiKey,
            'ConnectionStatusPk__c' => 'Connected'
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

        NetworkEntity__c mothershipToUpdate = new NetworkEntity__c(
            Id = localEntityId,
            ApiKeyTxt__c = sharedApiKey,
            ConnectionStatusPk__c = 'Connected'
        );
        if (String.isNotBlank(remoteEntityId)) {
            mothershipToUpdate.RemoteExternalIdTxt__c = remoteEntityId;
        }
        if (String.isNotBlank(remoteOrgId)) {
            mothershipToUpdate.OrgIdTxt__c = remoteOrgId;
        }
        update mothershipToUpdate;

        initializeDefaultSettings();
        configureGuestUserAccess();

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
            Datetime now = Datetime.now();
            settings = new DeliveryHubSettings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                EnableNotificationsDateTime__c = now,
                EnableAutoCreateWorkRequestDateTime__c = now,
                EnableAutoSyncNetworkEntityDateTime__c = now,
                EnableAISuggestionsDateTime__c = now,
                EnableAutoGenerateDescriptionsDateTime__c = now,
                EnableAIEstimationDateTime__c = now,
                EnableEmailNotificationsDateTime__c = now,
                EnableActivityLoggingDateTime__c = now,
                EnableFieldTrackingDateTime__c = now,
                EnableBoardMetricsDateTime__c = now,
                StagesToAutoShareWithDevTeamTxt__c = 'All'
            );
            insert settings;
        } else {
            // Ensure sync settings are enabled when handshake runs on existing orgs
            Boolean needsUpdate = false;
            if (settings.EnableAutoSyncNetworkEntityDateTime__c == null) {
                settings.EnableAutoSyncNetworkEntityDateTime__c = Datetime.now();
                needsUpdate = true;
            }
            if (settings.EnableAutoCreateWorkRequestDateTime__c == null) {
                settings.EnableAutoCreateWorkRequestDateTime__c = Datetime.now();
                needsUpdate = true;
            }
            if (needsUpdate) {
                update settings;
            }
        }
    }

    /**
     * @description Returns the count of NetworkEntity__c records with Pending Approval status.
     * @return Integer count of pending approval connections
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static Integer getPendingApprovalCount() {
        return [
            SELECT Count()
            FROM NetworkEntity__c
            WHERE ConnectionStatusPk__c = 'Pending Approval'
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Returns NetworkEntity__c records with Pending Approval status
     * so admins can review and approve/reject incoming connection requests.
     * @return List of NetworkEntity__c records pending approval
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static List<NetworkEntity__c> getPendingApprovals() {
        return [
            SELECT Id, Name, EntityTypePk__c, OrgIdTxt__c, IntegrationEndpointUrlTxt__c,
                   ConnectionStatusPk__c, CreatedDate
            FROM NetworkEntity__c
            WHERE ConnectionStatusPk__c = 'Pending Approval'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }

    /**
     * @description Approves a pending connection request by setting ConnectionStatusPk__c to Connected.
     * @param networkEntityId The Id of the NetworkEntity__c to approve
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static void approveConnection(Id networkEntityId) {
        if (networkEntityId == null) {
            throw new AuraHandledException('Network Entity ID is required.');
        }
        List<NetworkEntity__c> entities = [
            SELECT Id, ConnectionStatusPk__c
            FROM NetworkEntity__c
            WHERE Id = :networkEntityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (entities.isEmpty()) {
            throw new AuraHandledException('Network Entity not found.');
        }
        NetworkEntity__c entity = entities[0];
        if (entity.ConnectionStatusPk__c != 'Pending Approval') {
            throw new AuraHandledException('Only connections with Pending Approval status can be approved.');
        }
        entity.ConnectionStatusPk__c = 'Connected';
        Database.update(entity, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Rejects a pending connection request by setting ConnectionStatusPk__c to Disabled.
     * @param networkEntityId The Id of the NetworkEntity__c to reject
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static void rejectConnection(Id networkEntityId) {
        if (networkEntityId == null) {
            throw new AuraHandledException('Network Entity ID is required.');
        }
        List<NetworkEntity__c> entities = [
            SELECT Id, ConnectionStatusPk__c
            FROM NetworkEntity__c
            WHERE Id = :networkEntityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (entities.isEmpty()) {
            throw new AuraHandledException('Network Entity not found.');
        }
        NetworkEntity__c entity = entities[0];
        if (entity.ConnectionStatusPk__c != 'Pending Approval') {
            throw new AuraHandledException('Only connections with Pending Approval status can be rejected.');
        }
        entity.ConnectionStatusPk__c = 'Disabled';
        Database.update(entity, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Assigns the DeliveryHubGuestUser permission set to the Delivery Hub
     * Site's guest user for REST API access. Safe to call multiple times.
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static void configureGuestUserAccess() {
        try {
            List<Site> sites = [
                SELECT GuestUserId FROM Site
                WHERE Name = 'Delivery_Hub' AND Status = 'Active'
                WITH SYSTEM_MODE LIMIT 1
            ];
            if (sites.isEmpty() || sites[0].GuestUserId == null) {
                return;
            }
            Id guestUserId = sites[0].GuestUserId;

            String psName = 'DeliveryHubGuestUser';
            String nsPrefix = 'delivery__';
            List<PermissionSet> permSets = [
                SELECT Id FROM PermissionSet
                WHERE Name = :psName OR Name = :(nsPrefix + psName)
                WITH SYSTEM_MODE LIMIT 1
            ];
            if (permSets.isEmpty()) {
                return;
            }
            Id permSetId = permSets[0].Id;

            List<PermissionSetAssignment> existing = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :guestUserId AND PermissionSetId = :permSetId
                WITH SYSTEM_MODE LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return;
            }

            insert new PermissionSetAssignment(
                AssigneeId = guestUserId,
                PermissionSetId = permSetId
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Failed to auto-configure guest user access: ' + e.getMessage());
        }
    }

    private static void scheduleSyncJobs() {
        DeliveryHubScheduler.scheduleAll();
    }

    // ── Prerequisites Check ────────────────────────────────────────────

    /**
     * @description Checks all prerequisites for a successful connection: Salesforce Site
     *              existence/activation, guest user permission set, and Remote Site Setting
     *              reachability. Returns status + deep links for any missing items.
     * @return PrerequisiteStatus with check results and Setup page URLs.
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static PrerequisiteStatus checkPrerequisites() {
        PrerequisiteStatus prereqs = new PrerequisiteStatus();

        // Org domain for deep links
        String orgDomain = Url.getOrgDomainUrl().toExternalForm();
        prereqs.orgDomain = orgDomain;
        prereqs.siteSetupUrl = orgDomain + '/lightning/setup/CustomDomain/home';
        prereqs.remoteSiteSetupUrl = orgDomain + '/lightning/setup/SecurityRemoteProxy/home';

        // Remote Site URL from config
        CloudNimbusGlobalSettings__mdt config = CloudNimbusGlobalSettings__mdt.getInstance('Default');
        prereqs.remoteSiteUrl = (config != null && String.isNotBlank(config.EndpointUrlTxt__c))
            ? config.EndpointUrlTxt__c.removeEnd('/')
            : '';

        // Check 1: Salesforce Site exists
        List<Site> sites = [
            SELECT Id, Status, GuestUserId FROM Site
            WHERE Name = 'Delivery_Hub'
            WITH SYSTEM_MODE LIMIT 1
        ];
        prereqs.siteExists = !sites.isEmpty();
        prereqs.siteActive = !sites.isEmpty() && sites[0].Status == 'Active';

        // Check 2: Guest user has permission set assigned
        prereqs.guestUserConfigured = false;
        if (prereqs.siteActive && sites[0].GuestUserId != null) {
            prereqs.guestUserConfigured = isGuestUserConfigured(sites[0].GuestUserId);
        }

        // Check 3: Remote Site Setting is reachable (test callout)
        prereqs.remoteSiteReachable = testRemoteSiteReachability(prereqs.remoteSiteUrl);

        prereqs.allPassed = prereqs.siteActive
            && prereqs.guestUserConfigured
            && prereqs.remoteSiteReachable;

        return prereqs;
    }

    /**
     * @description Checks if the guest user has the DeliveryHubGuestUser permission set assigned.
     * @param guestUserId The Id of the Site's guest user.
     * @return true if the permission set is assigned.
     */
    private static Boolean isGuestUserConfigured(Id guestUserId) {
        String psName = 'DeliveryHubGuestUser';
        String nsPrefix = 'delivery__';
        List<PermissionSetAssignment> assignments = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :guestUserId
            AND (PermissionSet.Name = :psName OR PermissionSet.Name = :(nsPrefix + psName))
            WITH SYSTEM_MODE LIMIT 1
        ];
        return !assignments.isEmpty();
    }

    /**
     * @description Tests whether the Remote Site Setting is configured by attempting a callout.
     * @param endpointUrl The URL to test.
     * @return true if the callout succeeds (any HTTP response), false if blocked.
     */
    private static Boolean testRemoteSiteReachability(String endpointUrl) {
        if (String.isBlank(endpointUrl)) {
            return false;
        }
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpointUrl);
            req.setMethod('GET');
            req.setTimeout(10000);
            new Http().send(req);
            return true;
        } catch (System.CalloutException ex) {
            // "Unauthorized endpoint" = Remote Site Setting missing
            return false;
        }
    }
}