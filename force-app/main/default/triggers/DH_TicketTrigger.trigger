trigger DH_TicketTrigger on DH_Ticket__c (after update) {
    Set<Id> toSync = new Set<Id>();

    for (DH_Ticket__c t : Trigger.new) {
        DH_Ticket__c oldT = Trigger.oldMap.get(t.Id);
        if (t.StatusPk__c == 'In Progress' && oldT.StatusPk__c != 'In Progress'
            /*&& String.isBlank(t.JiraTicketKey__c)
             */
             ) {
            toSync.add(t.Id);
        }
    }

    if (!toSync.isEmpty()) {
        DHTicket_JiraSync.createJiraIssues(toSync);
    }
}