/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Estimate/approval queue service for WorkItem__c work — PR1
 *               (schema + service) of the work-approval queue. Deliberately a
 *               near-copy of the shipped DeliveryFeatureApprovalService rails
 *               with Feature__c swapped for WorkItem__c/WorkRequest__c:
 *
 *               submitForApproval(workItemIds)
 *                 -> ensures ONE WorkRequest__c per WorkItem (reusing an
 *                    existing Draft request when present), stamps
 *                    QuotedHoursNumber__c from the WorkItem's
 *                    EstimatedHoursNumber__c (or an explicit per-item value),
 *                    and moves the request Draft -> 'Offer Sent'.
 *                 -> discretionary short-circuit: when the quoted hours are at
 *                    or under DeliveryHubSettings__c.DiscretionaryThresholdHoursNumber__c
 *                    AND this calendar month's Auto-approved sum is still under
 *                    DiscretionaryMonthlyCapHoursNumber__c, the approval row is
 *                    created StatusPk__c='Auto' and the request is short-circuited
 *                    straight to Accepted (WorkItem cap + stage stamped exactly
 *                    as an explicit approve would). Otherwise a Pending
 *                    WorkItemApproval__c row is created and the WorkItem moves
 *                    to StageNamePk__c='Ready for Final Approval'.
 *               approve(workRequestId, approvedHours, note)
 *                 -> request StatusPk__c='Accepted'; approval row Approved with
 *                    approver/timestamp/note; the WorkItem's
 *                    ClientPreApprovedHoursNumber__c = approvedHours (THE
 *                    canonical client-approved cap) and the stage moves to
 *                    'Ready for Development'.
 *               decline(workRequestId, reason)
 *                 -> request StatusPk__c='Inactive' with StandDownReasonTxt__c;
 *                    any Pending approval row is stamped Rejected; the
 *                    WorkItem's ClientIntentionPk__c -> 'On Hold'.
 *               requestIncrease(workItemId, extraHours, reason)
 *                 -> NEW WorkRequest__c carrying
 *                    RequestedBudgetIncreaseNumber__c so the delta goes back
 *                    through the pending queue (increases never auto-approve).
 *               getPendingForApprover(userId)
 *                 -> the queue feed for the approval LWC (PR2).
 *
 *               WorkRequest__c lifecycle values used here are the verified
 *               picklist values: Draft / Offer Sent / Accepted / In Progress /
 *               Completed / Budget Hold / Inactive. Approval rows reuse the
 *               shipped ApprovalStatus global value set (Pending / Approved /
 *               Rejected / Auto). SOQL is WITH SYSTEM_MODE per CLAUDE.md
 *               (WITH USER_MODE breaks in namespaced package test context);
 *               DML follows the FeatureToggle service's suppression style.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.ExcessivePublicCount,PMD.CognitiveComplexity')
