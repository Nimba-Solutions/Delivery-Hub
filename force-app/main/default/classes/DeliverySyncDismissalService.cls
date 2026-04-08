/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Dismiss / restore / auto-age Failed SyncItem__c records.
 *              Dismissal is orthogonal to status — items keep StatusPk__c='Failed'
 *              but get DismissedDateTime__c set, which excludes them from
 *              Sync Health % and the default failed-sync retry panel view.
 *              Manual dismissal is gated to Modify All Data; the auto-aging
 *              path runs from DeliveryHubScheduler with no caller permission
 *              check (it's the system acting on its own).
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliverySyncDismissalService {

    private static final String COMPONENT_NAME = 'DeliverySyncDismissalService';
    // ActivityLog__c.ActionTypePk__c is a restricted picklist; the operation
    // (Manual / Auto / Restore) is discriminated via ContextDataTxt__c instead
    // so we don't have to grow the picklist.
    private static final String AUDIT_ACTION_TYPE = 'Feature_Use';

    /**
     * @description Marks the given Failed SyncItem__c records as dismissed.
     *              Only items currently in 'Failed' status with DismissedDateTime__c
     *              still null are touched — already-dismissed and non-failed
     *              items are silently skipped so callers can pass mixed lists.
     * @param ids Set of SyncItem__c Ids to dismiss.
     * @param reason Free-text reason persisted on each updated row and audit log.
     * @return Count of records actually dismissed.
     */
    public static Integer dismiss(Set<Id> ids, String reason) {
        requireDismissPermission();
        if (ids == null || ids.isEmpty()) {
            return 0;
        }
        return dismissInternal(ids, reason, 'Manual');
    }

    /**
     * @description Restores previously dismissed items by clearing
     *              DismissedDateTime__c. Status is unchanged — restored items
     *              re-appear in the failed-sync panel and dashboard health
     *              calculations exactly as they were before dismissal.
     * @param ids Set of SyncItem__c Ids to restore.
     * @return Count of records actually restored.
     */
    public static Integer restore(Set<Id> ids) {
        requireDismissPermission();
        if (ids == null || ids.isEmpty()) {
            return 0;
        }
        List<SyncItem__c> toRestore = new List<SyncItem__c>();
        for (SyncItem__c si : [
            SELECT Id FROM SyncItem__c
            WHERE Id IN :ids AND DismissedDateTime__c != NULL
            WITH SYSTEM_MODE
        ]) {
            toRestore.add(new SyncItem__c(Id = si.Id, DismissedDateTime__c = null));
        }
        if (toRestore.isEmpty()) {
            return 0;
        }
        Database.update(toRestore, AccessLevel.SYSTEM_MODE);
        writeAuditLog('SyncRestore', toRestore.size(), null, ids);
        return toRestore.size();
    }

    /**
     * @description Auto-dismisses Failed sync items whose retries are exhausted
     *              and whose LastModifiedDate is older than
     *              FailedSyncAutoDismissDaysNumber__c. Called from
     *              DeliveryHubScheduler.execute(). Returns 0 (no-op) when the
     *              setting is null or 0 — auto-aging is opt-in.
     * @return Count of records auto-dismissed.
     */
    public static Integer dismissAged() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.FailedSyncAutoDismissDaysNumber__c == null
            || settings.FailedSyncAutoDismissDaysNumber__c <= 0) {
            return 0;
        }
        Integer ageDays = (Integer) settings.FailedSyncAutoDismissDaysNumber__c;
        Integer maxRetries = settings.SyncRetryLimitNumber__c != null
            ? (Integer) settings.SyncRetryLimitNumber__c : 3;
        Datetime cutoff = Datetime.now().addDays(-ageDays);

        Set<Id> agedIds = new Set<Id>();
        for (SyncItem__c si : [
            SELECT Id FROM SyncItem__c
            WHERE StatusPk__c = 'Failed'
            AND DismissedDateTime__c = NULL
            AND LastModifiedDate < :cutoff
            AND RetryCountNumber__c >= :maxRetries
            WITH SYSTEM_MODE
            LIMIT 200
        ]) {
            agedIds.add(si.Id);
        }
        if (agedIds.isEmpty()) {
            return 0;
        }
        return dismissInternal(agedIds, 'Auto-aged after ' + ageDays + ' days', 'Auto');
    }

    // ── Internals ───────────────────────────────────────────────────────────

    /**
     * @description Shared write path used by both manual and auto dismissal.
     *              Skips items already dismissed or not in Failed status to keep
     *              the operation idempotent.
     * @param ids Candidate Ids.
     * @param reason Reason persisted on the audit log.
     * @param mode 'Manual' or 'Auto' — discriminator for the audit log only.
     * @return Number of rows updated.
     */
    private static Integer dismissInternal(Set<Id> ids, String reason, String mode) {
        Datetime now = Datetime.now();
        List<SyncItem__c> toDismiss = new List<SyncItem__c>();
        for (SyncItem__c si : [
            SELECT Id FROM SyncItem__c
            WHERE Id IN :ids
            AND StatusPk__c = 'Failed'
            AND DismissedDateTime__c = NULL
            WITH SYSTEM_MODE
        ]) {
            toDismiss.add(new SyncItem__c(Id = si.Id, DismissedDateTime__c = now));
        }
        if (toDismiss.isEmpty()) {
            return 0;
        }
        Database.update(toDismiss, AccessLevel.SYSTEM_MODE);
        Set<Id> dismissedIds = new Set<Id>();
        for (SyncItem__c si : toDismiss) {
            dismissedIds.add(si.Id);
        }
        writeAuditLog('SyncDismiss-' + mode, toDismiss.size(), reason, dismissedIds);
        return toDismiss.size();
    }

    /**
     * @description Writes a single ActivityLog__c row summarizing the bulk operation.
     *              ActionTypePk__c is the generic 'Feature_Use' picklist value;
     *              the operation discriminator (SyncDismiss-Manual, SyncDismiss-Auto,
     *              SyncRestore) lives in ContextDataTxt__c.operation. Failure to
     *              write is swallowed — the underlying dismissal/restore must
     *              never be aborted by an audit-log issue.
     * @param operation Discriminator string ('SyncDismiss-Manual', 'SyncDismiss-Auto', 'SyncRestore').
     * @param count Number of records affected.
     * @param reason Optional reason supplied by the caller.
     * @param ids Set of affected SyncItem__c Ids (serialized into ContextDataTxt__c).
     */
    private static void writeAuditLog(String operation, Integer count, String reason, Set<Id> ids) {
        try {
            Map<String, Object> ctx = new Map<String, Object>{
                'operation' => operation,
                'count'     => count,
                'reason'    => reason,
                'ids'       => new List<Id>(ids)
            };
            Database.insert(new ActivityLog__c(
                ActionTypePk__c     = AUDIT_ACTION_TYPE,
                ComponentNameTxt__c = COMPONENT_NAME,
                UserIdTxt__c        = UserInfo.getUserId(),
                ContextDataTxt__c   = JSON.serialize(ctx)
            ), AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliverySyncDismissalService] audit log write failed: ' + e.getMessage());
        }
    }

    /**
     * @description Throws AuraHandledException if the running user is neither
     *              a sysadmin (ModifyAllData) nor assigned to the DeliveryHubAdmin
     *              permission set group. The auto-aging path bypasses this entirely
     *              because it is called from DeliveryHubScheduler in system context.
     */
    private static void requireDismissPermission() {
        if (isCurrentUserDismissAdmin()) {
            return;
        }
        throw new AuraHandledException('Only administrators can dismiss or restore sync items.');
    }

    /**
     * @description True when the running user has Modify All Data on their profile
     *              OR is assigned to the DeliveryHubAdmin permission set group.
     *              Single SOQL — guarded so a user with neither falls through to false.
     * @return Whether the current user may dismiss/restore.
     */
    @TestVisible
    private static Boolean isCurrentUserDismissAdmin() {
        Id userId = UserInfo.getUserId();
        for (User u : [
            SELECT Id, Profile.PermissionsModifyAllData
            FROM User WHERE Id = :userId
            WITH SYSTEM_MODE LIMIT 1
        ]) {
            if (u.Profile != null && u.Profile.PermissionsModifyAllData == true) {
                return true;
            }
        }
        return ![
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSetGroup.DeveloperName = 'DeliveryHubAdmin'
            WITH SYSTEM_MODE LIMIT 1
        ].isEmpty();
    }
}
