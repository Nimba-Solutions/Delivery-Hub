/**
 * Aggregates Ticket rows that need a Jira *create* or *update*,
 * then enqueues **one** worker job for each operation type.
 */
public with sharing class DH_TicketTriggerHandler {

    /* Public entry used by the trigger ----------------------------------- */
    public static void handleAfter(
        List<DH_Ticket__c> newRows,
        Map<Id, DH_Ticket__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        /* Collect the two ID sets we care about */
        Set<Id> toCreate = new Set<Id>();
        Set<Id> toUpdate = new Set<Id>();

        /* -------- INSERT -------- */
        if (isInsert){
            for (DH_Ticket__c row : newRows){
                if (isEligible(row) && String.isBlank(row.JiraTicketKeyTxt__c)){
                    toCreate.add(row.Id);
                }
            }
        }

        /* -------- UPDATE -------- */
        if (isUpdate){
            for (DH_Ticket__c row : newRows){
                DH_Ticket__c oldRow = oldMap.get(row.Id);
                if (!isEligible(row))              continue;     // still not “In Progress”
                
                /* Need a Jira issue but none yet –> CREATE */
                if (String.isBlank(row.JiraTicketKeyTxt__c)){
                    toCreate.add(row.Id);
                    continue;
                }

                /* Has a Jira key – did any sync-relevant field change?       */
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
            System.enqueueJob(
                new DH_JiraSyncWorker(DH_JiraSyncWorker.Mode.CREATE,       toCreate)
            );
        }
        if (!toUpdate.isEmpty()){
            System.enqueueJob(
                new DH_JiraSyncWorker(DH_JiraSyncWorker.Mode.UPDATE_JIRA,  toUpdate)
            );
        }
    }

    /* Helper : which Tickets do we sync?  -------------------------------- */
    private static Boolean isEligible(DH_Ticket__c row){
        // adjust if you later base the rule on a different field / value
        return row.StatusPk__c == 'In Progress';
    }
}