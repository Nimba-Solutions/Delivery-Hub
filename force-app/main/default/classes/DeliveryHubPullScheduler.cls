/**
 * @description Scheduled job to batch pull comments from remote Motherships.
 */
public class DeliveryHubPullScheduler implements Schedulable, Database.Batchable<sObject>, Database.AllowsCallouts {
    
    /**
     * @description Execute the Schedulable context.
     * @param sc The schedulable context.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 10); // Batch size 10 to allow callouts
    }

    /**
     * @description Start the Batchable context.
     * @param bc The batchable context.
     * @return Database.QueryLocator The records to process.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query all OPEN tickets that are linked to a Mothership
        return Database.getQueryLocator([
            SELECT Id FROM Ticket__c 
            WHERE RemoteTicketIdTxt__c != NULL 
            AND StatusPk__c != 'Closed'
        ]);
    }

    /**
     * @description Execute the batch logic for a scope of records.
     * @param bc The batchable context.
     * @param scope The list of Tickets.
     */
    public void execute(Database.BatchableContext bc, List<Ticket__c> scope) {
        for (Ticket__c t : scope) {
            try {
                DeliveryHubSubscriptionService.pullUpdates(t.Id);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Batch pull error for ' + t.Id + ': ' + e.getMessage());
            }
        }
    }

    /**
     * @description Finish the batch job.
     * @param bc The batchable context.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'DeliveryHubPullScheduler completed.');
    }
}