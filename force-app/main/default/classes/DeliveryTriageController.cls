/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Triage controller backing the queue cards Jose runs on a
 *               standup, front, middle and back of the work-item pipeline:
 *
 *               getCloseOutItems()  — back of pipe. WorkItems sitting in
 *                 'Deployed to Prod' awaiting the triager's verification /
 *                 close-out. Makes the "Deployed to Prod – Awaiting
 *                 Verification" report actionable from inside the workspace.
 *               getIntakeItems()    — front of pipe. WorkItems that have
 *                 arrived but were never activated onto the timeline
 *                 (ActivatedDateTime__c = NULL → invisible on the board/Gantt,
 *                 which filter ActivatedDateTime != null). This tab is the
 *                 only surface that shows them.
 *               getInFlightItems()  — middle of pipe. WorkItems in the dev →
 *                 deploying band (read-only; the Home "In Flight" card).
 *               getUnapprovedHours() / acknowledgeUnapprovedHours() — the Home
 *                 "Hours without approval" card: hours logged (after the
 *                 EnableUnapprovedHoursFlagDateTime__c cutover) on requests
 *                 nobody approved, and the approver's one-click clear.
 *
 *               Mutations are all bulk + partial-failure-safe, mirroring
 *               DeliveryWorkApprovalService.approveMany: every id is processed,
 *               failures (including ids that resolve to no record) are
 *               collected per row, and both lists come back in BulkResultDTO —
 *               one bad row never blocks the rest of the batch, and the counts
 *               always reconcile to the input.
 *
 *               SOQL is WITH SYSTEM_MODE per CLAUDE.md (WITH USER_MODE breaks
 *               in namespaced package test context). Picklist values are passed
 *               as safe known literals (the picklist-allowlist trigger is a
 *               documented no-op; the fields accept known values). Report ids
 *               are resolved by DeveloperName the same way
 *               DeliveryApprovalSummaryController does — bare names are safe
 *               because Report DeveloperNames are not namespace-prefixed on
 *               subscriber installs.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity')
