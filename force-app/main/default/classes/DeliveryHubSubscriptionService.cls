/**
 * @description Service to "Pull" (Subscribe) to updates from upstream Motherships.
 * UPDATED: Uses Sync_Item__c to deduplicate messages (Idempotency Pattern).
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class DeliveryHubSubscriptionService {

    public static void pullUpdates(Id localTicketId) {
        // 1. Find ALL Active Requests
        List<Request__c> requests = [
            SELECT Id, RemoteTicketIdTxt__c, 
                   DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Request__c 
            WHERE TicketId__c = :localTicketId 
            AND RemoteTicketIdTxt__c != NULL
            AND StatusPk__c != 'Inactive'
        ];

        if (requests.isEmpty()) return;

        // 2. Determine "Last Sync" Time (fallback for efficiency)
        Long lastSyncTime = 0;
        List<Ticket_Comment__c> latestComments = [
            SELECT CreatedDate 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :localTicketId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        if (!latestComments.isEmpty()) {
            lastSyncTime = latestComments[0].CreatedDate.getTime();
        }

        List<Ticket_Comment__c> newCommentsToInsert = new List<Ticket_Comment__c>();
        List<Sync_Item__c> newSyncLogs = new List<Sync_Item__c>();
        Set<String> incomingRemoteIds = new Set<String>();

        // 3. Loop through Vendors and Fetch
        for (Request__c req : requests) {
            if (String.isBlank(req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c)) continue;

            String baseUrl = DeliveryHubCalloutService.getBaseUrl(req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c);
            String endpoint = baseUrl + 'comments/' + req.RemoteTicketIdTxt__c + '?since=' + lastSyncTime;

            try {
                HttpResponse res = DeliveryHubCalloutService.get(endpoint);
                if (res.getStatusCode() == 200) {
                    List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                    
                    for (Object obj : results) {
                        Map<String, Object> data = (Map<String, Object>) obj;
                        String remoteId = (String) data.get('id');
                        
                        // Collect ID to check against Ledger
                        if(String.isNotBlank(remoteId)) {
                             incomingRemoteIds.add(remoteId);
                        }
                    }

                    // --- THE DEDUPLICATION LOGIC ---
                    // Query Ledger: Have we seen these IDs before?
                    Set<String> existingRemoteIds = new Set<String>();
                    if(!incomingRemoteIds.isEmpty()) {
                        for(Sync_Item__c log : [SELECT RemoteExternalIdTxt__c 
                                                FROM Sync_Item__c 
                                                WHERE RemoteExternalIdTxt__c IN :incomingRemoteIds 
                                                AND ObjectTypePk__c = 'Ticket_Comment__c']) {
                            existingRemoteIds.add(log.RemoteExternalIdTxt__c);
                        }
                    }

                    // Process only NET NEW items
                    for (Object obj : results) {
                        Map<String, Object> data = (Map<String, Object>) obj;
                        String remoteId = (String) data.get('id');

                        // If we haven't seen this Remote ID, it's new.
                        if (!existingRemoteIds.contains(remoteId)) {
                            
                            // 1. Prepare Comment
                            Ticket_Comment__c c = new Ticket_Comment__c(
                                TicketId__c = localTicketId,
                                BodyTxt__c = (String) data.get('body'),
                                AuthorTxt__c = (String) data.get('author'),
                                JiraSyncStatusTxt__c = 'Synced', 
                                SourcePk__c = (String) data.get('source')
                            );
                            newCommentsToInsert.add(c);

                            // 2. Prepare Ledger Entry (So we don't import it again)
                            // We link the Sync Item to the Comment later
                            Sync_Item__c log = new Sync_Item__c(
                                TicketId__c = localTicketId,
                                RequestId__c = req.Id,
                                RemoteExternalIdTxt__c = remoteId,
                                DirectionPk__c = 'Inbound',
                                StatusPk__c = 'Synced',
                                ObjectTypePk__c = 'Ticket_Comment__c'
                            );
                            newSyncLogs.add(log);
                            
                            // Add to set so we don't duplicate within the same batch
                            existingRemoteIds.add(remoteId); 
                        }
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Pull Failed: ' + e.getMessage());
            }
        }

        // 4. Commit to Database
        if (!newCommentsToInsert.isEmpty()) {
            insert newCommentsToInsert;

            // Link the Sync Logs to the newly created comments
            for (Integer i = 0; i < newCommentsToInsert.size(); i++) {
                newSyncLogs[i].TicketCommentId__c = newCommentsToInsert[i].Id;
                newSyncLogs[i].LocalRecordIdTxt__c = newCommentsToInsert[i].Id;
            }
            insert newSyncLogs;
        }
    }
}