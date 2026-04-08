/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Queueable Worker that processes 'Outbound' Sync Items.
 * It reads the specific Endpoint from the linked Request, pushes the payload natively,
 * passes the Global Traceability ID, and extracts the response ID to close the bridge loop.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity, PMD.CyclomaticComplexity, PMD.AvoidGlobalModifier')
global inherited sharing class DeliverySyncItemProcessor implements Queueable, Database.AllowsCallouts {

    /**
     * @description Processes queued outbound Sync Items by resolving endpoints, performing HTTP
     * callouts, updating item statuses, closing bridge loops with response IDs, and chaining
     * for remaining work.
     * @param context The QueueableContext provided by the Apex runtime.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    global void execute(QueueableContext context) {

        // 1a. Query Queued Outbound Items linked to a valid Request route (Push Mode — downstream)
        // Excludes entities with 'Pending Approval' connection status
        List<SyncItem__c> pushItems = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, LocalRecordIdTxt__c, GlobalSourceIdTxt__c,
                   RetryCountNumber__c, RequestLookup__c,
                   RequestLookup__r.DeliveryEntityLookup__c,
                   RequestLookup__r.DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c,
                   RequestLookup__r.DeliveryEntityLookup__r.ApiKeyTxt__c,
                   RequestLookup__r.DeliveryEntityLookup__r.HmacSecretTxt__c,
                   RequestLookup__r.DeliveryEntityLookup__r.ConnectionStatusPk__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Queued'
            AND DirectionPk__c = 'Outbound'
            AND RequestLookup__c != NULL
            AND RequestLookup__r.DeliveryEntityLookup__r.ConnectionStatusPk__c != 'Pending Approval'
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        // 1b. Query Queued Outbound Items with no Request (Hub Mode — upstream to client)
        // Excludes entities with 'Pending Approval' connection status
        List<SyncItem__c> hubItems = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, LocalRecordIdTxt__c, GlobalSourceIdTxt__c,
                   RetryCountNumber__c, RequestLookup__c,
                   WorkItemLookup__r.ClientNetworkEntityLookup__c,
                   WorkItemLookup__r.ClientNetworkEntityLookup__r.IntegrationEndpointUrlTxt__c,
                   WorkItemLookup__r.ClientNetworkEntityLookup__r.ApiKeyTxt__c,
                   WorkItemLookup__r.ClientNetworkEntityLookup__r.HmacSecretTxt__c,
                   WorkItemLookup__r.ClientNetworkEntityLookup__r.ConnectionStatusPk__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Queued'
            AND DirectionPk__c = 'Outbound'
            AND RequestLookup__c = NULL
            AND WorkItemLookup__r.ClientNetworkEntityLookup__c != NULL
            AND WorkItemLookup__r.ClientNetworkEntityLookup__r.ConnectionStatusPk__c != 'Pending Approval'
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        // 1c. Query Queued local-only items (e.g. UsageAnalytics) that need no callout
        // These have no Request or WorkItem linkage and are resolved locally.
        List<SyncItem__c> localItems = [
            SELECT Id, ObjectTypePk__c, PayloadTxt__c, LocalRecordIdTxt__c, GlobalSourceIdTxt__c,
                   RetryCountNumber__c, RequestLookup__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Queued'
            AND DirectionPk__c = 'Outbound'
            AND ObjectTypePk__c = 'UsageAnalytics'
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        List<SyncItem__c> items = new List<SyncItem__c>();
        items.addAll(pushItems);
        items.addAll(hubItems);
        items.addAll(localItems);

        if (items.isEmpty()) {
            return;
        }

        List<SyncItem__c> itemsToUpdate = new List<SyncItem__c>();
        Map<Id, WorkRequest__c> requestsToUpdate = new Map<Id, WorkRequest__c>();
        List<DeliverySync__e> syncEvents = new List<DeliverySync__e>();
        // Destination NetworkEntity__c Ids whose LastOutboundSyncDateTime__c should be
        // refreshed after a successful Synced. Collected via Set to dedupe across the
        // batch — one entity may receive multiple items in a single processor run.
        Set<Id> destinationEntityIds = new Set<Id>();

        for (SyncItem__c item : items) {
            try {
                // Skip UsageAnalytics items — they are local analytics with no remote handler.
                // Mark as Synced immediately without attempting a callout.
                if (item.ObjectTypePk__c == 'UsageAnalytics') {
                    item.StatusPk__c = 'Synced';
                    itemsToUpdate.add(item);
                    syncEvents.add(new DeliverySync__e(
                        ObjectTypeTxt__c = item.ObjectTypePk__c,
                        DirectionTxt__c = 'Outbound',
                        StatusTxt__c = 'Synced',
                        RecordIdTxt__c = item.LocalRecordIdTxt__c
                    ));
                    continue;
                }

                // Resolve endpoint and API key: Push Mode uses Request→Entity, Hub Mode uses WorkItem→ClientEntity
                String endpointUrl = item.RequestLookup__c != null
                    ? item.RequestLookup__r.DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c
                    : item.WorkItemLookup__r.ClientNetworkEntityLookup__r.IntegrationEndpointUrlTxt__c;
                String apiKey = item.RequestLookup__c != null
                    ? item.RequestLookup__r.DeliveryEntityLookup__r.ApiKeyTxt__c
                    : item.WorkItemLookup__r.ClientNetworkEntityLookup__r.ApiKeyTxt__c;
                String hmacSecret = item.RequestLookup__c != null
                    ? item.RequestLookup__r.DeliveryEntityLookup__r.HmacSecretTxt__c
                    : item.WorkItemLookup__r.ClientNetworkEntityLookup__r.HmacSecretTxt__c;

                // Validate Endpoint Configuration — no endpoint means entity isn't set up
                // for push sync. Park as Staged (available for polling) instead of failing.
                if (String.isBlank(endpointUrl)) {
                    item.StatusPk__c = 'Staged';
                    item.ErrorLogTxt__c = null;
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
                    
                    // Inject the Global Traceability ID as an HTTP Header for Gateway-level loop prevention
                    if (String.isNotBlank(item.GlobalSourceIdTxt__c)) {
                        req.setHeader('X-Global-Source-Id', item.GlobalSourceIdTxt__c);
                    }

                    // Inject API key for authentication with the remote entity
                    if (String.isNotBlank(apiKey)) {
                        req.setHeader('X-Api-Key', apiKey);
                    }

                    // HMAC request signing — attach signature when entity has a shared secret
                    if (String.isNotBlank(hmacSecret)) {
                        String hmac = DeliveryCryptoService.computeHMAC(hmacSecret, item.PayloadTxt__c);
                        req.setHeader('X-Signature', hmac);
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

                    // Stamp Last Outbound Sync on the destination entity. Push Mode
                    // resolves to Request→DeliveryEntityLookup; Hub Mode resolves to
                    // WorkItem→ClientNetworkEntityLookup. Either way the destination
                    // is a NetworkEntity__c whose LastOutboundSyncDateTime__c should
                    // reflect the moment we successfully pushed to it.
                    Id destEntityId = item.RequestLookup__c != null
                        ? item.RequestLookup__r.DeliveryEntityLookup__c
                        : (item.WorkItemLookup__c != null
                            ? item.WorkItemLookup__r.ClientNetworkEntityLookup__c
                            : null);
                    if (destEntityId != null) {
                        destinationEntityIds.add(destEntityId);
                    }

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
                            if (String.isNotBlank(remoteId) && item.ObjectTypePk__c.endsWithIgnoreCase('WorkItem__c') && item.RequestLookup__c != null) {
                                requestsToUpdate.put(item.RequestLookup__c, new WorkRequest__c(
                                    Id = item.RequestLookup__c,
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

            // Collect platform event for each processed sync item
            syncEvents.add(new DeliverySync__e(
                ObjectTypeTxt__c = item.ObjectTypePk__c,
                DirectionTxt__c = 'Outbound',
                StatusTxt__c = item.StatusPk__c,
                RecordIdTxt__c = item.LocalRecordIdTxt__c,
                ErrorMessageTxt__c = item.ErrorLogTxt__c
            ));
        }

        // Execute DML
        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        // Stamp LastOutboundSyncDateTime__c on every destination NetworkEntity that
        // received a successful Synced item this batch. The Data Lineage / Data Flow
        // widget reads this field for downstream client connections — without this
        // write, the widget shows "Last sync: Never" forever even when sync is healthy.
        if (!destinationEntityIds.isEmpty()) {
            Datetime now = Datetime.now();
            List<NetworkEntity__c> entitiesToStamp = new List<NetworkEntity__c>();
            for (Id eId : destinationEntityIds) {
                entitiesToStamp.add(new NetworkEntity__c(
                    Id = eId,
                    LastOutboundSyncDateTime__c = now
                ));
            }
            Database.update(entitiesToStamp, AccessLevel.SYSTEM_MODE);
        }

        if (!requestsToUpdate.isEmpty()) {
            Database.update(requestsToUpdate.values(), AccessLevel.SYSTEM_MODE);
        }

        // Publish sync platform events for external subscribers
        if (!syncEvents.isEmpty()) {
            EventBus.publish(syncEvents);
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