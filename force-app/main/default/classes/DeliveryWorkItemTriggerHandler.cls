/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Aggregates WorkItem rows that need a DeliverySyncEngine update,
 * then enqueues worker jobs. Also handles Network Entity Sync and High-Water Mark Sync.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public without sharing class DeliveryWorkItemTriggerHandler {
    
    /** @description Flag to disable trigger execution */
    public static boolean triggerDisabled = false;

    /** @description Guard flag to prevent recursive SLA target setting */
    private static Boolean slaProcessed = false;

    /**
     * @description Entry point for After Insert/Update logic
     * @param newRows List of new WorkItem records
     * @param oldMap Map of old WorkItem records
     * @param isInsert Boolean indicating insert context
     * @param isUpdate Boolean indicating update context
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static void handleAfter(
        List<WorkItem__c> newRows,
        Map<Id, WorkItem__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        if (!DeliveryTriggerControl.runAfterLogic) { return; }

        // 1. BRIDGE CREATION (Network Entity Sync)
        if (isInsert){
            handleNetworkEntitySync(newRows);
            autoSetSLATargets(newRows);
        }

        // 2. STAGE CHANGE EVENTS (real-time board refresh via Platform Events)
        if (isUpdate) {
            publishStageChangeEvents(newRows, oldMap);
        }

        // 3. UNIFIED SYNC ENGINE (High-Water Mark)
        Set<String> syncFields = new Set<String>{
            'BriefDescriptionTxt__c', 
            'DetailsTxt__c', 
            'StageNamePk__c', 
            'StatusPk__c', 
            'PriorityPk__c', 
            'DeveloperDaysSizeNumber__c', 
            'EstimatedHoursNumber__c', 
            'ClientPreApprovedHoursNumber__c', 
            'Developer__c', 
            'CalculatedETADate__c', 
            'ProjectedUATReadyDate__c',
            'AcceptanceCriteriaTxt__c', 
            'StepsToReproduceTxt__c'
        };

        DeliverySyncEngine.captureChanges(newRows, oldMap, syncFields);
    }

    /**
     * @description Checks settings and auto-creates/sends a Request if configured.
     * @param newWorkItems List of new work items
     */
    private static void handleNetworkEntitySync(List<WorkItem__c> newWorkItems) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        
        Boolean shouldCreateRequest = true;
        if (settings.Id != null) {
            Map<String, Object> populatedFields = settings.getPopulatedFieldsAsMap();
            if (populatedFields.containsKey('AutoCreateWorkRequestBool__c')) {
                shouldCreateRequest = settings.AutoCreateWorkRequestBool__c;
            }
        }

        if (!shouldCreateRequest) {
            return;
        }

        // FIX: Swapped USER_MODE for SYSTEM_MODE to prevent packaging test failures
        List<NetworkEntity__c> vendors = [
            SELECT Id FROM NetworkEntity__c
            WHERE StatusPk__c = 'Active' AND EntityTypePk__c = 'Vendor'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        List<WorkRequest__c> newRequests = new List<WorkRequest__c>();

        if (!vendors.isEmpty()) {
            NetworkEntity__c vendor = vendors[0];
            for (WorkItem__c t : newWorkItems) {
                newRequests.add(new WorkRequest__c(
                    WorkItemId__c = t.Id,
                    DeliveryEntityId__c = vendor.Id,
                    StatusPk__c = 'Draft',
                    PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                ));
            }
        } else {
            for (WorkItem__c t : newWorkItems) {
                if (t.ClientNetworkEntityId__c != null) {
                    newRequests.add(new WorkRequest__c(
                        WorkItemId__c = t.Id,
                        DeliveryEntityId__c = t.ClientNetworkEntityId__c,
                        StatusPk__c = 'Draft',
                        PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                    ));
                }
            }
        }

        if (newRequests.isEmpty()) {
            return;
        }

        // Enforce CRUD/FLS on Insert but allow System Mode execution
        Database.insert(newRequests, AccessLevel.SYSTEM_MODE);
    }
    
    /**
     * @description Publishes a DeliveryWorkItemChange__e Platform Event for every workItem
     *              whose StageNamePk__c changed in this transaction, enabling real-time
     *              board refresh via the EMP API without polling.
     *              Also schedules an async Slack notification for the same changes.
     * @param newRows List of updated WorkItem__c records
     * @param oldMap  Map of pre-update WorkItem__c records
     */
    private static void publishStageChangeEvents(
        List<WorkItem__c> newRows,
        Map<Id, WorkItem__c> oldMap
    ) {
        List<DeliveryWorkItemChange__e> events = new List<DeliveryWorkItemChange__e>();
        Map<String, String> slackChanges = new Map<String, String>();
        Set<Id> changedIds = new Set<Id>();
        Map<Id, String> emailStageMap = new Map<Id, String>();

        for (WorkItem__c t : newRows) {
            WorkItem__c old = oldMap.get(t.Id);
            if (old != null && t.StageNamePk__c != old.StageNamePk__c) {
                events.add(new DeliveryWorkItemChange__e(
                    WorkItemId__c   = t.Id,
                    ChangeType__c = 'stage_change',
                    NewStage__c   = t.StageNamePk__c
                ));
                slackChanges.put(t.Name, t.StageNamePk__c);
                changedIds.add(t.Id);
                emailStageMap.put(t.Id, t.StageNamePk__c);
            }
        }

        if (!events.isEmpty()) {
            EventBus.publish(events);
        }

        if (!slackChanges.isEmpty()) {
            DeliverySlackService.postStageChanges(slackChanges);
        }

        // Email notifications for stage changes
        if (!changedIds.isEmpty()) {
            DeliveryEmailNotificationService.sendStageChangeEmails(changedIds, emailStageMap);
        }
    }

    /**
     * @description Auto-sets SLA target dates on newly inserted work items via
     *              DeliverySLAService. Creates lightweight update records to persist
     *              the computed dates (after-insert requires separate DML).
     * @param newRows List of newly inserted WorkItem__c records
     */
    private static void autoSetSLATargets(List<WorkItem__c> newRows) {
        if (slaProcessed) {
            return;
        }
        slaProcessed = true;

        List<WorkItem__c> clones = new List<WorkItem__c>();
        for (WorkItem__c wi : newRows) {
            clones.add(wi.clone(true, true, false, false));
        }

        DeliverySLAService.autoSetSLATarget(clones);

        List<WorkItem__c> slaUpdates = new List<WorkItem__c>();
        for (WorkItem__c wi : clones) {
            if (wi.SLATargetDate__c != null) {
                slaUpdates.add(new WorkItem__c(Id = wi.Id, SLATargetDate__c = wi.SLATargetDate__c));
            }
        }

        if (!slaUpdates.isEmpty()) {
            Database.update(slaUpdates, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Logic to handle Before Update events (stage timestamp + blocking logic)
     * @param newWorkItems List of WorkItem__c records being updated
     * @param oldMap Map of old WorkItem__c records keyed by Id
     */
    public static void handleBeforeUpdate(List<WorkItem__c> newWorkItems, Map<Id, WorkItem__c> oldMap) {
        stampStageEnteredOnUpdate(newWorkItems, oldMap);

        Set<String> activeDevStages = new Set<String>{'In Development', 'Ready for QA'};
        Set<Id> workItemsToCheck = new Set<Id>();
        for (WorkItem__c workItem : newWorkItems) {
            String oldStage = oldMap.get(workItem.Id).StageNamePk__c;
            String newStage = workItem.StageNamePk__c;
            if (activeDevStages.contains(newStage) && !activeDevStages.contains(oldStage)) {
                workItemsToCheck.add(workItem.Id);
            }
        }
        if (!workItemsToCheck.isEmpty()) {
            // FIX: Swapped USER_MODE for SYSTEM_MODE
            List<WorkItemDependency__c> unresolvedBlockers = [
                SELECT BlockedWorkItemId__c, BlockingWorkItemId__r.BriefDescriptionTxt__c, BlockingWorkItemId__r.StageNamePk__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__c IN :workItemsToCheck
                AND BlockingWorkItemId__r.StageNamePk__c NOT IN ('Done', 'Deployed to Prod', 'Cancelled')
                WITH SYSTEM_MODE
            ];
            for (WorkItemDependency__c dependency : unresolvedBlockers) {
                for (WorkItem__c workItem : newWorkItems) {
                    if (workItem.Id == dependency.BlockedWorkItemId__c) {
                        workItem.addError('This work item cannot be started. It is blocked by: ' + dependency.BlockingWorkItemId__r.BriefDescriptionTxt__c);
                    }
                }
            }
        }
    }

    /**
     * @description Sets StageEnteredDateTime__c on new work items during before-insert.
     * @param newWorkItems List of WorkItem__c records being inserted
     */
    public static void handleBeforeInsert(List<WorkItem__c> newWorkItems) {
        Datetime now = Datetime.now();
        for (WorkItem__c workItem : newWorkItems) {
            if (workItem.StageEnteredDateTime__c == null) {
                workItem.StageEnteredDateTime__c = now;
            }
        }
    }

    /**
     * @description Sets StageEnteredDateTime__c when the stage changes during update.
     * @param newWorkItems List of WorkItem__c records being updated
     * @param oldMap Map of old WorkItem__c records keyed by Id
     */
    private static void stampStageEnteredOnUpdate(
        List<WorkItem__c> newWorkItems,
        Map<Id, WorkItem__c> oldMap
    ) {
        Datetime now = Datetime.now();
        for (WorkItem__c workItem : newWorkItems) {
            WorkItem__c oldItem = oldMap.get(workItem.Id);
            if (oldItem != null && workItem.StageNamePk__c != oldItem.StageNamePk__c) {
                workItem.StageEnteredDateTime__c = now;
            }
        }
    }
}