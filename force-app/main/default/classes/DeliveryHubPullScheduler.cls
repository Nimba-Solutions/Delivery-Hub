/**
 * @description Scheduled job to batch pull comments from remote Motherships via Requests.
 */
public class DeliveryHubPullScheduler implements Schedulable, Database.Batchable<sObject>, Database.AllowsCallouts {
    
    /**
     * @description Execute the Schedulable context.
     * @param sc The schedulable context.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 10); 
    }

    /**
     * @description Start the Batchable context.
     * @param bc The batchable context.
     * @return Database.QueryLocator Queries active REQUESTS.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query REQUESTS that have a Remote ID (meaning they are linked)
        return Database.getQueryLocator([
            SELECT Id, TicketId__c 
            FROM Request__c 
            WHERE RemoteTicketIdTxt__c != NULL 
            AND StatusPk__c != 'Closed'
        ]);
    }

    /**
     * @description Execute the batch logic.
     * @param bc The batchable context.
     * @param scope The list of Requests.
     */
    public void execute(Database.BatchableContext bc, List<Request__c> scope) {
        // Collect Ticket IDs to avoid duplicates if multiple requests exist for one ticket
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