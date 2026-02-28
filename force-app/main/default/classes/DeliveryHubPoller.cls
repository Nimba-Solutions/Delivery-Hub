/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Robust poller logic.
 * Uses Static SOQL to guarantee field visibility in namespaced tests.
 * V2 Architecture: Appends identity parameters for secure Hub multi-tenancy.
 * V3: Polls all active vendors, not just the first one.
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliveryHubPoller {

    /**
     * @description Polls all active vendor endpoints for new sync items since the last
     * inbound sync timestamp. Processes received payloads through SyncItemIngestor and
     * advances each vendor's watermark to prevent duplicate pulls.
     * @return String summary message indicating synced item count and any vendor errors
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    @AuraEnabled
    public static String pollUpdates() {
        try {
            // Query ALL Active Vendors (Including 'Both' types)
            List<NetworkEntity__c> vendors = [
                SELECT Id,
                       IntegrationEndpointUrlTxt__c,
                       LastInboundSyncDateTime__c,
                       RemoteExternalIdTxt__c
                FROM NetworkEntity__c
                WHERE StatusPk__c = 'Active'
                AND EntityTypePk__c IN ('Vendor', 'Both')
                WITH SYSTEM_MODE
            ];

            if (vendors.isEmpty()) {
                return 'Error: No Active Vendor found.';
            }

            Integer totalSynced = 0;
            List<String> errors = new List<String>();

            for (NetworkEntity__c vendor : vendors) {
                String endpointUrl = vendor.IntegrationEndpointUrlTxt__c;
                String remoteId = vendor.RemoteExternalIdTxt__c;
                DateTime lastSync = vendor.LastInboundSyncDateTime__c;

                if (String.isBlank(endpointUrl) || String.isBlank(remoteId)) {
                    errors.add('Vendor ' + vendor.Id + ': Configuration incomplete (missing URL or Remote ID).');
                    continue;
                }

                String sinceParam = (lastSync != null) ? lastSync.formatGmt('yyyy-MM-dd HH:mm:ss') : '1900-01-01 00:00:00';
                String baseUrl = endpointUrl.endsWith('/') ? endpointUrl.removeEnd('/') : endpointUrl;

                // V2 ARCHITECTURE: Append clientId to strictly isolate multi-tenant Vendor data
                String endpoint = baseUrl + '/sync/changes?since=' + EncodingUtil.urlEncode(sinceParam, 'UTF-8')
                                          + '&clientId=' + EncodingUtil.urlEncode(remoteId, 'UTF-8');

                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setTimeout(120000); // 120s timeout for bulk loads

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() == 200) {
                    totalSynced += handleSuccess(res.getBody(), vendor);
                } else {
                    errors.add('Vendor ' + vendor.Id + ': HTTP ' + res.getStatusCode() + ' ' + res.getBody());
                }
            }

            String result = 'Success: Synced ' + totalSynced + ' items.';
            if (!errors.isEmpty()) {
                result += ' Errors (' + errors.size() + '): ' + String.join(errors, '; ');
            }
            return result;

        } catch (Exception e) {
            return 'Exception: ' + e.getMessage();
        }
    }

    private static Integer handleSuccess(String responseBody, NetworkEntity__c vendor) {
        // V2 ARCHITECTURE: The Vendor's API now returns a direct JSON array
        List<Object> events = (List<Object>) JSON.deserializeUntyped(responseBody);

        Integer successCount = 0;
        DateTime latestTime = vendor.LastInboundSyncDateTime__c;

        if (events != null && !events.isEmpty()) {
            for (Object itemObj : events) {
                Map<String, Object> item = (Map<String, Object>) itemObj;

                // The vendor sends the payload as a serialized String; Ingestor requires a Map
                String payloadStr = (String) item.get('payload');
                Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(payloadStr);

                DeliverySyncItemIngestor.processInboundItem(
                    (String) item.get('objectType'),
                    payloadMap
                );
                successCount++;

                // Calculate the highest CreatedDate to dynamically advance the Poller watermark
                String createdDateStr = (String) item.get('createdDate');
                if (String.isNotBlank(createdDateStr)) {
                    // Normalize standard JSON DateTime string to Apex DateTime
                    DateTime itemDate = (DateTime) JSON.deserialize('\"' + createdDateStr + '\"', DateTime.class);
                    if (latestTime == null || itemDate > latestTime) {
                        latestTime = itemDate;
                    }
                }
            }
        }

        // Commit the new watermark so we don't pull these same records again
        if (latestTime != null && latestTime != vendor.LastInboundSyncDateTime__c) {
            vendor.LastInboundSyncDateTime__c = latestTime;
            update as system vendor;
        }

        return successCount;
    }
}
