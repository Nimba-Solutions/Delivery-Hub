/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Queueable job that fetches ContentVersion bytes from a peer
 *              Delivery Hub org via authenticated HTTP GET, inserts a local
 *              ContentVersion + ContentDocumentLink, and closes out the
 *              originating SyncItem__c.
 *
 *              Enqueued by DeliverySyncItemIngestor when an inbound
 *              ContentVersion payload arrives with FileTransport="pull-callout"
 *              (metadata-only; bytes live on the sender). See
 *              DeliveryContentDocLinkTriggerHandler for the sender half and
 *              DeliveryFileBytesResource for the REST endpoint it calls back to.
 *
 *              Heap ceiling: async Apex heap is 12 MB. VersionData is held in
 *              heap while the insert runs, so the effective cross-org file
 *              limit is ~12 MB until the org moves to Winter '26 API v65's
 *              streaming Http pattern.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.AvoidGlobalModifier')
global inherited sharing class DeliveryFileBytesFetcher implements Queueable, Database.AllowsCallouts {

    /** @description The SyncItem__c row whose payload describes the desired fetch. */
    private final Id syncItemId;
    /** @description Resolved local parent WorkItem Id for the resulting ContentDocumentLink. */
    private final Id localParentWorkItemId;

    /**
     * @description Queueable constructor.
     * @param syncItemId The inbound SyncItem__c carrying the metadata-only payload.
     * @param localParentWorkItemId Resolved local WorkItem Id the file should link to.
     */
    global DeliveryFileBytesFetcher(Id syncItemId, Id localParentWorkItemId) {
        this.syncItemId = syncItemId;
        this.localParentWorkItemId = localParentWorkItemId;
    }

    /**
     * @description Executes the fetch: authenticated callout, sha256 verify
     *              (when supplied), ContentVersion insert, ContentDocumentLink
     *              insert. Marks SyncItem status Synced on success, Failed on
     *              any error so the retry engine can pick it up.
     * @param ctx Standard QueueableContext
     */
    @SuppressWarnings('PMD.NcssMethodCount, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    global void execute(QueueableContext ctx) {
        // Suppress triggers that would try to re-emit this inbound file.
        DeliverySyncEngine.setSyncContext();

        SyncItem__c item = null;
        try {
            List<SyncItem__c> rows = [
                SELECT Id, PayloadTxt__c, ObjectTypePk__c, StatusPk__c,
                       RetryCountNumber__c, WorkItemLookup__c
                FROM SyncItem__c
                WHERE Id = :syncItemId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                return;
            }
            item = rows[0];

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);

            String senderOrgId = (String) payload.get('SenderOrgId');
            String contentDocumentId = (String) payload.get('ContentDocumentId');
            String expectedSha = (String) payload.get('Sha256');
            String title = (String) payload.get('Title');
            String pathOnClient = (String) payload.get('PathOnClient');

            if (String.isBlank(contentDocumentId)) {
                failItem(item, 'Pull-callout payload missing ContentDocumentId');
                return;
            }
            if (String.isBlank(senderOrgId)) {
                failItem(item, 'Pull-callout payload missing SenderOrgId — cannot resolve source endpoint');
                return;
            }

            NetworkEntity__c sourceEntity = resolveSourceEntity(senderOrgId);
            if (sourceEntity == null) {
                failItem(item, 'No registered NetworkEntity found for sender org ' + senderOrgId);
                return;
            }
            if (String.isBlank(sourceEntity.IntegrationEndpointUrlTxt__c)) {
                failItem(item, 'Source entity ' + sourceEntity.Id + ' has no IntegrationEndpointUrlTxt__c — cannot pull bytes');
                return;
            }
            if (String.isBlank(sourceEntity.ApiKeyTxt__c) || String.isBlank(sourceEntity.HmacSecretTxt__c)) {
                failItem(item, 'Source entity ' + sourceEntity.Id + ' missing ApiKeyTxt__c/HmacSecretTxt__c — cannot authenticate pull');
                return;
            }

            // Perform the callout
            HttpResponse res = performCallout(sourceEntity, contentDocumentId);
            if (res.getStatusCode() >= 400) {
                failItem(item, 'File-bytes callout failed (' + res.getStatusCode() + '): ' + res.getBody());
                return;
            }

            Blob bytes = res.getBodyAsBlob();
            if (bytes == null || bytes.size() == 0) {
                failItem(item, 'File-bytes callout returned empty body');
                return;
            }

            // Verify sha256 when the sender supplied one. Absent/null is tolerated
            // (sender flagged the file Oversized, or is a legacy sender).
            if (String.isNotBlank(expectedSha)) {
                String actualSha = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', bytes));
                if (!actualSha.equalsIgnoreCase(expectedSha)) {
                    failItem(item, 'File-bytes integrity check failed — expected ' + expectedSha + ' got ' + actualSha);
                    return;
                }
            }

            // Insert ContentVersion locally
            ContentVersion cv = new ContentVersion(
                Title = title,
                PathOnClient = String.isNotBlank(pathOnClient) ? pathOnClient : (String.isNotBlank(title) ? title : 'file.bin'),
                VersionData = bytes,
                Origin = 'H'
            );
            Database.insert(cv, AccessLevel.SYSTEM_MODE);

            // Link to the local parent Work Item
            if (localParentWorkItemId != null) {
                Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH SYSTEM_MODE LIMIT 1].ContentDocumentId;
                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = cdId,
                    LinkedEntityId = localParentWorkItemId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                Database.insert(cdl, AccessLevel.SYSTEM_MODE);
            }

            // Mark the inbound sync row complete
            item.StatusPk__c = 'Synced';
            item.ErrorLogTxt__c = null;
            item.LocalRecordIdTxt__c = cv.Id;
            Database.update(item, AccessLevel.SYSTEM_MODE);

        } catch (Exception e) {
            if (item != null) {
                failItem(item, 'Pull-callout exception: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Builds and sends the authenticated HTTP GET to the source org's
     *              /fileBytes endpoint. Signs the request with HMAC-SHA256 over
     *              contentDocumentId|timestamp using the peer's shared secret.
     * @param sourceEntity Peer NetworkEntity__c with endpoint/api-key/hmac-secret fields populated.
     * @param contentDocumentId ContentDocumentId on the source org to fetch.
     * @return Raw HttpResponse from the callout.
     */
    private HttpResponse performCallout(NetworkEntity__c sourceEntity, String contentDocumentId) {
        String baseUrl = sourceEntity.IntegrationEndpointUrlTxt__c.removeEnd('/');
        String endpoint;
        // The IntegrationEndpointUrlTxt__c field in the wild is stored either as
        // the org base (e.g. https://my-org.my.salesforce.com) or already pointed
        // at the sync service path. Normalize both into the /fileBytes/<id>
        // endpoint under /services/apexrest/delivery.
        String lowerBase = baseUrl.toLowerCase();
        if (lowerBase.contains('/services/apexrest')) {
            // Strip anything past /services/apexrest and rebuild
            endpoint = baseUrl.substringBefore('/services/apexrest')
                + '/services/apexrest/delivery/fileBytes/' + contentDocumentId;
        } else {
            endpoint = baseUrl + '/services/apexrest/delivery/fileBytes/' + contentDocumentId;
        }

        String timestamp = String.valueOf(Datetime.now().getTime() / 1000L);
        String signingString = contentDocumentId + '|' + timestamp;
        String signature = DeliveryCryptoService.computeHMAC(sourceEntity.HmacSecretTxt__c, signingString);

        HttpRequest hreq = new HttpRequest();
        hreq.setEndpoint(endpoint);
        hreq.setMethod('GET');
        hreq.setHeader('X-Api-Key', sourceEntity.ApiKeyTxt__c);
        hreq.setHeader('X-Timestamp', timestamp);
        hreq.setHeader('X-Signature', signature);
        hreq.setHeader('Accept', 'application/octet-stream');
        hreq.setTimeout(120000);

        return new Http().send(hreq);
    }

    /**
     * @description Resolves the NetworkEntity__c representing the source org of
     *              the inbound payload. Handles both OrgIdTxt__c and legacy
     *              RemoteExternalIdTxt__c matches, and both 15/18-char Org Ids.
     * @param senderOrgId 15 or 18 char Organization Id advertised by the sender.
     * @return The NetworkEntity__c with endpoint/api-key/hmac fields, or null.
     */
    private NetworkEntity__c resolveSourceEntity(String senderOrgId) {
        String baseOrgId = senderOrgId.length() >= 15 ? senderOrgId.substring(0, 15) + '%' : senderOrgId;
        List<NetworkEntity__c> entities = [
            SELECT Id, IntegrationEndpointUrlTxt__c, ApiKeyTxt__c, HmacSecretTxt__c
            FROM NetworkEntity__c
            WHERE (OrgIdTxt__c LIKE :baseOrgId OR RemoteExternalIdTxt__c LIKE :baseOrgId)
            AND ConnectionStatusPk__c = 'Connected'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return entities.isEmpty() ? null : entities[0];
    }

    /**
     * @description Marks the SyncItem__c row Failed with a structured error and
     *              increments retry counter so DeliverySyncItemProcessor-style
     *              retry sweeps can pick it up.
     * @param item SyncItem__c row being processed.
     * @param message Error message.
     */
    private void failItem(SyncItem__c item, String message) {
        item.StatusPk__c = 'Failed';
        item.ErrorLogTxt__c = message;
        item.RetryCountNumber__c = (item.RetryCountNumber__c == null ? 0 : item.RetryCountNumber__c) + 1;
        Database.update(item, AccessLevel.SYSTEM_MODE);
    }
}
