global class DeliveryHubScheduler implements Schedulable {

    /**
     * @description Schedulable execute method. 
     * Delegates to an async method immediately to allow for HTTP Callouts.
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
        // Call the Poller logic we wrote earlier
        String result = DeliveryHubPoller.pollUpdates();
        
        // Optional: Log failure to debug log if needed
        if (!result.contains('Success') && !result.contains('Synced 0 items')) {
            System.debug(LoggingLevel.ERROR, 'Delivery Hub Sync Failed: ' + result);
        }
    }
}