/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Schedulable class to trigger the Delivery Hub Poller and escalation engine.
 * Runs in the background to keep the Client Org in sync with the Mothership
 * and to process automated escalation rules for stalled work items.
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliveryHubScheduler implements Schedulable {

    /**
     * @description Schedulable execute method.
     * Requeues failed outbound sync items, runs escalation processing,
     * then delegates to an async method for HTTP callouts.
     * @param sc The SchedulableContext (standard system parameter).
     */
    public void execute(SchedulableContext sc) {
        requeueFailedItems();
        processEscalations();
        runSyncAsync();
    }

    /**
     * @description Evaluates CMT-driven escalation rules against stalled work items
     * and executes automated actions (email, Slack, bump priority, move stage, reassign).
     */
    private static void processEscalations() {
        try {
            DeliveryEscalationService.processEscalations();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Delivery Hub Escalation Processing Failed: ' + e.getMessage());
        }
    }

    /**
     * @description Resets failed outbound Sync Items that have not exceeded the retry limit
     * back to 'Queued' so the DeliverySyncItemProcessor can re-attempt them.
     */
    private static void requeueFailedItems() {
        List<SyncItem__c> failedItems = [
            SELECT Id, StatusPk__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            AND DirectionPk__c = 'Outbound'
            AND (RetryCountNumber__c = null OR RetryCountNumber__c < 3)
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        if (failedItems.isEmpty()) {
            return;
        }

        for (SyncItem__c item : failedItems) {
            item.StatusPk__c = 'Queued';
        }
        Database.update(failedItems, AccessLevel.SYSTEM_MODE);
        System.enqueueJob(new DeliverySyncItemProcessor());
    }

    /**
     * @description Future method to perform the HTTP Callout to the Mothership.
     * Required because SchedulableContext cannot perform synchronous callouts.
     */
    @future(callout=true)
    public static void runSyncAsync() {
        // Triggers the poller logic to fetch delta updates
        String result = DeliveryHubPoller.pollUpdates();

        // Logs an error only if the result does not indicate success or zero items
        if (!result.contains('Success') && !result.contains('Synced 0 items')) {
            System.debug(LoggingLevel.ERROR, 'Delivery Hub Sync Failed: ' + result);
        }
    }
}
