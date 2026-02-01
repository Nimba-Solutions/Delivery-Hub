/**
 * @description Service to "Pull" (Subscribe) to updates from upstream Motherships.
 * FIX: Added 'Echo Blocking' to prevent importing our own messages.
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

        // 2. Determine "Last Sync" Time
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
        List<Object> allFetchedResults = new List<Object>(); // Store raw data for processing

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
                        String source = (String) data.get('source');

                        // --- THE FIX: ECHO BLOCKER ---
                        // If the source is ME, skip it.
                        if (source == 'Client Org') {
                            continue;
                        }

                        if(String.isNotBlank(remoteId)) {
                             incomingRemoteIds.add(remoteId);
                             // Store the valid result + Request context for later
                             // We attach the RequestId to the data map so we know who sent it
                             data.put('parentRequestId', req.Id);
                             allFetchedResults.add(data);
                        }
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Pull Failed: ' + e.getMessage());
            }
        }

        // 4. Check Ledger for Duplicates
        Set<String> existingRemoteIds = new Set<String>();
        if(!incomingRemoteIds.isEmpty()) {
            for(Sync_Item__c log : [SELECT RemoteExternalIdTxt__c 
                                    FROM Sync_Item__c 
                                    WHERE RemoteExternalIdTxt__c IN :incomingRemoteIds 
                                    AND ObjectTypePk__c = 'Ticket_Comment__c']) {
                existingRemoteIds.add(log.RemoteExternalIdTxt__c);
            }
        }

        // 5. Process Valid New Items
        for (Object obj : allFetchedResults) {
            Map<String, Object> data = (Map<String, Object>) obj;
            String remoteId = (String) data.get('id');
            Id requestId = (Id) data.get('parentRequestId');

            if (!existingRemoteIds.contains(remoteId)) {
                
                Ticket_Comment__c c = new Ticket_Comment__c(
                    TicketId__c = localTicketId,
                    BodyTxt__c = (String) data.get('body'),
                    AuthorTxt__c = (String) data.get('author'),
                    JiraSyncStatusTxt__c = 'Synced', 
                    SourcePk__c = (String) data.get('source')
                );
                newCommentsToInsert.add(c);

                Sync_Item__c log = new Sync_Item__c(
                    TicketId__c = localTicketId,
                    RequestId__c = requestId,
                    RemoteExternalIdTxt__c = remoteId,
                    DirectionPk__c = 'Inbound',
                    StatusPk__c = 'Synced',
                    ObjectTypePk__c = 'Ticket_Comment__c'
                );
                newSyncLogs.add(log);
                
                existingRemoteIds.add(remoteId); 
            }
        }

        // 6. Commit
        if (!newCommentsToInsert.isEmpty()) {
            insert newCommentsToInsert;

            for (Integer i = 0; i < newCommentsToInsert.size(); i++) {
                newSyncLogs[i].TicketCommentId__c = newCommentsToInsert[i].Id;
                newSyncLogs[i].LocalRecordIdTxt__c = newCommentsToInsert[i].Id;
            }
            insert newSyncLogs;
        }
    }
}