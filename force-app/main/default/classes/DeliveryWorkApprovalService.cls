/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Estimate/approval queue service for WorkItem__c work — PR1
 *               (schema + service) of the work-approval queue.
 *
 *               Architecture: the decision lives ON WorkRequest__c — no child
 *               approval object. A request is decided at most once in its
 *               lifecycle (Offer Sent -> Accepted/Inactive; budget increases
 *               are NEW requests), so per-step child rows would be speculative
 *               machinery. This mirrors the shipped DeliveryDocApprovalService
 *               pattern (decision state on the record + immutable per-event
 *               history in ActivityLog__c via the SHA-256 hash-chain trigger)
 *               rather than the FeatureToggle request/approval pair, whose
 *               multi-step StepNumber machinery this flow does not need. If a
 *               tiered chain ever becomes real, a child object can be ADDED
 *               then — objects shipped in the package cannot be removed.
 *
 *               submitForApproval(workItemIds)
 *                 -> ensures ONE WorkRequest__c per WorkItem (reusing the
 *                    newest Draft request when present), stamps
 *                    QuotedHoursNumber__c from the WorkItem's
 *                    EstimatedHoursNumber__c (or an explicit per-item value),
 *                    and moves the request Draft -> 'Offer Sent'.
 *                 -> discretionary short-circuit: when the quoted hours are at
 *                    or under DeliveryHubSettings__c.DiscretionaryThresholdHoursNumber__c
 *                    AND this calendar month's auto-approved sum is still under
 *                    DiscretionaryMonthlyCapHoursNumber__c, the request is
 *                    short-circuited straight to Accepted with
 *                    AutoApprovedDateTime__c stamped (WorkItem cap + stage
 *                    stamped exactly as an explicit approve would). Otherwise
 *                    the request parks at 'Offer Sent' with the configured
 *                    approver and the WorkItem moves to
 *                    StageNamePk__c='Ready for Final Approval'.
 *               approve(workRequestId, approvedHours, note)
 *                 -> request StatusPk__c='Accepted' with approver/timestamp/
 *                    note; the WorkItem's ClientPreApprovedHoursNumber__c (THE
 *                    canonical client-approved cap) is set — or RAISED by the
 *                    approved delta when the request is a budget increase,
 *                    never overwritten — and the stage moves to
 *                    'Ready for Development'.
 *               decline(workRequestId, reason)
 *                 -> request StatusPk__c='Inactive' with StandDownReasonTxt__c;
 *                    the WorkItem parks (ClientIntentionPk__c='On Hold') ONLY
 *                    when nothing was previously approved — declining a budget
 *                    INCREASE leaves the in-flight item and its original cap
 *                    untouched.
 *               requestIncrease(workItemId, extraHours, reason)
 *                 -> NEW WorkRequest__c carrying
 *                    RequestedBudgetIncreaseNumber__c so the delta goes back
 *                    through the pending queue (increases never auto-approve).
 *                    The WorkItem keeps its current stage — only the delta
 *                    awaits a decision, not the already-approved work.
 *               getPendingForApprover(userId)
 *                 -> the queue feed for the approval LWC (PR2).
 *
 *               WorkRequest__c lifecycle values used here are the verified
 *               picklist values: Draft / Offer Sent / Accepted / In Progress /
 *               Completed / Budget Hold / Inactive. SOQL is WITH SYSTEM_MODE
 *               per CLAUDE.md (WITH USER_MODE breaks in namespaced package
 *               test context); DML follows the Doc-approval service's
 *               suppression style.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.CognitiveComplexity')
