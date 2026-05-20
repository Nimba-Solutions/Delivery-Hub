/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  PR 7 — Single-step approval framework for Feature__c toggles
 *               (Layer 5 of the cockpit architecture).
 *
 *               The lifecycle:
 *                 submit(featureId, action, reason)
 *                   -> creates FeatureToggleRequest__c (Status=Pending) with a
 *                      frozen CascadeSnapshotJsonTxt__c
 *                   -> creates ONE FeatureToggleApproval__c row
 *                      (Step=1, Status=Pending, Required=now)
 *                 grant(approvalId, note)
 *                   -> stamps Approval row Status=Approved + Decision fields
 *                   -> applyIfFullyGranted() — if every approval row on the
 *                      request is Approved or Auto, flips the underlying
 *                      Feature__c and marks request Status=Applied. The
 *                      Feature__c trigger handles the settings-mirror cascade
 *                      and ActivityLog__c audit row (with SHA-256 hash chain
 *                      contributed by DeliveryActivityLogTrigger).
 *                 reject(approvalId, note)
 *                   -> stamps Approval row Status=Rejected
 *                   -> propagates to the request (Status=Rejected) so a
 *                      single dissent halts the chain.
 *                 rollback(requestId, note)
 *                   -> reverses an Applied request by flipping the Feature__c
 *                      back to its pre-Apply state. Marks request RolledBack.
 *
 *               PR 8 adds multi-step cascading approvals, REST endpoints, and
 *               explicit hash-chain audit on apply.
 *
 *               Global because PR 8 may expose this surface via REST for the
 *               external onboarding portal; all DTO classes used in the
 *               return signature are global per CLAUDE.md.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
