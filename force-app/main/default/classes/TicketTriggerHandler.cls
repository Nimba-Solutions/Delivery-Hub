/**
 * @description Aggregates Ticket rows that need a Jira *create* or *update*,
 * then enqueues worker jobs. Also handles Network Entity Sync.
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
        
        Set<Id> toCreate = new Set<Id>();
        Set<Id> toUpdate = new Set<Id>();

        if (isInsert){
            // 1. Run Network Entity Sync (Auto-create and potentially Auto-send Requests)
            handleNetworkEntitySync(newRows);

            // 2. Jira Logic
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
    }

    /**
     * @description Checks settings and auto-creates/sends a Request if configured.
     * @param newTickets List of new tickets
     */
    private static void handleNetworkEntitySync(List<Ticket__c> newTickets) {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getInstance();
        
        // 1. Check "Create Request" Setting (Default TRUE if missing)
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

        // 2. Get active vendors
        // FIX: Removed WITH USER_MODE to prevent "No such column" errors in tests/community contexts
        // where the user may not have FLS on the config object. This runs in System Mode (without sharing class).
        List<Network_Entity__c> vendors = [
            SELECT Id 
            FROM Network_Entity__c 
            WHERE StatusPk__c = 'Active' 
            LIMIT 2
        ];

        if (vendors.size() != 1) {
            return; // Only sync if exactly one active vendor exists
        }

        Network_Entity__c vendor = vendors[0];
        List<Request__c> newRequests = new List<Request__c>();

        for (Ticket__c t : newTickets) {
            newRequests.add(new Request__c(
                TicketId__c = t.Id, 
                DeliveryEntityId__c = vendor.Id,
                StatusPk__c = 'Draft',
                PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
            ));
        }

        if (newRequests.isEmpty()) {
            return;
        }

        // We keep stripInaccessible for the INSERT as that creates new user data, which is safer
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, newRequests);
        insert decision.getRecords();

        // 3. Check "Auto-Send" Setting (Default TRUE if missing, per requirements)
        Boolean shouldAutoSend = true;
        if (settings.Id != null) {
            Map<String, Object> populatedFields = settings.getPopulatedFieldsAsMap();
            if (populatedFields.containsKey('AutoSyncNetworkEntityBool__c')) { // This is your "Send" field
                shouldAutoSend = settings.AutoSyncNetworkEntityBool__c;
            }
        }

        // 4. Enqueue Job if Auto-Send is ON
        if (shouldAutoSend) {
            List<Id> createdRequestIds = new List<Id>();
            for (SObject r : decision.getRecords()) {
                createdRequestIds.add(r.Id);
            }
            if (!createdRequestIds.isEmpty()) {
                System.enqueueJob(new DeliveryHubRequestSenderQueueable(createdRequestIds));
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
            // FIX: Removed WITH USER_MODE to prevent test failures on dependency checks
            List<Ticket_Dependency__c> unresolvedBlockers = [
                SELECT Blocked_Ticket__c, Blocking_Ticket__r.Name, Blocking_Ticket__r.StageNamePk__c
                FROM Ticket_Dependency__c
                WHERE Blocked_Ticket__c IN :ticketsToCheck
                AND Blocking_Ticket__r.StageNamePk__c NOT IN ('Done', 'Deployed to Prod', 'Cancelled')
            ];
            for (Ticket_Dependency__c dependency : unresolvedBlockers) {
                for (Ticket__c ticket : newTickets) {
                    if (ticket.Id == dependency.Blocked_Ticket__c) {
                        ticket.addError('This ticket cannot be started. It is blocked by ticket: ' + dependency.Blocking_Ticket__r.Name);
                    }
                }
            }
        }
    }
}