/**
 * @description Queueable Worker that processes 'Outbound' Sync Items.
 * It reads the specific Endpoint from the linked Request and pushes the payload natively.
 */
public inherited sharing class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        
        // 1. Query Queued Outbound Items linked to a valid Request route
        List<Sync_Item__c> items = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, 
                   RequestId__c, RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Sync_Item__c 
            WHERE StatusPk__c = 'Queued' 
            AND DirectionPk__c = 'Outbound'
            AND RequestId__c != NULL 
            WITH SYSTEM_MODE 
            LIMIT 50
        ];

        if (items.isEmpty()) {
            return;
        }

        List<Sync_Item__c> itemsToUpdate = new List<Sync_Item__c>();

        for (Sync_Item__c item : items) {
            try {
                String endpointUrl = item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
                
                // Validate Endpoint Configuration
                if (String.isBlank(endpointUrl)) {
                    item.StatusPk__c = 'Failed';
                    item.ErrorLogTxt__c = 'Configuration Error: Linked Network Entity is missing Integration Endpoint URL.';
                } else {
                    // --- NATIVE HTTP CALLOUT ---
                    String baseUrl = endpointUrl.removeEnd('/');
                    String finalEndpoint;
                    
                    // Safely construct universal endpoint regardless of how URL was saved
                    if (baseUrl.endsWithIgnoreCase('/sync')) {
                        finalEndpoint = baseUrl + '/' + item.ObjectTypePk__c;
                    } else if (baseUrl.containsIgnoreCase('/deliveryhub/v1')) {
                        // FIX: Changed substringBeforeIgnoreCase to substringBefore
                        String lowerBase = baseUrl.toLowerCase();
                        if(lowerBase.contains('/deliveryhub/v1')) {
                            finalEndpoint = baseUrl.substringBefore('/deliveryhub/v1') + '/deliveryhub/v1/sync/' + item.ObjectTypePk__c;
                        } else {
                            finalEndpoint = baseUrl + '/sync/' + item.ObjectTypePk__c;
                        }
                    } else {
                        finalEndpoint = baseUrl + '/services/apexrest/delivery/deliveryhub/v1/sync/' + item.ObjectTypePk__c;
                    }

                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(finalEndpoint);
                    req.setMethod('POST');
                    req.setHeader('Content-Type', 'application/json');
                    req.setBody(item.PayloadTxt__c);
                    req.setTimeout(60000); 

                    Http http = new Http();
                    HttpResponse res = http.send(req);

                    if (res.getStatusCode() >= 400) {
                        throw new CalloutException('Sync Failed (' + res.getStatusCode() + '): ' + res.getBody());
                    }
                    
                    item.StatusPk__c = 'Synced';
                    item.ErrorLogTxt__c = null;
                }

            } catch (Exception e) {
                // Handle HTTP or System Errors
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'SyncItemProcessor Error: ' + e.getMessage());
            }
            itemsToUpdate.add(item);
        }

        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        // Chain Job if more outbound work exists
        Integer remaining = [
            SELECT Count() 
            FROM Sync_Item__c 
            WHERE StatusPk__c = 'Queued' 
            AND DirectionPk__c = 'Outbound' 
            WITH SYSTEM_MODE 
            LIMIT 1
        ];
        
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }
}