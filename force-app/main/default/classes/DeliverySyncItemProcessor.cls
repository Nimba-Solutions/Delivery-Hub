/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Queueable Worker that processes 'Outbound' Sync Items.
 * It reads the specific Endpoint from the linked Request, pushes the payload natively,
 * passes the Global Traceability ID, and extracts the response ID to close the bridge loop.
 * @author Cloud Nimbus LLC
 */
public inherited sharing class DeliverySyncItemProcessor implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {

        // 1a. Query Queued Outbound Items linked to a valid Request route (Push Mode — downstream)
        List<SyncItem__c> pushItems = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, LocalRecordIdTxt__c, GlobalSourceIdTxt__c,
                   RetryCountNumber__c, RequestId__c, RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Queued'
            AND DirectionPk__c = 'Outbound'
            AND RequestId__c != NULL
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        // 1b. Query Queued Outbound Items with no Request (Hub Mode — upstream to client)
        List<SyncItem__c> hubItems = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, LocalRecordIdTxt__c, GlobalSourceIdTxt__c,
                   RetryCountNumber__c, RequestId__c,
                   WorkItemId__r.ClientNetworkEntityId__r.IntegrationEndpointUrlTxt__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Queued'
            AND DirectionPk__c = 'Outbound'
            AND RequestId__c = NULL
            AND WorkItemId__r.ClientNetworkEntityId__c != NULL
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        List<SyncItem__c> items = new List<SyncItem__c>();
        items.addAll(pushItems);
        items.addAll(hubItems);

        if (items.isEmpty()) {
            return;
        }

        List<SyncItem__c> itemsToUpdate = new List<SyncItem__c>();
        Map<Id, WorkRequest__c> requestsToUpdate = new Map<Id, WorkRequest__c>();

        for (SyncItem__c item : items) {
            try {
                // Resolve endpoint: Push Mode uses Request→Entity, Hub Mode uses WorkItem→ClientEntity
                String endpointUrl = item.RequestId__c != null
                    ? item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
                    : item.WorkItemId__r.ClientNetworkEntityId__r.IntegrationEndpointUrlTxt__c;
                
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
                                    RemoteWorkItemIdTxt__c = remoteId
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

        // Chain Job if more outbound work exists (both Push and Hub Mode items)
        Integer remaining = [
            SELECT Count()
            FROM SyncItem__c
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