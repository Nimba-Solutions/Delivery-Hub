/**
 * @description Queueable Worker that processes 'Outbound' Sync Items.
 * It reads the specific Endpoint from the linked Request, pushes the payload natively,
 * passes the Global Traceability ID, and extracts the response ID to close the bridge loop.
 * @author Cloud Nimbus LLC
 */
public inherited sharing class DeliverySyncItemProcessor implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        
        // 1. Query Queued Outbound Items linked to a valid Request route
        // NEW: Added GlobalSourceIdTxt__c to the query for header injection
        List<Sync_Item__c> items = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, LocalRecordIdTxt__c, GlobalSourceIdTxt__c,
                   RetryCountNumber__c, RequestId__c, RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
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
        Map<Id, WorkRequest__c> requestsToUpdate = new Map<Id, WorkRequest__c>();

        for (Sync_Item__c item : items) {
            try {
                String endpointUrl = item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
                
                // Validate Endpoint Configuration
                if (String.isBlank(endpointUrl)) {
                    item.StatusPk__c = 'Failed';
                    item.ErrorLogTxt__c = 'Configuration Error: Linked Network Entity is missing Integration Endpoint URL.';
                    item.RetryCountNumber__c = (item.RetryCountNumber__c == null ? 0 : item.RetryCountNumber__c) + 1;
                } else {
                    // --- NATIVE HTTP CALLOUT ---
                    String baseUrl = endpointUrl.removeEnd('/');
                    String finalEndpoint;
                    
                    // Safely construct universal endpoint regardless of how URL was saved
                    if (baseUrl.endsWithIgnoreCase('/sync')) {
                        finalEndpoint = baseUrl + '/' + item.ObjectTypePk__c;
                    } else if (baseUrl.containsIgnoreCase('/deliveryhub/v1')) {
                        String lowerBase = baseUrl.toLowerCase();
                        if (lowerBase.contains('/deliveryhub/v1')) {
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
                    
                    // NEW: Inject the Global Traceability ID as an HTTP Header for Gateway-level loop prevention
                    if (String.isNotBlank(item.GlobalSourceIdTxt__c)) {
                        req.setHeader('X-Global-Source-Id', item.GlobalSourceIdTxt__c);
                    }
                    
                    req.setBody(item.PayloadTxt__c);
                    req.setTimeout(60000); 

                    Http http = new Http();
                    HttpResponse res = http.send(req);

                    if (res.getStatusCode() >= 400) {
                        throw new CalloutException('Sync Failed (' + res.getStatusCode() + '): ' + res.getBody());
                    }
                    
                    item.StatusPk__c = 'Synced';
                    item.ErrorLogTxt__c = null;

                    // --- EXTRACT RESPONSE & UPDATE BRIDGE (Handshake Flow) ---
                    if (String.isNotBlank(res.getBody())) {
                        try {
                            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                            
                            String remoteId = null;
                            if (responseMap.containsKey('processedId')) {
                                remoteId = (String) responseMap.get('processedId');
                            } else if (responseMap.containsKey('remoteId')) {
                                remoteId = (String) responseMap.get('remoteId'); // Fallback
                            }

                            // If we pushed a Work Item, map the Vendor's new ID to our Request bridge
                            if (String.isNotBlank(remoteId) && item.ObjectTypePk__c.endsWithIgnoreCase('WorkItem__c') && item.RequestId__c != null) {
                                requestsToUpdate.put(item.RequestId__c, new WorkRequest__c(
                                    Id = item.RequestId__c,
                                    RemoteTicketIdTxt__c = remoteId
                                ));
                            }
                        } catch (Exception parseEx) {
                            System.debug(LoggingLevel.WARN, 'Could not parse sync response: ' + parseEx.getMessage());
                        }
                    }
                }

            } catch (Exception e) {
                // Handle HTTP or System Errors
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
                item.RetryCountNumber__c = (item.RetryCountNumber__c == null ? 0 : item.RetryCountNumber__c) + 1;
                System.debug(LoggingLevel.ERROR, 'DeliverySyncItemProcessor Error: ' + e.getMessage());
            }
            itemsToUpdate.add(item);
        }

        // Execute DML
        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }
        
        if (!requestsToUpdate.isEmpty()) {
            Database.update(requestsToUpdate.values(), AccessLevel.SYSTEM_MODE);
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
            System.enqueueJob(new DeliverySyncItemProcessor());
        }
    }
}