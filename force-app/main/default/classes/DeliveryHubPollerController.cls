public with sharing class DeliveryHubPollerController {
    
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