global with sharing class DeliveryFeatureApprovalService {

    /** Action value: enable the feature. */
    public static final String ACTION_ENABLE = 'Enable';
    /** Action value: disable the feature. */
    public static final String ACTION_DISABLE = 'Disable';

    /** Request status values. */
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_GRANTED = 'Granted';
    public static final String STATUS_REJECTED = 'Rejected';
    public static final String STATUS_APPLIED = 'Applied';
    public static final String STATUS_ROLLED_BACK = 'RolledBack';

    /** Approval row status values. */
    public static final String APPROVAL_PENDING = 'Pending';
    public static final String APPROVAL_APPROVED = 'Approved';
    public static final String APPROVAL_REJECTED = 'Rejected';
    public static final String APPROVAL_AUTO = 'Auto';

    /** Recursion guard so the request trigger doesn't re-enter applyIfFullyGranted. */
    @TestVisible
    private static Boolean inApplyContext = false;

    /**
     * @description DTO for the approval inbox LWC. One row per pending
     *              FeatureToggleApproval__c assigned to the running user.
     */
    global class ApprovalInboxDTO {
        @AuraEnabled public Id approvalId;
        @AuraEnabled public Id requestId;
        @AuraEnabled public Id featureId;
        @AuraEnabled public String featureLabel;
        @AuraEnabled public String action;
        @AuraEnabled public String reason;
        @AuraEnabled public DateTime requestedAt;
        @AuraEnabled public String requestedByName;
        @AuraEnabled public Integer stepNumber;
        @AuraEnabled public String status;
    }

    // ────────────────────────────────────────────────────────────────────
    // SUBMIT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Submits a new toggle request. Creates the request row in
     *              Pending status with a frozen cascade snapshot, then one
     *              FeatureToggleApproval__c row in Pending status with
     *              StepNumber=1 and RequiredDateTime__c=now.
     * @param featureId The Feature__c being toggled.
     * @param action 'Enable' or 'Disable'.
     * @param reason Optional rationale from the requester.
     * @return The new FeatureToggleRequest__c Id.
     */
    @AuraEnabled
    global static Id submit(Id featureId, String action, String reason) {
        validateSubmitInputs(featureId, action);

        String snapshot = serializeCascadeSnapshot(featureId, action);

        FeatureToggleRequest__c req = new FeatureToggleRequest__c(
            FeatureLookup__c = featureId,
            ActionPk__c = action,
            StatusPk__c = STATUS_PENDING,
            ReasonTxt__c = String.isBlank(reason) ? null : reason.left(1024),
            RequestedByUserLookup__c = UserInfo.getUserId(),
            RequestedDateTime__c = DateTime.now(),
            CascadeSnapshotJsonTxt__c = snapshot
        );
        try {
            insert req;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.submit] insert request failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to submit toggle request.');
        }

        insertSingleStepApproval(req.Id, featureId);
        return req.Id;
    }

    private static void validateSubmitInputs(Id featureId, String action) {
        if (featureId == null) {
            throw new AuraHandledException('featureId is required.');
        }
        if (action != ACTION_ENABLE && action != ACTION_DISABLE) {
            throw new AuraHandledException('action must be Enable or Disable.');
        }
    }

    private static String serializeCascadeSnapshot(Id featureId, String action) {
        try {
            DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
                DeliveryFeatureGraphService.computeCascade(featureId, action);
            return JSON.serialize(root);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.serializeCascadeSnapshot] failed: '
                + e.getMessage());
            return null;
        }
    }

    private static void insertSingleStepApproval(Id requestId, Id featureId) {
        FeatureToggleApproval__c row = new FeatureToggleApproval__c(
            RequestLookup__c = requestId,
            FeatureLookup__c = featureId,
            StepNumber__c = 1,
            StatusPk__c = APPROVAL_PENDING,
            RequiredDateTime__c = DateTime.now()
        );
        try {
            insert row;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.insertSingleStepApproval] failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to create approval row.');
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // GRANT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approver-side grant. Stamps the approval row Approved +
     *              decision fields, then re-evaluates the request: if every
     *              row on the request is Approved or Auto, applyIfFullyGranted
     *              flips the underlying feature and stamps the request
     *              Applied.
     * @param approvalId The FeatureToggleApproval__c row being decided.
     * @param note Optional decision note from the approver.
     */
    @AuraEnabled
    global static void grant(Id approvalId, String note) {
        FeatureToggleApproval__c row = loadApprovalForDecision(approvalId);
        stampDecision(row, APPROVAL_APPROVED, note);
        applyIfFullyGranted(row.RequestLookup__c);
    }

    /**
     * @description Approver-side reject. Stamps the row Rejected + propagates
     *              Status=Rejected to the parent request (single dissent
     *              halts the chain).
     * @param approvalId The FeatureToggleApproval__c row being decided.
     * @param note Optional decision note from the approver.
     */
    @AuraEnabled
    global static void reject(Id approvalId, String note) {
        FeatureToggleApproval__c row = loadApprovalForDecision(approvalId);
        stampDecision(row, APPROVAL_REJECTED, note);
        markRequestRejected(row.RequestLookup__c);
    }

    private static FeatureToggleApproval__c loadApprovalForDecision(Id approvalId) {
        if (approvalId == null) {
            throw new AuraHandledException('approvalId is required.');
        }
        List<FeatureToggleApproval__c> rows = [
            SELECT Id, RequestLookup__c, FeatureLookup__c, StepNumber__c,
                   StatusPk__c, ApproverUserLookup__c
            FROM FeatureToggleApproval__c
            WHERE Id = :approvalId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Approval row not found.');
        }
        return rows.get(0);
    }

    private static void stampDecision(FeatureToggleApproval__c row, String status, String note) {
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
                '[DeliveryFeatureApprovalService.stampDecision] update failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to record decision.');
        }
    }

    private static void markRequestRejected(Id requestId) {
        if (requestId == null) {
            return;
        }
        FeatureToggleRequest__c req = new FeatureToggleRequest__c(
            Id = requestId,
            StatusPk__c = STATUS_REJECTED
        );
        try {
            update req;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.markRequestRejected] failed: '
                + e.getMessage());
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // APPLY (private — called from grant + the request trigger)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description When every approval row on a request is Approved (or
     *              Auto), flips the underlying Feature__c and stamps the
     *              request Applied. No-ops if any row is still Pending or
     *              already Rejected. Recursion-guarded so the request
     *              trigger and the explicit grant path don't double-apply.
     * @param requestId The FeatureToggleRequest__c to evaluate.
     */
    public static void applyIfFullyGranted(Id requestId) {
        if (inApplyContext || requestId == null) {
            return;
        }
        FeatureToggleRequest__c req = loadRequestOrNull(requestId);
        if (req == null || req.StatusPk__c == STATUS_APPLIED
            || req.StatusPk__c == STATUS_REJECTED
            || req.StatusPk__c == STATUS_ROLLED_BACK) {
            return;
        }
        if (!allApprovalsGranted(requestId)) {
            return;
        }
        runApply(req);
    }

    private static FeatureToggleRequest__c loadRequestOrNull(Id requestId) {
        List<FeatureToggleRequest__c> reqs = [
            SELECT Id, FeatureLookup__c, ActionPk__c, StatusPk__c,
                   EffectiveDateTime__c, RequestedByUserLookup__c
            FROM FeatureToggleRequest__c
            WHERE Id = :requestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return reqs.isEmpty() ? null : reqs.get(0);
    }

    private static Boolean allApprovalsGranted(Id requestId) {
        List<FeatureToggleApproval__c> rows = [
            SELECT Id, StatusPk__c
            FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId
            WITH SYSTEM_MODE
        ];
        if (rows.isEmpty()) {
            return false;
        }
        for (FeatureToggleApproval__c row : rows) {
            if (row.StatusPk__c != APPROVAL_APPROVED && row.StatusPk__c != APPROVAL_AUTO) {
                return false;
            }
        }
        return true;
    }

    private static void runApply(FeatureToggleRequest__c req) {
        inApplyContext = true;
        try {
            flipFeature(req.FeatureLookup__c, req.ActionPk__c);
            req.StatusPk__c = STATUS_APPLIED;
            req.AppliedDateTime__c = DateTime.now();
            update req;
            writeAuditRow(req.FeatureLookup__c, req.ActionPk__c, req.Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.runApply] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to apply toggle.');
        } finally {
            inApplyContext = false;
        }
    }

    private static void flipFeature(Id featureId, String action) {
        Feature__c f = loadFeatureForFlipOrThrow(featureId);
        applyFlipFields(f, action == ACTION_ENABLE);
        update f;
    }

    private static Feature__c loadFeatureForFlipOrThrow(Id featureId) {
        List<Feature__c> rows = [
            SELECT Id, EnabledDateTime__c, DisabledDateTime__c, LastToggledByUserLookup__c
            FROM Feature__c
            WHERE Id = :featureId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Feature not found.');
        }
        return rows.get(0);
    }

    private static void applyFlipFields(Feature__c f, Boolean enable) {
        DateTime now = DateTime.now();
        if (enable) {
            f.EnabledDateTime__c = now;
            f.DisabledDateTime__c = null;
        } else {
            f.DisabledDateTime__c = now;
        }
        f.LastToggledByUserLookup__c = UserInfo.getUserId();
    }

    // ────────────────────────────────────────────────────────────────────
    // ROLLBACK
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Reverses a previously-Applied request. Flips the
     *              underlying Feature__c back to its pre-Apply state (the
     *              inverse of the request's Action) and marks the request
     *              RolledBack with AppliedDateTime cleared. Emits an audit
     *              row for the reversal.
     * @param requestId The FeatureToggleRequest__c to roll back.
     * @param note Optional rollback note recorded in the audit ContextData.
     */
    @AuraEnabled
    global static void rollback(Id requestId, String note) {
        FeatureToggleRequest__c req = loadRequestForRollbackOrThrow(requestId);
        String inverse = (req.ActionPk__c == ACTION_ENABLE) ? ACTION_DISABLE : ACTION_ENABLE;
        inApplyContext = true;
        try {
            flipFeature(req.FeatureLookup__c, inverse);
            req.StatusPk__c = STATUS_ROLLED_BACK;
            req.AppliedDateTime__c = null;
            update req;
            writeAuditRowWithNote(
                req.FeatureLookup__c,
                'Rollback_' + req.ActionPk__c,
                req.Id,
                note);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.rollback] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to roll back the request.');
        } finally {
            inApplyContext = false;
        }
    }

    private static FeatureToggleRequest__c loadRequestForRollbackOrThrow(Id requestId) {
        if (requestId == null) {
            throw new AuraHandledException('requestId is required.');
        }
        List<FeatureToggleRequest__c> reqs = [
            SELECT Id, FeatureLookup__c, ActionPk__c, StatusPk__c, AppliedDateTime__c
            FROM FeatureToggleRequest__c
            WHERE Id = :requestId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (reqs.isEmpty()) {
            throw new AuraHandledException('Request not found.');
        }
        FeatureToggleRequest__c req = reqs.get(0);
        if (req.StatusPk__c != STATUS_APPLIED) {
            throw new AuraHandledException(
                'Only Applied requests can be rolled back.');
        }
        return req;
    }

    // ────────────────────────────────────────────────────────────────────
    // INBOX (LWC-facing)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Returns Pending approval rows assigned to the running user,
     *              joined with their request + feature for one-screen render.
     *              Rows with no assigned approver are filtered out (the
     *              single-step inbox shape will be widened by PR 8 when
     *              ApproverUserLookup__c is populated by the chain builder).
     * @return List of ApprovalInboxDTO ordered by request RequestedDateTime__c
     *         ASC (oldest first).
     */
    @AuraEnabled(cacheable=true)
    global static List<ApprovalInboxDTO> getInbox() {
        List<ApprovalInboxDTO> out = new List<ApprovalInboxDTO>();
        Id userId = UserInfo.getUserId();
        try {
            for (FeatureToggleApproval__c row : [
                SELECT Id, RequestLookup__c, FeatureLookup__c, StepNumber__c,
                       StatusPk__c,
                       RequestLookup__r.ActionPk__c,
                       RequestLookup__r.ReasonTxt__c,
                       RequestLookup__r.RequestedDateTime__c,
                       RequestLookup__r.RequestedByUserLookup__c,
                       RequestLookup__r.RequestedByUserLookup__r.Name,
                       FeatureLookup__r.Name,
                       FeatureLookup__r.FeatureDefinitionTxt__c
                FROM FeatureToggleApproval__c
                WHERE StatusPk__c = :APPROVAL_PENDING
                  AND ApproverUserLookup__c = :userId
                WITH SYSTEM_MODE
                ORDER BY RequestLookup__r.RequestedDateTime__c ASC NULLS LAST
                LIMIT 200
            ]) {
                out.add(toInboxDto(row));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.getInbox] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to load approval inbox.');
        }
        return out;
    }

    private static ApprovalInboxDTO toInboxDto(FeatureToggleApproval__c row) {
        ApprovalInboxDTO dto = new ApprovalInboxDTO();
        dto.approvalId = row.Id;
        dto.requestId = row.RequestLookup__c;
        dto.featureId = row.FeatureLookup__c;
        dto.stepNumber = (row.StepNumber__c == null) ? 1 : row.StepNumber__c.intValue();
        dto.status = row.StatusPk__c;
        if (row.RequestLookup__r != null) {
            dto.action = row.RequestLookup__r.ActionPk__c;
            dto.reason = row.RequestLookup__r.ReasonTxt__c;
            dto.requestedAt = row.RequestLookup__r.RequestedDateTime__c;
            if (row.RequestLookup__r.RequestedByUserLookup__r != null) {
                dto.requestedByName = row.RequestLookup__r.RequestedByUserLookup__r.Name;
            }
        }
        if (row.FeatureLookup__r != null) {
            String defName = row.FeatureLookup__r.FeatureDefinitionTxt__c;
            dto.featureLabel = String.isNotBlank(defName)
                ? defName
                : row.FeatureLookup__r.Name;
        }
        return dto;
    }

    // ────────────────────────────────────────────────────────────────────
    // TRIGGER ENTRY POINT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Trigger entry point. Re-evaluates applyIfFullyGranted for
     *              every request whose status moved into Pending or Granted
     *              in this transaction (or was inserted Pending). The
     *              recursion guard inside applyIfFullyGranted prevents
     *              double-application when the apply path mutates the
     *              request row.
     * @param op Trigger.operationType.
     * @param newRows Trigger.new.
     * @param oldMap Trigger.oldMap (null on insert).
     */
    public static void onRequestAfterChange(
        TriggerOperation op,
        List<FeatureToggleRequest__c> newRows,
        Map<Id, FeatureToggleRequest__c> oldMap
    ) {
        if (inApplyContext || newRows == null || newRows.isEmpty()) {
            return;
        }
        Set<Id> requestIds = collectRequestIdsToEvaluate(newRows, oldMap);
        for (Id rid : requestIds) {
            applyIfFullyGranted(rid);
        }
    }

    private static Set<Id> collectRequestIdsToEvaluate(
        List<FeatureToggleRequest__c> newRows,
        Map<Id, FeatureToggleRequest__c> oldMap
    ) {
        Set<Id> ids = new Set<Id>();
        for (FeatureToggleRequest__c req : newRows) {
            String oldStatus = (oldMap == null || !oldMap.containsKey(req.Id))
                ? null
                : oldMap.get(req.Id).StatusPk__c;
            if (isRequestEvaluatable(req.StatusPk__c, oldStatus)) {
                ids.add(req.Id);
            }
        }
        return ids;
    }

    private static Boolean isRequestEvaluatable(String newStatus, String oldStatus) {
        if (newStatus != STATUS_PENDING && newStatus != STATUS_GRANTED) {
            return false;
        }
        return newStatus != oldStatus || oldStatus == null;
    }

    // ────────────────────────────────────────────────────────────────────
    // AUDIT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Emits one ActivityLog__c per Apply / Rollback. The
     *              DeliveryActivityLogTrigger handles SHA-256 hash chain
     *              insertion (via DeliveryAuditChainService.setHashOnInsert),
     *              so this method only populates the visible fields.
     * @param featureId Feature__c whose toggle just flipped.
     * @param action The Action picklist value from the request.
     * @param requestId The FeatureToggleRequest__c Id (carried in ContextData).
     */
    private static void writeAuditRow(Id featureId, String action, Id requestId) {
        writeAuditRowWithNote(featureId, action, requestId, null);
    }

    private static void writeAuditRowWithNote(
        Id featureId, String action, Id requestId, String note
    ) {
        Map<String, Object> ctx = new Map<String, Object>{
            'requestId' => requestId,
            'action' => action,
            'approverUserId' => UserInfo.getUserId()
        };
        if (String.isNotBlank(note)) {
            ctx.put('note', note.left(500));
        }
        ActivityLog__c row = new ActivityLog__c(
            ActionTypePk__c = 'Feature_Toggle',
            RecordIdTxt__c = (featureId == null) ? null : String.valueOf(featureId),
            ContextDataTxt__c = JSON.serialize(ctx),
            UserIdTxt__c = UserInfo.getUserId(),
            ComponentNameTxt__c = 'DeliveryFeatureApprovalService'
        );
        try {
            insert row;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.writeAuditRow] insert failed: '
                + e.getMessage());
        }
    }
}
