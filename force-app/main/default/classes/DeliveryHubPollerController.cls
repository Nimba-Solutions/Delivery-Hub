/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the SyncPollerButton LWC.
 * Exposes the Delivery Hub polling logic to the Lightning UI for manual and on-load refreshes.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryHubPollerController {
    
    @TestVisible 
    private static Boolean forceException = false;
    
    /**
     * @description Triggers the polling process to fetch updates from the Vendor.
     * Wraps standard exceptions in an AuraHandledException for the LWC to display gracefully.
     */
    @AuraEnabled
    public static void triggerPoll() {
        try {
            // Used strictly to test the AuraHandledException wrapping
            if (forceException) {
                throw new CalloutException('Simulated UI Error');
            }
            
            // Fires your existing logic!
            DeliveryHubPoller.pollUpdates();
            
        } catch (Exception e) {
            throw new AuraHandledException('Polling failed: ' + e.getMessage());
        }
    }
}