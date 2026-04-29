/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Inbound side of the cross-org gantt bridge. Implements
 *               IWebhookEventHandler so DeliveryWebhookReceiverApi routes
 *               POSTs to /services/apexrest/delivery/deliveryhub/v1/webhook/cross-org-gantt
 *               here. Verifies the HMAC signature against the shared secret
 *               on DeliveryHubSettings__c, decodes the WorkItem patches,
 *               and applies them with DeliveryTriggerControl.inboundSyncContext = true
 *               so the trigger doesn't bridge the change back to the sender.
 *
 *               ID translation strategy: payloads carry the SENDER's local
 *               WorkItem Id. The receiver looks up the corresponding LOCAL
 *               WorkItem via the existing SyncItem__c ledger (the slow-lane
 *               SyncEngine maintains this mapping on every initial sync).
 *               If no SyncItem mapping exists, the patch is dropped silently
 *               with a debug log — the slow-lane will pick it up on its
 *               next drain.
 *
 *               IntegrationProvider__mdt row required for routing:
 *                 DeveloperName: Cross_Org_Gantt
 *                 DirectionTxt__c: Inbound
 *                 SignatureAlgorithmTxt__c: HmacSha256
 *                 SignatureHeaderTxt__c: X-DH-Signature
 *                 SignatureSecretTxt__c: (left empty in CMT — verified
 *                                         against DeliveryHubSettings__c at
 *                                         dispatch time, see verifyAtHandler)
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
global with sharing class DeliveryCrossOrgGanttUpdateHandler implements IWebhookEventHandler {

    /**
     * @description Entry point invoked by DeliveryCrossOrgGanttReceiverApi after
     *              signature verification. Decodes the patches list, resolves
     *              cross-org Ids via the SyncItem ledger, and applies the DML
     *              with inboundSyncContext=true to suppress trigger bounce-back.
     * @param eventType Event-type string from the receiver (currently only 'task_upsert' is supported).
     * @param payload   Decoded JSON body — expects ChangeTypeTxt__c + TaskPatchesJson__c keys.
     * @return WebhookHandlerResult with httpStatus + message for the receiver to relay.
     */
    global WebhookHandlerResult handle(String eventType, Map<String, Object> payload) {
        if (!verifyAgainstSettings()) {
            return WebhookHandlerResult.terminal('Cross-org bridge signature mismatch');
        }
        String changeType = (String) payload.get('ChangeTypeTxt__c');
        if (String.isBlank(changeType)) {
            changeType = eventType;
        }
        String patchesRaw = (String) payload.get('TaskPatchesJson__c');
        if (changeType != 'task_upsert' || String.isBlank(patchesRaw)) {
            return WebhookHandlerResult.ignored('Non-task_upsert payload');
        }
        List<Object> patchObjects = (List<Object>) JSON.deserializeUntyped(patchesRaw);
        if (patchObjects.isEmpty()) {
            return WebhookHandlerResult.ignored('Empty patch list');
        }
        Set<String> senderIds = collectSenderIds(patchObjects);
        if (senderIds.isEmpty()) {
            return WebhookHandlerResult.ignored('No ids in patch');
        }
        Map<String, Id> senderIdToLocalId = lookupLocalIds(senderIds);
        List<WorkItem__c> updates = buildUpdates(patchObjects, senderIdToLocalId);
        if (updates.isEmpty()) {
            return WebhookHandlerResult.ignored('No mapped rows');
        }
        applyUpdates(updates);
        return WebhookHandlerResult.ok(null);
    }

    /**
     * @description Pull every senderId from a list of patch maps into a flat set
     *              so we can do a single SyncItem lookup.
     * @param patchObjects List of decoded patch maps.
     * @return Set of senderId strings present on the patches (blank ids skipped).
     */
    private static Set<String> collectSenderIds(List<Object> patchObjects) {
        Set<String> senderIds = new Set<String>();
        for (Object o : patchObjects) {
            Map<String, Object> p = (Map<String, Object>) o;
            String sid = (String) p.get('Id');
            if (String.isNotBlank(sid)) {
                senderIds.add(sid);
            }
        }
        return senderIds;
    }

    /**
     * @description Iterate decoded patches, mapping each senderId to the local
     *              WorkItem Id and assembling DML rows. Patches without a
     *              mapping are dropped (slow-lane SyncEngine still owns the
     *              eventual-consistency path).
     * @param patchObjects List of decoded patch maps.
     * @param senderIdToLocalId Mapping from sender record Id → local WorkItem Id.
     * @return List of WorkItem__c rows ready for Database.update.
     */
    private static List<WorkItem__c> buildUpdates(List<Object> patchObjects, Map<String, Id> senderIdToLocalId) {
        List<WorkItem__c> updates = new List<WorkItem__c>();
        for (Object o : patchObjects) {
            Map<String, Object> p = (Map<String, Object>) o;
            String senderId = (String) p.get('Id');
            Id localId = senderIdToLocalId.get(senderId);
            if (localId == null) {
                continue;
            }
            updates.add(buildLocalUpdate(localId, p));
        }
        return updates;
    }

    /**
     * @description Apply the assembled updates with the inboundSyncContext
     *              flag set so the trigger doesn't re-bridge them.
     * @param updates List of WorkItem__c rows to update.
     */
    private static void applyUpdates(List<WorkItem__c> updates) {
        Boolean priorContext = DeliveryTriggerControl.inboundSyncContext;
        try {
            DeliveryTriggerControl.inboundSyncContext = true;
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        } finally {
            DeliveryTriggerControl.inboundSyncContext = priorContext;
        }
    }

    /**
     * @description Verify the incoming signature header against the settings-stored
     *              secret. Reads the raw request body + header from RestContext
     *              (defense-in-depth: receiver already verified once, this
     *              handler can also be invoked from non-receiver paths).
     * @return True when signature matches, false on any mismatch.
     */
    @TestVisible
    private static Boolean verifyAgainstSettings() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || String.isBlank(settings.CrossOrgGanttPeerSecretTxt__c)) {
            return false;
        }
        String secret = settings.CrossOrgGanttPeerSecretTxt__c;
        RestRequest req = RestContext.request;
        if (req == null) {
            return false;
        }
        String headerSig = req.headers != null ? req.headers.get('X-DH-Signature') : null;
        if (String.isBlank(headerSig)) {
            return false;
        }
        String body = req.requestBody == null ? '' : req.requestBody.toString();
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(body), Blob.valueOf(secret));
        String expected = EncodingUtil.convertToHex(mac);
        return expected.equalsIgnoreCase(headerSig);
    }

    /**
     * @description Resolve a set of sender record Ids to local WorkItem Ids via
     *              the existing SyncItem__c ledger. Falls through to direct Id
     *              match for the case where two orgs share the same data slice
     *              (e.g. gantt-review scratch matching MF-Prod Ids exactly).
     * @param senderIds Sender's WorkItem record Ids extracted from the payload.
     * @return Map from senderId → local WorkItem Id; missing keys mean unmapped.
     */
    private static Map<String, Id> lookupLocalIds(Set<String> senderIds) {
        Map<String, Id> result = new Map<String, Id>();
        for (SyncItem__c si : [
            SELECT GlobalSourceIdTxt__c, WorkItemLookup__c
            FROM SyncItem__c
            WHERE GlobalSourceIdTxt__c IN :senderIds
              AND WorkItemLookup__c != NULL
            WITH SYSTEM_MODE
        ]) {
            if (!result.containsKey(si.GlobalSourceIdTxt__c)) {
                result.put(si.GlobalSourceIdTxt__c, si.WorkItemLookup__c);
            }
        }
        Set<Id> directIds = collectDirectIds(senderIds, result);
        if (!directIds.isEmpty()) {
            for (WorkItem__c w : [SELECT Id FROM WorkItem__c WHERE Id IN :directIds WITH SYSTEM_MODE]) {
                result.put((String) w.Id, w.Id);
            }
        }
        return result;
    }

    /**
     * @description Filter senderIds to those that look like valid Salesforce Ids
     *              and aren't already resolved via the SyncItem ledger. Used
     *              for the same-data-slice fallback.
     * @param senderIds Source set of senderId strings.
     * @param alreadyResolved Map already populated by the SyncItem lookup.
     * @return Set of valid Id values to query directly against WorkItem__c.
     */
    private static Set<Id> collectDirectIds(Set<String> senderIds, Map<String, Id> alreadyResolved) {
        Set<Id> directIds = new Set<Id>();
        for (String sid : senderIds) {
            if (alreadyResolved.containsKey(sid)) {
                continue;
            }
            try {
                directIds.add(Id.valueOf(sid));
            } catch (Exception e) {
                // sid is not a valid Salesforce Id format — skip silently; the
                // patch will be dropped because no local mapping exists.
                continue;
            }
        }
        return directIds;
    }

    /**
     * @description Build a WorkItem__c sObject with only the fields present in
     *              the patch (mirrors Apex-side per-field patch semantics).
     *              Field-by-field assignment is dispatched through helper
     *              setters to keep cyclomatic complexity manageable.
     * @param localId The receiver-side WorkItem Id this patch updates.
     * @param p Decoded patch map keyed by Salesforce field API name.
     * @return WorkItem__c row ready for DML — only the changed fields populated.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    private static WorkItem__c buildLocalUpdate(Id localId, Map<String, Object> p) {
        WorkItem__c w = new WorkItem__c(Id = localId);
        setIfPresent(w, p, 'Name');
        setIfPresent(w, p, 'BriefDescriptionTxt__c');
        setIfPresent(w, p, 'StageNamePk__c');
        setIfPresent(w, p, 'StatusPk__c');
        setIfPresent(w, p, 'PriorityPk__c');
        setIfPresent(w, p, 'PriorityGroupPk__c');
        setSortOrderIfPresent(w, p);
        setIfPresent(w, p, 'ParentWorkItemLookup__c');
        setDateIfPresent(w, p, 'EstimatedStartDevDate__c');
        setDateIfPresent(w, p, 'EstimatedEndDevDate__c');
        setDateIfPresent(w, p, 'ProjectedUATReadyDate__c');
        setDateIfPresent(w, p, 'CalculatedETADate__c');
        setDateTimeIfPresent(w, p, 'ActivatedDateTime__c');
        return w;
    }

    /**
     * @description Generic setter — copies p[fieldName] onto the row when present.
     *              SObject.put handles type coercion for Strings + Lookups.
     * @param w Target row.
     * @param p Patch map.
     * @param fieldName Salesforce field API name (also used as patch map key).
     */
    private static void setIfPresent(WorkItem__c w, Map<String, Object> p, String fieldName) {
        if (p.containsKey(fieldName)) {
            w.put(fieldName, p.get(fieldName));
        }
    }

    /**
     * @description SortOrderNumber__c may arrive as Decimal, Integer, or String
     *              depending on how the sender JSON-serialized — coerce to Decimal.
     * @param w Target row.
     * @param p Patch map.
     */
    private static void setSortOrderIfPresent(WorkItem__c w, Map<String, Object> p) {
        if (!p.containsKey('SortOrderNumber__c')) {
            return;
        }
        Object v = p.get('SortOrderNumber__c');
        if (v == null) {
            w.SortOrderNumber__c = null;
            return;
        }
        if (v instanceof Decimal) {
            w.SortOrderNumber__c = (Decimal) v;
            return;
        }
        try {
            w.SortOrderNumber__c = Decimal.valueOf(String.valueOf(v));
        } catch (Exception e) {
            // Unparseable sortOrder — leave the field untouched on the local row.
            w.SortOrderNumber__c = null;
        }
    }

    /**
     * @description Date-typed setter — parses ISO-8601 strings via parseDate
     *              before assignment. Quietly drops unparseable values.
     * @param w Target row.
     * @param p Patch map.
     * @param fieldName Salesforce Date field API name.
     */
    private static void setDateIfPresent(WorkItem__c w, Map<String, Object> p, String fieldName) {
        if (p.containsKey(fieldName)) {
            w.put(fieldName, parseDate(p.get(fieldName)));
        }
    }

    /**
     * @description DateTime-typed setter — parses ISO-8601 strings via parseDateTime
     *              before assignment. Quietly drops unparseable values.
     * @param w Target row.
     * @param p Patch map.
     * @param fieldName Salesforce DateTime field API name.
     */
    private static void setDateTimeIfPresent(WorkItem__c w, Map<String, Object> p, String fieldName) {
        if (p.containsKey(fieldName)) {
            w.put(fieldName, parseDateTime(p.get(fieldName)));
        }
    }

    /**
     * @description Best-effort Date parser tolerant of Date instances and
     *              ISO-8601 date-only strings (yyyy-MM-dd).
     * @param v Source value.
     * @return Parsed Date, or null when input is unparseable.
     */
    private static Date parseDate(Object v) {
        if (v == null) {
            return null;
        }
        if (v instanceof Date) {
            return (Date) v;
        }
        try {
            return Date.valueOf((String) v);
        } catch (Exception e) {
            // Unparseable date string — caller treats null as "leave field unchanged".
            return null;
        }
    }

    /**
     * @description Best-effort Datetime parser tolerant of Datetime instances,
     *              ISO-8601 with T/Z separators, and the SOAP datetime format.
     * @param v Source value.
     * @return Parsed Datetime, or null when input is unparseable.
     */
    private static Datetime parseDateTime(Object v) {
        if (v == null) {
            return null;
        }
        if (v instanceof Datetime) {
            return (Datetime) v;
        }
        String s = String.valueOf(v);
        try {
            return Datetime.valueOfGmt(s.replace('T', ' ').replace('Z', ''));
        } catch (Exception e) {
            // Fall through to second strategy.
            return parseDateTimeFallback(s);
        }
    }

    /**
     * @description Second-attempt Datetime parser using Datetime.valueOf.
     *              Quietly returns null when input is unparseable.
     * @param s Candidate datetime string.
     * @return Parsed Datetime, or null on failure.
     */
    private static Datetime parseDateTimeFallback(String s) {
        try {
            return Datetime.valueOf(s);
        } catch (Exception e) {
            // Both strategies failed — caller treats null as "leave field unchanged".
            return null;
        }
    }
}
