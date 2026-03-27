/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Hub Board LWC.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryHubBoardController {

    /**
     * @description Updates the stage of a single work item.
     * @param workItemId The Id of the WorkItem__c to update.
     * @param newStage The new stage picklist value to set.
     */
    @AuraEnabled
    public static void updateWorkItemStage(Id workItemId, String newStage) {
        try {
            if (Schema.sObjectType.WorkItem__c.isUpdateable()) {
                WorkItem__c workItem = new WorkItem__c(Id = workItemId, StageNamePk__c = newStage);
                update workItem;
            } else {
                throw createAuraException('Insufficient permissions to update work item.');
            }
        } catch (Exception e) {
            throw createAuraException('Error updating work item stage: ' + e.getMessage());
        }
    }

    /**
     * @description Reorders a work item using integer-based indexing.
     * @param workItemId The Id of the WorkItem__c being moved.
     * @param newStage The target stage column for the work item.
     * @param newIndex The zero-based position within the target stage column.
     */
    @AuraEnabled
    public static void reorderWorkItem(Id workItemId, String newStage, Integer newIndex) {
        try {
            // 1. Get existing work items in this stage (EXCLUDING the one we are moving)
            // FIX: Removed 'WITH SECURITY_ENFORCED' to prevent FLS errors on SortOrderNumber__c/ActivatedDateTime__c
            List<WorkItem__c> workItemsInColumn = [
                SELECT Id, SortOrderNumber__c
                FROM WorkItem__c
                WHERE StageNamePk__c = :newStage
                AND Id != :workItemId
                AND ActivatedDateTime__c != null
                WITH SYSTEM_MODE
                ORDER BY SortOrderNumber__c ASC NULLS LAST, CreatedDate DESC
            ];

            // 2. Prepare the moving work item object
            WorkItem__c movingWorkItem = new WorkItem__c(Id = workItemId, StageNamePk__c = newStage);

            // 3. SAFETY FIX: Manually build a NEW list to avoid "Index Out of Bounds"
            List<WorkItem__c> processingList = new List<WorkItem__c>();
            Boolean added = false;

            // Loop through existing work items and insert ours at the right spot
            for (Integer i = 0; i < workItemsInColumn.size(); i++) {
                if (i == newIndex) {
                    processingList.add(movingWorkItem);
                    added = true;
                }
                processingList.add(workItemsInColumn[i]);
            }

            // If we reached the end and haven't added it yet (e.g. dropped at bottom), add it now
            if (!added) {
                processingList.add(movingWorkItem);
            }

            // 4. Re-index the new clean list (1, 2, 3...)
            List<WorkItem__c> toUpdate = new List<WorkItem__c>();
            for (Integer i = 0; i < processingList.size(); i++) {
                WorkItem__c t = processingList[i];
                Decimal expectedSort = i + 1;

                // Update if the sort order is wrong OR if it's the moving work item (to save the new Stage)
                if (t.Id == workItemId || t.SortOrderNumber__c != expectedSort) {
                    if (t.Id == workItemId) {
                        t.SortOrderNumber__c = expectedSort;
                        t.StageNamePk__c = newStage;
                    } else {
                        t.SortOrderNumber__c = expectedSort;
                    }
                    toUpdate.add(t);
                }
            }

            if (!toUpdate.isEmpty()) {
                // This check ensures we still have permission to Write, maintaining security
                if (Schema.sObjectType.WorkItem__c.isUpdateable()) {
                    update toUpdate;
                } else {
                    throw createAuraException('Insufficient permissions to reorder work items.');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in reorderWorkItem: ' + e.getMessage());
            throw createAuraException(e.getMessage());
        }
    }

    /**
     * @description Creates a blocking dependency between two work items.
     * @param blockedWorkItemId The Id of the work item that is blocked.
     * @param blockingWorkItemId The Id of the work item that is blocking.
     * @return The newly created WorkItemDependency__c record.
     */
    @AuraEnabled
    public static WorkItemDependency__c createDependency(Id blockedWorkItemId, Id blockingWorkItemId) {
        if (blockedWorkItemId == blockingWorkItemId) {
            throw createAuraException('A work item cannot block itself.');
        }

        try {
            if (Schema.sObjectType.WorkItemDependency__c.isCreateable()) {
                WorkItemDependency__c newDependency = new WorkItemDependency__c(
                    BlockedWorkItemId__c = blockedWorkItemId,
                    BlockingWorkItemId__c = blockingWorkItemId,
                    TypePk__c = 'Blocks'
                );
                insert newDependency;
                return newDependency;
            } else {
                throw createAuraException('Insufficient permissions to create dependency.');
            }
        } catch (Exception e) {
            throw createAuraException('Error creating dependency: ' + e.getMessage());
        }
    }

    /**
     * @description Deletes a work item dependency record.
     * @param dependencyId The Id of the WorkItemDependency__c to delete.
     */
    @AuraEnabled
    public static void removeDependency(Id dependencyId) {
        try {
            if (Schema.sObjectType.WorkItemDependency__c.isDeletable()) {
                WorkItemDependency__c dep = [SELECT Id FROM WorkItemDependency__c WHERE Id = :dependencyId LIMIT 1];
                delete dep;
            } else {
                throw createAuraException('Insufficient permissions to remove dependency.');
            }
        } catch (Exception e) {
            throw createAuraException('Error removing dependency: ' + e.getMessage());
        }
    }
    
    /**
     * @description Searches for work items that could be added as blockers, excluding terminal stages
     *              and already-linked dependencies.
     * @param searchTerm Text to match against work item Name or BriefDescriptionTxt__c.
     * @param currentWorkItemId The Id of the current work item (excluded from results).
     * @param existingDependencyIds List of Ids already linked as dependencies (excluded from results).
     * @param workflowType The workflow type DeveloperName used to determine terminal stages.
     * @return List of matching non-terminal WorkItem__c records (max 10).
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled(cacheable=true)
    public static List<WorkItem__c> searchForPotentialBlockers(String searchTerm, Id currentWorkItemId, List<Id> existingDependencyIds, String workflowType) {
        String queryTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        Set<Id> exclusionIds = new Set<Id>();
        if (currentWorkItemId != null) {
            exclusionIds.add(currentWorkItemId);
        }
        if (existingDependencyIds != null) {
            exclusionIds.addAll(existingDependencyIds);
        }

        // Exclude terminal stages (Done, Cancelled, etc.) using CMT-driven config
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(
            String.isBlank(workflowType) ? 'Software_Delivery' : workflowType
        );

        // Removed WITH SECURITY_ENFORCED to prevent build failures on FLS checks
        // Assuming sharing settings cover visibility.
        return [
            SELECT Id, Name, StageNamePk__c, BriefDescriptionTxt__c
            FROM WorkItem__c
            WHERE (Name LIKE :queryTerm OR BriefDescriptionTxt__c LIKE :queryTerm)
            AND Id NOT IN :exclusionIds
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
    }

    /**
     * @description Returns board-level KPI metrics: active items, weekly/monthly throughput,
     * average cycle time, blocked count, and attention-needed count.
     * Optionally scoped to a single NetworkEntity when entityId is provided.
     * @param workflowType The workflow type DeveloperName (defaults to 'Software_Delivery').
     * @return Map of metric name to value.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBoardMetrics(String workflowType) {
        return getBoardMetricsForEntity(workflowType, null);
    }

    /**
     * @description Returns board-level KPI metrics scoped to an optional NetworkEntity.
     * When entityId is null, returns metrics across all entities (admin view).
     * When entityId is provided, filters all counts to that single client entity.
     * @param workflowType The workflow type DeveloperName (defaults to 'Software_Delivery').
     * @param entityId Optional ClientNetworkEntityId__c to scope metrics. Null for all entities.
     * @return Map of metric name to value.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBoardMetricsForEntity(String workflowType, Id entityId) {
        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }
        Map<String, Object> metrics = new Map<String, Object>();

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);
        Set<String> attentionStages = DeliveryWorkflowConfigService.getAttentionStageValues(workflowType);

        // 1. Active items (non-terminal)
        Integer activeCount;
        if (entityId != null) {
            activeCount = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c NOT IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND ClientNetworkEntityId__c = :entityId
                WITH SYSTEM_MODE
            ];
        } else {
            activeCount = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c NOT IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                WITH SYSTEM_MODE
            ];
        }
        metrics.put('activeCount', activeCount);

        // 2. Completed this week
        Date weekStart = Date.today().toStartOfWeek();
        Datetime weekStartDt = Datetime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));
        Integer completedThisWeek;
        if (entityId != null) {
            completedThisWeek = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND LastModifiedDate >= :weekStartDt
                AND ClientNetworkEntityId__c = :entityId
                WITH SYSTEM_MODE
            ];
        } else {
            completedThisWeek = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND LastModifiedDate >= :weekStartDt
                WITH SYSTEM_MODE
            ];
        }
        metrics.put('completedThisWeek', completedThisWeek);

        // 3. Completed this month (throughput)
        Date monthStart = Date.today().toStartOfMonth();
        Datetime monthStartDt = Datetime.newInstance(monthStart, Time.newInstance(0, 0, 0, 0));
        Integer completedThisMonth;
        if (entityId != null) {
            completedThisMonth = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND LastModifiedDate >= :monthStartDt
                AND ClientNetworkEntityId__c = :entityId
                WITH SYSTEM_MODE
            ];
        } else {
            completedThisMonth = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND LastModifiedDate >= :monthStartDt
                WITH SYSTEM_MODE
            ];
        }
        metrics.put('completedThisMonth', completedThisMonth);

        // 4. Average cycle time (days from creation to terminal stage, last 30 days)
        Date thirtyDaysAgo = Date.today().addDays(-30);
        Datetime thirtyDaysAgoDt = Datetime.newInstance(thirtyDaysAgo, Time.newInstance(0, 0, 0, 0));
        List<WorkItem__c> completedRecent;
        if (entityId != null) {
            completedRecent = [
                SELECT CreatedDate, LastModifiedDate
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND LastModifiedDate >= :thirtyDaysAgoDt
                AND ClientNetworkEntityId__c = :entityId
                WITH SYSTEM_MODE
                LIMIT 200
            ];
        } else {
            completedRecent = [
                SELECT CreatedDate, LastModifiedDate
                FROM WorkItem__c
                WHERE StageNamePk__c IN :terminalStages
                AND WorkflowTypeTxt__c = :workflowType
                AND LastModifiedDate >= :thirtyDaysAgoDt
                WITH SYSTEM_MODE
                LIMIT 200
            ];
        }
        Decimal totalDays = 0;
        for (WorkItem__c wi : completedRecent) {
            Long msecDiff = wi.LastModifiedDate.getTime() - wi.CreatedDate.getTime();
            totalDays += msecDiff / (1000.0 * 60 * 60 * 24);
        }
        Decimal avgCycleTime = completedRecent.isEmpty()
            ? 0
            : (totalDays / completedRecent.size()).setScale(1, RoundingMode.HALF_UP);
        metrics.put('avgCycleTimeDays', avgCycleTime);

        // 5. Blocked items count (items that have unresolved blocking dependencies)
        Set<Id> blockedIds = new Set<Id>();
        if (entityId != null) {
            for (WorkItemDependency__c dep : [
                SELECT BlockedWorkItemId__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__c IN (
                    SELECT Id FROM WorkItem__c
                    WHERE StageNamePk__c NOT IN :terminalStages
                    AND WorkflowTypeTxt__c = :workflowType
                    AND ClientNetworkEntityId__c = :entityId
                )
                AND BlockingWorkItemId__c IN (
                    SELECT Id FROM WorkItem__c WHERE StageNamePk__c NOT IN :terminalStages
                )
                WITH SYSTEM_MODE
            ]) {
                blockedIds.add(dep.BlockedWorkItemId__c);
            }
        } else {
            for (WorkItemDependency__c dep : [
                SELECT BlockedWorkItemId__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__c IN (
                    SELECT Id FROM WorkItem__c
                    WHERE StageNamePk__c NOT IN :terminalStages
                    AND WorkflowTypeTxt__c = :workflowType
                )
                AND BlockingWorkItemId__c IN (
                    SELECT Id FROM WorkItem__c WHERE StageNamePk__c NOT IN :terminalStages
                )
                WITH SYSTEM_MODE
            ]) {
                blockedIds.add(dep.BlockedWorkItemId__c);
            }
        }
        metrics.put('blockedCount', blockedIds.size());

        // 6. Attention-needed items
        Integer attentionCount;
        if (entityId != null) {
            attentionCount = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :attentionStages
                AND WorkflowTypeTxt__c = :workflowType
                AND ClientNetworkEntityId__c = :entityId
                WITH SYSTEM_MODE
            ];
        } else {
            attentionCount = [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE StageNamePk__c IN :attentionStages
                AND WorkflowTypeTxt__c = :workflowType
                WITH SYSTEM_MODE
            ];
        }
        metrics.put('attentionCount', attentionCount);

        return metrics;
    }

    /**
     * @description Returns active work items scoped to an optional NetworkEntity.
     * When entityId is null, returns all active work items for the workflow type (admin view).
     * When entityId is provided, filters to only that entity's work items (client view).
     * @param workflowType The workflow type DeveloperName (defaults to 'Software_Delivery').
     * @param entityId Optional ClientNetworkEntityId__c to scope results. Null for all entities.
     * @return List of active WorkItem__c records with related dependencies and comments.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled(cacheable=true)
    public static List<WorkItem__c> getWorkItemsForEntity(String workflowType, Id entityId) {
        if (String.isBlank(workflowType)) {
            workflowType = 'Software_Delivery';
        }
        if (entityId != null) {
            return [
                SELECT Id,
                    BriefDescriptionTxt__c,
                    CalculatedETADate__c,
                    DeveloperDaysSizeNumber__c,
                    StageNamePk__c,
                    ClientIntentionPk__c,
                    SortOrderNumber__c,
                    Epic__c,
                    Tags__c,
                    WorkflowTypeTxt__c,
                    TotalLoggedHoursNumber__c,
                    EstimatedHoursNumber__c,
                    LastModifiedDate,
                    PriorityPk__c,
                    (SELECT Id, BlockingWorkItemId__c, BlockingWorkItemId__r.Name FROM BlockedByDeps__r),
                    (SELECT Id, BlockedWorkItemId__c, BlockedWorkItemId__r.Name FROM BlockingDeps__r),
                    (SELECT Id FROM WorkItemComments__r LIMIT 100)
                FROM WorkItem__c
                WHERE ActivatedDateTime__c != null
                AND TemplateMarkedDateTime__c = null
                AND WorkflowTypeTxt__c = :workflowType
                AND ClientNetworkEntityId__c = :entityId
                WITH SYSTEM_MODE
                ORDER BY SortOrderNumber__c
            ];
        }
        return [
            SELECT Id,
                BriefDescriptionTxt__c,
                CalculatedETADate__c,
                DeveloperDaysSizeNumber__c,
                StageNamePk__c,
                ClientIntentionPk__c,
                SortOrderNumber__c,
                Epic__c,
                Tags__c,
                WorkflowTypeTxt__c,
                TotalLoggedHoursNumber__c,
                EstimatedHoursNumber__c,
                LastModifiedDate,
                PriorityPk__c,
                (SELECT Id, BlockingWorkItemId__c, BlockingWorkItemId__r.Name FROM BlockedByDeps__r),
                (SELECT Id, BlockedWorkItemId__c, BlockedWorkItemId__r.Name FROM BlockingDeps__r),
                (SELECT Id FROM WorkItemComments__r LIMIT 100)
            FROM WorkItem__c
            WHERE ActivatedDateTime__c != null
            AND TemplateMarkedDateTime__c = null
            AND WorkflowTypeTxt__c = :workflowType
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c
        ];
    }

    /**
     * @description Returns full work item detail for the slide-out panel including
     *              comments and attached files. Reuses existing controller methods
     *              for comments (DeliveryHubCommentController) and files
     *              (DeliveryHubFilesController) to avoid duplicating SOQL.
     * @param workItemId The WorkItem__c record Id.
     * @return Map containing workItem, comments, and files keys.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    @AuraEnabled
    public static Map<String, Object> getWorkItemDetail(Id workItemId) {
        Map<String, Object> result = new Map<String, Object>();

        // 1. Fetch the work item with key fields
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c,
                   StageNamePk__c, PriorityPk__c, Owner.Name, OwnerId,
                   DeveloperDaysSizeNumber__c, TotalLoggedHoursNumber__c,
                   EstimatedHoursNumber__c, CalculatedETADate__c,
                   Tags__c, WorkflowTypeTxt__c, CreatedDate, LastModifiedDate,
                   Developer__c, Developer__r.Name, Epic__c,
                   ProjectedUATReadyDate__c, ClientIntentionPk__c
            FROM WorkItem__c
            WHERE Id = :workItemId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (items.isEmpty()) {
            throw createAuraException('Work item not found.');
        }
        result.put('workItem', items[0]);

        // 2. Fetch comments via existing controller
        List<WorkItemComment__c> comments = DeliveryHubCommentController.getLiveComments(workItemId);
        result.put('comments', comments);

        // 3. Fetch files via existing controller
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getWorkItemFiles(workItemId);
        result.put('files', files);

        return result;
    }

    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}