/**
 * Aggregates Ticket rows that need a Jira *create* or *update*,
 * then enqueues **one** worker job for each operation type.
 * Also handles Network Entity Sync and Dependency Blocking.
 */
public without sharing class TicketTriggerHandler {
    
    public static boolean triggerDisabled = false;

    /* Public entry used by the trigger ----------------------------------- */
    public static void handleAfter(
        List<Ticket__c> newRows,
        Map<Id, Ticket__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        
        if (!TriggerControl.runAfterLogic) {
            return;
        }
        /* Collect the two ID sets we care about for JIRA */
        Set<Id> toCreate = new Set<Id>();
        Set<Id> toUpdate = new Set<Id>();

        /* -------- INSERT -------- */
        if (isInsert){
            // 1. Run Network Entity Sync (Auto-create Requests)
            handleNetworkEntitySync(newRows);

            // 2. Jira Logic
            for (Ticket__c row : newRows){
                // Any new ticket is eligible for creation in Jira.
                if (String.isBlank(row.JiraTicketKeyTxt__c)){
                    toCreate.add(row.Id);
                }
            }
        }

        /* -------- UPDATE -------- */
        if (isUpdate){
            for (Ticket__c row : newRows){
                Ticket__c oldRow = oldMap.get(row.Id);
                
                // If the ticket is updated but still doesn't have a Jira Key, it needs to be CREATED.
                if (String.isBlank(row.JiraTicketKeyTxt__c)) {
                    toCreate.add(row.Id);
                    continue; // Skip to the next record, as it can't be updated yet.
                }

                // If it has a Jira Key, check if relevant fields have changed for an UPDATE.
                if (
                    row.BriefDescriptionTxt__c != oldRow.BriefDescriptionTxt__c ||
                    row.DetailsTxt__c          != oldRow.DetailsTxt__c ||
                    row.StageNamePk__c         != oldRow.StageNamePk__c
                ){
                    toUpdate.add(row.Id);
                }
            }
        }

        /* -------- Enqueue worker jobs -------- */
        if (!toCreate.isEmpty()){
            if (Test.isRunningTest()) {
                // Use synchronous methods during tests to avoid async job limits
                Ticket_JiraSync.createJiraIssuesSync(toCreate);
            } else {
                //System.enqueueJob(
                //    new JiraSyncWorker(JiraSyncWorker.Mode.CREATE, toCreate)
                //);
            }
        }
        if (!toUpdate.isEmpty()){
            if (Test.isRunningTest()) {
                // Use synchronous methods during tests to avoid async job limits
                Ticket_JiraSync.updateJiraIssuesSync(toUpdate);
            } else {
                //System.enqueueJob(
                //    new JiraSyncWorker(JiraSyncWorker.Mode.UPDATE_JIRA, toUpdate)
                //);
            }
        }
    }

    /* ---------------------------------------------------------------------
       NEW LOGIC: Auto-Create Requests for Single Active Vendor
       --------------------------------------------------------------------- */
    private static void handleNetworkEntitySync(List<Ticket__c> newTickets) {
        // 1. Check the Setting (Safe Defaulting to TRUE if null)
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getInstance();
        Boolean shouldRunSync = (settings.AutoSyncNetworkEntityBool__c == null) ? true : settings.AutoSyncNetworkEntityBool__c;

        if (!shouldRunSync) {
            return;
        }

        // 2. Check for Single Active Network Entity
        // Limit 2 to efficiently check "Is there exactly one?"
        List<Network_Entity__c> vendors = [
            SELECT Id 
            FROM Network_Entity__c 
            WHERE StatusPk__c = 'Active' 
            LIMIT 2
        ];

        // 3. If exactly one exists, create Requests
        if (vendors.size() == 1) {
            Network_Entity__c vendor = vendors[0];
            List<Request__c> newRequests = new List<Request__c>();

            for (Ticket__c t : newTickets) {
                newRequests.add(new Request__c(
                    TicketId__c = t.Id, 
                    DeliveryEntityId__c = vendor.Id,
                    StatusPk__c = 'Draft',
                    // Map the Client's budget to the Request so the vendor sees it immediately
                    PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                ));
            }

            if (!newRequests.isEmpty()) {
                if (Schema.sObjectType.Request__c.isCreateable()) {
                    insert newRequests;
                }
            }
        }
    }

    /* Helper : which Tickets do we sync?  -------------------------------- */
    private static Boolean isEligible(Ticket__c row){
        // Now allows all tickets to be eligible for syncing, regardless of status.
        return true;
    }
    
    public static void handleBeforeUpdate(List<Ticket__c> newTickets, Map<Id, Ticket__c> oldMap) {
        // Define which stages are considered "active work"
        Set<String> activeDevStages = new Set<String>{'In Development', 'Ready for QA'}; // Add all relevant stages

        // Collect IDs of tickets moving into an active stage
        Set<Id> ticketsToCheck = new Set<Id>();
        for (Ticket__c ticket : newTickets) {
            String oldStage = oldMap.get(ticket.Id).StageNamePk__c;
            String newStage = ticket.StageNamePk__c;
            // Check if the stage is changing TO an active stage FROM a non-active one
            if (activeDevStages.contains(newStage) && !activeDevStages.contains(oldStage)) {
                ticketsToCheck.add(ticket.Id);
            }
        }

        if (!ticketsToCheck.isEmpty()) {
            // Find all unresolved tickets that are blocking the ones we're checking
            List<Ticket_Dependency__c> unresolvedBlockers = [
                SELECT Blocked_Ticket__c, Blocking_Ticket__r.Name, Blocking_Ticket__r.StageNamePk__c
                FROM Ticket_Dependency__c
                WHERE Blocked_Ticket__c IN :ticketsToCheck
                AND Blocking_Ticket__r.StageNamePk__c NOT IN ('Done', 'Deployed to Prod', 'Cancelled') // Define your "complete" statuses
            ];

            // Add an error to any ticket that has an unresolved blocker
            for (Ticket_Dependency__c dependency : unresolvedBlockers) {
                // Find the ticket in the trigger context and add the error
                for (Ticket__c ticket : newTickets) {
                    if (ticket.Id == dependency.Blocked_Ticket__c) {
                        ticket.addError('This ticket cannot be started. It is blocked by ticket: ' + dependency.Blocking_Ticket__r.Name);
                    }
                }
            }
        }
    }
}