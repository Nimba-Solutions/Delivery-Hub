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
        /**
         * @description Optional per-row visual decorators consumed by
         *              nimbus-gantt &gt;= 0.185.36. Shape matches GanttRowDecorators
         *              (borderStyle, borderWidth, borderColor, fillStyle,
         *              fillOpacity, badge, styleNote). Sanitized at the adapter
         *              boundary via sanitizeGanttTaskStyle so the renderer
         *              never sees unknown enum values or out-of-range numbers.
         */
        @AuraEnabled public Map<String, Object> style { get; set; }
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

        task.style = buildRecentlyDoneStyle(item, isTerminal);

        return task;
    }

    /**
     * @description Decorate terminal items modified in the last
     *              RECENTLY_DONE_WINDOW_DAYS so stakeholders can scan
     *              "what just shipped" without those bars looking
     *              identical to in-flight work. Sub-spec from the
     *              nimbus-gantt 0.185.36 dispatch.
     * @param item The WorkItem__c being mapped.
     * @param isTerminal Pre-computed terminal flag from the caller.
     * @return Sanitized style map, or null when the row should not be decorated.
     */
    @TestVisible
    private static Map<String, Object> buildRecentlyDoneStyle(WorkItem__c item, Boolean isTerminal) {
        if (!isTerminal || item.LastModifiedDate == null) {
            return null;
        }
        Datetime cutoff = Datetime.now().addDays(-RECENTLY_DONE_WINDOW_DAYS);
        if (item.LastModifiedDate < cutoff) {
            return null;
        }
        return sanitizeGanttTaskStyle(new Map<String, Object>{
            'borderStyle' => 'dashed',
            'borderWidth' => 2,
            'fillStyle'   => 'muted',
            'badge'       => new Map<String, Object>{
                'text'      => '✓',
                'placement' => 'end'
            },
            'styleNote'   => 'Recently completed (within last '
                + RECENTLY_DONE_WINDOW_DAYS + ' days)'
        });
    }

    /**
     * @description Normalise a GanttRowDecorators-shaped map at the adapter
     *              boundary. nimbus-gantt's renderer is enum-strict and will
     *              not degrade malformed input gracefully — same pattern as
     *              dependency.type sanitization. Strips unknown enum values,
     *              clamps borderWidth to 1|2|3, clamps fillOpacity to [0,1],
     *              and recursively sanitizes the badge sub-object.
     * @param raw The map handed in by the caller (may contain extra keys
     *            and unvalidated values).
     * @return A sanitized map safe to ship to nimbus-gantt, or null when
     *         every key was rejected.
     */
    @TestVisible
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    private static Map<String, Object> sanitizeGanttTaskStyle(Map<String, Object> raw) {
        if (raw == null || raw.isEmpty()) {
            return null;
        }
        Map<String, Object> clean = new Map<String, Object>();
        copyEnum(raw, clean, 'borderStyle', ALLOWED_BORDER_STYLES);
        copyClampedBorderWidth(raw, clean);
        copyNonBlankString(raw, clean, 'borderColor');
        copyEnum(raw, clean, 'fillStyle', ALLOWED_FILL_STYLES);
        copyClampedFillOpacity(raw, clean);
        copyNonBlankString(raw, clean, 'styleNote');
        copyBadge(raw, clean);
        return clean.isEmpty() ? null : clean;
    }

    private static void copyEnum(Map<String, Object> src, Map<String, Object> dst,
        String key, Set<String> allowed) {
        if (!src.containsKey(key) || src.get(key) == null) { return; }
        String value = String.valueOf(src.get(key));
        if (allowed.contains(value)) {
            dst.put(key, value);
        }
    }

    private static void copyNonBlankString(Map<String, Object> src, Map<String, Object> dst, String key) {
        if (!src.containsKey(key) || src.get(key) == null) { return; }
        String value = String.valueOf(src.get(key)).trim();
        if (String.isNotBlank(value)) {
            dst.put(key, value);
        }
    }

    private static void copyClampedBorderWidth(Map<String, Object> src, Map<String, Object> dst) {
        if (!src.containsKey('borderWidth') || src.get('borderWidth') == null) { return; }
        Integer raw;
        try {
            raw = Integer.valueOf(String.valueOf(src.get('borderWidth')));
        } catch (Exception e) {
            return;
        }
        Integer clamped = raw <= 1 ? 1 : (raw >= 3 ? 3 : 2);
        dst.put('borderWidth', clamped);
    }

    private static void copyClampedFillOpacity(Map<String, Object> src, Map<String, Object> dst) {
        if (!src.containsKey('fillOpacity') || src.get('fillOpacity') == null) { return; }
        Decimal raw;
        try {
            raw = Decimal.valueOf(String.valueOf(src.get('fillOpacity')));
        } catch (Exception e) {
            return;
        }
        Decimal clamped = raw < 0 ? 0 : (raw > 1 ? 1 : raw);
        dst.put('fillOpacity', clamped);
    }

    private static void copyBadge(Map<String, Object> src, Map<String, Object> dst) {
        if (!src.containsKey('badge') || !(src.get('badge') instanceof Map<String, Object>)) {
            return;
        }
        Map<String, Object> rawBadge = (Map<String, Object>) src.get('badge');
        Map<String, Object> cleanBadge = new Map<String, Object>();
        copyNonBlankString(rawBadge, cleanBadge, 'text');
        copyEnum(rawBadge, cleanBadge, 'placement', ALLOWED_BADGE_PLACEMENTS);
        copyNonBlankString(rawBadge, cleanBadge, 'color');
        if (!cleanBadge.isEmpty() && cleanBadge.containsKey('text')) {
            dst.put('badge', cleanBadge);
        }
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

    /** @description Days back from today that count as "recently done" for the style decorator. */
    private static final Integer RECENTLY_DONE_WINDOW_DAYS = 7;

    /** @description Allowed values for GanttRowDecorators.borderStyle. */
    private static final Set<String> ALLOWED_BORDER_STYLES = new Set<String>{
        'solid', 'dashed', 'dotted', 'double', 'none'
    };

    /** @description Allowed values for GanttRowDecorators.fillStyle. */
    private static final Set<String> ALLOWED_FILL_STYLES = new Set<String>{
        'solid', 'shaded', 'hatched', 'gradient', 'muted'
    };

    /** @description Allowed values for GanttRowDecorators.badge.placement. */
    private static final Set<String> ALLOWED_BADGE_PLACEMENTS = new Set<String>{
        'start', 'end'
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
     * @description Creates a new WorkItemDependency__c row linking blocking → blocked.
     *              Returns the new dep DTO so the LWC can append it to the local
     *              dependency array without a refetch.
     * @param blockingId  Predecessor work item Id (source).
     * @param blockedId   Successor work item Id (target).
     * @param depType     Picklist value on TypePk__c (e.g. 'Blocks', 'Relates To').
     * @return GanttDependency DTO in the shape the LWC already consumes.
     */
    @AuraEnabled
    public static GanttDependency createWorkItemDependency(String blockingId, String blockedId, String depType) {
        try {
            if (String.isBlank(blockingId) || String.isBlank(blockedId)) {
                throw new AuraHandledException('Both blocking and blocked work item ids are required');
            }
            if (blockingId == blockedId) {
                throw new AuraHandledException('A work item cannot depend on itself');
            }
            String resolvedType = String.isNotBlank(depType) ? depType : 'Blocks';
            WorkItemDependency__c row = new WorkItemDependency__c(
                BlockingWorkItemLookup__c = blockingId,
                BlockedWorkItemLookup__c = blockedId,
                TypePk__c = resolvedType
            );
            // SYSTEM_MODE: running user on subscriber orgs (e.g. MF-Prod) may
            // lack Edit FLS on delivery__BlockingWorkItemLookup__c /
            // delivery__BlockedWorkItemLookup__c. Plain insert strips those
            // fields and fails with REQUIRED_FIELD_MISSING.
            Database.insert(new List<WorkItemDependency__c>{ row }, AccessLevel.SYSTEM_MODE);
            GanttDependency dto = new GanttDependency();
            dto.id = row.Id;
            dto.source = blockingId;
            dto.target = blockedId;
            dto.dependencyType = resolvedType;
            return dto;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Deletes a WorkItemDependency__c record by id.
     * @param depId  The WorkItemDependency__c record Id.
     */
    @AuraEnabled
    public static void deleteWorkItemDependency(String depId) {
        try {
            if (String.isBlank(depId)) {
                throw new AuraHandledException('depId is required');
            }
            WorkItemDependency__c row = new WorkItemDependency__c(Id = depId);
            Database.delete(new List<WorkItemDependency__c>{ row }, true, AccessLevel.SYSTEM_MODE);
        } catch (AuraHandledException ahe) {
            throw ahe;
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
     * @description Writes NG's pre-computed sortOrder value directly to the
     *              record. NG 0.183.1+ emits sparse, collision-safe values
     *              (midpoint of neighbors: 500/1000/1500/2500...), so Apex
     *              just persists what the client sends. Prior PR #662 added
     *              an atomic renumber here that reinterpreted the parameter
     *              as a position index — which broke reorder entirely for
     *              NG clients passing sparse values (500 interpreted as
     *              "move to index 500" → clamped to list size → task
     *              bumped to bottom).
     * @param workItemId The Salesforce record Id.
     * @param sortOrder  NG-computed SortOrderNumber__c value (sparse).
     */
    @AuraEnabled
    public static void updateWorkItemSortOrder(String workItemId, Decimal sortOrder) {
        try {
            // Collision guard: NG's midpoint algorithm can emit the SAME
            // sortOrder value on repeated drags into the same "between
            // neighbors" slot (e.g., midpoint(15000,17000)=16000 every
            // time). Multiple records at the same SortOrderNumber__c cause
            // ORDER BY to tiebreak by Name alphabetically — user's intended
            // order is lost. Nudge the incoming value by 0.5 increments
            // until it's unique within the target task's priority group.
            Decimal finalSort = sortOrder;
            if (finalSort != null) {
                // Collision guard: check ALL other records' sortOrder values
                // regardless of priority group. The prior bucket-scoped check
                // missed the case where a task with explicit PriorityGroupPk__c
                // ('active') collides with a task with null group that derives
                // at render time to the same bucket — visually they're in the
                // same lane and their sortOrders must be unique. Global check
                // is cheap (one soql) and handles both explicit and derived
                // bucket collisions.
                Set<Decimal> siblingValues = new Set<Decimal>();
                List<WorkItem__c> siblings = [SELECT SortOrderNumber__c FROM WorkItem__c WHERE Id != :workItemId AND SortOrderNumber__c != null];
                for (WorkItem__c s : siblings) {
                    siblingValues.add(s.SortOrderNumber__c);
                }
                Integer maxNudges = siblings.size() + 2;
                Integer nudged = 0;
                while (siblingValues.contains(finalSort) && nudged < maxNudges) {
                    finalSort = finalSort + 0.5;
                    nudged++;
                }
            }
            WorkItem__c item = new WorkItem__c(Id = workItemId, SortOrderNumber__c = finalSort);
            update item; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Dense 1..N sortOrder renumber for a single bucket on drag.
     *              NG 0.185.35+ emits position/beforeTaskId/afterTaskId so the
     *              server can deterministically splice the dragged task at the
     *              right spot and rewrite every row in the bucket to contiguous
     *              integers 1..N. Replaces the sparse-midpoint scheme (which
     *              produces the -964, -481, -481.5 drift users see after many
     *              reorders).
     *
     *              The moved task always lands with a positive integer in the
     *              final 1..N sequence; no negatives survive a drag.
     *
     * @param workItemId     Id of the dragged task.
     * @param position       'above-all' | 'below-all' | 'between'.
     * @param beforeTaskId   Task the dragged item lands BEFORE (position=between). Nullable.
     * @param afterTaskId    Task the dragged item lands AFTER (position=between). Nullable.
     * @param priorityGroup  Bucket the drop is in (top-priority/active/follow-on/proposed/deferred).
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static void reorderWorkItemDense(String workItemId, String position, String beforeTaskId, String afterTaskId, String priorityGroup) {
        try {
            if (String.isBlank(workItemId) || String.isBlank(position) || String.isBlank(priorityGroup)) {
                throw new AuraHandledException('workItemId, position, and priorityGroup are required');
            }
            DeliverySyncEngine.setSyncContext();
            List<WorkItem__c> bucket = loadBucketItems(priorityGroup);
            List<WorkItem__c> finalOrder = spliceForReorder(bucket, workItemId, position, beforeTaskId, afterTaskId);
            applyDenseSortOrders(finalOrder);
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Loads active WorkItems whose effective priority bucket
     *              (explicit `PriorityGroupPk__c` or derived from priority/stage)
     *              equals the target bucket, sorted by current SortOrder nulls-last.
     * @param priorityGroup Target bucket name.
     * @return Items in the bucket, ordered by current SortOrderNumber__c ascending.
     */
    private static List<WorkItem__c> loadBucketItems(String priorityGroup) {
        List<WorkItem__c> all = [
            SELECT Id, PriorityPk__c, StageNamePk__c, PriorityGroupPk__c, SortOrderNumber__c
            FROM WorkItem__c
            WHERE ActivatedDateTime__c != null
            WITH SYSTEM_MODE
        ];
        List<WorkItem__c> bucket = new List<WorkItem__c>();
        for (WorkItem__c w : all) {
            String effective = String.isNotBlank(w.PriorityGroupPk__c)
                ? w.PriorityGroupPk__c
                : derivePriorityGroup(w.PriorityPk__c, w.StageNamePk__c);
            if (effective == priorityGroup) {
                bucket.add(w);
            }
        }
        bucket.sort(new SortOrderComparator());
        return bucket;
    }

    /**
     * @description Splices the dragged task at the position implied by
     *              position + beforeTaskId / afterTaskId, returning the new
     *              intended ordering. Defensive: if the task isn't currently
     *              in the bucket (e.g., bucket change landed client-side but
     *              server hasn't seen the PriorityGroup write yet), a stub
     *              record is inserted at the implied index.
     * @param bucket       Current bucket ordered by SortOrder.
     * @param workItemId   Id of the dragged task.
     * @param position     'above-all' | 'below-all' | 'between'.
     * @param beforeTaskId Task the dragged item lands BEFORE (nullable).
     * @param afterTaskId  Task the dragged item lands AFTER (nullable).
     * @return New ordered list — ready to be renumbered 1..N.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static List<WorkItem__c> spliceForReorder(List<WorkItem__c> bucket, String workItemId, String position, String beforeTaskId, String afterTaskId) {
        List<WorkItem__c> others = new List<WorkItem__c>();
        WorkItem__c moving = null;
        for (WorkItem__c w : bucket) {
            if (w.Id == workItemId) {
                moving = w;
            } else {
                others.add(w);
            }
        }
        if (moving == null) {
            moving = new WorkItem__c(Id = workItemId);
        }
        Integer insertAt = computeInsertIndex(others, position, beforeTaskId, afterTaskId);
        List<WorkItem__c> finalOrder = new List<WorkItem__c>();
        for (Integer i = 0; i < insertAt && i < others.size(); i++) {
            finalOrder.add(others[i]);
        }
        finalOrder.add(moving);
        for (Integer i = insertAt; i < others.size(); i++) {
            finalOrder.add(others[i]);
        }
        return finalOrder;
    }

    /**
     * @description Computes the splice index for the dragged task in the
     *              bucket (excluding the moving task itself).
     * @param others       Bucket minus the moving task, ordered.
     * @param position     'above-all' | 'below-all' | 'between'.
     * @param beforeTaskId Task the dragged item lands BEFORE (nullable).
     * @param afterTaskId  Task the dragged item lands AFTER (nullable).
     * @return Zero-based index where the moving task should be inserted.
     */
    private static Integer computeInsertIndex(List<WorkItem__c> others, String position, String beforeTaskId, String afterTaskId) {
        if (position == 'above-all') {
            return 0;
        }
        if (position == 'below-all') {
            return others.size();
        }
        if (String.isNotBlank(afterTaskId)) {
            for (Integer i = 0; i < others.size(); i++) {
                if (others[i].Id == afterTaskId) {
                    return i + 1;
                }
            }
        }
        if (String.isNotBlank(beforeTaskId)) {
            for (Integer i = 0; i < others.size(); i++) {
                if (others[i].Id == beforeTaskId) {
                    return i;
                }
            }
        }
        return others.size();
    }

    /**
     * @description Writes contiguous 1..N SortOrder values, only updating
     *              rows whose sort actually changes (narrow DML).
     * @param finalOrder The target order.
     */
    private static void applyDenseSortOrders(List<WorkItem__c> finalOrder) {
        List<WorkItem__c> toUpdate = new List<WorkItem__c>();
        for (Integer i = 0; i < finalOrder.size(); i++) {
            Decimal desired = Decimal.valueOf(i + 1);
            WorkItem__c row = finalOrder[i];
            if (row.SortOrderNumber__c != desired) {
                toUpdate.add(new WorkItem__c(Id = row.Id, SortOrderNumber__c = desired));
            }
        }
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Sorts WorkItem__c by SortOrderNumber__c ascending, nulls last.
     */
    private class SortOrderComparator implements Comparator<WorkItem__c> {
        /**
         * @description Comparator for WorkItem__c SortOrderNumber__c ascending
         *              with nulls sorted to the end.
         * @param a First record.
         * @param b Second record.
         * @return -1 if a < b, 1 if a > b, 0 if equal.
         */
        public Integer compare(WorkItem__c a, WorkItem__c b) {
            if (a.SortOrderNumber__c == b.SortOrderNumber__c) {
                return 0;
            }
            if (a.SortOrderNumber__c == null) {
                return 1;
            }
            if (b.SortOrderNumber__c == null) {
                return -1;
            }
            return a.SortOrderNumber__c > b.SortOrderNumber__c ? 1 : -1;
        }
    }

    /**
     * @description Generic field-level patch endpoint for NG's DetailPanel
     *              fieldSchema. Caller passes an arbitrary Map<String,Object>
     *              of field writes; FLS is checked per field; non-updateable
     *              or unknown fields are silently skipped rather than failing
     *              the whole patch. Field API names are accepted in any form
     *              the running context might provide (map key, unprefixed,
     *              or prefixed), to sidestep the managed-pkg describe
     *              behavior quirk that killed the 2026-04-20 build. Date
     *              fields accept Date or ISO 'YYYY-MM-DD' strings.
     * @param workItemId The Salesforce record Id.
     * @param fields     Map of field API name → new value.
     */
    @AuraEnabled
    public static void updateWorkItemFields(String workItemId, Map<String, Object> fields) {
        if (String.isBlank(workItemId)) {
            throw new AuraHandledException('workItemId is required');
        }
        if (fields == null || fields.isEmpty()) {
            return;
        }
        try {
            Id rid = Id.valueOf(workItemId);
            WorkItem__c item = new WorkItem__c(Id = rid);
            Map<String, Schema.SObjectField> fieldMap =
                WorkItem__c.SObjectType.getDescribe().fields.getMap();
            // Comprehensive 3-form index: map key, getLocalName(), getName()
            // — all lowercased. Lookup by any of those forms finds the token.
            Map<String, Schema.SObjectField> byAnyName =
                new Map<String, Schema.SObjectField>();
            for (String mapKey : fieldMap.keySet()) {
                Schema.SObjectField sf = fieldMap.get(mapKey);
                Schema.DescribeFieldResult dfr = sf.getDescribe();
                byAnyName.put(mapKey.toLowerCase(), sf);
                byAnyName.put(dfr.getLocalName().toLowerCase(), sf);
                byAnyName.put(dfr.getName().toLowerCase(), sf);
            }
            Boolean anyAssigned = false;
            for (String fieldKey : fields.keySet()) {
                if (String.isBlank(fieldKey)) {
                    continue;
                }
                Schema.SObjectField fToken = byAnyName.get(fieldKey.toLowerCase());
                if (fToken == null) {
                    continue;
                }
                Schema.DescribeFieldResult dfr = fToken.getDescribe();
                if (!dfr.isUpdateable()) {
                    continue;
                }
                Object rawValue = fields.get(fieldKey);
                Object coerced = coerceFieldValue(dfr, rawValue);
                item.put(fToken, coerced);
                anyAssigned = true;
            }
            if (!anyAssigned) {
                return;
            }
            update item; //NOPMD - with sharing class handles CRUD; as user breaks managed package tests
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Coerce JSON-ish caller values into types sObject.put expects.
     *              Date and DateTime picklist payloads arrive as ISO strings from
     *              the LWC layer; sObject.put needs native Date/DateTime.
     * @param dfr Describe for the target field (used to read DisplayType).
     * @param raw Raw value from the caller's fields map.
     * @return Coerced value suitable for sObject.put, or null if raw was null.
     */
    private static Object coerceFieldValue(Schema.DescribeFieldResult dfr, Object raw) {
        if (raw == null) {
            return null;
        }
        Schema.DisplayType t = dfr.getType();
        if (t == Schema.DisplayType.DATE && raw instanceof String) {
            String s = (String) raw;
            return String.isBlank(s) ? null : Date.valueOf(s);
        }
        if (t == Schema.DisplayType.DATETIME && raw instanceof String) {
            String s = (String) raw;
            return String.isBlank(s) ? null : (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
        }
        return raw;
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
        /** @description Schedule progress 0..1 — fraction of (endDate - startDate) elapsed
         *  by today. Null when dates are missing or the bar is in the future / past
         *  entirely. Pairs with `progress` (hours-based) so the gantt can render two
         *  overlay shades on each bar: where the work IS vs where the schedule SAYS
         *  it should be. Same shape as cloudnimbusllc.com v12 visual language. */
        @AuraEnabled public Decimal scheduleProgress { get; set; }
        /** @description Schedule-vs-output variance signal — one of:
         *  'done' (terminal stage), 'ahead' (output > schedule by >10pp),
         *  'behind' (output < schedule by >10pp), 'at-risk' (>95% of schedule
         *  elapsed but <100% complete), 'on-track' (within ±10pp). Used for
         *  bar color / overlay tinting in the gantt. Null when no data. */
        @AuraEnabled public String variance { get; set; }
        /** @description ISO YYYY-MM-DD actual completion date — populated for items
         *  whose stage is terminal (Done / Deployed to Prod / Cancelled) using
         *  LastModifiedDate as the proxy for "stage entered terminal". Null for
         *  in-flight items. Lets the gantt render a "shipped early/late" marker
         *  comparing actualEndDate vs endDate for Done items. */
        @AuraEnabled public String actualEndDate { get; set; }
        /** @description Direct-child count when this row is a parent in the result
         *  set; null when the row is a leaf. Powers "X of Y children done" badges
         *  alongside the parent's rolled-up bar. */
        @AuraEnabled public Integer childrenCount { get; set; }
        /** @description Count of direct children whose variance is 'done' (terminal
         *  stage). Pairs with childrenCount for the X-of-Y badge. */
        @AuraEnabled public Integer doneChildrenCount { get; set; }
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
    // cacheable=false because this method is called after every mutation
    // (drag reorder, date edit, field patch) to refresh the NG view. With
    // cacheable=true, Lightning Data Service would return stale cached rows
    // instead of reading the just-committed DB state, causing "drag saves
    // but UI doesn't update" symptoms. Performance cost on initial mount
    // is negligible (50 tasks × ~6 fields = one SOQL, ~200ms).
    @AuraEnabled
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
            applyParentRollups(rows);
            return rows;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Roll up child rows onto their parents so a parent's bar
     *              reflects the aggregate state of the work breakdown rather
     *              than whatever was manually typed onto the parent record.
     *              Touches: estimatedHours, loggedHours, progress, startDate,
     *              endDate, scheduleProgress, variance, childrenCount,
     *              doneChildrenCount. Only applied when the row has children
     *              in the result set; leaf rows are untouched.
     *
     *              Subtract-Glen lever: with this in place, daily worklogs
     *              against children automatically move the parent's bar +
     *              variance signal — no manual parent updates required.
     * @param rows All rows in the result set (mutated in place).
     */
    private static void applyParentRollups(List<ProFormaTimelineRow> rows) {
        Map<Id, List<ProFormaTimelineRow>> childrenByParent = new Map<Id, List<ProFormaTimelineRow>>();
        for (ProFormaTimelineRow r : rows) {
            if (String.isBlank(r.parentWorkItemId)) {
                continue;
            }
            Id pid = (Id) r.parentWorkItemId;
            if (!childrenByParent.containsKey(pid)) {
                childrenByParent.put(pid, new List<ProFormaTimelineRow>());
            }
            childrenByParent.get(pid).add(r);
        }
        if (childrenByParent.isEmpty()) {
            return;
        }
        for (ProFormaTimelineRow r : rows) {
            List<ProFormaTimelineRow> kids = childrenByParent.get((Id) r.id);
            if (kids == null || kids.isEmpty()) {
                continue;
            }
            applyParentRollup(r, kids);
        }
    }

    /**
     * @description Override a parent row's fields with aggregates from its
     *              children. Sums hours, takes earliest child start +
     *              latest child end as the bar bounds, and recomputes
     *              schedule progress + variance from those aggregates.
     *              Variance is 'done' iff every child is done.
     * @param parent Parent row (mutated).
     * @param children Direct children of `parent` (rows whose parentWorkItemId == parent.id).
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    private static void applyParentRollup(ProFormaTimelineRow parent, List<ProFormaTimelineRow> children) {
        Decimal totalEst = 0;
        Decimal totalLogged = 0;
        Boolean hasEstimate = false;
        Date earliestStart = null;
        Date latestEnd = null;
        Integer doneCount = 0;

        for (ProFormaTimelineRow c : children) {
            if (c.estimatedHours != null) {
                totalEst += c.estimatedHours;
                hasEstimate = true;
            }
            if (c.loggedHours != null) {
                totalLogged += c.loggedHours;
            }
            Date cStart = parseIsoDate(c.startDate);
            if (cStart != null && (earliestStart == null || cStart < earliestStart)) {
                earliestStart = cStart;
            }
            Date cEnd = parseIsoDate(c.endDate);
            if (cEnd != null && (latestEnd == null || cEnd > latestEnd)) {
                latestEnd = cEnd;
            }
            if ('done' == c.variance) {
                doneCount++;
            }
        }

        if (hasEstimate) {
            parent.estimatedHours = totalEst;
            parent.loggedHours = totalLogged;
            parent.progress = totalEst > 0 ? Math.min(totalLogged / totalEst, 1.0) : null;
        }
        if (earliestStart != null) {
            parent.startDate = String.valueOf(earliestStart);
        }
        if (latestEnd != null) {
            parent.endDate = String.valueOf(latestEnd);
        }
        parent.scheduleProgress = computeScheduleProgress(earliestStart, latestEnd);
        if (doneCount == children.size() && doneCount > 0) {
            parent.variance = 'done';
        } else {
            parent.variance = computeVariance(parent.progress, parent.scheduleProgress, false);
        }
        parent.childrenCount = children.size();
        parent.doneChildrenCount = doneCount;
    }

    /**
     * @description Parse an ISO YYYY-MM-DD date string back into a Date.
     *              Null-safe: returns null when input is blank or unparseable.
     *              Used by the parent-rollup pass to compute earliest-start /
     *              latest-end across children whose dates are stored as
     *              ISO strings on the DTO.
     * @param iso ISO YYYY-MM-DD date string, or null.
     * @return Parsed Date, or null when input is blank / unparseable.
     */
    private static Date parseIsoDate(String iso) {
        if (String.isBlank(iso)) {
            return null;
        }
        try {
            return Date.valueOf(iso);
        } catch (Exception e) {
            return null;
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

        // Schedule progress + variance — pairs with `progress` (hours-based) so
        // the gantt can render two overlay shades on each bar (output progress
        // vs schedule progress) and tint by variance signal. Mirrors the v12
        // visual language we want to bring to DH.
        row.scheduleProgress = computeScheduleProgress(startDt, endDt);
        row.variance = computeVariance(row.progress, row.scheduleProgress, isTerminal);
        row.actualEndDate = isTerminal && item.LastModifiedDate != null
            ? String.valueOf(item.LastModifiedDate.date())
            : null;

        return row;
    }

    /**
     * @description Fraction of (endDt - startDt) elapsed by today, clamped 0..1.
     *              Returns null when the interval is degenerate (same day or
     *              missing dates) so the renderer can fall back to bar-only.
     * @param startDt Bar start date.
     * @param endDt Bar end date.
     * @return Decimal in [0,1], or null when undefined.
     */
    private static Decimal computeScheduleProgress(Date startDt, Date endDt) {
        if (startDt == null || endDt == null || endDt <= startDt) {
            return null;
        }
        Date today = Date.today();
        if (today <= startDt) {
            return 0;
        }
        if (today >= endDt) {
            return 1;
        }
        Integer total = startDt.daysBetween(endDt);
        if (total <= 0) {
            return null;
        }
        Integer elapsed = startDt.daysBetween(today);
        return Decimal.valueOf(elapsed).divide(Decimal.valueOf(total), 4);
    }

    /**
     * @description Compute the variance signal for the gantt bar tint.
     *              'done' for terminal stages, 'at-risk' when schedule is
     *              nearly out but output is not, 'ahead' / 'behind' / 'on-track'
     *              based on the gap between hours-progress and schedule-progress.
     * @param hoursProgress Output progress 0..1 from logged/estimated hours.
     * @param schedProgress Time progress 0..1 from elapsed/total bar duration.
     * @param isTerminal True when the WorkItem stage is terminal.
     * @return Variance label or null when inputs insufficient.
     */
    private static String computeVariance(Decimal hoursProgress, Decimal schedProgress, Boolean isTerminal) {
        if (isTerminal) {
            return 'done';
        }
        if (hoursProgress == null || schedProgress == null) {
            return null;
        }
        // Out-of-time but not complete → at-risk (schedule consumed >95%, output <100%).
        if (schedProgress > 0.95 && hoursProgress < 1) {
            return 'at-risk';
        }
        Decimal delta = hoursProgress - schedProgress;
        if (delta > 0.10) {
            return 'ahead';
        }
        if (delta < -0.10) {
            return 'behind';
        }
        return 'on-track';
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