public with sharing class DeliveryWorkApprovalService {

    /** WorkRequest__c lifecycle values (verified picklist values). */
    public static final String REQUEST_DRAFT = 'Draft';
    public static final String REQUEST_OFFER_SENT = 'Offer Sent';
    public static final String REQUEST_ACCEPTED = 'Accepted';
    public static final String REQUEST_INACTIVE = 'Inactive';

    /** Approval row status values — shared ApprovalStatus global value set. */
    public static final String APPROVAL_PENDING = 'Pending';
    public static final String APPROVAL_APPROVED = 'Approved';
    public static final String APPROVAL_REJECTED = 'Rejected';
    public static final String APPROVAL_AUTO = 'Auto';

    /** WorkItem__c stage values driven by the approval lifecycle. */
    public static final String STAGE_READY_FOR_FINAL_APPROVAL = 'Ready for Final Approval';
    public static final String STAGE_READY_FOR_DEVELOPMENT = 'Ready for Development';

    /** WorkItem__c client intention written on decline. */
    public static final String INTENT_ON_HOLD = 'On Hold';

    /** Hard cap on rows scanned by the queue feed / monthly-cap sweep. */
    private static final Integer MAX_QUEUE_ROWS = 200;
    private static final Integer MAX_CAP_ROWS = 5000;

    // ────────────────────────────────────────────────────────────────────
    // DTOs
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description One render-ready pending-approval row for the queue LWC
     *              (PR2). Mirrors DeliveryFeatureApprovalService.ApprovalInboxDTO.
     */
    public class PendingApprovalDTO {
        @AuraEnabled public Id approvalId;
        @AuraEnabled public Id requestId;
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String workItemName;
        @AuraEnabled public String workItemLabel;
        @AuraEnabled public Decimal quotedHours;
        @AuraEnabled public Decimal requestedIncrease;
        @AuraEnabled public String requestStatus;
        @AuraEnabled public Integer stepNumber;
        @AuraEnabled public String status;
        @AuraEnabled public DateTime submittedAt;
        @AuraEnabled public Id approverUserId;
    }

    /**
     * @description Per-item result of submitForApproval — which request the
     *              item landed on and whether the discretionary short-circuit
     *              auto-approved it.
     */
    public class SubmitResultDTO {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public Id workRequestId;
        @AuraEnabled public Id approvalId;
        @AuraEnabled public Boolean autoApproved;
        @AuraEnabled public Decimal quotedHours;
    }

    // ────────────────────────────────────────────────────────────────────
    // SUBMIT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Submits WorkItems for client approval using each item's
     *              EstimatedHoursNumber__c as the quoted hours.
     * @param workItemIds The WorkItem__c ids to submit.
     * @return One SubmitResultDTO per submitted item.
     */
    public static List<SubmitResultDTO> submitForApproval(Set<Id> workItemIds) {
        return submitForApproval(workItemIds, null);
    }

    /**
     * @description Submits WorkItems for client approval. Ensures one
     *              WorkRequest__c per item (reusing the newest Draft request
     *              when one exists), stamps the quoted hours, runs the
     *              discretionary Auto check, and creates the approval rows.
     * @param workItemIds The WorkItem__c ids to submit.
     * @param quotedHoursByItem Optional explicit quoted hours per item;
     *        items absent from the map fall back to EstimatedHoursNumber__c.
     * @return One SubmitResultDTO per submitted item.
     */
    public static List<SubmitResultDTO> submitForApproval(
        Set<Id> workItemIds, Map<Id, Decimal> quotedHoursByItem
    ) {
        if (workItemIds == null || workItemIds.isEmpty()) {
            throw new AuraHandledException('workItemIds is required.');
        }
        List<WorkItem__c> items = loadWorkItemsForSubmit(workItemIds);
        if (items.isEmpty()) {
            throw new AuraHandledException('No matching work items found.');
        }
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Decimal threshold = settings == null ? null : settings.DiscretionaryThresholdHoursNumber__c;
        Decimal monthlyCap = settings == null ? null : settings.DiscretionaryMonthlyCapHoursNumber__c;
        Id approverId = resolveDefaultApproverId(settings);
        // Running sum so several under-threshold items in ONE submit call
        // can't collectively blow past the monthly cap unnoticed.
        Decimal autoSumThisMonth = sumAutoApprovedHoursThisMonth();

        List<SubmitResultDTO> results = new List<SubmitResultDTO>();
        List<WorkRequest__c> requestsToSave = new List<WorkRequest__c>();
        List<WorkItem__c> itemUpdates = new List<WorkItem__c>();

        for (WorkItem__c wi : items) {
            Decimal quoted = resolveQuotedHours(wi, quotedHoursByItem);
            WorkRequest__c req = ensureRequest(wi);
            req.QuotedHoursNumber__c = quoted;

            Boolean auto = isAutoApprovable(quoted, threshold, monthlyCap, autoSumThisMonth);
            if (auto) {
                autoSumThisMonth += quoted;
                req.StatusPk__c = REQUEST_ACCEPTED;
                itemUpdates.add(new WorkItem__c(
                    Id = wi.Id,
                    ClientPreApprovedHoursNumber__c = quoted,
                    StageNamePk__c = STAGE_READY_FOR_DEVELOPMENT
                ));
            } else {
                req.StatusPk__c = REQUEST_OFFER_SENT;
                itemUpdates.add(new WorkItem__c(
                    Id = wi.Id,
                    StageNamePk__c = STAGE_READY_FOR_FINAL_APPROVAL
                ));
            }
            requestsToSave.add(req);

            SubmitResultDTO dto = new SubmitResultDTO();
            dto.workItemId = wi.Id;
            dto.autoApproved = auto;
            dto.quotedHours = quoted;
            results.add(dto);
        }

        persistSubmit(requestsToSave, itemUpdates, results, approverId);
        return results;
    }

    private static List<WorkItem__c> loadWorkItemsForSubmit(Set<Id> workItemIds) {
        return [
            SELECT Id, EstimatedHoursNumber__c, StageNamePk__c,
                   ClientPreApprovedHoursNumber__c,
                   (SELECT Id, StatusPk__c, QuotedHoursNumber__c
                    FROM Requests__r
                    WHERE StatusPk__c = :REQUEST_DRAFT
                    ORDER BY CreatedDate DESC
                    LIMIT 1)
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
        ];
    }

    private static Decimal resolveQuotedHours(WorkItem__c wi, Map<Id, Decimal> quotedHoursByItem) {
        if (quotedHoursByItem != null && quotedHoursByItem.containsKey(wi.Id)
            && quotedHoursByItem.get(wi.Id) != null) {
            return quotedHoursByItem.get(wi.Id);
        }
        return wi.EstimatedHoursNumber__c;
    }

    /**
     * @description Reuses the newest Draft WorkRequest__c on the item when one
     *              exists (the auto-create trigger seeds Drafts), otherwise
     *              builds a new request. No DML here — the caller batches it.
     * @param wi WorkItem with the Requests__r Draft subquery populated.
     * @return The (possibly unsaved) WorkRequest__c to stamp and persist.
     */
    private static WorkRequest__c ensureRequest(WorkItem__c wi) {
        if (wi.Requests__r != null && !wi.Requests__r.isEmpty()) {
            return wi.Requests__r[0];
        }
        return new WorkRequest__c(WorkItemId__c = wi.Id);
    }

    /**
     * @description The discretionary gate: quoted hours must be known and at
     *              or under the per-request threshold, AND the month's running
     *              Auto-approved sum must still be under the monthly cap.
     *              A blank/zero threshold disables the Auto path entirely; a
     *              blank cap means only the per-request threshold gates it.
     * @param quoted Quoted hours for this request.
     * @param threshold Per-request discretionary ceiling from settings.
     * @param monthlyCap Monthly Auto budget from settings.
     * @param autoSumThisMonth Running Auto-approved sum for the current month.
     * @return true when the request may auto-approve.
     */
    private static Boolean isAutoApprovable(
        Decimal quoted, Decimal threshold, Decimal monthlyCap, Decimal autoSumThisMonth
    ) {
        if (quoted == null || threshold == null || threshold <= 0) {
            return false;
        }
        if (quoted > threshold) {
            return false;
        }
        return monthlyCap == null || autoSumThisMonth < monthlyCap;
    }

    /**
     * @description Sums this calendar month's Auto-approved quoted hours —
     *              the consumed portion of the discretionary monthly cap.
     * @return Total Auto-approved hours decided THIS_MONTH (0 when none).
     */
    @TestVisible
    private static Decimal sumAutoApprovedHoursThisMonth() {
        Decimal total = 0;
        for (WorkItemApproval__c row : [
            SELECT RequestLookup__r.QuotedHoursNumber__c
            FROM WorkItemApproval__c
            WHERE StatusPk__c = :APPROVAL_AUTO
              AND DecisionDateTime__c = THIS_MONTH
            WITH SYSTEM_MODE
            LIMIT :MAX_CAP_ROWS
        ]) {
            if (row.RequestLookup__r != null
                && row.RequestLookup__r.QuotedHoursNumber__c != null) {
                total += row.RequestLookup__r.QuotedHoursNumber__c;
            }
        }
        return total;
    }

    private static Id resolveDefaultApproverId(DeliveryHubSettings__c settings) {
        if (settings == null || String.isBlank(settings.ApproverUserIdTxt__c)) {
            return null;
        }
        try {
            return Id.valueOf(settings.ApproverUserIdTxt__c.trim());
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.resolveDefaultApproverId] bad id in settings: '
                + e.getMessage());
            return null;
        }
    }

    /**
     * @description Batched DML for submit: upsert the requests, insert one
     *              approval row per request (Auto rows get the decision stamp,
     *              Pending rows get the default approver), update the items,
     *              and write one audit row per Auto short-circuit.
     * @param requests Requests to save (mixed insert/update).
     * @param itemUpdates WorkItem stage/cap updates.
     * @param results DTOs to backfill with request/approval ids.
     * @param approverId Default approver from settings (nullable).
     */
    private static void persistSubmit(
        List<WorkRequest__c> requests,
        List<WorkItem__c> itemUpdates,
        List<SubmitResultDTO> results,
        Id approverId
    ) {
        try {
            upsert requests;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.persistSubmit] upsert requests failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to submit for approval.');
        }
        List<WorkItemApproval__c> approvals = new List<WorkItemApproval__c>();
        DateTime nowTs = DateTime.now();
        for (Integer i = 0; i < requests.size(); i++) {
            SubmitResultDTO dto = results[i];
            dto.workRequestId = requests[i].Id;
            approvals.add(dto.autoApproved
                ? new WorkItemApproval__c(
                      RequestLookup__c = requests[i].Id,
                      StepNumber__c = 1,
                      StatusPk__c = APPROVAL_AUTO,
                      DecisionDateTime__c = nowTs)
                : new WorkItemApproval__c(
                      RequestLookup__c = requests[i].Id,
                      StepNumber__c = 1,
                      StatusPk__c = APPROVAL_PENDING,
                      ApproverUserLookup__c = approverId));
        }
        try {
            insert approvals;
            update itemUpdates;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.persistSubmit] approvals/items failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to create approval rows.');
        }
        for (Integer i = 0; i < results.size(); i++) {
            results[i].approvalId = approvals[i].Id;
            if (results[i].autoApproved) {
                writeAuditRow(results[i].workItemId, 'Auto_Approve', results[i].workRequestId, null);
            }
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // APPROVE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approver-side accept. Stamps the Pending approval row
     *              Approved with approver/timestamp/note, moves the request to
     *              Accepted, and lands the canonical client cap on the
     *              WorkItem (ClientPreApprovedHoursNumber__c) before moving it
     *              to 'Ready for Development'.
     * @param workRequestId The WorkRequest__c being approved.
     * @param approvedHours The hours the client is capping the work at; null
     *        falls back to the request's QuotedHoursNumber__c.
     * @param note Optional decision note from the approver.
     */
    @AuraEnabled
    public static void approve(Id workRequestId, Decimal approvedHours, String note) {
        WorkRequest__c req = loadRequestOrThrow(workRequestId);
        WorkItemApproval__c row = loadPendingApprovalOrThrow(req.Id);
        assertCallerMayDecide(row);
        Decimal cap = approvedHours == null ? req.QuotedHoursNumber__c : approvedHours;

        stampDecision(row, APPROVAL_APPROVED, note);
        req.StatusPk__c = REQUEST_ACCEPTED;
        WorkItem__c wi = new WorkItem__c(
            Id = req.WorkItemId__c,
            ClientPreApprovedHoursNumber__c = cap,
            StageNamePk__c = STAGE_READY_FOR_DEVELOPMENT
        );
        try {
            update req;
            update wi;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.approve] update failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to approve the request.');
        }
        writeAuditRow(req.WorkItemId__c, 'Approve', req.Id, note);
    }

    // ────────────────────────────────────────────────────────────────────
    // DECLINE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approver-side decline. Stamps any Pending approval row
     *              Rejected, stands the request down (Inactive +
     *              StandDownReasonTxt__c), and parks the WorkItem
     *              (ClientIntentionPk__c='On Hold') so it drops out of the
     *              committed cohort.
     * @param workRequestId The WorkRequest__c being declined.
     * @param reason Why the client declined (stored on the request).
     */
    @AuraEnabled
    public static void decline(Id workRequestId, String reason) {
        WorkRequest__c req = loadRequestOrThrow(workRequestId);
        WorkItemApproval__c row = loadPendingApprovalOrNull(req.Id);
        if (row != null) {
            assertCallerMayDecide(row);
            stampDecision(row, APPROVAL_REJECTED, reason);
        }
        req.StatusPk__c = REQUEST_INACTIVE;
        req.StandDownReasonTxt__c = String.isBlank(reason) ? null : reason.left(255);
        WorkItem__c wi = new WorkItem__c(
            Id = req.WorkItemId__c,
            ClientIntentionPk__c = INTENT_ON_HOLD
        );
        try {
            update req;
            update wi;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.decline] update failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to decline the request.');
        }
        writeAuditRow(req.WorkItemId__c, 'Decline', req.Id, reason);
    }

    // ────────────────────────────────────────────────────────────────────
    // REQUEST INCREASE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Vendor-side budget-increase ask. Creates a NEW
     *              WorkRequest__c carrying RequestedBudgetIncreaseNumber__c so
     *              the delta goes back through the pending queue — increases
     *              NEVER take the discretionary Auto path. The WorkItem moves
     *              back to 'Ready for Final Approval' while the delta awaits a
     *              decision.
     * @param workItemId The WorkItem__c needing more hours.
     * @param extraHours The additional hours requested beyond the original cap.
     * @param reason Why the original budget is insufficient (audit-logged).
     * @return The new WorkRequest__c id.
     */
    @AuraEnabled
    public static Id requestIncrease(Id workItemId, Decimal extraHours, String reason) {
        if (workItemId == null) {
            throw new AuraHandledException('workItemId is required.');
        }
        if (extraHours == null || extraHours <= 0) {
            throw new AuraHandledException('extraHours must be greater than zero.');
        }
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        WorkRequest__c req = new WorkRequest__c(
            WorkItemId__c = workItemId,
            StatusPk__c = REQUEST_OFFER_SENT,
            QuotedHoursNumber__c = extraHours,
            RequestedBudgetIncreaseNumber__c = extraHours
        );
        try {
            insert req;
            insert new WorkItemApproval__c(
                RequestLookup__c = req.Id,
                StepNumber__c = 1,
                StatusPk__c = APPROVAL_PENDING,
                ApproverUserLookup__c = resolveDefaultApproverId(settings)
            );
            update new WorkItem__c(
                Id = workItemId,
                StageNamePk__c = STAGE_READY_FOR_FINAL_APPROVAL
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.requestIncrease] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to request a budget increase.');
        }
        writeAuditRow(workItemId, 'Request_Increase', req.Id, reason);
        return req.Id;
    }

    // ────────────────────────────────────────────────────────────────────
    // QUEUE FEED (LWC-facing — PR2 renders this)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Returns Pending approval rows for the queue LWC, joined
     *              with their request + work item for one-screen render.
     *              Includes rows assigned to the given user AND unassigned
     *              rows (no default approver configured) so the queue never
     *              silently hides work — mirrors the FeatureToggle inbox shape
     *              but relaxes its assigned-only filter because approver
     *              assignment is settings-optional in PR1.
     * @param userId Approver to fetch for; null = the running user.
     * @return Oldest-first list of PendingApprovalDTO (LIMIT 200).
     */
    @AuraEnabled(cacheable=true)
    public static List<PendingApprovalDTO> getPendingForApprover(Id userId) {
        Id approverId = userId == null ? UserInfo.getUserId() : userId;
        List<PendingApprovalDTO> out = new List<PendingApprovalDTO>();
        try {
            for (WorkItemApproval__c row : [
                SELECT Id, RequestLookup__c, StepNumber__c, StatusPk__c,
                       ApproverUserLookup__c, CreatedDate,
                       RequestLookup__r.StatusPk__c,
                       RequestLookup__r.QuotedHoursNumber__c,
                       RequestLookup__r.RequestedBudgetIncreaseNumber__c,
                       RequestLookup__r.WorkItemId__c,
                       RequestLookup__r.WorkItemId__r.Name,
                       RequestLookup__r.WorkItemId__r.BriefDescriptionTxt__c
                FROM WorkItemApproval__c
                WHERE StatusPk__c = :APPROVAL_PENDING
                  AND (ApproverUserLookup__c = :approverId
                       OR ApproverUserLookup__c = NULL)
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT :MAX_QUEUE_ROWS
            ]) {
                out.add(toPendingDto(row));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.getPendingForApprover] failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to load the approval queue.');
        }
        return out;
    }

    private static PendingApprovalDTO toPendingDto(WorkItemApproval__c row) {
        PendingApprovalDTO dto = new PendingApprovalDTO();
        dto.approvalId = row.Id;
        dto.requestId = row.RequestLookup__c;
        dto.stepNumber = row.StepNumber__c == null ? 1 : row.StepNumber__c.intValue();
        dto.status = row.StatusPk__c;
        dto.submittedAt = row.CreatedDate;
        dto.approverUserId = row.ApproverUserLookup__c;
        if (row.RequestLookup__r != null) {
            dto.requestStatus = row.RequestLookup__r.StatusPk__c;
            dto.quotedHours = row.RequestLookup__r.QuotedHoursNumber__c;
            dto.requestedIncrease = row.RequestLookup__r.RequestedBudgetIncreaseNumber__c;
            dto.workItemId = row.RequestLookup__r.WorkItemId__c;
            if (row.RequestLookup__r.WorkItemId__r != null) {
                dto.workItemName = row.RequestLookup__r.WorkItemId__r.Name;
                String brief = row.RequestLookup__r.WorkItemId__r.BriefDescriptionTxt__c;
                dto.workItemLabel = String.isNotBlank(brief)
                    ? brief
                    : row.RequestLookup__r.WorkItemId__r.Name;
            }
        }
        return dto;
    }

    // ────────────────────────────────────────────────────────────────────
    // SHARED HELPERS
    // ────────────────────────────────────────────────────────────────────

    private static WorkRequest__c loadRequestOrThrow(Id workRequestId) {
        if (workRequestId == null) {
            throw new AuraHandledException('workRequestId is required.');
        }
        List<WorkRequest__c> reqs = [
            SELECT Id, StatusPk__c, QuotedHoursNumber__c, WorkItemId__c,
                   RequestedBudgetIncreaseNumber__c
            FROM WorkRequest__c
            WHERE Id = :workRequestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (reqs.isEmpty()) {
            throw new AuraHandledException('Work request not found.');
        }
        return reqs.get(0);
    }

    private static WorkItemApproval__c loadPendingApprovalOrThrow(Id workRequestId) {
        WorkItemApproval__c row = loadPendingApprovalOrNull(workRequestId);
        if (row == null) {
            throw new AuraHandledException('No pending approval row for this request.');
        }
        return row;
    }

    private static WorkItemApproval__c loadPendingApprovalOrNull(Id workRequestId) {
        List<WorkItemApproval__c> rows = [
            SELECT Id, StatusPk__c, ApproverUserLookup__c
            FROM WorkItemApproval__c
            WHERE RequestLookup__c = :workRequestId
              AND StatusPk__c = :APPROVAL_PENDING
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * @description Caller guard, cloned from the FeatureToggle rails' caller-
     *              is-approver gate but relaxed for unassigned rows: when an
     *              approver IS assigned, only that user may decide (the
     *              @AuraEnabled surface is reachable outside the LWC);
     *              unassigned rows may be decided by any authorised caller,
     *              who is then stamped as the approver — PR1 leaves approver
     *              assignment settings-optional.
     * @param row The loaded approval row.
     */
    private static void assertCallerMayDecide(WorkItemApproval__c row) {
        if (row.ApproverUserLookup__c != null
            && row.ApproverUserLookup__c != UserInfo.getUserId()) {
            throw new AuraHandledException(
                'You are not the assigned approver for this request.');
        }
    }

    private static void stampDecision(WorkItemApproval__c row, String status, String note) {
        row.StatusPk__c = status;
        row.DecisionDateTime__c = DateTime.now();
        row.DecisionNoteTxt__c = String.isBlank(note) ? null : note.left(1024);
        if (row.ApproverUserLookup__c == null) {
            row.ApproverUserLookup__c = UserInfo.getUserId();
        }
        try {
            update row;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.stampDecision] update failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to record decision.');
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // AUDIT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Emits one ActivityLog__c per approval lifecycle event,
     *              mirroring the FeatureToggle service's audit pattern. The
     *              activity-log trigger contributes the SHA-256 hash chain via
     *              DeliveryAuditChainService.setHashOnInsert.
     * @param workItemId WorkItem__c the decision concerns.
     * @param action Lifecycle verb (Auto_Approve / Approve / Decline / Request_Increase).
     * @param requestId The WorkRequest__c id (carried in ContextData).
     * @param note Optional decision note carried in ContextData.
     */
    private static void writeAuditRow(Id workItemId, String action, Id requestId, String note) {
        Map<String, Object> ctx = new Map<String, Object>{
            'requestId' => requestId,
            'action' => action,
            'approverUserId' => UserInfo.getUserId()
        };
        if (String.isNotBlank(note)) {
            ctx.put('note', note.left(500));
        }
        ActivityLog__c row = new ActivityLog__c(
            ActionTypePk__c = 'Work_Approval',
            RecordIdTxt__c = workItemId == null ? null : String.valueOf(workItemId),
            ContextDataTxt__c = JSON.serialize(ctx),
            UserIdTxt__c = UserInfo.getUserId(),
            ComponentNameTxt__c = 'DeliveryWorkApprovalService'
        );
        try {
            insert row;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.writeAuditRow] insert failed: '
                + e.getMessage());
        }
    }
}
