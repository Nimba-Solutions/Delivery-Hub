/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  PR5 (billing close-out) of the work-approval queue: enforces
 *               the client-approved hours cap (WorkItem__c.
 *               ClientPreApprovedHoursNumber__c, stamped by
 *               DeliveryWorkApprovalService) at WorkLog__c time.
 *
 *               Two postures, gated by DeliveryHubSettings__c.
 *               EnforceApprovalCapDateTime__c:
 *
 *               FLAG MODE (the default — setting is null): an over-cap log
 *               still SAVES, but the item's newest Accepted WorkRequest__c
 *               moves to StatusPk__c='Budget Hold' and one bell notification
 *               goes to the org-default approver (ApproverUserIdTxt__c) plus
 *               the item's assigned developer. Flag mode never throws — every
 *               side effect is WARN-logged on failure.
 *
 *               ENFORCE MODE (setting populated): the offending row gets
 *               addError() in the BEFORE context, so the over-cap log never
 *               commits. The unblock path is the shipped
 *               DeliveryWorkApprovalService.requestIncrease(...) → approve(...)
 *               flow, which raises the cap by the approved delta only.
 *
 *               Execution is split across trigger contexts because addError
 *               only works BEFORE the DML while the flag-mode side effects
 *               (request update + queueable) must run AFTER the WorkLog row is
 *               in the database: checkInserts/checkUpdates run in before
 *               insert/update and stash flag-mode work in a static buffer;
 *               processPendingFlags() drains that buffer in after
 *               insert/update.
 *
 *               Logged totals are summed LIVE from WorkLog__c —
 *               WorkItem__c.TotalLoggedHoursSum__c is a rollup and cannot be
 *               trusted mid-transaction. Items with a null/zero cap are
 *               uncapped and never evaluated. All SOQL is WITH SYSTEM_MODE per
 *               CLAUDE.md (WITH USER_MODE breaks in namespaced package test
 *               context).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity')
