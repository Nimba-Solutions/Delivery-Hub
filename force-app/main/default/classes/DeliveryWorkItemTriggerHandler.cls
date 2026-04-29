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
            publishLiveGanttEvents(newRows, null, true);
        }

        // 2. STAGE CHANGE EVENTS (real-time board refresh via Platform Events)
        //    + Activity Log history for time-study analytics
        //    + Configurable field change tracking via TrackedField__mdt
        //    + SLA pause/resume when stage enters/exits configured stages
        if (isUpdate) {
            publishStageChangeEvents(newRows, oldMap);
            publishLiveGanttEvents(newRows, oldMap, false);
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
            // PriorityGroupPk__c drives gantt grouping (NOW / NEXT / PROPOSED).
            // Without this in syncFields the field stays null on subscriber orgs
            // and the timeline groups collapse to a single default bucket — even
            // though the source has top-priority/active/etc populated correctly.
            'PriorityGroupPk__c',
            // ParentWorkItemLookup__c is a cross-org self-FK. The OUTBOUND payload
            // carries the sender-org WorkItem Id; the inbound ingestor translates
            // it to the local Id via the SyncItem ledger. Without this in syncFields,
            // children arrive flat on subscriber orgs and gantt nesting breaks
            // (parent rollup bar shows but children don't fold under it).
            'ParentWorkItemLookup__c',
            'DeveloperDaysSizeNumber__c',
            'EstimatedHoursNumber__c',
            'ClientPreApprovedHoursNumber__c',
            // DeveloperLookup__c intentionally NOT synced — User Ids are
            // org-specific and cannot translate cross-org. Including it
            // produced INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY errors
            // on every dispatch when subscriber orgs received a User Id
            // that doesn't exist in their User table (verified in MF-Prod
            // 2026-04-26 13:16 UTC: 20 SyncItems retry-exhausted with that
            // exact error class). Future replacement: cross-org-safe text
            // attribution via the Integration Framework (DH PR #700).
            // Regression-prevention test in DeliveryWorkItemTriggerHandlerTest
            // asserts no User-typed lookup ever lives in this Set.
            'CalculatedETADate__c',
            'ProjectedUATReadyDate__c',
            'AcceptanceCriteriaTxt__c',
            'StepsToReproduceTxt__c',
            // SLA & scheduling fields — must sync to preserve explicit dates.
            // NOTE: SLAStatusTxt__c is intentionally NOT synced. It's a Formula(Text)
            // computed from SLATargetDate__c + stage; the receiving org recalculates
            // it locally. Including it caused inbound sync writes to fail with
            // "Field delivery__SLAStatusTxt__c is not editable".
            'SLATargetDate__c',
            'EstimatedStartDevDate__c',
            'EstimatedEndDevDate__c',
            // ActivatedDateTime__c filters Delivery Timeline visibility. The
            // receiver-side auto-set in handleBeforeInsert is now gated on
            // inboundSyncContext so the source value is the source of truth;
            // include it here so explicit activations propagate cross-org.
            'ActivatedDateTime__c',
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
                    WorkItemId__c = t.Id,
                    DeliveryEntityLookup__c = vendor.Id,
                    StatusPk__c = 'Draft',
                    PreApprovedHoursNumber__c = (t.ClientPreApprovedHoursNumber__c != null) ? t.ClientPreApprovedHoursNumber__c : 0
                ));
            }
        } else {
            for (WorkItem__c t : newWorkItems) {
                if (t.ClientNetworkEntityLookup__c != null) {
                    newRequests.add(new WorkRequest__c(
                        WorkItemId__c = t.Id,
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
     * @description Publishes task_upsert Platform Events for connected gantt LWCs
     *              (nimbus-gantt 0.185.38+ remote-events channel). Fires on after-insert
     *              and after-update when EnableLiveGanttEventsDateTime__c is set on
     *              DeliveryHubSettings__c. Patches are grouped by ClientNonceTxt__c so
     *              subscribers can drop self-echoes via per-mount nonce comparison.
     *
     *              Insert payload: full set of gantt-relevant fields per row.
     *              Update payload: only fields whose values changed (plus Id).
     *
     *              task_delete + dep_upsert/dep_delete are intentionally deferred — the
     *              trigger has no after-delete hook and dependencies live on a separate
     *              object. See dispatch-ng-remote-events.md for the host-side contract.
     * @param newRows List of WorkItem__c records (post-trigger state)
     * @param oldMap  Map of pre-trigger records keyed by Id (null on insert)
     * @param isInsert True for after-insert context, false for after-update
     */
    private static void publishLiveGanttEvents(
        List<WorkItem__c> newRows,
        Map<Id, WorkItem__c> oldMap,
        Boolean isInsert
    ) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || settings.Id == null || settings.EnableLiveGanttEventsDateTime__c == null) {
            return;
        }

        // Group patches by clientNonce so a single event carries one originating
        // mount's writes — subscribers compare nonce against their own per-mount
        // UUID to drop self-echoes (multi-tab same-user safe).
        Map<String, List<Map<String, Object>>> patchesByNonce = new Map<String, List<Map<String, Object>>>();

        for (WorkItem__c t : newRows) {
            WorkItem__c old = isInsert ? null : (oldMap != null ? oldMap.get(t.Id) : null);
            Map<String, Object> patch = buildLiveGanttTaskPatch(t, old);
            // Skip rows where no gantt-relevant field changed (patch has only Id).
            if (patch.size() <= 1) {
                continue;
            }
            String nonce = String.isNotBlank(t.ClientNonceTxt__c) ? t.ClientNonceTxt__c : '';
            List<Map<String, Object>> bucket = patchesByNonce.get(nonce);
            if (bucket == null) {
                bucket = new List<Map<String, Object>>();
                patchesByNonce.put(nonce, bucket);
            }
            bucket.add(patch);
        }

        if (patchesByNonce.isEmpty()) {
            return;
        }

        List<DeliveryWorkItemChange__e> events = new List<DeliveryWorkItemChange__e>();
        List<Map<String, Object>> bridgePayloads = new List<Map<String, Object>>();
        for (String nonce : patchesByNonce.keySet()) {
            String patchesJson = JSON.serialize(patchesByNonce.get(nonce));
            events.add(new DeliveryWorkItemChange__e(
                ChangeTypeTxt__c   = 'task_upsert',
                TaskPatchesJson__c = patchesJson,
                ClientNonceTxt__c  = nonce
            ));
            // Bridge payload mirrors the Platform Event shape so the receiving
            // org's handler can apply patches identically. Unconditional
            // assembly is cheap; the bridge service fast-exits when toggle
            // off / peer URL blank, so no callout cost when disabled.
            bridgePayloads.add(new Map<String, Object>{
                'ChangeTypeTxt__c'   => 'task_upsert',
                'TaskPatchesJson__c' => patchesJson,
                'ClientNonceTxt__c'  => nonce
            });
        }

        EventBus.publish(events);

        // Layer 2: cross-org bridge. Skip when this DML is itself an inbound
        // bridge write — otherwise we'd ping-pong forever.
        if (!DeliveryTriggerControl.inboundSyncContext) {
            DeliveryCrossOrgGanttBridge.enqueueIfEnabled(bridgePayloads);
        }
    }

    /**
     * @description Builds a per-row JSON patch keyed by SObject API name. On insert,
     *              includes all gantt-relevant fields (full row). On update, includes
     *              only fields whose values changed, plus Id. The LWC adapter is
     *              responsible for mapping SF field names to its camelCase TaskPatch
     *              keys (id, parentId, sortOrder, name, status, startDate, endDate, ...).
     * @param t    Current WorkItem__c row
     * @param old  Pre-update WorkItem__c row, or null on insert
     * @return Map with Id always set; field keys present only when changed (or always on insert)
     */
    @SuppressWarnings('PMD.NcssMethodCount')
    private static Map<String, Object> buildLiveGanttTaskPatch(WorkItem__c t, WorkItem__c old) {
        Map<String, Object> patch = new Map<String, Object>{ 'Id' => t.Id };
        Boolean force = (old == null);

        putIfChanged(patch, force, 'Name', t.Name, force ? null : old.Name);
        putIfChanged(patch, force, 'BriefDescriptionTxt__c', t.BriefDescriptionTxt__c, force ? null : old.BriefDescriptionTxt__c);
        putIfChanged(patch, force, 'StageNamePk__c', t.StageNamePk__c, force ? null : old.StageNamePk__c);
        putIfChanged(patch, force, 'StatusPk__c', t.StatusPk__c, force ? null : old.StatusPk__c);
        putIfChanged(patch, force, 'PriorityPk__c', t.PriorityPk__c, force ? null : old.PriorityPk__c);
        putIfChanged(patch, force, 'PriorityGroupPk__c', t.PriorityGroupPk__c, force ? null : old.PriorityGroupPk__c);
        putIfChanged(patch, force, 'SortOrderNumber__c', t.SortOrderNumber__c, force ? null : old.SortOrderNumber__c);
        putIfChanged(patch, force, 'ParentWorkItemLookup__c', t.ParentWorkItemLookup__c, force ? null : old.ParentWorkItemLookup__c);
        putIfChanged(patch, force, 'EstimatedStartDevDate__c', t.EstimatedStartDevDate__c, force ? null : old.EstimatedStartDevDate__c);
        putIfChanged(patch, force, 'EstimatedEndDevDate__c', t.EstimatedEndDevDate__c, force ? null : old.EstimatedEndDevDate__c);
        putIfChanged(patch, force, 'ProjectedUATReadyDate__c', t.ProjectedUATReadyDate__c, force ? null : old.ProjectedUATReadyDate__c);
        putIfChanged(patch, force, 'CalculatedETADate__c', t.CalculatedETADate__c, force ? null : old.CalculatedETADate__c);
        putIfChanged(patch, force, 'ActivatedDateTime__c', t.ActivatedDateTime__c, force ? null : old.ActivatedDateTime__c);

        return patch;
    }

    /**
     * @description Adds a key/value to the patch map when force=true (insert) or when
     *              newVal differs from oldVal (update). Null-safe via Apex Object equality.
     * @param patch The patch map being assembled.
     * @param force True for insert context — every field always added.
     * @param key Field API name used as map key.
     * @param newVal Current value of the field.
     * @param oldVal Pre-update value of the field (ignored when force=true).
     */
    private static void putIfChanged(Map<String, Object> patch, Boolean force, String key, Object newVal, Object oldVal) {
        if (force || newVal != oldVal) {
            patch.put(key, newVal);
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
        // When the inbound-sync ingestor is performing the insert, the source
        // org owns ActivatedDateTime__c — skip receiver-side auto-population so
        // the source's value (often null for non-active items) is preserved.
        Boolean skipAutoActivate = DeliveryTriggerControl.inboundSyncContext;
        for (WorkItem__c workItem : newWorkItems) {
            if (!skipAutoActivate && workItem.ActivatedDateTime__c == null) {
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