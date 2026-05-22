/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Multi-step cascading approval framework for Feature__c toggles
 *               (Layer 5 of the cockpit architecture). PR 8 generalizes the
 *               single-step PR 7 surface:
 *
 *               submit(featureId, action, reason)
 *                 -> creates FeatureToggleRequest__c (Status=Pending) with a
 *                    frozen CascadeSnapshotJsonTxt__c.
 *                 -> walks the cascade graph (BFS via DeliveryFeatureGraphService)
 *                    and inserts ONE FeatureToggleApproval__c per non-Optional
 *                    cascade node, plus a root-level (StepNumber=0) row that
 *                    represents the final sign-off on the requested feature.
 *                    Hard edges get RequiredDateTime__c=now (blocking). Soft
 *                    edges get RequiredDateTime__c=null (informational; auto-
 *                    satisfied when all required rows resolve). The root row
 *                    is always required.
 *               grant(approvalId, note)
 *                 -> stamps approval row Status=Approved + decision fields.
 *                 -> applyIfFullyGranted() — when every REQUIRED approval row
 *                    is Approved or Auto, flips the underlying Feature__c,
 *                    auto-marks every Soft/non-required row Status='Auto',
 *                    stamps the request Status=Applied + AppliedDateTime, and
 *                    writes an ActivityLog__c row. The activity-log trigger
 *                    contributes the SHA-256 hash chain via
 *                    DeliveryAuditChainService.setHashOnInsert.
 *               reject(approvalId, note)
 *                 -> stamps row Status=Rejected and propagates Status=Rejected
 *                    to the parent request so a single dissent halts the chain.
 *               rollback(requestId, note)
 *                 -> reverses an Applied request by flipping the Feature__c
 *                    back to its pre-Apply state. Marks request RolledBack.
 *               getApprovalChain(requestId)
 *                 -> Ordered list of every approval row for a request, shaped
 *                    for the LWC "Show chain" modal.
 *
 *               Global because PR 8 exposes this surface via REST for the
 *               external onboarding portal (see DeliveryPublicApiService);
 *               all DTO classes used in the return signature are global per
 *               CLAUDE.md.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.ExcessivePublicCount')
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

    /** Dependency type values from FeatureDependencyType GVS. */
    public static final String DEP_HARD = 'Hard';
    public static final String DEP_SOFT = 'Soft';
    public static final String DEP_OPTIONAL = 'Optional';

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

    /**
     * @description DTO row for getApprovalChain(). One entry per
     *              FeatureToggleApproval__c on the request, ordered by
     *              StepNumber then DecisionDateTime. Used by the LWC
     *              "Show chain" modal to render the full multi-step chain.
     */
    global class ApprovalChainNodeDTO {
        @AuraEnabled public Id approvalId;
        @AuraEnabled public Id featureId;
        @AuraEnabled public String featureLabel;
        @AuraEnabled public Integer stepNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean requiredBoolean;
        @AuraEnabled public Id approverUserId;
        @AuraEnabled public String approverUserName;
        @AuraEnabled public DateTime decisionDateTime;
        @AuraEnabled public String decisionNote;
    }

    // ────────────────────────────────────────────────────────────────────
    // SUBMIT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Submits a new toggle request. Creates the request row in
     *              Pending status with a frozen cascade snapshot, then walks
     *              the cascade graph to insert one FeatureToggleApproval__c
     *              per non-Optional dependency node plus a root-level
     *              sign-off row.
     * @param featureId The Feature__c being toggled.
     * @param action 'Enable' or 'Disable'.
     * @param reason Optional rationale from the requester.
     * @return The new FeatureToggleRequest__c Id.
     */
    @AuraEnabled
    global static Id submit(Id featureId, String action, String reason) {
        validateSubmitInputs(featureId, action);

        DeliveryFeatureGraphService.FeatureGraphNodeDTO root =
            computeCascadeRootOrNull(featureId, action);
        String snapshot = serializeRootOrNull(root);

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

        List<FeatureToggleApproval__c> approvals = buildApprovalsForCascade(req.Id, featureId, root);
        try {
            insert approvals;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.submit] insert approvals failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to create approval rows.');
        }
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

    private static DeliveryFeatureGraphService.FeatureGraphNodeDTO computeCascadeRootOrNull(
        Id featureId, String action
    ) {
        try {
            return DeliveryFeatureGraphService.computeCascade(featureId, action);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.computeCascadeRootOrNull] failed: '
                + e.getMessage());
            return null;
        }
    }

    private static String serializeRootOrNull(DeliveryFeatureGraphService.FeatureGraphNodeDTO root) {
        if (root == null) {
            return null;
        }
        try {
            return JSON.serialize(root);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Walks the cascade tree and produces one approval row per
     *              non-Optional cascade node + one root-level (StepNumber=0)
     *              row representing the final sign-off on the requested
     *              feature. Hard rows are Required (RequiredDateTime__c=now).
     *              Soft rows are not required (RequiredDateTime__c=null) and
     *              get auto-marked at apply time. If the cascade graph could
     *              not be computed (e.g. transient SOQL error), falls back to
     *              a single root row so submit still produces a valid request.
     * @param requestId Parent FeatureToggleRequest__c.
     * @param rootFeatureId The Feature__c the request targets.
     * @param root Cascade tree root, or null if computeCascade returned null.
     * @return List of unsaved FeatureToggleApproval__c rows ready to insert.
     */
    private static List<FeatureToggleApproval__c> buildApprovalsForCascade(
        Id requestId,
        Id rootFeatureId,
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root
    ) {
        List<FeatureToggleApproval__c> rows = new List<FeatureToggleApproval__c>();
        DateTime nowTs = DateTime.now();
        // Root-level sign-off row — always required, StepNumber=0.
        rows.add(new FeatureToggleApproval__c(
            RequestLookup__c = requestId,
            FeatureLookup__c = rootFeatureId,
            StepNumber__c = 0,
            StatusPk__c = APPROVAL_PENDING,
            RequiredDateTime__c = nowTs
        ));
        if (root == null) {
            return rows;
        }
        List<CascadeNodeWithDepth> flat = flattenCascadeWithDepth(root);
        for (CascadeNodeWithDepth entry : flat) {
            // Skip the root itself (depth 0 handled above) and Optional edges.
            if (entry.depth == 0 || entry.node == null) {
                continue;
            }
            String depType = entry.node.dependencyType;
            if (depType == DEP_OPTIONAL) {
                continue;
            }
            Boolean isHard = (depType == DEP_HARD);
            rows.add(new FeatureToggleApproval__c(
                RequestLookup__c = requestId,
                FeatureLookup__c = entry.node.featureId,
                StepNumber__c = entry.depth,
                StatusPk__c = APPROVAL_PENDING,
                // Hard => required (blocking). Soft => informational (auto on apply).
                RequiredDateTime__c = isHard ? nowTs : null
            ));
        }
        return rows;
    }

    /**
     * @description Internal tuple — pairs a cascade node DTO with its BFS depth.
     *              Keeps flattenCascadeWithDepth's return signature flat.
     */
    private class CascadeNodeWithDepth {
        DeliveryFeatureGraphService.FeatureGraphNodeDTO node;
        Integer depth;
        /**
         * @description Constructs a node-with-depth pair.
         * @param n Cascade node DTO from DeliveryFeatureGraphService.computeCascade.
         * @param d BFS depth (0 = root).
         */
        CascadeNodeWithDepth(DeliveryFeatureGraphService.FeatureGraphNodeDTO n, Integer d) {
            this.node = n;
            this.depth = d;
        }
    }

    /**
     * @description Flattens a cascade tree into a depth-ordered list using
     *              an iterative BFS — Apex caps recursive call depth at ~1000
     *              and the graph service caps cascade depth at 10, but BFS
     *              is also more natural here because we want shallow nodes
     *              earliest (StepNumber matches BFS layer).
     * @param root Root cascade node from DeliveryFeatureGraphService.computeCascade.
     * @return Flat list of (node, depth) tuples in BFS layer order.
     */
    private static List<CascadeNodeWithDepth> flattenCascadeWithDepth(
        DeliveryFeatureGraphService.FeatureGraphNodeDTO root
    ) {
        List<CascadeNodeWithDepth> out = new List<CascadeNodeWithDepth>();
        if (root == null) {
            return out;
        }
        List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> currentLayer =
            new List<DeliveryFeatureGraphService.FeatureGraphNodeDTO>{ root };
        Integer depth = 0;
        while (!currentLayer.isEmpty()) {
            List<DeliveryFeatureGraphService.FeatureGraphNodeDTO> nextLayer =
                new List<DeliveryFeatureGraphService.FeatureGraphNodeDTO>();
            for (DeliveryFeatureGraphService.FeatureGraphNodeDTO node : currentLayer) {
                if (node == null) {
                    continue;
                }
                out.add(new CascadeNodeWithDepth(node, depth));
                if (node.children != null) {
                    nextLayer.addAll(node.children);
                }
            }
            currentLayer = nextLayer;
            depth++;
        }
        return out;
    }

    // ────────────────────────────────────────────────────────────────────
    // GRANT
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Approver-side grant. Stamps the approval row Approved +
     *              decision fields, then re-evaluates the request: if every
     *              required row on the request is Approved or Auto,
     *              applyIfFullyGranted flips the underlying feature and
     *              stamps the request Applied.
     * @param approvalId The FeatureToggleApproval__c row being decided.
     * @param note Optional decision note from the approver.
     */
    @AuraEnabled
    global static void grant(Id approvalId, String note) {
        FeatureToggleApproval__c row = loadApprovalForDecision(approvalId);
        assertCallerIsApprover(row);
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
        assertCallerIsApprover(row);
        stampDecision(row, APPROVAL_REJECTED, note);
        markRequestRejected(row.RequestLookup__c);
    }

    /**
     * @description Caller-is-approver guard. Rejects callers other than the
     *              assigned approver and rejects rows that have no approver
     *              assigned. Without this gate, any authenticated user could
     *              call grant/reject directly (the LWC filters by approver,
     *              but the @AuraEnabled surface is reachable independently).
     *              Severity Medium per docs/audits/security-review-2026-05-21.md §7.
     * @param row The loaded approval row.
     */
    private static void assertCallerIsApprover(FeatureToggleApproval__c row) {
        if (row.ApproverUserLookup__c == null) {
            throw new AuraHandledException(
                'Approval has no assigned approver — cannot decide.');
        }
        if (row.ApproverUserLookup__c != UserInfo.getUserId()) {
            throw new AuraHandledException(
                'You are not the assigned approver for this row.');
        }
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
     * @description When every REQUIRED approval row on a request is Approved
     *              (or Auto), flips the underlying Feature__c, auto-marks the
     *              non-required rows Status='Auto', and stamps the request
     *              Applied. No-ops if any required row is still Pending or
     *              has been Rejected. Recursion-guarded so the request
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
        List<FeatureToggleApproval__c> rows = loadApprovalRows(requestId);
        if (!allRequiredApprovalsGranted(rows)) {
            return;
        }
        applyAndAudit(req, rows);
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

    private static List<FeatureToggleApproval__c> loadApprovalRows(Id requestId) {
        return [
            SELECT Id, StatusPk__c, RequiredDateTime__c
            FROM FeatureToggleApproval__c
            WHERE RequestLookup__c = :requestId
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Multi-step gating contract: every approval row whose
     *              RequiredDateTime__c is populated must be either Approved
     *              or Auto. Non-required rows do not block apply (they are
     *              auto-marked at the apply step). Empty row set returns
     *              false defensively (every request should have at least
     *              the root sign-off row).
     * @param rows All approval rows for the request.
     * @return true when every required row is decided in the affirmative.
     */
    private static Boolean allRequiredApprovalsGranted(List<FeatureToggleApproval__c> rows) {
        if (rows == null || rows.isEmpty()) {
            return false;
        }
        Boolean sawRequired = false;
        for (FeatureToggleApproval__c row : rows) {
            if (row.RequiredDateTime__c == null) {
                continue;
            }
            sawRequired = true;
            if (row.StatusPk__c != APPROVAL_APPROVED && row.StatusPk__c != APPROVAL_AUTO) {
                return false;
            }
        }
        return sawRequired;
    }

    /**
     * @description Performs the actual apply: flip the feature, auto-mark
     *              non-required rows, stamp the request, and write the audit
     *              row. Wrapped in the recursion guard.
     * @param req The request being applied.
     * @param rows All approval rows for the request (for the Auto sweep).
     */
    private static void applyAndAudit(
        FeatureToggleRequest__c req,
        List<FeatureToggleApproval__c> rows
    ) {
        inApplyContext = true;
        try {
            flipFeature(req.FeatureLookup__c, req.ActionPk__c);
            autoMarkNonRequired(rows);
            req.StatusPk__c = STATUS_APPLIED;
            req.AppliedDateTime__c = DateTime.now();
            update req;
            writeAuditRow(req.FeatureLookup__c, req.ActionPk__c, req.Id);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.applyAndAudit] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to apply toggle.');
        } finally {
            inApplyContext = false;
        }
    }

    private static void autoMarkNonRequired(List<FeatureToggleApproval__c> rows) {
        List<FeatureToggleApproval__c> updates = new List<FeatureToggleApproval__c>();
        DateTime nowTs = DateTime.now();
        for (FeatureToggleApproval__c row : rows) {
            if (row.RequiredDateTime__c != null) {
                continue;
            }
            if (row.StatusPk__c == APPROVAL_APPROVED
                || row.StatusPk__c == APPROVAL_REJECTED
                || row.StatusPk__c == APPROVAL_AUTO) {
                continue;
            }
            updates.add(new FeatureToggleApproval__c(
                Id = row.Id,
                StatusPk__c = APPROVAL_AUTO,
                DecisionDateTime__c = nowTs
            ));
        }
        if (!updates.isEmpty()) {
            try {
                update updates;
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryFeatureApprovalService.autoMarkNonRequired] failed: '
                    + e.getMessage());
            }
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
     *              Rows with no assigned approver are filtered out — PR 8
     *              leaves ApproverUserLookup__c null at submit time, so
     *              admins assign approvers out-of-band on the record page;
     *              PR 9+ will wire automatic approver resolution.
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

    /**
     * @description Returns every approval row on the request, ordered by
     *              StepNumber then DecisionDateTime. Used by the LWC "Show
     *              chain" modal and by the REST surface to expose the full
     *              multi-step chain to external onboarding portals.
     * @param requestId FeatureToggleRequest__c to inspect.
     * @return Ordered list of ApprovalChainNodeDTO entries.
     */
    @AuraEnabled(cacheable=true)
    global static List<ApprovalChainNodeDTO> getApprovalChain(Id requestId) {
        List<ApprovalChainNodeDTO> out = new List<ApprovalChainNodeDTO>();
        if (requestId == null) {
            return out;
        }
        try {
            for (FeatureToggleApproval__c row : [
                SELECT Id, FeatureLookup__c, StepNumber__c, StatusPk__c,
                       RequiredDateTime__c, DecisionDateTime__c, DecisionNoteTxt__c,
                       ApproverUserLookup__c, ApproverUserLookup__r.Name,
                       FeatureLookup__r.Name, FeatureLookup__r.FeatureDefinitionTxt__c
                FROM FeatureToggleApproval__c
                WHERE RequestLookup__c = :requestId
                WITH SYSTEM_MODE
                ORDER BY StepNumber__c ASC NULLS LAST,
                         DecisionDateTime__c ASC NULLS LAST,
                         CreatedDate ASC
                LIMIT 200
            ]) {
                out.add(toChainDto(row));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryFeatureApprovalService.getApprovalChain] failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to load approval chain.');
        }
        return out;
    }

    private static ApprovalChainNodeDTO toChainDto(FeatureToggleApproval__c row) {
        ApprovalChainNodeDTO dto = new ApprovalChainNodeDTO();
        dto.approvalId = row.Id;
        dto.featureId = row.FeatureLookup__c;
        dto.stepNumber = (row.StepNumber__c == null) ? null : row.StepNumber__c.intValue();
        dto.status = row.StatusPk__c;
        dto.requiredBoolean = row.RequiredDateTime__c != null;
        dto.approverUserId = row.ApproverUserLookup__c;
        if (row.ApproverUserLookup__r != null) {
            dto.approverUserName = row.ApproverUserLookup__r.Name;
        }
        dto.decisionDateTime = row.DecisionDateTime__c;
        dto.decisionNote = row.DecisionNoteTxt__c;
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
