/**
 * @description Schedulable class to trigger the Delivery Hub Poller.
 * Runs in the background to keep the Client Org in sync with the Mothership.
 */
global class DeliveryHubScheduler implements Schedulable {

    /**
     * @description Schedulable execute method. 
     * Delegates to an async method immediately to allow for HTTP Callouts.
     * @param sc The SchedulableContext (standard system parameter).
     */
    global void execute(SchedulableContext sc) {
        runSyncAsync();
    }

    /**
     * @description Future method to perform the HTTP Callout to the Mothership.
     * Required because SchedulableContext cannot perform synchronous callouts.
     */
    @future(callout=true)
    public static void runSyncAsync() {
        String result = DeliveryHubPoller.pollUpdates();
        
        if (!result.contains('Success') && !result.contains('Synced 0 items')) {
            System.debug(LoggingLevel.ERROR, 'Delivery Hub Sync Failed: ' + result);
        }
    }
}