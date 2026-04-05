/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Utility service that reads TrackedField__mdt configuration and
 *               automatically detects field value changes on SObject records,
 *               delegating to DeliveryFieldChangeService for persistent logging.
 *               Designed to be called from trigger handlers (after update context).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryFieldTrackingService {

    /** @description Cached list of enabled tracked field configurations, queried once per transaction. */
    private static List<TrackedField__mdt> cachedTrackedFields;

    /** @description Captures the last batch of change requests for test verification. */
    @TestVisible
    private static List<DeliveryFieldChangeService.FieldChangeRequest> lastChangeRequests;

    /**
     * @description Logs creation of records. For each tracked field on the object,
     *              logs the initial value as a field change with dmlType = Created.
     *              Safe to call from any after-insert trigger context. Returns silently
     *              when field tracking is disabled via DeliveryHubSettings__c.
     * @param newRecords The list of newly inserted SObject records (Trigger.new).
     */
    public static void trackCreates(List<SObject> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || settings.EnableFieldTrackingDateTime__c == null) {
            return;
        }

        String objectApiName = newRecords[0].getSObjectType().getDescribe().getLocalName();
        List<TrackedField__mdt> trackedFields = getTrackedFieldsForObject(objectApiName);
        if (trackedFields.isEmpty()) {
            return;
        }

        List<DeliveryFieldChangeService.FieldChangeRequest> changeRequests =
            new List<DeliveryFieldChangeService.FieldChangeRequest>();

        for (SObject newRecord : newRecords) {
            for (TrackedField__mdt tf : trackedFields) {
                Object newValue = newRecord.get(tf.FieldApiName__c);
                DeliveryFieldChangeService.FieldChangeRequest req =
                    new DeliveryFieldChangeService.FieldChangeRequest();
                req.recordId   = newRecord.Id;
                req.fieldName  = tf.FieldApiName__c;
                req.fieldLabel = tf.FieldLabel__c;
                req.objectName = objectApiName;
                req.oldValue   = null;
                req.newValue   = newValue != null ? String.valueOf(newValue) : null;
                req.extraContext = '{"dmlType":"Created"}';
                changeRequests.add(req);
            }
        }

        if (!changeRequests.isEmpty()) {
            lastChangeRequests = changeRequests;
            DeliveryFieldChangeService.captureFieldChanges(changeRequests);
        }
    }

    /**
     * @description Logs deletion of records. For each tracked field on the object,
     *              logs the final value as a field change with dmlType = Deleted.
     *              Safe to call from any before-delete trigger context. Returns silently
     *              when field tracking is disabled via DeliveryHubSettings__c.
     * @param oldRecords The list of SObject records being deleted (Trigger.old).
     */
    public static void trackDeletes(List<SObject> oldRecords) {
        if (oldRecords == null || oldRecords.isEmpty()) {
            return;
        }

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || settings.EnableFieldTrackingDateTime__c == null) {
            return;
        }

        String objectApiName = oldRecords[0].getSObjectType().getDescribe().getLocalName();
        List<TrackedField__mdt> trackedFields = getTrackedFieldsForObject(objectApiName);
        if (trackedFields.isEmpty()) {
            return;
        }

        List<DeliveryFieldChangeService.FieldChangeRequest> changeRequests =
            new List<DeliveryFieldChangeService.FieldChangeRequest>();

        for (SObject oldRecord : oldRecords) {
            for (TrackedField__mdt tf : trackedFields) {
                Object oldValue = oldRecord.get(tf.FieldApiName__c);
                DeliveryFieldChangeService.FieldChangeRequest req =
                    new DeliveryFieldChangeService.FieldChangeRequest();
                req.recordId   = oldRecord.Id;
                req.fieldName  = tf.FieldApiName__c;
                req.fieldLabel = tf.FieldLabel__c;
                req.objectName = objectApiName;
                req.oldValue   = oldValue != null ? String.valueOf(oldValue) : null;
                req.newValue   = null;
                req.extraContext = '{"dmlType":"Deleted"}';
                changeRequests.add(req);
            }
        }

        if (!changeRequests.isEmpty()) {
            lastChangeRequests = changeRequests;
            DeliveryFieldChangeService.captureFieldChanges(changeRequests);
        }
    }

    /**
     * @description Compares old and new field values for every enabled TrackedField__mdt
     *              record that matches the SObject type of the given records. For each
     *              detected change, builds a FieldChangeRequest and delegates to
     *              DeliveryFieldChangeService.captureFieldChanges().
     *
     *              Safe to call from any after-update trigger context. Returns silently
     *              when field tracking is disabled via DeliveryHubSettings__c.
     *
     * @param newRecords The list of SObject records in their updated state (Trigger.new).
     * @param oldMap     The map of SObject records in their prior state (Trigger.oldMap).
     */
    public static void trackChanges(List<SObject> newRecords, Map<Id, SObject> oldMap) {
        if (newRecords == null || newRecords.isEmpty() || oldMap == null) {
            return;
        }

        // Gate: check org-level setting
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || settings.EnableFieldTrackingDateTime__c == null) {
            return;
        }

        // Determine the SObject type from the first record
        String objectApiName = newRecords[0].getSObjectType().getDescribe().getLocalName();

        // Get tracked fields for this object
        List<TrackedField__mdt> trackedFields = getTrackedFieldsForObject(objectApiName);
        if (trackedFields.isEmpty()) {
            return;
        }

        // Compare old vs new and build change requests
        List<DeliveryFieldChangeService.FieldChangeRequest> changeRequests =
            new List<DeliveryFieldChangeService.FieldChangeRequest>();

        for (SObject newRecord : newRecords) {
            SObject oldRecord = oldMap.get(newRecord.Id);
            if (oldRecord == null) {
                continue;
            }

            for (TrackedField__mdt tf : trackedFields) {
                Object oldValue = oldRecord.get(tf.FieldApiName__c);
                Object newValue = newRecord.get(tf.FieldApiName__c);

                if (oldValue != newValue) {
                    DeliveryFieldChangeService.FieldChangeRequest req =
                        new DeliveryFieldChangeService.FieldChangeRequest();
                    req.recordId   = newRecord.Id;
                    req.fieldName  = tf.FieldApiName__c;
                    req.fieldLabel = tf.FieldLabel__c;
                    req.objectName = objectApiName;
                    req.oldValue   = oldValue != null ? String.valueOf(oldValue) : null;
                    req.newValue   = newValue != null ? String.valueOf(newValue) : null;
                    changeRequests.add(req);
                }
            }
        }

        if (!changeRequests.isEmpty()) {
            lastChangeRequests = changeRequests;
            DeliveryFieldChangeService.captureFieldChanges(changeRequests);
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────

    /**
     * @description Returns the list of enabled TrackedField__mdt records that match
     *              the given object API name. Uses a static cache to avoid repeated
     *              SOQL queries within the same transaction.
     * @param objectApiName The API name of the SObject to filter by.
     * @return List of matching TrackedField__mdt records, sorted by SortOrderNumber__c.
     */
    private static List<TrackedField__mdt> getTrackedFieldsForObject(String objectApiName) {
        if (cachedTrackedFields == null) {
            cachedTrackedFields = [
                SELECT ObjectApiName__c, FieldApiName__c, FieldLabel__c, SortOrderNumber__c
                FROM TrackedField__mdt
                WHERE EnabledDateTime__c != null
                WITH SYSTEM_MODE
                ORDER BY SortOrderNumber__c ASC
            ];
        }

        List<TrackedField__mdt> result = new List<TrackedField__mdt>();
        for (TrackedField__mdt tf : cachedTrackedFields) {
            if (tf.ObjectApiName__c == objectApiName) {
                result.add(tf);
            }
        }
        return result;
    }

    /**
     * @description Clears the cached TrackedField__mdt records. Exposed for test
     *              isolation so each test method starts with a fresh cache.
     */
    @TestVisible
    private static void clearCache() {
        cachedTrackedFields = null;
    }
}
