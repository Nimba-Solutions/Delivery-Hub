/**
 * Aggregates Ticket rows that need a Jira *create* or *update*,
 * then enqueues **one** worker job for each operation type.
 */
public without sharing class TicketTriggerHandler {

    /* Public entry used by the trigger ----------------------------------- */
    public static void handleAfter(
        List<Ticket__c> newRows,
        Map<Id, Ticket__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        /* Collect the two ID sets we care about */
        Set<Id> toCreate = new Set<Id>();
        Set<Id> toUpdate = new Set<Id>();

        /* -------- INSERT -------- */
        if (isInsert){
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
                    row.DetailsTxt__c           != oldRow.DetailsTxt__c ||
                    row.StageNamePk__c          != oldRow.StageNamePk__c
                ){
                    toUpdate.add(row.Id);
                }
            }
        }

        /* -------- Enqueue worker jobs -------- */
        if (!toCreate.isEmpty()){
            System.enqueueJob(
                new JiraSyncWorker(JiraSyncWorker.Mode.CREATE, toCreate)
            );
        }
        if (!toUpdate.isEmpty()){
            System.enqueueJob(
                new JiraSyncWorker(JiraSyncWorker.Mode.UPDATE_JIRA, toUpdate)
            );
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