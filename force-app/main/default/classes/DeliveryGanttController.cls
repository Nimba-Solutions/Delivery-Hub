/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides work item data for timeline/Gantt chart LWCs.
 *              getWorkItemsForGantt: legacy CSS chart (UAT-date-only items).
 *              getGanttData: rich data for Frappe Gantt (hours, developer,
 *              client grouping, resolved start/end dates, progress).
 *              updateWorkItemDates: saves date changes from drag-to-reschedule.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity')
public with sharing class DeliveryGanttController {

    /**
     * @description Legacy DTO for the CSS-based Gantt chart.
     */
    public class GanttRow {
        /** @description Salesforce record Id */
        @AuraEnabled public String workItemId { get; set; }
        /** @description Auto-number work item name */
        @AuraEnabled public String name { get; set; }
        /** @description Brief description of the work item */
        @AuraEnabled public String description { get; set; }
        /** @description Current workflow stage */
        @AuraEnabled public String stage { get; set; }
        /** @description Priority level (High, Medium, Low) */
        @AuraEnabled public String priority { get; set; }
        /** @description Projected UAT-ready date as ISO string */
        @AuraEnabled public String uatDate { get; set; }
        /** @description Calculated ETA date as ISO string */
        @AuraEnabled public String etaDate { get; set; }
        /** @description Record created date as ISO string */
        @AuraEnabled public String createdDate { get; set; }
    }

    /**
     * @description Rich DTO for Frappe Gantt — includes hours, developer,
     *              client entity, progress, and resolved start/end dates.
     */
    public class GanttTask {
        /** @description Salesforce record Id */
        @AuraEnabled public String workItemId { get; set; }
        /** @description Auto-number work item name */
        @AuraEnabled public String name { get; set; }
        /** @description Brief description of the work item */
        @AuraEnabled public String description { get; set; }
        /** @description Current workflow stage */
        @AuraEnabled public String stage { get; set; }
        /** @description Priority level (High, Medium, Low) */
        @AuraEnabled public String priority { get; set; }
        /** @description Resolved start date as ISO string */
        @AuraEnabled public String startDate { get; set; }
        /** @description Resolved end date as ISO string */
        @AuraEnabled public String endDate { get; set; }
        /** @description Estimated hours for this work item */
        @AuraEnabled public Decimal estimatedHours { get; set; }
        /** @description Total logged hours against this work item */
        @AuraEnabled public Decimal loggedHours { get; set; }
        /** @description Progress ratio (0-1) based on logged vs estimated hours, or null when no estimate exists */
        @AuraEnabled public Decimal progress { get; set; }
        /** @description Name of the assigned developer */
        @AuraEnabled public String developerName { get; set; }
        /** @description Client entity record Id */
        @AuraEnabled public String entityId { get; set; }
        /** @description Client entity name for grouping */
        @AuraEnabled public String entityName { get; set; }
        /** @description Parent work item Id for hierarchy */
        @AuraEnabled public String parentWorkItemId { get; set; }
        /** @description True when the work item is no longer in the active workflow (ActivatedDateTime is null) */
        @AuraEnabled public Boolean isInactive { get; set; }
        /** @description True when endDate was synthesized (no real EstimatedEnd / UAT / ETA date existed) */
        @AuraEnabled public Boolean hasFallbackEndDate { get; set; }
    }

    /**
     * @description Legacy: returns active work items with a ProjectedUATReadyDate__c.
     * @return List of GanttRow ordered by UAT date.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttRow> getWorkItemsForGantt() {
        try {
            List<WorkItem__c> items = [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                       ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate
                FROM WorkItem__c
                WHERE ActivatedDateTime__c != null
                AND TemplateMarkedDateTime__c = null
                AND ProjectedUATReadyDate__c != null
                WITH SYSTEM_MODE
                ORDER BY ProjectedUATReadyDate__c ASC
            ];

            List<GanttRow> rows = new List<GanttRow>();
            for (WorkItem__c t : items) {
                GanttRow row     = new GanttRow();
                row.workItemId   = t.Id;
                row.name         = t.Name;
                row.description = t.BriefDescriptionTxt__c;
                row.stage     = t.StageNamePk__c;
                row.priority  = t.PriorityPk__c;
                row.uatDate   = String.valueOf(t.ProjectedUATReadyDate__c);
                row.etaDate   = t.CalculatedETADate__c != null ? String.valueOf(t.CalculatedETADate__c) : null;
                row.createdDate = String.valueOf(t.CreatedDate.date());
                rows.add(row);
            }
            return rows;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /** @description Default freshness window (days) when including completed items. */
    @TestVisible private static final Integer DEFAULT_STALE_CUTOFF_DAYS = 90;

    /**
     * @description Returns work items with full date/hour/developer/client data
     *              for the Frappe Gantt chart. Resolves start/end dates using a
     *              fallback chain and calculates progress from logged vs estimated hours.
     *              When showCompleted is true, completed items are still bounded by
     *              LastModifiedDate >= LAST_N_DAYS:90 so the timeline does not get
     *              flooded with archived work.
     * @param showCompleted When true, includes inactive (completed/archived) items.
     * @return List of GanttTask ordered by entity then start date.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttTask> getGanttData(Boolean showCompleted) {
        try {
            String query = 'SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
                + 'PriorityPk__c, EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
                + 'ProjectedUATReadyDate__c, CalculatedETADate__c, CreatedDate, '
                + 'LastModifiedDate, '
                + 'EstimatedHoursNumber__c, TotalLoggedHoursSum__c, '
                + 'ActivatedDateTime__c, ParentWorkItemLookup__c, '
                + 'DeveloperLookup__r.Name, '
                + 'ClientNetworkEntityLookup__c, ClientNetworkEntityLookup__r.Name '
                + 'FROM WorkItem__c '
                + 'WHERE TemplateMarkedDateTime__c = null ';

            if (showCompleted == true) {
                // Active items always show; inactive items must be recently modified.
                query += 'AND (ActivatedDateTime__c != null '
                    + 'OR LastModifiedDate >= LAST_N_DAYS:' + DEFAULT_STALE_CUTOFF_DAYS + ') ';
            } else {
                query += 'AND ActivatedDateTime__c != null ';
            }

            query += 'WITH SYSTEM_MODE '
                + 'ORDER BY ClientNetworkEntityLookup__r.Name ASC NULLS LAST, '
                + 'EstimatedStartDevDate__c ASC NULLS LAST, CreatedDate ASC';

            List<WorkItem__c> items = Database.query(query); // NOPMD — dynamic for conditional WHERE
            List<GanttTask> tasks = new List<GanttTask>();
            for (WorkItem__c item : items) {
                tasks.add(mapToGanttTask(item));
            }
            return tasks;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Saves updated start/end dates after a drag-to-reschedule
     *              action in the Gantt chart.
     * @param workItemId The Salesforce record Id.
     * @param startDate  New start date (ISO YYYY-MM-DD).
     * @param endDate    New end date (ISO YYYY-MM-DD).
     */
    @AuraEnabled
    public static void updateWorkItemDates(String workItemId, String startDate, String endDate) {
        try {
            WorkItem__c item = new WorkItem__c(Id = workItemId);
            if (String.isNotBlank(startDate)) {
                item.EstimatedStartDevDate__c = Date.valueOf(startDate);
            }
            if (String.isNotBlank(endDate)) {
                item.EstimatedEndDevDate__c = Date.valueOf(endDate);
            }
            update item; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    private static GanttTask mapToGanttTask(WorkItem__c item) {
        GanttTask task = new GanttTask();
        task.workItemId = item.Id;
        task.name = item.Name;
        task.description = item.BriefDescriptionTxt__c;
        task.stage = item.StageNamePk__c;
        task.priority = item.PriorityPk__c;
        task.estimatedHours = item.EstimatedHoursNumber__c;
        task.loggedHours = item.TotalLoggedHoursSum__c;
        task.isInactive = item.ActivatedDateTime__c == null;
        task.parentWorkItemId = item.ParentWorkItemLookup__c;

        // Progress is null (not 0) when no estimate exists, so the LWC can render
        // "no estimate" differently from "0% complete".
        if (item.EstimatedHoursNumber__c != null && item.EstimatedHoursNumber__c > 0) {
            Decimal logged = item.TotalLoggedHoursSum__c != null ? item.TotalLoggedHoursSum__c : 0;
            task.progress = Math.min(logged / item.EstimatedHoursNumber__c, 1.0);
        } else {
            task.progress = null;
        }

        task.developerName = item.DeveloperLookup__r != null ? item.DeveloperLookup__r.Name : null;

        task.entityName = item.ClientNetworkEntityLookup__r != null
            ? item.ClientNetworkEntityLookup__r.Name : null;
        task.entityId = item.ClientNetworkEntityLookup__c;

        Date startDt = item.EstimatedStartDevDate__c != null
            ? item.EstimatedStartDevDate__c
            : item.CreatedDate.date();
        task.startDate = String.valueOf(startDt);

        Boolean hasEngineeredEnd = item.EstimatedEndDevDate__c != null
            || item.ProjectedUATReadyDate__c != null
            || item.CalculatedETADate__c != null;
        Boolean isTerminal = TERMINAL_STAGES.contains(item.StageNamePk__c);

        // Terminal items without engineered dates use LastModifiedDate as a real
        // completion timestamp; otherwise the existing fallback chain handles it.
        // hasFallbackEndDate = false in both real-data branches (engineered or
        // terminal-LastModified), true only when we genuinely synthesize a future bar.
        task.hasFallbackEndDate = !hasEngineeredEnd && !isTerminal;

        Date endDt = chooseEndDate(item, startDt, hasEngineeredEnd, isTerminal);
        if (endDt < startDt) {
            endDt = startDt.addDays(1);
        }
        task.endDate = String.valueOf(endDt);

        return task;
    }

    /**
     * @description Stage values considered terminal for Gantt rendering. Terminal
     *              items receive their LastModifiedDate as the bar end instead of
     *              the synthesized +14-day forward bar that the fallback chain
     *              would otherwise produce. Hardcoded here (not CMT-driven) so the
     *              Gantt's terminal definition stays stable across workflow types.
     */
    private static final Set<String> TERMINAL_STAGES = new Set<String>{
        'Done', 'Deployed to Prod', 'Cancelled', 'Closed', 'Rejected'
    };

    /**
     * @description Picks the right end date for a Gantt bar. Real engineered date
     *              wins; otherwise terminal items use LastModifiedDate (their actual
     *              completion timestamp); otherwise the +14d fallback chain runs.
     * @param item The work item being mapped
     * @param startDt The already-resolved start date for fallback anchoring
     * @param hasEngineeredEnd True when at least one engineered end-date field is set
     * @param isTerminal True when the item's stage is in TERMINAL_STAGES
     * @return The end date the Gantt should render
     */
    private static Date chooseEndDate(WorkItem__c item, Date startDt, Boolean hasEngineeredEnd, Boolean isTerminal) {
        if (hasEngineeredEnd) {
            return resolveEndDate(item, startDt);
        }
        if (isTerminal) {
            return item.LastModifiedDate.date();
        }
        return resolveEndDate(item, startDt);
    }

    /**
     * @description DTO representing a dependency between two work items on the Gantt chart.
     */
    public class GanttDependency {
        /** @description Dependency record Id */
        @AuraEnabled public String id { get; set; }
        /** @description Blocking (predecessor) work item Id */
        @AuraEnabled public String source { get; set; }
        /** @description Blocked (successor) work item Id */
        @AuraEnabled public String target { get; set; }
        /** @description Type of dependency relationship */
        @AuraEnabled public String dependencyType { get; set; }
    }

    /**
     * @description Returns work item dependencies for rendering arrows on the
     *              Gantt chart. When showCompleted is true, dependencies that
     *              touch inactive items are also returned so the dependency
     *              graph stays consistent with the visible task set.
     * @param showCompleted Mirrors the same flag on getGanttData.
     * @return List of GanttDependency for the relevant blocked/blocking pairs.
     */
    @AuraEnabled(cacheable=true)
    public static List<GanttDependency> getGanttDependencies(Boolean showCompleted) {
        try {
            List<WorkItemDependency__c> rows;
            if (showCompleted == true) {
                rows = [
                    SELECT Id, BlockedWorkItemLookup__c, BlockingWorkItemLookup__c, TypePk__c
                    FROM WorkItemDependency__c
                    WITH SYSTEM_MODE
                    LIMIT 500
                ];
            } else {
                rows = [
                    SELECT Id, BlockedWorkItemLookup__c, BlockingWorkItemLookup__c, TypePk__c
                    FROM WorkItemDependency__c
                    WHERE BlockedWorkItemLookup__r.ActivatedDateTime__c != null
                      AND BlockingWorkItemLookup__r.ActivatedDateTime__c != null
                    WITH SYSTEM_MODE
                    LIMIT 500
                ];
            }
            List<GanttDependency> deps = new List<GanttDependency>();
            for (WorkItemDependency__c d : rows) {
                GanttDependency dep = new GanttDependency();
                dep.id = d.Id;
                dep.source = d.BlockingWorkItemLookup__c;
                dep.target = d.BlockedWorkItemLookup__c;
                dep.dependencyType = d.TypePk__c;
                deps.add(dep);
            }
            return deps;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Saves the priority bucket when a user drags a task into a
     *              different group in the PriorityGroupingPlugin. Writes
     *              PriorityGroupPk__c so the bucket persists across reloads
     *              instead of reverting to the server-side derivation.
     * @param workItemId   The Salesforce record Id.
     * @param priorityGroup One of: top-priority, active, follow-on, proposed, deferred.
     */
    @AuraEnabled
    public static void updateWorkItemPriorityGroup(String workItemId, String priorityGroup) {
        try {
            WorkItem__c item = new WorkItem__c(Id = workItemId, PriorityGroupPk__c = priorityGroup);
            update item; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Updates the parent work item after a drag-reparent action.
     *              Pass null to clear the parent (promote to root level).
     * @param workItemId The Salesforce record Id.
     * @param parentId   The new parent WorkItem__c Id, or null to make root-level.
     */
    @AuraEnabled
    public static void updateWorkItemParent(String workItemId, String parentId) {
        try {
            WorkItem__c item = new WorkItem__c(Id = workItemId);
            item.ParentWorkItemLookup__c = String.isNotBlank(parentId) ? parentId : null;
            update item; //NOPMD
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Moves a work item to a new position within its priority
     *              group and re-spaces siblings to stable 1000-step values.
     *              The `sortOrder` parameter is interpreted as the desired
     *              POSITION (newIndex) within the lane, not as a raw
     *              SortOrderNumber__c value — writing raw newIndex caused
     *              collisions (two tasks at sortOrder=0) which made the
     *              ORDER BY tiebreaker decide winner, producing the
     *              snap-back-after-drag symptom. Atomic renumber here
     *              guarantees strictly-ordered siblings after each drag.
     * @param workItemId The Salesforce record Id.
     * @param sortOrder  Desired position (newIndex) within the task's
     *                   priority group; 0 = top. Clamped to [0, size].
     */
    @AuraEnabled
    public static void updateWorkItemSortOrder(String workItemId, Decimal sortOrder) {
        if (String.isBlank(workItemId)) {
            throw new AuraHandledException('workItemId is required');
        }
        Integer newIndex = sortOrder == null ? 0 : Integer.valueOf(sortOrder);
        try {
            WorkItem__c target = [
                SELECT Id, PriorityGroupPk__c, SortOrderNumber__c
                FROM WorkItem__c WHERE Id = :workItemId LIMIT 1
            ];
            String pg = target.PriorityGroupPk__c;
            List<WorkItem__c> siblings = pg == null
                ? [SELECT Id, SortOrderNumber__c FROM WorkItem__c
                   WHERE PriorityGroupPk__c = null
                   ORDER BY SortOrderNumber__c ASC NULLS LAST, Name ASC]
                : [SELECT Id, SortOrderNumber__c FROM WorkItem__c
                   WHERE PriorityGroupPk__c = :pg
                   ORDER BY SortOrderNumber__c ASC NULLS LAST, Name ASC];
            List<WorkItem__c> reordered = new List<WorkItem__c>();
            for (WorkItem__c s : siblings) {
                if (s.Id != target.Id) {
                    reordered.add(s);
                }
            }
            Integer clamped = Math.min(Math.max(newIndex, 0), reordered.size());
            reordered.add(clamped, target);
            List<WorkItem__c> toUpdate = new List<WorkItem__c>();
            for (Integer i = 0; i < reordered.size(); i++) {
                Decimal newSort = (i + 1) * 1000;
                if (reordered[i].SortOrderNumber__c != newSort) {
                    toUpdate.add(new WorkItem__c(Id = reordered[i].Id, SortOrderNumber__c = newSort));
                }
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
            }
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  PRO FORMA TIMELINE — ported from cloudnimbusllc.com /mf/delivery-timeline-v5
    // ═══════════════════════════════════════════════════════════════════════
    // The v5 page on cloudnimbusllc.com renders a pro forma timeline grouped
    // by priority bucket (NOW / NEXT / PLANNED / PROPOSED / HOLD), powered by
    // nimbus-gantt's PriorityGroupingPlugin. This method serves the same shape
    // from real WorkItem__c records so the deliveryProFormaTimeline LWC can
    // render the same visual against actual DH data. The plugin reads
    // `priorityGroup` from each row — if blank, it derives the bucket at
    // render time from priority + stage using the same rule as
    // derivePriorityGroup() below.
    //
    // Source of truth for the derivation rule:
    //   cloudnimbusllc.com/src/lib/dhWorkItemToProForma.ts → derivePriorityGroup
    // Keep these two in sync. If the rule changes in one place, change both.

    /**
     * @description DTO for pro forma timeline rows. Mirrors v5's ProFormaItem
     *              shape. Used by deliveryProFormaTimeline LWC.
     */
    public class ProFormaTimelineRow {
        /** @description Salesforce record Id of the WorkItem__c */
        @AuraEnabled public String id { get; set; }
        /** @description Auto-number work item name */
        @AuraEnabled public String name { get; set; }
        /** @description Brief description (used as the row title in the timeline) */
        @AuraEnabled public String title { get; set; }
        /** @description Current workflow stage (StageNamePk__c) */
        @AuraEnabled public String stage { get; set; }
        /** @description Priority level (PriorityPk__c — Low / Medium / High / Critical) */
        @AuraEnabled public String priority { get; set; }
        /** @description Priority bucket for grouping — explicit PriorityGroupPk__c value
         *  when present, otherwise derived at read time from priority + stage */
        @AuraEnabled public String priorityGroup { get; set; }
        /** @description ISO YYYY-MM-DD start date for the timeline bar */
        @AuraEnabled public String startDate { get; set; }
        /** @description ISO YYYY-MM-DD end date for the timeline bar */
        @AuraEnabled public String endDate { get; set; }
        /** @description Sized estimate in hours (EstimatedHoursNumber__c) */
        @AuraEnabled public Decimal estimatedHours { get; set; }
        /** @description Total logged hours (TotalLoggedHoursSum__c) */
        @AuraEnabled public Decimal loggedHours { get; set; }
        /** @description Progress 0..1 computed from logged / estimated; null when no estimate */
        @AuraEnabled public Decimal progress { get; set; }
        /** @description Developer/owner display name (DeveloperLookup__r.Name) */
        @AuraEnabled public String developerName { get; set; }
        /** @description Parent work item record Id for tree rendering */
        @AuraEnabled public String parentWorkItemId { get; set; }
        /** @description Client NetworkEntity__c record Id */
        @AuraEnabled public String entityId { get; set; }
        /** @description Client NetworkEntity__c display name */
        @AuraEnabled public String entityName { get; set; }
        /** @description True when the item has no ActivatedDateTime__c (completed/archived) */
        @AuraEnabled public Boolean isInactive { get; set; }
        /** @description User-defined sort position within a priority group — set by
         *  drag-to-reorder in the timeline. Lower values appear first. Null when
         *  the item has never been reordered; LWC maps null → 0. */
        @AuraEnabled public Decimal sortOrder { get; set; }
    }

    /** Stages where work is actively moving forward (bucket = active or top-priority) */
    private static final Set<String> ACTIVE_STAGES = new Set<String>{
        'Ready for Development', 'In Development',
        'Ready for QA', 'QA In Progress',
        'Ready for Client UAT', 'In Client UAT', 'Ready for UAT Sign-off',
        'Ready for Deployment', 'Deploying'
    };

    /** Stages where the item is sized but not yet committed (bucket = proposed) */
    private static final Set<String> PROPOSED_STAGES = new Set<String>{
        'Backlog', 'Scoping In Progress',
        'Clarification Requested (Pre-Dev)', 'Ready for Sizing'
    };

    /** Stages indicating the item is on hold (bucket = deferred) */
    private static final Set<String> PAUSED_STAGES = new Set<String>{
        'Paused', 'On Hold', 'Blocked', 'Awaiting Client'
    };

    /**
     * @description Derives the priority bucket from priority + stage when
     *              PriorityGroupPk__c is null on the record. Matches the
     *              derivePriorityGroup() rule in
     *              cloudnimbusllc.com/src/lib/dhWorkItemToProForma.ts.
     *
     * Rule:
     *   1. Paused/blocked/hold stage → "deferred"
     *   2. Terminal/done stage       → "follow-on"
     *   3. High or Critical + active → "top-priority"
     *   4. Any active stage          → "active"
     *   5. Proposed stage            → "proposed"
     *   6. Anything else             → "follow-on"
     *
     * @param priority The PriorityPk__c value
     * @param stage    The StageNamePk__c value
     * @return One of "top-priority", "active", "follow-on", "proposed", "deferred"
     */
    @TestVisible
    private static String derivePriorityGroup(String priority, String stage) {
        if (String.isBlank(stage)) {
            return 'follow-on';
        }
        String lower = stage.toLowerCase();
        Boolean looksPaused = PAUSED_STAGES.contains(stage)
            || lower.contains('hold') || lower.contains('blocked') || lower.contains('paused');
        if (looksPaused) {
            return 'deferred';
        }
        if (TERMINAL_STAGES.contains(stage)) {
            return 'follow-on';
        }
        Boolean isActive = ACTIVE_STAGES.contains(stage);
        if (isActive) {
            return (priority == 'High' || priority == 'Critical') ? 'top-priority' : 'active';
        }
        if (PROPOSED_STAGES.contains(stage)) {
            return 'proposed';
        }
        return 'follow-on';
    }

    /**
     * @description Returns work items shaped for the deliveryProFormaTimeline
     *              LWC. Same SOQL strategy as getGanttData but includes
     *              PriorityGroupPk__c and uses the ProFormaTimelineRow DTO. Rows
     *              where PriorityGroupPk__c is null get their bucket derived
     *              from priority + stage via derivePriorityGroup().
     *
     * @param showCompleted When true, includes inactive items (same semantics
     *                      as getGanttData's showCompleted flag).
     * @return List of ProFormaTimelineRow ordered by entity then start date.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProFormaTimelineRow> getProFormaTimelineData(Boolean showCompleted) {
        try {
            String query = 'SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, '
                + 'PriorityPk__c, PriorityGroupPk__c, SortOrderNumber__c, '
                + 'EstimatedStartDevDate__c, EstimatedEndDevDate__c, '
                + 'ProjectedUATReadyDate__c, CalculatedETADate__c, '
                + 'CreatedDate, LastModifiedDate, '
                + 'EstimatedHoursNumber__c, TotalLoggedHoursSum__c, '
                + 'ActivatedDateTime__c, ParentWorkItemLookup__c, '
                + 'DeveloperLookup__r.Name, '
                + 'ClientNetworkEntityLookup__c, ClientNetworkEntityLookup__r.Name '
                + 'FROM WorkItem__c '
                + 'WHERE TemplateMarkedDateTime__c = null ';

            if (showCompleted == true) {
                query += 'AND (ActivatedDateTime__c != null '
                    + 'OR LastModifiedDate >= LAST_N_DAYS:' + DEFAULT_STALE_CUTOFF_DAYS + ') ';
            } else {
                query += 'AND ActivatedDateTime__c != null ';
            }

            // SortOrderNumber__c is the primary sort — drag-to-reorder writes it,
            // and NG groups tasks by priorityGroup client-side, so returning them
            // sorted keeps within-group order deterministic across refetches.
            // NULLS LAST so never-reordered items fall to the tail of each group.
            query += 'WITH SYSTEM_MODE '
                + 'ORDER BY SortOrderNumber__c ASC NULLS LAST, '
                + 'ClientNetworkEntityLookup__r.Name ASC NULLS LAST, '
                + 'EstimatedStartDevDate__c ASC NULLS LAST, CreatedDate ASC';

            List<WorkItem__c> items = Database.query(query); // NOPMD — dynamic for conditional WHERE
            List<ProFormaTimelineRow> rows = new List<ProFormaTimelineRow>();
            for (WorkItem__c item : items) {
                rows.add(mapToProFormaRow(item));
            }
            return rows;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    private static ProFormaTimelineRow mapToProFormaRow(WorkItem__c item) {
        ProFormaTimelineRow row = new ProFormaTimelineRow();
        row.id = item.Id;
        row.name = item.Name;
        row.title = item.BriefDescriptionTxt__c;
        row.stage = item.StageNamePk__c;
        row.priority = item.PriorityPk__c;

        // Picklist override wins; fall back to derivation when blank
        row.priorityGroup = String.isNotBlank(item.PriorityGroupPk__c)
            ? item.PriorityGroupPk__c
            : derivePriorityGroup(item.PriorityPk__c, item.StageNamePk__c);

        row.estimatedHours = item.EstimatedHoursNumber__c;
        row.loggedHours = item.TotalLoggedHoursSum__c;
        row.isInactive = item.ActivatedDateTime__c == null;
        row.parentWorkItemId = item.ParentWorkItemLookup__c;
        row.sortOrder = item.SortOrderNumber__c;

        if (item.EstimatedHoursNumber__c != null && item.EstimatedHoursNumber__c > 0) {
            Decimal logged = item.TotalLoggedHoursSum__c != null ? item.TotalLoggedHoursSum__c : 0;
            row.progress = Math.min(logged / item.EstimatedHoursNumber__c, 1.0);
        } else {
            row.progress = null;
        }

        row.developerName = item.DeveloperLookup__r != null ? item.DeveloperLookup__r.Name : null;
        row.entityId = item.ClientNetworkEntityLookup__c;
        row.entityName = item.ClientNetworkEntityLookup__r != null
            ? item.ClientNetworkEntityLookup__r.Name : null;

        // Reuse the existing date resolution logic from getGanttData — same
        // fallback chain, so the two LWCs render bars at identical positions.
        Date startDt = item.EstimatedStartDevDate__c != null
            ? item.EstimatedStartDevDate__c
            : item.CreatedDate.date();
        row.startDate = String.valueOf(startDt);

        Boolean hasEngineeredEnd = item.EstimatedEndDevDate__c != null
            || item.ProjectedUATReadyDate__c != null
            || item.CalculatedETADate__c != null;
        Boolean isTerminal = TERMINAL_STAGES.contains(item.StageNamePk__c);
        Date endDt = chooseEndDate(item, startDt, hasEngineeredEnd, isTerminal);
        if (endDt < startDt) {
            endDt = startDt.addDays(1);
        }
        row.endDate = String.valueOf(endDt);

        return row;
    }

    /**
     * @description Resolves an end date from the first non-null real date
     *              field. When all are null, falls back to a 14-day bar
     *              anchored to the LATER of (startDt, today) so stale items
     *              don't render as floating bars in the past.
     * @param item The work item to resolve the end date for
     * @param startDt The resolved start date used as the fallback anchor
     * @return The resolved end date — real if any engineered field is set,
     *         otherwise the synthesized +14-day fallback
     */
    private static Date resolveEndDate(WorkItem__c item, Date startDt) {
        if (item.EstimatedEndDevDate__c != null) {
            return item.EstimatedEndDevDate__c;
        }
        if (item.ProjectedUATReadyDate__c != null) {
            return item.ProjectedUATReadyDate__c;
        }
        if (item.CalculatedETADate__c != null) {
            return item.CalculatedETADate__c;
        }
        Date today = Date.today();
        Date anchor = startDt > today ? startDt : today;
        return anchor.addDays(14);
    }
}