public with sharing class DeliveryWorkCapEnforcementService {

    /** WorkRequest__c lifecycle value consumed by the flag path (verified picklist value). */
    public static final String REQUEST_ACCEPTED = 'Accepted';

    /** WorkRequest__c lifecycle value written by the flag path (verified picklist value). */
    public static final String REQUEST_BUDGET_HOLD = 'Budget Hold';

    /** Hard cap on existing-log rows scanned per evaluation. */
    private static final Integer MAX_LOG_ROWS = 10000;

    /** Hard cap on Accepted-request rows scanned by the flag path. */
    private static final Integer MAX_REQUEST_ROWS = 1000;

    /**
     * Before-context stash keyed by WorkItem id (one flag per item per
     * transaction chunk), drained by processPendingFlags() in after context.
     */
    private static Map<Id, PendingFlag> pendingFlags = new Map<Id, PendingFlag>();

    /**
     * @description One over-cap work item flagged in the before context,
     *              awaiting its after-commit side effects (Budget Hold +
     *              notification). Internal carrier only.
     */
    private class PendingFlag {
        private Id workItemId;
        private String itemLabel;
        private Decimal cap;
        private Decimal total;
        private Id developerId;
    }

    // ────────────────────────────────────────────────────────────────────
    // BEFORE-CONTEXT ENTRY POINTS
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Evaluates WorkLog__c rows being INSERTED against their
     *              parent items' client-approved caps. Enforce mode addErrors
     *              the offending rows; flag mode stashes after-commit work.
     *              Call from BEFORE INSERT.
     * @param rows Trigger.new in before insert (no ids yet).
     */
    public static void checkInserts(List<WorkLog__c> rows) {
        evaluate(rows, null);
    }

    /**
     * @description Evaluates WorkLog__c rows being UPDATED against their
     *              parent items' client-approved caps. Only rows whose hours
     *              or parent item changed are evaluated, so unrelated edits to
     *              an already-over-cap log are never blocked. Call from
     *              BEFORE UPDATE.
     * @param rows Trigger.new in before update.
     * @param oldMap Trigger.oldMap (pre-update values).
     */
    public static void checkUpdates(List<WorkLog__c> rows, Map<Id, WorkLog__c> oldMap) {
        evaluate(rows, oldMap);
    }

    // ────────────────────────────────────────────────────────────────────
    // AFTER-CONTEXT ENTRY POINT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Drains the flag-mode buffer AFTER the WorkLog DML has
     *              committed: moves each flagged item's newest Accepted
     *              WorkRequest__c to 'Budget Hold' and enqueues one
     *              DeliveryNotificationQueueable per item to the org-default
     *              approver + the item's assigned developer. Never throws —
     *              flag mode must not abort the caller's save; failures are
     *              WARN-logged. Honors DeliveryTriggerControl.runAfterLogic
     *              like sibling after-handlers (the buffer is still cleared so
     *              suppressed flags cannot leak into a later DML). Call from
     *              AFTER INSERT / AFTER UPDATE.
     */
    public static void processPendingFlags() {
        if (pendingFlags.isEmpty()) {
            return;
        }
        Map<Id, PendingFlag> flags = pendingFlags;
        pendingFlags = new Map<Id, PendingFlag>();
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        moveAcceptedRequestsToBudgetHold(flags.keySet());
        notifyOverCap(flags.values());
    }

    // ────────────────────────────────────────────────────────────────────
    // EVALUATION CORE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Shared bulkified evaluation: loads each parent item's cap
     *              (skipping uncapped items), sums existing logged hours live
     *              from WorkLog__c (excluding the in-flight rows themselves),
     *              then walks the incoming rows accumulating a running total
     *              per item so several rows in ONE batch cannot collectively
     *              sneak past the cap. Inbound-sync DML is exempt — relayed
     *              logs were already evaluated at their origin org and must
     *              not be blocked mid-sync.
     * @param rows The WorkLog__c rows being saved.
     * @param oldMap Pre-update values (null on insert).
     */
    private static void evaluate(List<WorkLog__c> rows, Map<Id, WorkLog__c> oldMap) {
        if (rows == null || rows.isEmpty() || DeliveryTriggerControl.inboundSyncContext) {
            return;
        }
        List<WorkLog__c> candidates = collectCandidates(rows, oldMap);
        if (candidates.isEmpty()) {
            return;
        }
        Map<Id, WorkItem__c> cappedItems = loadCappedItems(candidateItemIds(candidates));
        if (cappedItems.isEmpty()) {
            return;
        }

        Map<Id, Decimal> runningTotals =
            sumExistingLoggedHours(cappedItems.keySet(), candidateLogIds(candidates));
        applyCapRules(candidates, cappedItems, runningTotals);
    }

    /**
     * @description Walks the candidate rows in batch order, accumulating a
     *              running per-item total (live DB sum + committing deltas) so
     *              several rows in ONE batch cannot collectively sneak past
     *              the cap. Over-cap rows are addError'd in enforce mode
     *              (blocked rows stay OUT of the running total — a later
     *              under-cap row in the same batch still passes) or stashed
     *              for after-commit flagging in flag mode.
     * @param candidates The rows requiring cap evaluation.
     * @param cappedItems The capped parent items by id (uncapped absent).
     * @param runningTotals Per-item persisted totals, mutated as rows commit.
     */
    private static void applyCapRules(
        List<WorkLog__c> candidates, Map<Id, WorkItem__c> cappedItems, Map<Id, Decimal> runningTotals
    ) {
        Boolean enforce = isEnforcementOn();
        for (WorkLog__c wl : candidates) {
            WorkItem__c item = cappedItems.get(wl.WorkItemLookup__c);
            if (item == null) {
                continue; // uncapped item — never enforced
            }
            Decimal cap = item.ClientPreApprovedHoursNumber__c;
            Decimal logged = runningTotals.containsKey(item.Id) ? runningTotals.get(item.Id) : 0;
            Decimal delta = wl.HoursLoggedNumber__c == null ? 0 : wl.HoursLoggedNumber__c;
            Decimal newTotal = logged + delta;

            if (newTotal <= cap) {
                runningTotals.put(item.Id, newTotal);
                continue;
            }
            if (enforce) {
                // Blocked row never commits — keep it OUT of the running total
                // so a later under-cap row in the same batch still passes.
                wl.addError('Logged hours would exceed the client-approved cap of ' + cap
                    + 'h (currently ' + logged
                    + 'h logged). Request a budget increase to continue.');
                continue;
            }
            // Flag mode: the row WILL commit — count it and stash the
            // after-commit side effects (one flag per item, newest total wins).
            runningTotals.put(item.Id, newTotal);
            stashFlag(item, newTotal);
        }
    }

    /**
     * @description Filters the trigger batch down to rows that can move a
     *              capped total: parented rows whose hours or parent changed
     *              (inserts always qualify). Rows whose update touches neither
     *              are skipped, so their old (= new) hours stay in the DB sum.
     * @param rows Trigger.new.
     * @param oldMap Trigger.oldMap (null on insert).
     * @return The rows requiring cap evaluation, in batch order.
     */
    private static List<WorkLog__c> collectCandidates(List<WorkLog__c> rows, Map<Id, WorkLog__c> oldMap) {
        List<WorkLog__c> candidates = new List<WorkLog__c>();
        for (WorkLog__c wl : rows) {
            if (wl.WorkItemLookup__c == null) {
                continue;
            }
            if (oldMap != null && !isRelevantChange(wl, oldMap.get(wl.Id))) {
                continue;
            }
            candidates.add(wl);
        }
        return candidates;
    }

    /**
     * @description Distinct parent WorkItem ids across the candidate rows.
     * @param candidates The rows requiring cap evaluation.
     * @return Set of parent WorkItem__c ids.
     */
    private static Set<Id> candidateItemIds(List<WorkLog__c> candidates) {
        Set<Id> itemIds = new Set<Id>();
        for (WorkLog__c wl : candidates) {
            itemIds.add(wl.WorkItemLookup__c);
        }
        return itemIds;
    }

    /**
     * @description Ids of candidate rows already in the database (updates).
     *              These are excluded from the live DB sum — in the before
     *              context the database still holds their OLD hours, and
     *              their NEW hours re-enter as the incoming delta instead.
     *              Inserts have no id yet and are naturally absent.
     * @param candidates The rows requiring cap evaluation.
     * @return Set of in-flight WorkLog__c ids to omit from the DB sum.
     */
    private static Set<Id> candidateLogIds(List<WorkLog__c> candidates) {
        Set<Id> logIds = new Set<Id>();
        for (WorkLog__c wl : candidates) {
            if (wl.Id != null) {
                logIds.add(wl.Id);
            }
        }
        return logIds;
    }

    /**
     * @description Records one flag-mode entry for an over-cap item in the
     *              before-context buffer (one per item — the newest running
     *              total wins), to be drained by processPendingFlags().
     * @param item The capped parent WorkItem__c (label/developer loaded).
     * @param newTotal The item's logged total INCLUDING the committing rows.
     */
    private static void stashFlag(WorkItem__c item, Decimal newTotal) {
        PendingFlag flag = new PendingFlag();
        flag.workItemId = item.Id;
        flag.itemLabel = String.isNotBlank(item.BriefDescriptionTxt__c)
            ? item.BriefDescriptionTxt__c : item.Name;
        flag.cap = item.ClientPreApprovedHoursNumber__c;
        flag.total = newTotal;
        flag.developerId = item.DeveloperLookup__c;
        pendingFlags.put(item.Id, flag);
    }

    /**
     * @description Update-path relevance filter: only a change to the logged
     *              hours or a reparenting to another work item can move a
     *              total, so everything else (status flips, description edits)
     *              skips evaluation entirely.
     * @param wl The new row.
     * @param old The pre-update row (null-safe).
     * @return true when the row must be (re)evaluated.
     */
    private static Boolean isRelevantChange(WorkLog__c wl, WorkLog__c old) {
        return old == null
            || wl.HoursLoggedNumber__c != old.HoursLoggedNumber__c
            || wl.WorkItemLookup__c != old.WorkItemLookup__c;
    }

    /**
     * @description Loads the parent work items that actually carry a cap.
     *              Items with a null/zero ClientPreApprovedHoursNumber__c are
     *              uncapped and intentionally absent from the result.
     * @param itemIds Parent WorkItem__c ids from the incoming rows.
     * @return Map of capped WorkItem__c by id (cap, label, developer loaded).
     */
    private static Map<Id, WorkItem__c> loadCappedItems(Set<Id> itemIds) {
        Map<Id, WorkItem__c> out = new Map<Id, WorkItem__c>();
        for (WorkItem__c wi : [
            SELECT Id, Name, BriefDescriptionTxt__c,
                   ClientPreApprovedHoursNumber__c, DeveloperLookup__c
            FROM WorkItem__c
            WHERE Id IN :itemIds
            AND ClientPreApprovedHoursNumber__c > 0
            WITH SYSTEM_MODE
        ]) {
            out.put(wi.Id, wi);
        }
        return out;
    }

    /**
     * @description Sums each capped item's ALREADY-PERSISTED logged hours live
     *              from WorkLog__c. The rows currently in flight are excluded
     *              by id (updates) or naturally absent (inserts have no id in
     *              the before context). TotalLoggedHoursSum__c is deliberately
     *              NOT used — rollups are stale mid-transaction.
     * @param cappedItemIds Items whose totals are needed.
     * @param excludeLogIds In-flight WorkLog ids to leave out of the DB sum.
     * @return Map of WorkItem id → persisted logged-hours total (absent = 0).
     */
    private static Map<Id, Decimal> sumExistingLoggedHours(Set<Id> cappedItemIds, Set<Id> excludeLogIds) {
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (WorkLog__c wl : [
            SELECT WorkItemLookup__c, HoursLoggedNumber__c
            FROM WorkLog__c
            WHERE WorkItemLookup__c IN :cappedItemIds
            AND Id NOT IN :excludeLogIds
            WITH SYSTEM_MODE
            LIMIT :MAX_LOG_ROWS
        ]) {
            Decimal current = totals.containsKey(wl.WorkItemLookup__c)
                ? totals.get(wl.WorkItemLookup__c) : 0;
            totals.put(wl.WorkItemLookup__c,
                current + (wl.HoursLoggedNumber__c == null ? 0 : wl.HoursLoggedNumber__c));
        }
        return totals;
    }

    /**
     * @description Whether hard-block enforcement is on: true when
     *              DeliveryHubSettings__c.EnforceApprovalCapDateTime__c is
     *              populated (DateTime-not-Boolean toggle pattern). Null =
     *              flag mode, the shipping default.
     * @return true when over-cap rows must be blocked with addError.
     */
    private static Boolean isEnforcementOn() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings != null && settings.EnforceApprovalCapDateTime__c != null;
    }

    // ────────────────────────────────────────────────────────────────────
    // FLAG-MODE SIDE EFFECTS (after context)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Moves each flagged item's NEWEST Accepted WorkRequest__c to
     *              'Budget Hold' so the over-cap state is visible on the
     *              request lifecycle. Items with no Accepted request are
     *              skipped silently. Never throws — WARN-logs failures.
     * @param itemIds The flagged WorkItem__c ids.
     */
    private static void moveAcceptedRequestsToBudgetHold(Set<Id> itemIds) {
        try {
            Map<Id, WorkRequest__c> newestAcceptedByItem = new Map<Id, WorkRequest__c>();
            for (WorkRequest__c req : [
                SELECT Id, WorkItemId__c
                FROM WorkRequest__c
                WHERE WorkItemId__c IN :itemIds
                AND StatusPk__c = :REQUEST_ACCEPTED
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT :MAX_REQUEST_ROWS
            ]) {
                if (!newestAcceptedByItem.containsKey(req.WorkItemId__c)) {
                    req.StatusPk__c = REQUEST_BUDGET_HOLD;
                    newestAcceptedByItem.put(req.WorkItemId__c, req);
                }
            }
            if (!newestAcceptedByItem.isEmpty()) {
                Database.update(newestAcceptedByItem.values(), AccessLevel.SYSTEM_MODE);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkCapEnforcementService.moveAcceptedRequestsToBudgetHold] failed: '
                + e.getMessage());
        }
    }

    /**
     * @description Enqueues ONE DeliveryNotificationQueueable per flagged item
     *              targeting the org-default approver (parsed from
     *              ApproverUserIdTxt__c, same resolver shape as the shipped
     *              approval service) plus the item's assigned developer.
     *              No-ops per item when neither target resolves. Never throws.
     * @param flags The drained flag-mode buffer entries.
     */
    @SuppressWarnings('PMD.OperationWithLimitsInLoop') // one queueable per flagged ITEM (already deduped); a flag batch is a handful of items, nowhere near the 50-job trigger limit, and each enqueue is individually guarded so one failure cannot starve the rest
    private static void notifyOverCap(List<PendingFlag> flags) {
        Id approverId = resolveDefaultApproverId();
        for (PendingFlag flag : flags) {
            try {
                Set<Id> targets = new Set<Id>();
                if (approverId != null) {
                    targets.add(approverId);
                }
                if (flag.developerId != null) {
                    targets.add(flag.developerId);
                }
                if (targets.isEmpty()) {
                    continue;
                }
                System.enqueueJob(new DeliveryNotificationQueueable(
                    targets,
                    'Over approved cap',
                    flag.itemLabel + ': ' + flag.total + 'h logged vs ' + flag.cap
                        + 'h approved — needs a budget increase.',
                    flag.workItemId));
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryWorkCapEnforcementService.notifyOverCap] enqueue failed for '
                    + flag.workItemId + ': ' + e.getMessage());
            }
        }
    }

    /**
     * @description Resolves the org-default approver from
     *              DeliveryHubSettings__c.ApproverUserIdTxt__c — a private
     *              copy of the shipped services' resolver (the approval
     *              service is owned by a parallel change and must not be
     *              touched). Bad/blank ids resolve to null with a WARN.
     * @return The configured approver's user id, or null when unset/invalid.
     */
    private static Id resolveDefaultApproverId() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.ApproverUserIdTxt__c)) {
            return null;
        }
        try {
            return Id.valueOf(settings.ApproverUserIdTxt__c.trim());
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkCapEnforcementService.resolveDefaultApproverId] bad id in settings: '
                + e.getMessage());
            return null;
        }
    }
}
