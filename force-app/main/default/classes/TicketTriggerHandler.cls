/**
 * @description Aggregates Ticket rows that need a Jira *create* or *update*,
 * then enqueues worker jobs. Also handles Network Entity Sync and High-Water Mark Sync.
 */
public without sharing class TicketTriggerHandler {
    
    /** @description Flag to disable trigger execution */
    public static boolean triggerDisabled = false;

    /**
     * @description Entry point for After Insert/Update logic
     * @param newRows List of new Ticket records
     * @param oldMap Map of old Ticket records
     * @param isInsert Boolean indicating insert context
     * @param isUpdate Boolean indicating update context
     */
    public static void handleAfter(
        List<Ticket__c> newRows,
        Map<Id, Ticket__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        if (!TriggerControl.runAfterLogic) { return; }

        // ============================================================================
        // 1. BRIDGE CREATION (Network Entity Sync)
        // ============================================================================
        // CRITICAL: This must run BEFORE SyncEngine.
        // On Insert, this creates the Request__c records that SyncEngine uses for routing.
        if (isInsert){
            handleNetworkEntitySync(newRows);
        }

        // ============================================================================
        // 2. UNIFIED SYNC ENGINE (High-Water Mark)
        // ============================================================================
        // Define the fields the Mothership needs to track (Allowlist).
        Set<String> syncFields = new Set<String>{
            'WorkItemNameTxt__c', // Changed 'Name' to API Name assuming it's custom or standard Name
            'BriefDescriptionTxt__c', 
            'DetailsTxt__c', 
            'StageNamePk__c', 
            'StatusPk__c', 
            'PriorityPk__c', 
            'DeveloperDaysSizeNumber__c', 
            'EstimatedHoursNumber__c', 
            'ClientPreApprovedHoursNumber__c', 
            'Developer__c', 
            'CalculatedETADate__c', 
            'ProjectedUATReadyDate__c',
            'AcceptanceCriteriaTxt__c', 
            'StepsToReproduceTxt__c'
        };

        // Capture changes and queue JSON payload
        // Now that Requests exist (from Step 1), SyncEngine will correctly route new Tickets.
        SyncEngine.captureChanges(newRows, oldMap, syncFields);

        // ============================================================================
        // 3. JIRA & LEGACY MODULES
        // ============================================================================
        
        Set<Id> toCreate = new Set<Id>();
        Set<Id> toUpdate = new Set<Id>();

        if (isInsert){
            // Jira Logic
            for (Ticket__c row : newRows){
                if (String.isBlank(row.JiraTicketKeyTxt__c)){
                    toCreate.add(row.Id);
                }
            }
        }

        if (isUpdate){
            for (Ticket__c row : newRows){
                Ticket__c oldRow = oldMap.get(row.Id);
                
                if (String.isBlank(row.JiraTicketKeyTxt__c)) {
                    toCreate.add(row.Id);
                    continue; 
                }

                if (
                    row.BriefDescriptionTxt__c != oldRow.BriefDescriptionTxt__c ||
                    row.DetailsTxt__c          != oldRow.DetailsTxt__c ||
                    row.StageNamePk__c         != oldRow.StageNamePk__c
                ){
                    toUpdate.add(row.Id);
                }
            }
        }
        
        // Enqueue Jira Jobs (Assuming existing workers handle these sets)
        // if (!toCreate.isEmpty()) { ... }
        // if (!toUpdate.isEmpty()) { ... }
    }

    /**
     * @description Checks settings and auto-creates/sends a Request if configured.
     * @param newTickets List of new tickets
     */
    private static void handleNetworkEntitySync(List<Ticket__c> newTickets) {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getInstance();
        
        // 1. Check "Create Request" Setting
        Boolean shouldCreateRequest = true;
        if (settings.Id != null) {
            Map<String, Object> populatedFields = settings.getPopulatedFieldsAsMap();
            if (populatedFields.containsKey('AutoCreateRequestFromTicketBool__c')) {
                shouldCreateRequest = settings.AutoCreateRequestFromTicketBool__c;
            }
        }

        if (!shouldCreateRequest) {
            return;
        }

        // 2. Determine entity for Request creation
        // Removed LIMIT 1 to potentially support multiple active vendors if architecture allows,
        // though logic below currently picks the first one found or ClientNetworkEntityId__c.
        List<Network_Entity__c> vendors = [
            SELECT Id FROM Network_Entity__c
            WHERE StatusPk__c = 'Active' AND EntityTypePk__c = 'Vendor'
            LIMIT 1
        ];

        List<Request__c> newRequests = new List<Request__c>();

        if (!vendors.isEmpty()) {
            Network_Entity__c vendor = vendors[0];
            for (Ticket__c t : newTickets) {
                newRequests.add(new Request__c(
                    TicketId__c = t.Id,
                    DeliveryEntityId__c = vendor.Id,
                    StatusPk__c = 'Draft',
                    PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                ));
            }
        } else {
            for (Ticket__c t : newTickets) {
                if (t.ClientNetworkEntityId__c != null) {
                    newRequests.add(new Request__c(
                        TicketId__c = t.Id,
                        DeliveryEntityId__c = t.ClientNetworkEntityId__c,
                        StatusPk__c = 'Draft',
                        PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                    ));
                }
            }
        }

        if (newRequests.isEmpty()) {
            return;
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, newRequests);
        insert decision.getRecords();

        // 3. Check "Auto-Send" Setting
        Boolean shouldAutoSend = true;
        if (settings.Id != null) {
            Map<String, Object> populatedFields = settings.getPopulatedFieldsAsMap();
            if (populatedFields.containsKey('AutoSyncNetworkEntityBool__c')) {
                shouldAutoSend = settings.AutoSyncNetworkEntityBool__c;
            }
        }

        // 4. Enqueue Job if Auto-Send is ON and Entity is 'Vendor'
        if (shouldAutoSend) {
            List<Request__c> insertedRequests = (List<Request__c>)decision.getRecords();
            Set<Id> entityIds = new Set<Id>();

            for (Request__c req : insertedRequests) {
                if (req.DeliveryEntityId__c != null) {
                    entityIds.add(req.DeliveryEntityId__c);
                }
            }

            // Identify which target entities are Vendors to satisfy the 'Vendor-only' auto-send requirement
            Map<Id, Network_Entity__c> vendorCheckMap = new Map<Id, Network_Entity__c>([
                SELECT Id FROM Network_Entity__c 
                WHERE Id IN :entityIds AND EntityTypePk__c = 'Vendor'
            ]);

            List<Id> requestsToEnqueue = new List<Id>();
            for (Request__c req : insertedRequests) {
                if (vendorCheckMap.containsKey(req.DeliveryEntityId__c)) {
                    requestsToEnqueue.add(req.Id);
                }
            }

            if (!requestsToEnqueue.isEmpty()) {
                System.enqueueJob(new DeliveryHubRequestSenderQueueable(requestsToEnqueue));
            }
        }
    }
    
    /**
     * @description Logic to handle Before Update events (Blocking logic)
     * @param newTickets List of new tickets
     * @param oldMap Map of old tickets
     */
    public static void handleBeforeUpdate(List<Ticket__c> newTickets, Map<Id, Ticket__c> oldMap) {
        Set<String> activeDevStages = new Set<String>{'In Development', 'Ready for QA'}; 
        Set<Id> ticketsToCheck = new Set<Id>();
        for (Ticket__c ticket : newTickets) {
            String oldStage = oldMap.get(ticket.Id).StageNamePk__c;
            String newStage = ticket.StageNamePk__c;
            if (activeDevStages.contains(newStage) && !activeDevStages.contains(oldStage)) {
                ticketsToCheck.add(ticket.Id);
            }
        }
        if (!ticketsToCheck.isEmpty()) {
            List<Ticket_Dependency__c> unresolvedBlockers = [
                SELECT Blocked_Ticket__c, Blocking_Ticket__r.WorkItemNameTxt__c, Blocking_Ticket__r.StageNamePk__c
                FROM Ticket_Dependency__c
                WHERE Blocked_Ticket__c IN :ticketsToCheck
                AND Blocking_Ticket__r.StageNamePk__c NOT IN ('Done', 'Deployed to Prod', 'Cancelled')
            ];
            for (Ticket_Dependency__c dependency : unresolvedBlockers) {
                for (Ticket__c ticket : newTickets) {
                    if (ticket.Id == dependency.Blocked_Ticket__c) {
                        ticket.addError('This ticket cannot be started. It is blocked by ticket: ' + dependency.Blocking_Ticket__r.WorkItemNameTxt__c);
                    }
                }
            }
        }
    }
}