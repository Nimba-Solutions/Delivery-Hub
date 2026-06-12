/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Trigger handler for WorkLog__c. On insert, queues an outbound SyncItem__c
 *              for each WorkLog whose parent Work Item has a client Network Entity linked.
 *              When approval is required (RequireWorkLogApprovalDateTime__c is set), only
 *              Approved WorkLogs generate SyncItems. Draft logs sync on approval via
 *              onAfterUpdate.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryWorkLogTriggerHandler {

    /**
     * @description Auto-populates ResourceTitleTxt__c from the running user's Title
     *              if not already set. Runs before insert so the value is saved with the record.
     * @param newLogs List of WorkLog__c records being inserted.
     */
    public static void onBeforeInsert(List<WorkLog__c> newLogs) {
        // Client-approved-cap gate (PR5): addError must happen in the BEFORE
        // context, so this runs ahead of the settings-dependent defaults below.
        DeliveryWorkCapEnforcementService.checkInserts(newLogs);

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null) {
            return;
        }

        // Require parent Work Item — prevents orphaned logs that drop off invoices
        for (WorkLog__c wl : newLogs) {
            if (wl.WorkItemLookup__c == null) {
                wl.addError('A Work Item is required. Work logs without a parent work item are excluded from invoices and reports.');
            }
        }

        // Default WorkDateDate__c to today when missing — extracted to helper to keep
        // onBeforeInsert under PMD's NCSS line-count threshold.
        defaultWorkDate(newLogs);

        // Enforce hour lockout for billing periods
        enforceLockout(newLogs, settings);

        // Auto-fill resource title (if enabled)
        if (settings.EnableResourceTitleAutoFillDateTime__c == null) {
            return;
        }

        // Collect work item IDs to resolve client entity context
        Set<Id> workItemIds = new Set<Id>();
        for (WorkLog__c wl : newLogs) {
            if (String.isBlank(wl.ResourceTitleTxt__c) && wl.WorkItemLookup__c != null) {
                workItemIds.add(wl.WorkItemLookup__c);
            }
        }
        if (workItemIds.isEmpty()) {
            return;
        }

        // Build workItemId → clientEntityId map
        Map<Id, Id> itemToEntityMap = new Map<Id, Id>();
        for (WorkItem__c wi : [
            SELECT Id, ClientNetworkEntityLookup__c FROM WorkItem__c
            WHERE Id IN :workItemIds WITH SYSTEM_MODE
        ]) {
            itemToEntityMap.put(wi.Id, wi.ClientNetworkEntityLookup__c);
        }

        // Find last used title per entity for this user
        Map<Id, String> entityTitleMap = new Map<Id, String>();
        for (WorkLog__c recent : [
            SELECT ResourceTitleTxt__c, WorkItemLookup__r.ClientNetworkEntityLookup__c
            FROM WorkLog__c
            WHERE CreatedById = :UserInfo.getUserId()
            AND ResourceTitleTxt__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            Id entityId = recent.WorkItemLookup__r.ClientNetworkEntityLookup__c;
            if (entityId != null && !entityTitleMap.containsKey(entityId)) {
                entityTitleMap.put(entityId, recent.ResourceTitleTxt__c);
            }
        }

        String userTitle = null;
        List<User> currentUser = [SELECT Title FROM User WHERE Id = :UserInfo.getUserId() WITH SYSTEM_MODE LIMIT 1];
        if (!currentUser.isEmpty()) {
            userTitle = currentUser[0].Title;
        }

        for (WorkLog__c wl : newLogs) {
            if (String.isNotBlank(wl.ResourceTitleTxt__c)) {
                continue;
            }
            // Priority: last title for this engagement > User.Title
            Id entityId = itemToEntityMap.get(wl.WorkItemLookup__c);
            String contextTitle = entityId != null ? entityTitleMap.get(entityId) : null;
            if (String.isNotBlank(contextTitle)) {
                wl.ResourceTitleTxt__c = contextTitle;
            } else if (String.isNotBlank(userTitle)) {
                wl.ResourceTitleTxt__c = userTitle;
            }
        }
    }

    /**
     * @description Cap-enforcement gate for updates (PR5): re-evaluates rows
     *              whose hours or parent item changed against the client-
     *              approved cap. Runs before update so over-cap rows can be
     *              blocked with addError when enforcement is on.
     * @param newLogs List of WorkLog__c records being updated.
     * @param oldMap Map of pre-update WorkLog__c records keyed by Id.
     */
    public static void onBeforeUpdate(List<WorkLog__c> newLogs, Map<Id, WorkLog__c> oldMap) {
        DeliveryWorkCapEnforcementService.checkUpdates(newLogs, oldMap);
    }

    /**
     * @description Processes newly inserted WorkLog records and creates outbound sync items
     *              for those tied to client-linked work items. When approval is required,
     *              only logs with StatusPk__c = 'Approved' (or null for backward compat)
     *              generate sync items.
     * @param newLogs List of newly inserted WorkLog__c records.
     */
    public static void onAfterInsert(List<WorkLog__c> newLogs) {
        // Drain flag-mode cap side effects now that the rows are committed.
        // The service honors runAfterLogic internally AND clears its buffer
        // either way, so it must run ahead of the guard below.
        DeliveryWorkCapEnforcementService.processPendingFlags();
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        DeliveryFieldTrackingService.trackCreates(newLogs);
        List<WorkLog__c> eligible = filterEligibleForSync(newLogs);
        if (eligible.isEmpty()) {
            return;
        }
        createSyncItemsForLogs(eligible);
    }

    /**
     * @description Processes updated WorkLog records. When a log transitions to 'Approved',
     *              creates outbound sync items (the approval → sync trigger).
     * @param newLogs List of updated WorkLog__c records.
     * @param oldMap Map of old WorkLog__c records keyed by Id.
     */
    public static void onAfterUpdate(List<WorkLog__c> newLogs, Map<Id, WorkLog__c> oldMap) {
        // Drain flag-mode cap side effects (see onAfterInsert).
        DeliveryWorkCapEnforcementService.processPendingFlags();
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        DeliveryFieldTrackingService.trackChanges(newLogs, oldMap);
        List<WorkLog__c> newlyApproved = new List<WorkLog__c>();
        for (WorkLog__c wl : newLogs) {
            WorkLog__c old = oldMap.get(wl.Id);
            if (wl.StatusPk__c == 'Approved' && old.StatusPk__c != 'Approved') {
                newlyApproved.add(wl);
            }
        }
        if (newlyApproved.isEmpty()) {
            return;
        }
        createSyncItemsForLogs(newlyApproved);
    }

    // ── Field defaults ─────────────────────────────────────────────────

    /**
     * @description Defaults WorkDateDate__c to today when null. System Pulse "Hours This Month"
     *              and reports filter on this field, so a null value silently dropped logs from
     *              totals. New logs going forward are always included; older logs heal forward.
     * @param logs The WorkLog__c records being inserted.
     */
    private static void defaultWorkDate(List<WorkLog__c> logs) {
        Date today = Date.today();
        for (WorkLog__c wl : logs) {
            if (wl.WorkDateDate__c == null) {
                wl.WorkDateDate__c = today;
            }
        }
    }

    // ── Hour lockout enforcement ────────────────────────────────────────

    private static void enforceLockout(List<WorkLog__c> logs, DeliveryHubSettings__c settings) {
        if (settings.InvoiceHourLockoutDayNumber__c == null) {
            return;
        }
        Integer lockoutDay = (Integer) settings.InvoiceHourLockoutDayNumber__c;
        Integer lockoutHour = settings.InvoiceHourLockoutTimeNumber__c != null
            ? (Integer) settings.InvoiceHourLockoutTimeNumber__c : 22; // default 5pm EST

        Datetime now = Datetime.now();
        Integer todayDay = now.dayGmt();
        Integer todayHour = now.hourGmt();
        Boolean pastLockout = todayDay > lockoutDay || (todayDay == lockoutDay && todayHour >= lockoutHour);

        if (!pastLockout) {
            return;
        }

        // After lockout: block work logs for the prior month
        Date priorMonthEnd = Date.today().toStartOfMonth().addDays(-1);
        for (WorkLog__c wl : logs) {
            if (wl.WorkDateDate__c != null && wl.WorkDateDate__c <= priorMonthEnd) {
                wl.addError('Hours for ' + priorMonthEnd.month() + '/' + priorMonthEnd.year()
                    + ' are locked. Entries must be submitted by day '
                    + lockoutDay + ' at ' + lockoutHour + ':00 UTC.');
            }
        }
    }

    // ── Shared sync item creation ──────────────────────────────────────

    /**
     * @description Delegates outbound relay minting to DeliveryWorkLogRelayMinter.
     *              The mint path lives in a dedicated `without sharing` class because
     *              inbound worklogs arrive via REST under the Site Guest User, whose
     *              record access is forced Private — inside this `with sharing`
     *              handler the WITH SYSTEM_MODE eligibility queries (FLS bypass only,
     *              sharing still enforced) returned empty and no relay was minted
     *              (2026-06 nimba: 65 rows / 138.5h never reached the billing org).
     * @param logs Sync-eligible WorkLog__c records (approval gate already applied).
     */
    private static void createSyncItemsForLogs(List<WorkLog__c> logs) {
        DeliveryWorkLogRelayMinter.mintForLogs(logs);
    }

    // ── Approval gate filter ───────────────────────────────────────────

    /**
     * @description Filters WorkLogs eligible for immediate sync on insert.
     *              When approval is required, only 'Approved' logs pass.
     *              When approval is NOT required (default), all logs pass
     *              (null StatusPk__c treated as Approved for backward compat).
     * @param logs The WorkLog records to filter.
     * @return Filtered list of WorkLogs eligible for sync.
     */
    private static List<WorkLog__c> filterEligibleForSync(List<WorkLog__c> logs) {
        if (!isApprovalRequired()) {
            return logs;
        }
        List<WorkLog__c> eligible = new List<WorkLog__c>();
        for (WorkLog__c wl : logs) {
            // Null status = legacy log created before approval was enabled → treat as Approved
            if (wl.StatusPk__c == null || wl.StatusPk__c == 'Approved') {
                eligible.add(wl);
            }
        }
        return eligible;
    }

    /**
     * @description Checks whether WorkLog approval is required based on the
     *              org-level DeliveryHubSettings__c.RequireWorkLogApprovalDateTime__c.
     * @return true when the DateTime field is populated (approval policy is active).
     */
    public static Boolean isApprovalRequired() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings.RequireWorkLogApprovalDateTime__c != null;
    }

}