public with sharing class DeliveryWorkApprovalService {

    /** WorkRequest__c lifecycle values (verified picklist values). */
    public static final String REQUEST_DRAFT = 'Draft';
    public static final String REQUEST_OFFER_SENT = 'Offer Sent';
    public static final String REQUEST_ACCEPTED = 'Accepted';
    public static final String REQUEST_INACTIVE = 'Inactive';

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
     *              (PR2): the Offer-Sent request joined with its work item.
     */
    public class PendingApprovalDTO {
        @AuraEnabled public Id requestId;
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String workItemName;
        @AuraEnabled public String workItemLabel;
        @AuraEnabled public Decimal quotedHours;
        @AuraEnabled public Decimal requestedIncrease;
        @AuraEnabled public String requestStatus;
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
     *              when one exists), stamps the quoted hours, and runs the
     *              discretionary Auto check.
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
        DateTime nowTs = DateTime.now();

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
                req.AutoApprovedDateTime__c = nowTs;
                req.DecisionDateTime__c = nowTs;
                req.PreApprovedHoursNumber__c = quoted;
                itemUpdates.add(new WorkItem__c(
                    Id = wi.Id,
                    ClientPreApprovedHoursNumber__c = quoted,
                    StageNamePk__c = STAGE_READY_FOR_DEVELOPMENT
                ));
            } else {
                req.StatusPk__c = REQUEST_OFFER_SENT;
                req.ApproverUserLookup__c = approverId;
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

        persistSubmit(requestsToSave, itemUpdates, results);
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
     *              exists, otherwise builds a new request. No DML here — the
     *              caller batches it.
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
     *              auto-approved sum must still be under the monthly cap.
     *              A blank/zero threshold disables the Auto path entirely; a
     *              blank cap means only the per-request threshold gates it.
     * @param quoted Quoted hours for this request.
     * @param threshold Per-request discretionary ceiling from settings.
     * @param monthlyCap Monthly Auto budget from settings.
     * @param autoSumThisMonth Running auto-approved sum for the current month.
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
     * @description Sums this calendar month's auto-approved quoted hours —
     *              the consumed portion of the discretionary monthly cap.
     * @return Total auto-approved hours decided THIS_MONTH (0 when none).
     */
    @TestVisible
    private static Decimal sumAutoApprovedHoursThisMonth() {
        Decimal total = 0;
        for (WorkRequest__c req : [
            SELECT QuotedHoursNumber__c
            FROM WorkRequest__c
            WHERE AutoApprovedDateTime__c = THIS_MONTH
            WITH SYSTEM_MODE
            LIMIT :MAX_CAP_ROWS
        ]) {
            if (req.QuotedHoursNumber__c != null) {
                total += req.QuotedHoursNumber__c;
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
     * @description Batched DML for submit: upsert the requests, update the
     *              items, and write one audit row per Auto short-circuit.
     * @param requests Requests to save (mixed insert/update).
     * @param itemUpdates WorkItem stage/cap updates.
     * @param results DTOs to backfill with request ids.
     */
    private static void persistSubmit(
        List<WorkRequest__c> requests,
        List<WorkItem__c> itemUpdates,
        List<SubmitResultDTO> results
    ) {
        try {
            upsert requests;
            update itemUpdates;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.persistSubmit] DML failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to submit for approval.');
        }
        for (Integer i = 0; i < results.size(); i++) {
            results[i].workRequestId = requests[i].Id;
            if (results[i].autoApproved) {
                writeAuditRow(results[i].workItemId, 'Auto_Approve', requests[i].Id, null);
            }
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // APPROVE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approver-side accept. Stamps the decision on the request
     *              (Accepted + approver/timestamp/note) and lands the
     *              canonical client cap on the WorkItem
     *              (ClientPreApprovedHoursNumber__c) before moving it to
     *              'Ready for Development'. When the request is a budget
     *              INCREASE, the approved hours are a DELTA and the existing
     *              cap is raised by it — never overwritten.
     * @param workRequestId The WorkRequest__c being approved.
     * @param approvedHours The hours being granted (cap for an original
     *        request, delta for an increase); null falls back to the
     *        request's QuotedHoursNumber__c.
     * @param note Optional decision note from the approver.
     */
    @AuraEnabled
    public static void approve(Id workRequestId, Decimal approvedHours, String note) {
        WorkRequest__c req = loadPendingRequestOrThrow(workRequestId);
        assertCallerMayDecide(req);
        Decimal granted = approvedHours == null ? req.QuotedHoursNumber__c : approvedHours;
        Boolean isIncrease = req.RequestedBudgetIncreaseNumber__c != null
            && req.RequestedBudgetIncreaseNumber__c > 0;

        Decimal newCap = granted;
        if (isIncrease) {
            Decimal currentCap = req.WorkItemId__r.ClientPreApprovedHoursNumber__c;
            newCap = (currentCap == null ? 0 : currentCap) + (granted == null ? 0 : granted);
        }

        stampDecision(req, REQUEST_ACCEPTED, note);
        req.PreApprovedHoursNumber__c = granted;
        WorkItem__c wi = new WorkItem__c(
            Id = req.WorkItemId__c,
            ClientPreApprovedHoursNumber__c = newCap,
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
        writeAuditRow(req.WorkItemId__c, isIncrease ? 'Approve_Increase' : 'Approve', req.Id, note);
    }

    // ────────────────────────────────────────────────────────────────────
    // DECLINE
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approver-side decline. Stands the request down (Inactive +
     *              StandDownReasonTxt__c). The WorkItem parks
     *              (ClientIntentionPk__c='On Hold') ONLY when nothing was
     *              previously approved — declining a budget increase leaves
     *              the in-flight item and its original cap untouched.
     * @param workRequestId The WorkRequest__c being declined.
     * @param reason Why the client declined (stored on the request).
     */
    @AuraEnabled
    public static void decline(Id workRequestId, String reason) {
        WorkRequest__c req = loadPendingRequestOrThrow(workRequestId);
        assertCallerMayDecide(req);
        Decimal currentCap = req.WorkItemId__r.ClientPreApprovedHoursNumber__c;
        Boolean parkItem = currentCap == null || currentCap <= 0;

        stampDecision(req, REQUEST_INACTIVE, null);
        req.StandDownReasonTxt__c = String.isBlank(reason) ? null : reason.left(255);
        try {
            update req;
            if (parkItem) {
                update new WorkItem__c(
                    Id = req.WorkItemId__c,
                    ClientIntentionPk__c = INTENT_ON_HOLD
                );
            }
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
     *              NEVER take the discretionary Auto path. The WorkItem keeps
     *              its current stage: only the delta awaits a decision, not
     *              the already-approved work.
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
            RequestedBudgetIncreaseNumber__c = extraHours,
            ApproverUserLookup__c = resolveDefaultApproverId(settings)
        );
        try {
            insert req;
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
     * @description Returns Offer-Sent requests for the queue LWC, joined with
     *              their work item for one-screen render. Includes requests
     *              assigned to the given user AND unassigned requests (no
     *              default approver configured) so the queue never silently
     *              hides work — approver assignment is settings-optional in PR1.
     * @param userId Approver to fetch for; null = the running user.
     * @return Oldest-first list of PendingApprovalDTO (LIMIT 200).
     */
    @AuraEnabled(cacheable=true)
    public static List<PendingApprovalDTO> getPendingForApprover(Id userId) {
        Id approverId = userId == null ? UserInfo.getUserId() : userId;
        List<PendingApprovalDTO> out = new List<PendingApprovalDTO>();
        try {
            for (WorkRequest__c req : [
                SELECT Id, StatusPk__c, QuotedHoursNumber__c,
                       RequestedBudgetIncreaseNumber__c, ApproverUserLookup__c,
                       CreatedDate, WorkItemId__c, WorkItemId__r.Name,
                       WorkItemId__r.BriefDescriptionTxt__c
                FROM WorkRequest__c
                WHERE StatusPk__c = :REQUEST_OFFER_SENT
                  AND (ApproverUserLookup__c = :approverId
                       OR ApproverUserLookup__c = NULL)
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT :MAX_QUEUE_ROWS
            ]) {
                out.add(toPendingDto(req));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWorkApprovalService.getPendingForApprover] failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to load the approval queue.');
        }
        return out;
    }

    private static PendingApprovalDTO toPendingDto(WorkRequest__c req) {
        PendingApprovalDTO dto = new PendingApprovalDTO();
        dto.requestId = req.Id;
        dto.requestStatus = req.StatusPk__c;
        dto.quotedHours = req.QuotedHoursNumber__c;
        dto.requestedIncrease = req.RequestedBudgetIncreaseNumber__c;
        dto.submittedAt = req.CreatedDate;
        dto.approverUserId = req.ApproverUserLookup__c;
        dto.workItemId = req.WorkItemId__c;
        if (req.WorkItemId__r != null) {
            dto.workItemName = req.WorkItemId__r.Name;
            String brief = req.WorkItemId__r.BriefDescriptionTxt__c;
            dto.workItemLabel = String.isNotBlank(brief)
                ? brief
                : req.WorkItemId__r.Name;
        }
        return dto;
    }

    // ────────────────────────────────────────────────────────────────────
    // SHARED HELPERS
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Loads a request that is still awaiting a decision
     *              (StatusPk__c='Offer Sent'), joined with its work item's
     *              current cap for increase math.
     * @param workRequestId The request id from the LWC.
     * @return The pending WorkRequest__c.
     */
    private static WorkRequest__c loadPendingRequestOrThrow(Id workRequestId) {
        if (workRequestId == null) {
            throw new AuraHandledException('workRequestId is required.');
        }
        List<WorkRequest__c> reqs = [
            SELECT Id, StatusPk__c, QuotedHoursNumber__c, WorkItemId__c,
                   RequestedBudgetIncreaseNumber__c, ApproverUserLookup__c,
                   WorkItemId__r.ClientPreApprovedHoursNumber__c
            FROM WorkRequest__c
            WHERE Id = :workRequestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (reqs.isEmpty()) {
            throw new AuraHandledException('Work request not found.');
        }
        WorkRequest__c req = reqs.get(0);
        if (req.StatusPk__c != REQUEST_OFFER_SENT) {
            throw new AuraHandledException(
                'This request is not awaiting a decision (status: ' + req.StatusPk__c + ').');
        }
        return req;
    }

    /**
     * @description Caller guard, mirroring the FeatureToggle rails' caller-
     *              is-approver gate but relaxed for unassigned requests: when
     *              an approver IS assigned, only that user may decide (the
     *              @AuraEnabled surface is reachable outside the LWC);
     *              unassigned requests may be decided by any authorised
     *              caller, who is then stamped as the approver — PR1 leaves
     *              approver assignment settings-optional.
     * @param req The loaded pending request.
     */
    private static void assertCallerMayDecide(WorkRequest__c req) {
        if (req.ApproverUserLookup__c != null
            && req.ApproverUserLookup__c != UserInfo.getUserId()) {
            throw new AuraHandledException(
                'You are not the assigned approver for this request.');
        }
    }

    /**
     * @description Stamps the decision state on the request in memory (the
     *              caller batches the DML): status, decision timestamp,
     *              optional note, and the deciding user when previously
     *              unassigned.
     * @param req The pending request being decided.
     * @param status Target StatusPk__c (Accepted / Inactive).
     * @param note Optional decision note (approve path only).
     */
    private static void stampDecision(WorkRequest__c req, String status, String note) {
        req.StatusPk__c = status;
        req.DecisionDateTime__c = DateTime.now();
        if (String.isNotBlank(note)) {
            req.DecisionNoteTxt__c = note.left(1024);
        }
        if (req.ApproverUserLookup__c == null) {
            req.ApproverUserLookup__c = UserInfo.getUserId();
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // AUDIT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Emits one ActivityLog__c per approval lifecycle event,
     *              mirroring the Doc-approval service's audit pattern. The
     *              activity-log trigger contributes the SHA-256 hash chain via
     *              DeliveryAuditChainService.setHashOnInsert — this is the
     *              immutable per-event decision history (the request itself
     *              carries only its final decision state).
     * @param workItemId WorkItem__c the decision concerns.
     * @param action Lifecycle verb (Auto_Approve / Approve / Approve_Increase
     *        / Decline / Request_Increase).
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
