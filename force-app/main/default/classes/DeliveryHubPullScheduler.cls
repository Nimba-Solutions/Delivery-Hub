global class DeliveryHubPullScheduler implements Schedulable, Database.Batchable<sObject>, Database.AllowsCallouts {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(this, 10); // Batch size 10 to allow callouts
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all OPEN tickets that are linked to a Mothership
        return Database.getQueryLocator([
            SELECT Id FROM Ticket__c 
            WHERE RemoteTicketIdTxt__c != NULL 
            AND StatusPk__c != 'Closed'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Ticket__c> scope) {
        for (Ticket__c t : scope) {
            // Pull updates for each ticket
            try {
                DeliveryHubSubscriptionService.pullUpdates(t.Id);
            } catch (Exception e) {
                System.debug('Batch pull error for ' + t.Id + ': ' + e.getMessage());
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        // Optional: Chain jobs or log completion
    }
}