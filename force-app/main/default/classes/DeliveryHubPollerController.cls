/**
 * @description Controller for the SyncPollerButton LWC.
 * Exposes the Delivery Hub polling logic to the Lightning UI for manual and on-load refreshes.
 */
public with sharing class DeliveryHubPollerController {
    
    /**
     * @description Triggers the polling process to fetch updates from the Vendor.
     * Wraps standard exceptions in an AuraHandledException for the LWC to display gracefully.
     */
    @AuraEnabled
    public static void triggerPoll() {
        try {
            // Fires your existing logic!
            DeliveryHubPoller.pollUpdates();
        } catch (Exception e) {
            throw new AuraHandledException('Polling failed: ' + e.getMessage());
        }
    }
}