public with sharing class DeliveryTriageController {

    /** Stage a work item sits in once deployed, awaiting close-out verification. */
    private static final String STAGE_DEPLOYED_TO_PROD =
        DeliveryWorkflowConfigService.STAGE_DEPLOYED_TO_PROD;

    /** Stage routeToDev hands an intake item into (and activates it). A raw
     *  inbound request isn't sized/estimated/approved yet, so hand-off lands it
     *  at the START of the real workflow — Ready for Sizing — not at
     *  Ready for Development (which would falsely signal it's ready to code). */
    private static final String STAGE_READY_FOR_SIZING = 'Ready for Sizing';

    /** Terminal value markDone / dismissIntake fall back to. */
    private static final String STAGE_DONE = 'Done';
    private static final String STAGE_CANCELLED = 'Cancelled';

    /** Report DeveloperName backing the close-out tab's "open full report" link. */
    private static final String REPORT_CLOSE_OUT =
        'Deployed_To_Prod_Awaiting_Verification';

    /** Report DeveloperName backing the in-flight card's "open full report" link. */
    private static final String REPORT_IN_FLIGHT = 'In_Flight_Work_Items';

    /**
     * @description WorkItem__c stages excluded from the intake scope — a
     * CMT-driven terminal union (defaults to Done/Cancelled when CMT empty) so
     * a dismissed/closed item never reappears at the front of the pipe.
     */
    @TestVisible
    private static Set<String> terminalStages {
        get {
            if (terminalStages == null) {
                terminalStages = DeliveryWorkflowConfigService.getAllTerminalStageValues();
            }
            return terminalStages;
        }
        set;
    }

    // ────────────────────────────────────────────────────────────────────
    // DTOs
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description One row in the close-out queue (Deployed to Prod, awaiting
     *              verification).
     */
    public class CloseOutItemDTO {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String name;
        @AuraEnabled public String briefDescription;
        @AuraEnabled public Datetime stageEnteredAt;
        @AuraEnabled public String developerName;
        @AuraEnabled public Id developerId;
    }

    /**
     * @description One row in the intake queue (arrived, not yet activated onto
     *              the timeline).
     */
    public class IntakeItemDTO {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String name;
        @AuraEnabled public String briefDescription;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String requestedByName;
        @AuraEnabled public String currentStage;
    }

    /**
     * @description One row on the Home "In Flight" card: a WorkItem inside the
     *              dev → deploying band (DeliveryWorkflowConfigService.IN_FLIGHT_STAGES).
     *              stageRank is the stage's position in that band so the LWC can
     *              keep pipeline order without knowing the stage list.
     */
    public class InFlightItemDTO {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String name;
        @AuraEnabled public String briefDescription;
        @AuraEnabled public String stage;
        @AuraEnabled public Integer stageRank;
        @AuraEnabled public Datetime stageEnteredAt;
        @AuraEnabled public String developerName;
        @AuraEnabled public Id developerId;
        @AuraEnabled public Decimal approvedHours;
    }

    /**
     * @description One row on the Home "Hours without approval" card: the
     *              flagged hours on ONE request (an item can carry several
     *              requests, so rows are per request, not per item).
     */
    public class UnapprovedHoursRowDTO {
        @AuraEnabled public Id requestId;
        @AuraEnabled public String requestStatus;
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String workItemName;
        @AuraEnabled public String briefDescription;
        @AuraEnabled public Decimal hours;
        @AuraEnabled public Integer logCount;
        @AuraEnabled public Date firstWorkDate;
        @AuraEnabled public Date lastWorkDate;
        /** False when the request must be decided elsewhere (see blockedReason). */
        @AuraEnabled public Boolean canAcknowledge;
        @AuraEnabled public String blockedReason;
    }

    /**
     * @description Feed for the "Hours without approval" card. enabled=false
     *              (and no rows) while EnableUnapprovedHoursFlagDateTime__c is
     *              null, so the card hides itself entirely.
     */
    public class UnapprovedHoursDTO {
        @AuraEnabled public Boolean enabled = false;
        @AuraEnabled public Boolean canApprove = false;
        @AuraEnabled public Datetime cutover;
        @AuraEnabled public Decimal totalHours = 0;
        @AuraEnabled public List<UnapprovedHoursRowDTO> rows = new List<UnapprovedHoursRowDTO>();
    }

    /**
     * @description Per-row failure entry for a bulk mutation.
     */
    public class FailureDTO {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String error;
        /**
         * @description Builds a per-row failure entry.
         * @param workItemId The work item id that failed.
         * @param error The failure message to surface.
         */
        public FailureDTO(Id workItemId, String error) {
            this.workItemId = workItemId;
            this.error = error;
        }
    }

    /**
     * @description Result of a bulk mutation: which items landed and one entry
     *              per failure, plus convenience counts so the LWC never has to
     *              length-check nulls.
     */
    public class BulkResultDTO {
        @AuraEnabled public List<Id> succeededIds = new List<Id>();
        @AuraEnabled public List<FailureDTO> failures = new List<FailureDTO>();
        @AuraEnabled public Integer succeededCount = 0;
        @AuraEnabled public Integer failedCount = 0;
    }

    // ────────────────────────────────────────────────────────────────────
    // Read getters (cacheable)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Back of pipe: WorkItems in 'Deployed to Prod' awaiting the
     *              triager's close-out verification. Oldest-in-stage first so
     *              the longest-waiting items lead.
     * @return CloseOutItemDTO rows (empty list when none).
     */
    @AuraEnabled(cacheable=true)
    public static List<CloseOutItemDTO> getCloseOutItems() {
        List<CloseOutItemDTO> rows = new List<CloseOutItemDTO>();
        try {
            for (WorkItem__c wi : [
                SELECT Id, Name, BriefDescriptionTxt__c, StageEnteredDateTime__c,
                       DeveloperLookup__c, DeveloperLookup__r.Name
                FROM WorkItem__c
                WHERE StageNamePk__c = :STAGE_DEPLOYED_TO_PROD
                  AND ArchivedDateTime__c = NULL
                  AND TemplateMarkedDateTime__c = NULL
                WITH SYSTEM_MODE
                ORDER BY StageEnteredDateTime__c ASC NULLS FIRST
            ]) {
                CloseOutItemDTO dto = new CloseOutItemDTO();
                dto.workItemId = wi.Id;
                dto.name = wi.Name;
                dto.briefDescription = wi.BriefDescriptionTxt__c;
                dto.stageEnteredAt = wi.StageEnteredDateTime__c;
                dto.developerId = wi.DeveloperLookup__c;
                dto.developerName = wi.DeveloperLookup__r != null
                    ? wi.DeveloperLookup__r.Name : null;
                rows.add(dto);
            }
        } catch (Exception e) {
            // No System.debug — AvoidDebugStatements is strictly enforced by the
            // CI PMD scan; the AuraHandledException carries the operator-facing text.
            throw new AuraHandledException('Unable to load the close-out queue.');
        }
        return rows;
    }

    /**
     * @description Front of pipe: WorkItems that arrived but were never
     *              activated onto the timeline. The board/Gantt require
     *              ActivatedDateTime__c != null, so un-activated items are
     *              invisible everywhere else — this is the gap the tab fills.
     *              Scope mirrors the board's exclusions (not archived, not a
     *              template) and drops terminal items so a dismissed inbound
     *              never reappears. Oldest arrivals first.
     * @return IntakeItemDTO rows (empty list when none).
     */
    @AuraEnabled(cacheable=true)
    public static List<IntakeItemDTO> getIntakeItems() {
        List<IntakeItemDTO> rows = new List<IntakeItemDTO>();
        try {
            for (WorkItem__c wi : [
                SELECT Id, Name, BriefDescriptionTxt__c, CreatedDate,
                       StageNamePk__c, ExternalRequesterEmail__c, CreatedBy.Name
                FROM WorkItem__c
                WHERE ActivatedDateTime__c = NULL
                  AND ArchivedDateTime__c = NULL
                  AND TemplateMarkedDateTime__c = NULL
                  AND StageNamePk__c NOT IN :terminalStages
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
            ]) {
                IntakeItemDTO dto = new IntakeItemDTO();
                dto.workItemId = wi.Id;
                dto.name = wi.Name;
                dto.briefDescription = wi.BriefDescriptionTxt__c;
                dto.createdDate = wi.CreatedDate;
                dto.currentStage = wi.StageNamePk__c;
                // Prefer the external requester (email-to-case intake) when
                // present; otherwise fall back to who created the record.
                dto.requestedByName = String.isNotBlank(wi.ExternalRequesterEmail__c)
                    ? wi.ExternalRequesterEmail__c
                    : (wi.CreatedBy != null ? wi.CreatedBy.Name : null);
                rows.add(dto);
            }
        } catch (Exception e) {
            // No System.debug — AvoidDebugStatements is strictly enforced by the
            // CI PMD scan; the AuraHandledException carries the operator-facing text.
            throw new AuraHandledException('Unable to load the intake queue.');
        }
        return rows;
    }

    /**
     * @description Everything currently in flight: WorkItems whose stage is in
     *              the dev → deploying band, oldest-in-stage first within each
     *              stage, stages in pipeline order. Read-only feed for the Home
     *              "In Flight" card (middle of the pipe, between Pending Work
     *              Approvals and Close Outs). Archived and template items are
     *              excluded the same way the other two queues exclude them.
     * @return In-flight rows in pipeline order (empty when nothing is in flight).
     */
    @AuraEnabled(cacheable=true)
    public static List<InFlightItemDTO> getInFlightItems() {
        List<String> orderedStages = DeliveryWorkflowConfigService.IN_FLIGHT_STAGES;
        Set<String> inFlight = DeliveryWorkflowConfigService.getInFlightStageValues();
        // Pre-seed one bucket per stage so the flatten below needs no branching.
        Map<String, List<InFlightItemDTO>> byStage = new Map<String, List<InFlightItemDTO>>();
        for (String stage : orderedStages) {
            byStage.put(stage, new List<InFlightItemDTO>());
        }
        for (WorkItem__c wi : [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   StageEnteredDateTime__c, ClientPreApprovedHoursNumber__c,
                   DeveloperLookup__c, DeveloperLookup__r.Name
            FROM WorkItem__c
            WHERE StageNamePk__c IN :inFlight
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
            WITH SYSTEM_MODE
            ORDER BY StageEnteredDateTime__c ASC NULLS FIRST
        ]) {
            InFlightItemDTO dto = new InFlightItemDTO();
            dto.workItemId = wi.Id;
            dto.name = wi.Name;
            dto.briefDescription = wi.BriefDescriptionTxt__c;
            dto.stage = wi.StageNamePk__c;
            dto.stageRank = orderedStages.indexOf(wi.StageNamePk__c);
            dto.stageEnteredAt = wi.StageEnteredDateTime__c;
            dto.developerId = wi.DeveloperLookup__c;
            dto.developerName = wi.DeveloperLookup__r?.Name;
            dto.approvedHours = wi.ClientPreApprovedHoursNumber__c;
            byStage.get(wi.StageNamePk__c).add(dto);
        }
        List<InFlightItemDTO> rows = new List<InFlightItemDTO>();
        for (String stage : orderedStages) {
            rows.addAll(byStage.get(stage));
        }
        return rows;
    }

    /**
     * @description Resolves the in-flight report's record id by DeveloperName
     *              so the card can link to the full report. Null when the
     *              report is absent in the org (the LWC disables the link).
     * @return The In_Flight_Work_Items report id, or null.
     */
    @AuraEnabled(cacheable=true)
    public static String getInFlightReportId() {
        for (Report r : [
            SELECT Id FROM Report
            WHERE DeveloperName = :REPORT_IN_FLIGHT
            WITH SYSTEM_MODE
            LIMIT 1
        ]) {
            return r.Id;
        }
        return null;
    }

    /**
     * @description Resolves the close-out report's record id by DeveloperName
     *              so the LWC can link to the full report without hardcoding an
     *              org-specific id. Returns null (LWC disables the link) when
     *              the report is absent in the org.
     * @return The Deployed-to-Prod-Awaiting-Verification report id, or null.
     */
    @AuraEnabled(cacheable=true)
    public static String getCloseOutReportId() {
        for (Report r : [
            SELECT Id FROM Report
            WHERE DeveloperName = :REPORT_CLOSE_OUT
            WITH SYSTEM_MODE
            LIMIT 1
        ]) {
            return r.Id;
        }
        return null;
    }

    // ────────────────────────────────────────────────────────────────────
    // Hours without approval (soft approve-before-hours gate)
    // ────────────────────────────────────────────────────────────────────

    /** Request statuses whose hours count as approved (never flagged). */
    @TestVisible
    private static final Set<String> APPROVED_REQUEST_STATUSES =
        new Set<String>{ 'Accepted', 'In Progress', 'Completed' };

    /** Request statuses this card must NOT flip: they are decided elsewhere. */
    private static final Map<String, String> BLOCKED_REQUEST_STATUSES = new Map<String, String>{
        'Offer Sent'  => 'Awaiting a decision in Pending Work Approvals. Approve it there.',
        'Inactive'    => 'This request was declined. Re-open it before approving hours on it.',
        'Budget Hold' => 'Over its approved budget. Approve a budget increase instead.'
    };

    private static final Integer MAX_UNAPPROVED_ROWS = 200;

    /**
     * @description Hours logged without an approved request. Only WorkLogs
     *              created at or after the EnableUnapprovedHoursFlagDateTime__c
     *              stamp count (the stamp doubles as the cutover, so historical
     *              hours are never flagged), whose parent request is not
     *              Accepted / In Progress / Completed, and that were not
     *              Rejected. Grouped per request, biggest first.
     * @return The card feed (enabled=false and empty while the flag is off).
     */
    @AuraEnabled(cacheable=true)
    public static UnapprovedHoursDTO getUnapprovedHours() {
        UnapprovedHoursDTO dto = new UnapprovedHoursDTO();
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Datetime cutover = settings == null ? null : settings.EnableUnapprovedHoursFlagDateTime__c;
        if (cutover == null) {
            return dto;
        }
        dto.enabled = true;
        dto.cutover = cutover;
        dto.canApprove = DeliveryAccessService.isApproverOrAdmin();

        Map<Id, UnapprovedHoursRowDTO> byRequest = new Map<Id, UnapprovedHoursRowDTO>();
        for (AggregateResult ar : [
            SELECT RequestId__c reqId, SUM(HoursLoggedNumber__c) hrs, COUNT(Id) cnt,
                   MIN(WorkDateDate__c) firstDate, MAX(WorkDateDate__c) lastDate
            FROM WorkLog__c
            WHERE CreatedDate >= :cutover
              AND RequestId__r.StatusPk__c NOT IN :APPROVED_REQUEST_STATUSES
              AND StatusPk__c != 'Rejected'
            WITH SYSTEM_MODE
            GROUP BY RequestId__c
            ORDER BY SUM(HoursLoggedNumber__c) DESC
            LIMIT :MAX_UNAPPROVED_ROWS
        ]) {
            UnapprovedHoursRowDTO row = new UnapprovedHoursRowDTO();
            row.requestId = (Id) ar.get('reqId');
            row.hours = (Decimal) ar.get('hrs');
            row.logCount = (Integer) ar.get('cnt');
            row.firstWorkDate = (Date) ar.get('firstDate');
            row.lastWorkDate = (Date) ar.get('lastDate');
            byRequest.put(row.requestId, row);
        }
        if (byRequest.isEmpty()) {
            return dto;
        }
        for (WorkRequest__c req : [
            SELECT Id, StatusPk__c, WorkItemId__c, WorkItemId__r.Name,
                   WorkItemId__r.BriefDescriptionTxt__c
            FROM WorkRequest__c
            WHERE Id IN :byRequest.keySet()
            WITH SYSTEM_MODE
        ]) {
            UnapprovedHoursRowDTO row = byRequest.get(req.Id);
            row.requestStatus = req.StatusPk__c;
            row.workItemId = req.WorkItemId__c;
            row.workItemName = req.WorkItemId__r?.Name;
            row.briefDescription = req.WorkItemId__r?.BriefDescriptionTxt__c;
            row.blockedReason = BLOCKED_REQUEST_STATUSES.get(req.StatusPk__c);
            row.canAcknowledge = row.blockedReason == null;
        }
        for (UnapprovedHoursRowDTO row : byRequest.values()) {
            dto.totalHours += row.hours == null ? 0 : row.hours;
            dto.rows.add(row);
        }
        return dto;
    }

    /**
     * @description "Approve hours": marks the given requests Accepted so the
     *              hours on them stop being flagged and later hours on the item
     *              land on an approved request. Deliberately NOT
     *              DeliveryWorkApprovalService.approve(): that also stamps the
     *              client cap (ClientPreApprovedHoursNumber__c /
     *              PreApprovedHoursNumber__c) and moves the WorkItem to Ready
     *              for Development. Here the WorkItem stage and caps are left
     *              untouched; only the request's status, decision time and
     *              approver change, plus one Work_Approval audit row
     *              ('Acknowledge_Hours') per request. Requests awaiting a
     *              decision (Offer Sent), declined (Inactive) or over budget
     *              (Budget Hold) are refused per row. Already-approved requests
     *              are idempotent successes. Approver or admin only.
     * @param requestIds WorkRequest__c ids from the card.
     * @return BulkResultDTO; succeededIds / failure ids are REQUEST ids.
     */
    @AuraEnabled
    public static BulkResultDTO acknowledgeUnapprovedHours(List<Id> requestIds) {
        DeliveryAccessService.requireApproverOrAdmin('approve hours');
        if (requestIds == null || requestIds.isEmpty()) {
            throw new AuraHandledException('No requests were selected.');
        }
        BulkResultDTO result = new BulkResultDTO();
        Set<Id> requested = new Set<Id>(requestIds);
        Map<Id, WorkRequest__c> found = new Map<Id, WorkRequest__c>([
            SELECT Id, StatusPk__c, WorkItemId__c, ApproverUserLookup__c
            FROM WorkRequest__c
            WHERE Id IN :requested
            WITH SYSTEM_MODE
        ]);
        List<WorkRequest__c> toUpdate = new List<WorkRequest__c>();
        for (Id reqId : requested) {
            WorkRequest__c req = found.get(reqId);
            String refusal = acknowledgeRefusal(req);
            if (refusal != null) {
                result.failures.add(new FailureDTO(reqId, refusal));
            } else if (APPROVED_REQUEST_STATUSES.contains(req.StatusPk__c)) {
                result.succeededIds.add(reqId);
            } else {
                toUpdate.add(stampAcknowledged(req));
            }
        }
        saveAcknowledged(result, toUpdate, found);
        finalizeCounts(result);
        return result;
    }

    // Saves the acknowledged requests (allOrNone=false), records per-row
    // outcomes, and writes one best-effort audit row per success. Extracted
    // from acknowledgeUnapprovedHours to keep it under the complexity gate.
    private static void saveAcknowledged(
        BulkResultDTO result, List<WorkRequest__c> toUpdate, Map<Id, WorkRequest__c> found
    ) {
        if (toUpdate.isEmpty()) {
            return;
        }
        Database.SaveResult[] saveResults =
            Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
        List<ActivityLog__c> audit = new List<ActivityLog__c>();
        for (Integer i = 0; i < saveResults.size(); i++) {
            Id reqId = toUpdate[i].Id;
            if (saveResults[i].isSuccess()) {
                result.succeededIds.add(reqId);
                audit.add(DeliveryWorkApprovalService.buildAuditRow(
                    found.get(reqId).WorkItemId__c, 'Acknowledge_Hours', reqId,
                    'Hours approved from Home'));
            } else {
                result.failures.add(new FailureDTO(reqId, firstError(saveResults[i])));
            }
        }
        // Audit is best-effort, like DeliveryWorkApprovalService.writeAuditRow.
        Database.insert(audit, false, AccessLevel.SYSTEM_MODE);
    }

    private static String acknowledgeRefusal(WorkRequest__c req) {
        if (req == null) {
            return 'Request not found.';
        }
        return BLOCKED_REQUEST_STATUSES.get(req.StatusPk__c);
    }

    private static WorkRequest__c stampAcknowledged(WorkRequest__c req) {
        WorkRequest__c upd = new WorkRequest__c(
            Id = req.Id,
            StatusPk__c = 'Accepted',
            DecisionDateTime__c = Datetime.now()
        );
        if (req.ApproverUserLookup__c == null) {
            upd.ApproverUserLookup__c = UserInfo.getUserId();
        }
        return upd;
    }

    // ────────────────────────────────────────────────────────────────────
    // Bulk mutations (non-cacheable, partial-failure-safe)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Close out the selected deployed items — moves each to the
     *              'Done' terminal stage. Bulk, partial-failure-safe.
     * @param workItemIds Items to mark done.
     * @return BulkResultDTO with succeeded ids and per-row failures.
     */
    @AuraEnabled
    public static BulkResultDTO markDone(List<Id> workItemIds) {
        return applyStageUpdate(workItemIds, STAGE_DONE, null, false);
    }

    /**
     * @description Hand the selected intake items off into the delivery
     *              workflow: assign the developer lookup, move to
     *              'Ready for Sizing' (the start of the real workflow — the item
     *              still needs sizing/estimation/approval before it's ready to
     *              code), and stamp ActivatedDateTime__c = now() so each becomes
     *              visible on the board/timeline. Bulk, partial-failure-safe.
     * @param workItemIds   Items to hand off.
     * @param developerUserId The User to assign (may be null to route unassigned).
     * @return BulkResultDTO with succeeded ids and per-row failures.
     */
    @AuraEnabled
    public static BulkResultDTO routeToDev(List<Id> workItemIds, Id developerUserId) {
        return applyStageUpdate(workItemIds, STAGE_READY_FOR_SIZING, developerUserId, true);
    }

    /**
     * @description Jose resolves an inbound item himself — moves it to a
     *              terminal stage ('Cancelled' when that value is in the
     *              terminal set, else 'Done'). Bulk, partial-failure-safe.
     * @param workItemIds Items to dismiss.
     * @return BulkResultDTO with succeeded ids and per-row failures.
     */
    @AuraEnabled
    public static BulkResultDTO dismissIntake(List<Id> workItemIds) {
        String dismissStage = terminalStages.contains(STAGE_CANCELLED)
            ? STAGE_CANCELLED : STAGE_DONE;
        return applyStageUpdate(workItemIds, dismissStage, null, false);
    }

    // ────────────────────────────────────────────────────────────────────
    // Internals
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Shared bulk-update engine. Loads the requested ids, applies
     *              the stage (and optionally the developer + activation stamp),
     *              runs an allOrNone=false update, and assembles a BulkResultDTO
     *              where: rows that updated land in succeededIds, rows that
     *              failed the DML become failures, AND ids that resolved to no
     *              record become not-found failures — so the returned counts
     *              always reconcile to the input list.
     * @param workItemIds Requested ids.
     * @param stage       Stage value to write.
     * @param developerUserId Developer lookup to set (ignored when routeToDev=false).
     * @param doActivate  When true, set DeveloperLookup__c + stamp ActivatedDateTime__c.
     * @return BulkResultDTO.
     */
    private static BulkResultDTO applyStageUpdate(
        List<Id> workItemIds, String stage, Id developerUserId, Boolean doActivate
    ) {
        BulkResultDTO result = new BulkResultDTO();
        if (workItemIds == null || workItemIds.isEmpty()) {
            throw new AuraHandledException('No items were selected.');
        }

        // De-dupe and load.
        Set<Id> requested = new Set<Id>(workItemIds);
        Map<Id, WorkItem__c> found = new Map<Id, WorkItem__c>([
            SELECT Id FROM WorkItem__c WHERE Id IN :requested WITH SYSTEM_MODE
        ]);

        // Ids that don't resolve to a record are deterministic failures.
        for (Id reqId : requested) {
            if (!found.containsKey(reqId)) {
                result.failures.add(new FailureDTO(reqId, 'Work item not found.'));
            }
        }

        if (found.isEmpty()) {
            finalizeCounts(result);
            return result;
        }

        Datetime now = System.now();
        List<WorkItem__c> toUpdate = new List<WorkItem__c>();
        for (WorkItem__c wi : found.values()) {
            wi.StageNamePk__c = stage;
            if (doActivate) {
                wi.DeveloperLookup__c = developerUserId;
                wi.ActivatedDateTime__c = now;
            }
            toUpdate.add(wi);
        }

        // allOrNone=false: one bad row never blocks the rest.
        Database.SaveResult[] saveResults =
            Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
        recordSaveResults(result, saveResults, toUpdate);

        finalizeCounts(result);
        return result;
    }

    // Splits a parallel SaveResult[] / row list into the result's succeeded ids
    // and per-row failures. Extracted from applyStageUpdate to keep that method
    // under the cyclomatic-complexity gate.
    private static void recordSaveResults(
        BulkResultDTO result, Database.SaveResult[] saveResults, List<WorkItem__c> rows
    ) {
        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult sr = saveResults[i];
            Id rowId = rows[i].Id;
            if (sr.isSuccess()) {
                result.succeededIds.add(rowId);
            } else {
                result.failures.add(new FailureDTO(rowId, firstError(sr)));
            }
        }
    }

    private static String firstError(Database.SaveResult sr) {
        if (sr.getErrors() != null && !sr.getErrors().isEmpty()) {
            return sr.getErrors()[0].getMessage();
        }
        return 'Update failed.';
    }

    private static void finalizeCounts(BulkResultDTO result) {
        result.succeededCount = result.succeededIds.size();
        result.failedCount = result.failures.size();
    }
}
