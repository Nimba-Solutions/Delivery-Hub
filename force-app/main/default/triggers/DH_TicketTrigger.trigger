trigger DH_TicketTrigger on DH_Ticket__c (after update) {
    Set<Id> toCreate = new Set<Id>();
    Set<Id> toUpdate = new Set<Id>();

    for (DH_Ticket__c t : Trigger.new) {
        DH_Ticket__c oldT = Trigger.oldMap.get(t.Id);

        if (t.StatusPk__c == 'In Progress'// && oldT.StatusPk__c != 'In Progress'
           ) {
            if (String.isBlank(t.JiraTicketKeyTxt__c)) {
                toCreate.add(t.Id);
            } else {
                toUpdate.add(t.Id);
            }
        }
    }

    if (!toCreate.isEmpty()) {
        DHTicket_JiraSync.createJiraIssues(toCreate);
    }

    if (!toUpdate.isEmpty()) {
        DHTicket_JiraSync.updateJiraIssues(toUpdate);
    }
}