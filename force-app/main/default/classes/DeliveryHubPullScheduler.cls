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
        // Query all OPEN REQUESTS that are linked to a Mothership
        return Database.getQueryLocator([
            SELECT Id, TicketId__c 
            FROM Request__c 
            WHERE RemoteTicketIdTxt__c != NULL 
            AND StatusPk__c != 'Closed'
        ]);
    }

    /**
     * @description Execute the batch logic for a scope of records.
     * @param bc The batchable context.
     * @param scope The list of Requests.
     */
    public void execute(Database.BatchableContext bc, List<Request__c> scope) {
        // Collect Ticket IDs to avoid duplicates
        Set<Id> ticketIds = new Set<Id>();
        for(Request__c r : scope) {
            ticketIds.add(r.TicketId__c);
        }

        for (Id tId : ticketIds) {
            try {
                DeliveryHubSubscriptionService.pullUpdates(tId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Batch pull error for Ticket ' + tId + ': ' + e.getMessage());
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