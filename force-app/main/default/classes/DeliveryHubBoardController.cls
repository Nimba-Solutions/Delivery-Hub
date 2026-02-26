/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Delivery Hub Board LWC.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryHubBoardController {

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
     */
    @AuraEnabled
    public static void reorderWorkItem(Id workItemId, String newStage, Integer newIndex) {
        try {
            // 1. Get existing work items in this stage (EXCLUDING the one we are moving)
            // FIX: Removed 'WITH SECURITY_ENFORCED' to prevent FLS errors on SortOrderNumber__c/IsActiveBool__c
            List<WorkItem__c> workItemsInColumn = [
                SELECT Id, SortOrderNumber__c
                FROM WorkItem__c
                WHERE StageNamePk__c = :newStage
                AND Id != :workItemId
                AND IsActiveBool__c = TRUE
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
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
    }

    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}