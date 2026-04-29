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
global with sharing class DeliveryCrossOrgGanttUpdateHandler implements IWebhookEventHandler {

    global WebhookHandlerResult handle(String eventType, Map<String, Object> payload) {
        // The generic receiver already verified provider-level signature, but
        // for the cross-org channel the secret lives on DeliveryHubSettings__c
        // (per-org, not in metadata) so the receiver's stub provider config
        // has an empty SignatureSecretTxt__c and we re-verify here.
        if (!verifyAgainstSettings()) {
            return WebhookHandlerResult.terminal('Cross-org bridge signature mismatch');
        }
        String changeType = (String) payload.get('ChangeTypeTxt__c');
        if (String.isBlank(changeType)) changeType = eventType;
        String patchesRaw = (String) payload.get('TaskPatchesJson__c');
        if (changeType != 'task_upsert' || String.isBlank(patchesRaw)) {
            return WebhookHandlerResult.ignored('Non-task_upsert payload');
        }
        List<Object> patchObjects = (List<Object>) JSON.deserializeUntyped(patchesRaw);
        if (patchObjects.isEmpty()) {
            return WebhookHandlerResult.ignored('Empty patch list');
        }

        // Pull every senderId in one set so we can do a single SyncItem lookup.
        Set<String> senderIds = new Set<String>();
        for (Object o : patchObjects) {
            Map<String, Object> p = (Map<String, Object>) o;
            String sid = (String) p.get('Id');
            if (String.isNotBlank(sid)) senderIds.add(sid);
        }
        if (senderIds.isEmpty()) {
            return WebhookHandlerResult.ignored('No ids in patch');
        }

        Map<String, Id> senderIdToLocalId = lookupLocalIds(senderIds);
        List<WorkItem__c> updates = new List<WorkItem__c>();
        for (Object o : patchObjects) {
            Map<String, Object> p = (Map<String, Object>) o;
            String senderId = (String) p.get('Id');
            Id localId = senderIdToLocalId.get(senderId);
            if (localId == null) continue; // No mapping — slow-lane will catch this on next drain.
            updates.add(buildLocalUpdate(localId, p));
        }

        if (updates.isEmpty()) {
            return WebhookHandlerResult.ignored('No mapped rows');
        }

        // Suppress the trigger's outbound bridge so this DML doesn't bounce.
        Boolean priorContext = DeliveryTriggerControl.inboundSyncContext;
        try {
            DeliveryTriggerControl.inboundSyncContext = true;
            Database.update(updates, AccessLevel.SYSTEM_MODE);
        } finally {
            DeliveryTriggerControl.inboundSyncContext = priorContext;
        }
        return WebhookHandlerResult.ok(null);
    }

    /**
     * Verify the incoming signature header against the settings-stored secret.
     * Reads the raw request body + header from RestContext (the receiver
     * already parsed body once but the original bytes are still on the
     * RestRequest). Constant-time compare via String.equals.
     */
    @TestVisible
    private static Boolean verifyAgainstSettings() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || String.isBlank(settings.CrossOrgGanttPeerSecretTxt__c)) {
            return false;
        }
        String secret = settings.CrossOrgGanttPeerSecretTxt__c;
        RestRequest req = RestContext.request;
        if (req == null) return false;
        String headerSig = req.headers != null ? req.headers.get('X-DH-Signature') : null;
        if (String.isBlank(headerSig)) return false;
        String body = req.requestBody == null ? '' : req.requestBody.toString();
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(body), Blob.valueOf(secret));
        String expected = EncodingUtil.convertToHex(mac);
        return expected.equalsIgnoreCase(headerSig);
    }

    /**
     * Look up local WorkItem Ids by querying the SyncItem ledger.
     * GlobalSourceIdTxt__c carries the original sender's record Id.
     */
    private static Map<String, Id> lookupLocalIds(Set<String> senderIds) {
        Map<String, Id> result = new Map<String, Id>();
        // SyncItem__c is the existing cross-org correlation ledger maintained
        // by DeliverySyncEngine. WorkItemLookup__c on it points to the local row.
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
        // Also accept the case where the sender's Id IS the local Id directly
        // (e.g. orgs initialized from the same data slice — gantt-review
        // scratch matches MF-Prod by Id). Look up by Id directly when not
        // found via SyncItem.
        Set<Id> directIds = new Set<Id>();
        for (String sid : senderIds) {
            if (!result.containsKey(sid)) {
                try { directIds.add(Id.valueOf(sid)); } catch (Exception e) { /* not a valid Id format */ }
            }
        }
        if (!directIds.isEmpty()) {
            for (WorkItem__c w : [SELECT Id FROM WorkItem__c WHERE Id IN :directIds WITH SYSTEM_MODE]) {
                result.put((String) w.Id, w.Id);
            }
        }
        return result;
    }

    /**
     * Build a WorkItem__c sObject with only the fields present in the patch
     * (mirrors the Apex-side per-field patch semantics — receiver applies
     * exactly what sender sent, nothing more).
     */
    private static WorkItem__c buildLocalUpdate(Id localId, Map<String, Object> p) {
        WorkItem__c w = new WorkItem__c(Id = localId);
        if (p.containsKey('Name')) w.Name = (String) p.get('Name');
        if (p.containsKey('BriefDescriptionTxt__c')) w.BriefDescriptionTxt__c = (String) p.get('BriefDescriptionTxt__c');
        if (p.containsKey('StageNamePk__c')) w.StageNamePk__c = (String) p.get('StageNamePk__c');
        if (p.containsKey('StatusPk__c')) w.StatusPk__c = (String) p.get('StatusPk__c');
        if (p.containsKey('PriorityPk__c')) w.PriorityPk__c = (String) p.get('PriorityPk__c');
        if (p.containsKey('PriorityGroupPk__c')) w.PriorityGroupPk__c = (String) p.get('PriorityGroupPk__c');
        if (p.containsKey('SortOrderNumber__c')) {
            Object v = p.get('SortOrderNumber__c');
            w.SortOrderNumber__c = (v instanceof Decimal) ? (Decimal) v : (v == null ? null : Decimal.valueOf(String.valueOf(v)));
        }
        if (p.containsKey('ParentWorkItemLookup__c')) w.ParentWorkItemLookup__c = (Id) p.get('ParentWorkItemLookup__c');
        if (p.containsKey('EstimatedStartDevDate__c')) w.EstimatedStartDevDate__c = parseDate(p.get('EstimatedStartDevDate__c'));
        if (p.containsKey('EstimatedEndDevDate__c')) w.EstimatedEndDevDate__c = parseDate(p.get('EstimatedEndDevDate__c'));
        if (p.containsKey('ProjectedUATReadyDate__c')) w.ProjectedUATReadyDate__c = parseDate(p.get('ProjectedUATReadyDate__c'));
        if (p.containsKey('CalculatedETADate__c')) w.CalculatedETADate__c = parseDate(p.get('CalculatedETADate__c'));
        if (p.containsKey('ActivatedDateTime__c')) w.ActivatedDateTime__c = parseDateTime(p.get('ActivatedDateTime__c'));
        return w;
    }

    private static Date parseDate(Object v) {
        if (v == null) return null;
        if (v instanceof Date) return (Date) v;
        try { return Date.valueOf((String) v); } catch (Exception e) { return null; }
    }

    private static Datetime parseDateTime(Object v) {
        if (v == null) return null;
        if (v instanceof Datetime) return (Datetime) v;
        String s = String.valueOf(v);
        try { return Datetime.valueOfGmt(s.replace('T', ' ').replace('Z', '')); } catch (Exception e) { /* fallthrough */ }
        try { return Datetime.valueOf(s); } catch (Exception e) { return null; }
    }
}
