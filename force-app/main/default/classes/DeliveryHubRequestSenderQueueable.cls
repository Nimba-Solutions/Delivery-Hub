/**
 * @description Queueable job to handle auto-sending Requests to the Vendor
 * immediately after they are created by the Trigger.
 */
public class DeliveryHubRequestSenderQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<Id> requestIds;

    /**
     * @description Constructor
     * @param requestIds List of Request IDs to process
     */
    public DeliveryHubRequestSenderQueueable(List<Id> requestIds) {
        this.requestIds = requestIds;
    }

    /**
     * @description Executes the queueable job
     * @param context Queueable context
     */
    public void execute(QueueableContext context) {
        if (requestIds == null || requestIds.isEmpty()) {
            return;
        }

        for (Id reqId : requestIds) {
            try {
                // Call the existing logic synchronously
                DeliveryHubSender.sendRequestSync(reqId);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Auto-Send Failed for Request ' + reqId + ': ' + e.getMessage());
                // Optional: Log error to a custom log object here
            }
        }
    }
}