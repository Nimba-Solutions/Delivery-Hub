/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Triage controller backing the two workspace queue tabs Jose
 *               runs to drive both ends of the work-item pipeline:
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
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryTriageController {

    /** Stage a work item sits in once deployed, awaiting close-out verification. */
    private static final String STAGE_DEPLOYED_TO_PROD =
        DeliveryWorkflowConfigService.STAGE_DEPLOYED_TO_PROD;

    /** Stage routeToDev moves an intake item into (and activates it). */
    private static final String STAGE_READY_FOR_DEVELOPMENT = 'Ready for Development';

    /** Terminal value markDone / dismissIntake fall back to. */
    private static final String STAGE_DONE = 'Done';
    private static final String STAGE_CANCELLED = 'Cancelled';

    /** Report DeveloperName backing the close-out tab's "open full report" link. */
    private static final String REPORT_CLOSE_OUT =
        'Deployed_To_Prod_Awaiting_Verification';

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
     * @description Route the selected intake items to a developer: assign the
     *              developer lookup, move to 'Ready for Development', and stamp
     *              ActivatedDateTime__c = now() so each becomes visible on the
     *              timeline. Bulk, partial-failure-safe.
     * @param workItemIds   Items to route.
     * @param developerUserId The User to assign (may be null to route unassigned).
     * @return BulkResultDTO with succeeded ids and per-row failures.
     */
    @AuraEnabled
    public static BulkResultDTO routeToDev(List<Id> workItemIds, Id developerUserId) {
        return applyStageUpdate(workItemIds, STAGE_READY_FOR_DEVELOPMENT, developerUserId, true);
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
