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
            // Load every active item + compute its effective bucket (explicit or derived),
            // then filter to the target bucket. Echo-suppressed so the bulk update doesn't
            // cascade into peer-org sync traffic.
            DeliverySyncEngine.setSyncContext();

            List<WorkItem__c> all = [
                SELECT Id, PriorityPk__c, StageNamePk__c, PriorityGroupPk__c, SortOrderNumber__c
                FROM WorkItem__c
                WHERE IsActiveBool__c = true
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
            // Stable pre-sort by current SortOrder (nulls last) to establish the baseline
            // order we're about to rewrite.
            bucket.sort(new SortOrderComparator());

            // Remove the dragged task from its current position in the bucket, then
            // re-insert at the implied position.
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
                // The dragged task isn't in this bucket yet — NG already updated the bucket
                // field client-side, but the server hasn't seen it. Fabricate a stub so the
                // splice logic can place it; subsequent PriorityGroupPk__c update arrives
                // via a separate patch endpoint.
                moving = new WorkItem__c(Id = workItemId);
            }

            Integer insertAt;
            if (position == 'above-all') {
                insertAt = 0;
            } else if (position == 'below-all') {
                insertAt = others.size();
            } else {
                // 'between' — locate the afterTaskId in the list and insert just after it,
                // or the beforeTaskId and insert just before it. Prefer afterTaskId.
                insertAt = others.size();
                if (String.isNotBlank(afterTaskId)) {
                    for (Integer i = 0; i < others.size(); i++) {
                        if (others[i].Id == afterTaskId) {
                            insertAt = i + 1;
                            break;
                        }
                    }
                } else if (String.isNotBlank(beforeTaskId)) {
                    for (Integer i = 0; i < others.size(); i++) {
                        if (others[i].Id == beforeTaskId) {
                            insertAt = i;
                            break;
                        }
                    }
                }
            }

            List<WorkItem__c> finalOrder = new List<WorkItem__c>();
            for (Integer i = 0; i < insertAt && i < others.size(); i++) {
                finalOrder.add(others[i]);
            }
            finalOrder.add(moving);
            for (Integer i = insertAt; i < others.size(); i++) {
                finalOrder.add(others[i]);
            }

            // Write contiguous 1..N. Only include rows whose sortOrder actually changes
            // to keep the DML narrow.
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
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Sorts WorkItem__c by SortOrderNumber__c ascending, nulls last.
     */
    private class SortOrderComparator implements Comparator<WorkItem__c> {
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
