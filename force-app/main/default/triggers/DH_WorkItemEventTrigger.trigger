trigger DH_WorkItemEventTrigger on Work_Item_Event__e (after insert) {
    List<DH_Ticket__c> tickets = new List<DH_Ticket__c>();
    for (Work_Item_Event__e evt : Trigger.new) {
        // Prevent duplicate tickets by ReplayId
        if ([SELECT COUNT() FROM DH_Ticket__c WHERE SourceEventReplayIdTxt__c = :evt.ReplayId] == 0) {
            tickets.add(new DH_Ticket__c(
                //SourceEventReplayIdTxt__c    = evt.ReplayId,
                //EventReceivedOnDateTime__c   = evt.CreatedDate,
                //WorkItemTypeTxt__c           = evt.Operation__c,
                //DetailsTxt__c                = evt.Body__c,
                StatusPk__c                  = 'New'
            ));
        }
    }
    if (!tickets.isEmpty()) {
        insert tickets;
    }
}