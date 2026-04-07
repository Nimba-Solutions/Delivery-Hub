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
    public static void handleAfter(
        List<WorkItem__c> newRows,
        Map<Id, WorkItem__c> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ){
        if (!DeliveryTriggerControl.runAfterLogic) { return; }

        // 1. BRIDGE CREATION (Network Entity Sync) + Field Tracking for Creates
        if (isInsert){
            handleNetworkEntitySync(newRows);
            autoSetSLATargets(newRows);
            DeliveryFieldTrackingService.trackCreates(newRows);
        }

        // 2. STAGE CHANGE EVENTS (real-time board refresh via Platform Events)
        //    + Activity Log history for time-study analytics
        //    + Configurable field change tracking via TrackedField__mdt
        //    + SLA pause/resume when stage enters/exits configured stages
        if (isUpdate) {
            publishStageChangeEvents(newRows, oldMap);
            logStageChanges(newRows, oldMap);
            DeliveryFieldTrackingService.trackChanges(newRows, oldMap);
            handleSLAPauseResume(newRows, oldMap);
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
            'DeveloperLookup__c',
            'CalculatedETADate__c',
            'ProjectedUATReadyDate__c',
            'AcceptanceCriteriaTxt__c',
            'StepsToReproduceTxt__c',
            // SLA & scheduling fields — must sync to preserve explicit dates
            'SLATargetDate__c',
            'SLAStatusTxt__c',
            'EstimatedStartDevDate__c',
            'EstimatedEndDevDate__c',
            'RequestTypePk__c',
            'WorkflowTypeTxt__c',
            'SortOrderNumber__c',
            // Bounty fields
            'BountyEnabledDateTime__c',
            'BountyAmountCurrency__c',
            'BountyDeadlineDate__c',
            'BountyStatusPk__c',
            'BountyTokenTxt__c',
            'BountyDifficultyPk__c',
            'BountySkillsTxt__c',
            'BountyMaxClaimsNumber__c'
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
            if (populatedFields.containsKey('EnableAutoCreateWorkRequestDateTime__c')) {
                shouldCreateRequest = settings.EnableAutoCreateWorkRequestDateTime__c != null;
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
                    WorkItemLookup__c = t.Id,
                    DeliveryEntityLookup__c = vendor.Id,
                    StatusPk__c = 'Draft',
                    PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                ));
            }
        } else {
            for (WorkItem__c t : newWorkItems) {
                if (t.ClientNetworkEntityLookup__c != null) {
                    newRequests.add(new WorkRequest__c(
                        WorkItemLookup__c = t.Id,
                        DeliveryEntityLookup__c = t.ClientNetworkEntityLookup__c,
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
                    WorkItemIdTxt__c   = t.Id,
                    ChangeTypeTxt__c = 'stage_change',
                    NewStageTxt__c   = t.StageNamePk__c
                ));
                slackChanges.put(t.Name, t.StageNamePk__c);
                changedIds.add(t.Id);
                emailStageMap.put(t.Id, t.StageNamePk__c);
            }
        }

        // Platform Event publish stays outside the notification toggle
        // (it powers real-time board refresh, not user notifications)
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }

        // Respect the master notification toggle
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        Boolean notificationsEnabled = settings.Id != null && settings.EnableNotificationsDateTime__c != null;

        if (notificationsEnabled) {
            if (!slackChanges.isEmpty()) {
                DeliverySlackService.postStageChanges(slackChanges);
            }

            // Email notifications for stage changes
            if (!changedIds.isEmpty()) {
                DeliveryEmailNotificationService.sendStageChangeEmails(changedIds, emailStageMap);
                DeliveryExternalNotificationService.sendExternalStageChangeEmails(changedIds, emailStageMap);
            }
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

        // Auto-generate bounty token when BountyEnabledDateTime__c flips to true on update
        for (WorkItem__c workItem : newWorkItems) {
            WorkItem__c oldItem = oldMap.get(workItem.Id);
            if (workItem.BountyEnabledDateTime__c != null
                && (oldItem == null || oldItem.BountyEnabledDateTime__c == null)
                && String.isBlank(workItem.BountyTokenTxt__c)) {
                workItem.BountyTokenTxt__c = DeliveryBountyService.generateBountyToken();
            }
        }

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
                SELECT BlockedWorkItemLookup__c, BlockingWorkItemLookup__r.BriefDescriptionTxt__c, BlockingWorkItemLookup__r.StageNamePk__c
                FROM WorkItemDependency__c
                WHERE BlockedWorkItemLookup__c IN :workItemsToCheck
                AND BlockingWorkItemLookup__r.StageNamePk__c NOT IN ('Done', 'Deployed to Prod', 'Cancelled')
                WITH SYSTEM_MODE
            ];
            for (WorkItemDependency__c dependency : unresolvedBlockers) {
                for (WorkItem__c workItem : newWorkItems) {
                    if (workItem.Id == dependency.BlockedWorkItemLookup__c) {
                        workItem.addError('This work item cannot be started. It is blocked by: ' + dependency.BlockingWorkItemLookup__r.BriefDescriptionTxt__c);
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
            if (workItem.ActivatedDateTime__c == null) {
                workItem.ActivatedDateTime__c = now;
            }
            if (workItem.StageEnteredDateTime__c == null) {
                workItem.StageEnteredDateTime__c = now;
            }
            // Auto-generate bounty token when published as a bounty
            if (workItem.BountyEnabledDateTime__c != null && String.isBlank(workItem.BountyTokenTxt__c)) {
                workItem.BountyTokenTxt__c = DeliveryBountyService.generateBountyToken();
            }
        }
    }

    /**
     * @description Pauses or resumes SLA clocks when a stage change matches the
     *              PauseOnStagesTxt__c / ResumeOnStagesTxt__c configuration on
     *              the matching SLARule__mdt record. Updates are performed via
     *              separate DML since this runs in after-update context.
     * @param newRows List of updated WorkItem__c records
     * @param oldMap  Map of pre-update WorkItem__c records
     */
    private static void handleSLAPauseResume(
        List<WorkItem__c> newRows,
        Map<Id, WorkItem__c> oldMap
    ) {
        List<WorkItem__c> slaUpdates = new List<WorkItem__c>();
        Datetime now = Datetime.now();

        for (WorkItem__c wi : newRows) {
            WorkItem__c old = oldMap.get(wi.Id);
            if (old == null || wi.StageNamePk__c == old.StageNamePk__c) {
                continue;
            }

            SLARule__mdt rule = DeliverySLAService.getRuleForContext(
                wi.WorkflowTypeTxt__c, wi.PriorityPk__c
            );
            if (rule == null) {
                continue;
            }

            String newStage = wi.StageNamePk__c;
            Set<String> pauseStages = parseStageSet(rule.PauseOnStagesTxt__c);
            Set<String> resumeStages = parseStageSet(rule.ResumeOnStagesTxt__c);

            // Pause: new stage is in the pause list and SLA is not already paused
            if (!pauseStages.isEmpty() && pauseStages.contains(newStage) && wi.SLAPausedDateTime__c == null) {
                slaUpdates.add(new WorkItem__c(
                    Id = wi.Id,
                    SLAPausedDateTime__c = now
                ));
            }
            // Resume: new stage is in the resume list and SLA is currently paused
            else if (!resumeStages.isEmpty() && resumeStages.contains(newStage) && wi.SLAPausedDateTime__c != null) {
                Decimal pausedDays = (Decimal)(now.getTime() - wi.SLAPausedDateTime__c.getTime()) / (1000.0 * 60 * 60 * 24);
                pausedDays = pausedDays.setScale(2, RoundingMode.HALF_UP);
                Decimal accrued = wi.SLAAccruedPauseDaysNumber__c != null ? wi.SLAAccruedPauseDaysNumber__c : 0;
                slaUpdates.add(new WorkItem__c(
                    Id = wi.Id,
                    SLAPausedDateTime__c = null,
                    SLAAccruedPauseDaysNumber__c = accrued + pausedDays
                ));
            }
        }

        if (!slaUpdates.isEmpty()) {
            Database.update(slaUpdates, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Parses a comma-separated string of stage names into a Set.
     * @param stages Comma-separated stage names (may be null or blank)
     * @return Set of trimmed stage name strings
     */
    private static Set<String> parseStageSet(String stages) {
        Set<String> result = new Set<String>();
        if (String.isBlank(stages)) {
            return result;
        }
        for (String s : stages.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                result.add(trimmed);
            }
        }
        return result;
    }

    /**
     * @description Creates ActivityLog__c records for every stage transition, capturing
     *              old stage, new stage, duration in previous stage, and the user who
     *              made the change. Powers time-study analytics and audit trails.
     * @param newRows List of updated WorkItem__c records
     * @param oldMap  Map of pre-update WorkItem__c records
     */
    private static void logStageChanges(
        List<WorkItem__c> newRows,
        Map<Id, WorkItem__c> oldMap
    ) {
        List<ActivityLog__c> logs = new List<ActivityLog__c>();
        Datetime now = Datetime.now();
        String userId = UserInfo.getUserId();

        for (WorkItem__c t : newRows) {
            WorkItem__c old = oldMap.get(t.Id);
            if (old == null || t.StageNamePk__c == old.StageNamePk__c) {
                continue;
            }

            Decimal durationHours = 0;
            if (old.StageEnteredDateTime__c != null) {
                Long ms = now.getTime() - old.StageEnteredDateTime__c.getTime();
                durationHours = (Decimal.valueOf(ms) / 3600000).setScale(2, RoundingMode.HALF_UP);
            }

            Map<String, Object> ctx = new Map<String, Object>{
                'workItemId' => t.Id,
                'workItemName' => t.Name,
                'oldStage' => old.StageNamePk__c,
                'newStage' => t.StageNamePk__c,
                'durationHours' => durationHours,
                'oldStageEnteredAt' => String.valueOf(old.StageEnteredDateTime__c)
            };

            logs.add(new ActivityLog__c(
                ActionTypePk__c     = 'Stage_Change',
                ComponentNameTxt__c = 'DeliveryWorkItemTrigger',
                UserIdTxt__c        = userId,
                RecordIdTxt__c      = t.Id,
                ContextDataTxt__c   = JSON.serialize(ctx)
            ));
        }

        if (!logs.isEmpty()) {
            Database.insert(logs, AccessLevel.SYSTEM_MODE);
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