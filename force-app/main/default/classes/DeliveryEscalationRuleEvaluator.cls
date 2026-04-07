/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Rule matching and evaluation logic extracted from DeliveryEscalationService.
 *               Queries candidate work items, builds stage-to-item lookups, evaluates each
 *               rule's filters and thresholds, checks cooldowns, and delegates action
 *               execution to DeliveryEscalationActionExecutor.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public with sharing class DeliveryEscalationRuleEvaluator {

    /**
     * @description Queries all active escalation rules from CMT, ordered by SortOrder.
     * @return List of active WorkflowEscalationRule__mdt records
     */
    public static List<WorkflowEscalationRule__mdt> queryActiveRules() {
        return [
            SELECT MasterLabel, WorkflowTypeTxt__c, TriggerStageTxt__c,
                   DaysThresholdNumber__c, ActionTypePk__c, TargetValueTxt__c,
                   PriorityFilterTxt__c, NotifyFieldTxt__c, SeverityLevelPk__c,
                   ActiveDateTime__c, SortOrderNumber__c, RequireNoResponseDateTime__c
            FROM WorkflowEscalationRule__mdt
            WHERE ActiveDateTime__c != null
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC
        ];
    }

    /**
     * @description Core processing loop. Evaluates rules against candidate work items,
     *              respects severity thresholds and cooldown periods, then executes actions.
     * @param rules List of escalation rules to evaluate
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    public static void processRules(List<WorkflowEscalationRule__mdt> rules) {
        if (rules == null || rules.isEmpty()) {
            return;
        }

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        Integer cooldownHours = settings != null && settings.EscalationCooldownHoursNumber__c != null
            ? (Integer) settings.EscalationCooldownHoursNumber__c : 24;

        // Collect all trigger stages to build a single SOQL query
        Set<String> triggerStages = new Set<String>();
        for (WorkflowEscalationRule__mdt rule : rules) {
            if (String.isNotBlank(rule.TriggerStageTxt__c)) {
                triggerStages.add(rule.TriggerStageTxt__c);
            }
        }

        if (triggerStages.isEmpty()) {
            return;
        }

        // Query all active work items in any of the trigger stages
        List<WorkItem__c> allCandidates = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   PriorityPk__c, OwnerId, DeveloperLookup__c, CreatedById,
                   WorkflowTypeTxt__c, StageEnteredDateTime__c,
                   LastModifiedDate, LastEscalatedDateTime__c
            FROM WorkItem__c
            WHERE StageNamePk__c IN :triggerStages
            AND ActivatedDateTime__c != null
            WITH SYSTEM_MODE
        ];

        if (allCandidates.isEmpty()) {
            return;
        }

        // Build a lookup: stage -> list of work items
        Map<String, List<WorkItem__c>> stageToItems = new Map<String, List<WorkItem__c>>();
        for (WorkItem__c wi : allCandidates) {
            String stage = wi.StageNamePk__c;
            if (!stageToItems.containsKey(stage)) {
                stageToItems.put(stage, new List<WorkItem__c>());
            }
            stageToItems.get(stage).add(wi);
        }

        // Pre-compute "has response" for no-response rules: work items where
        // someone OTHER than the creator has commented
        Boolean anyNoResponseRules = false;
        for (WorkflowEscalationRule__mdt rule : rules) {
            if (rule.RequireNoResponseDateTime__c != null) {
                anyNoResponseRules = true;
                break;
            }
        }
        Set<Id> workItemsWithResponse = new Set<Id>();
        if (anyNoResponseRules && !allCandidates.isEmpty()) {
            Map<Id, Id> candidateCreators = new Map<Id, Id>();
            for (WorkItem__c wi : allCandidates) {
                candidateCreators.put(wi.Id, wi.CreatedById);
            }
            for (WorkItemComment__c c : [
                SELECT WorkItemLookup__c, CreatedById
                FROM WorkItemComment__c
                WHERE WorkItemLookup__c IN :candidateCreators.keySet()
                WITH SYSTEM_MODE
            ]) {
                Id creator = candidateCreators.get(c.WorkItemLookup__c);
                if (creator != null && c.CreatedById != creator) {
                    workItemsWithResponse.add(c.WorkItemLookup__c);
                }
            }
        }

        // Track which work items need DML updates (Bump_Priority, Move_Stage, Reassign, LastEscalated)
        Map<Id, WorkItem__c> itemsToUpdate = new Map<Id, WorkItem__c>();
        // Track email notifications: workItemId -> EscalationDetail
        Map<Id, DeliveryEscalationService.EscalationDetail> emailTargets =
            new Map<Id, DeliveryEscalationService.EscalationDetail>();
        // Track Chatter post targets: workItemId -> message
        Map<Id, String> chatterTargets = new Map<Id, String>();
        // Track Slack notifications to batch
        Map<String, String> slackNotifications = new Map<String, String>();
        // Track activity log entries
        List<ActivityLog__c> logEntries = new List<ActivityLog__c>();

        DateTime now = DateTime.now();
        Date today = Date.today();

        for (WorkflowEscalationRule__mdt rule : rules) {
            List<WorkItem__c> candidates = stageToItems.get(rule.TriggerStageTxt__c);
            if (candidates == null || candidates.isEmpty()) {
                continue;
            }

            Integer threshold = rule.DaysThresholdNumber__c != null
                ? rule.DaysThresholdNumber__c.intValue() : 0;

            // Severity: Critical rules fire at 2x threshold, Warning at 1x
            String severity = String.isNotBlank(rule.SeverityLevelPk__c)
                ? rule.SeverityLevelPk__c : 'Warning';

            for (WorkItem__c wi : candidates) {
                // Check workflow type filter
                if (String.isNotBlank(rule.WorkflowTypeTxt__c)
                    && rule.WorkflowTypeTxt__c != wi.WorkflowTypeTxt__c) {
                    continue;
                }

                // Check priority filter
                if (String.isNotBlank(rule.PriorityFilterTxt__c)
                    && rule.PriorityFilterTxt__c != wi.PriorityPk__c) {
                    continue;
                }

                // Calculate days in stage using StageEnteredDateTime__c (preferred)
                // or fall back to LastModifiedDate
                Integer daysInStage = calculateDaysInStage(wi, today);

                // Determine effective threshold based on severity
                Integer effectiveThreshold = threshold;
                if (severity == 'Critical') {
                    effectiveThreshold = threshold; // Critical fires at configured threshold
                }
                // Warning fires at configured threshold too — severity just affects notification tone

                if (daysInStage < effectiveThreshold) {
                    continue;
                }

                // Check cooldown — skip if already escalated within the cooldown window
                if (wi.LastEscalatedDateTime__c != null) {
                    Long hoursSinceLastEscalation = (now.getTime()
                        - wi.LastEscalatedDateTime__c.getTime()) / (1000 * 60 * 60);
                    if (hoursSinceLastEscalation < cooldownHours) {
                        continue;
                    }
                }

                // No-response check — skip if rule requires no response but someone responded
                if (rule.RequireNoResponseDateTime__c != null
                    && workItemsWithResponse.contains(wi.Id)) {
                    continue;
                }

                // Mark as escalated
                WorkItem__c toUpdate = itemsToUpdate.containsKey(wi.Id)
                    ? itemsToUpdate.get(wi.Id) : new WorkItem__c(Id = wi.Id);
                toUpdate.LastEscalatedDateTime__c = now;
                itemsToUpdate.put(wi.Id, toUpdate);

                // Execute the action
                DeliveryEscalationContext ctx = new DeliveryEscalationContext(
                    rule, wi, daysInStage, severity,
                    itemsToUpdate, emailTargets, chatterTargets,
                    slackNotifications, logEntries
                );
                DeliveryEscalationActionExecutor.executeAction(ctx);
            }
        }

        // Perform batched DML for field updates (includes LastEscalatedDateTime__c)
        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate.values(), AccessLevel.SYSTEM_MODE);
        }

        // Send batched email notifications
        if (!emailTargets.isEmpty()) {
            DeliveryEscalationNotifService.sendEscalationEmails(emailTargets);
            DeliveryExternalNotificationService.sendExternalSLABreachEmails(emailTargets.keySet());
        }

        // Post Chatter messages
        if (!chatterTargets.isEmpty()) {
            DeliveryEscalationNotifService.postChatterEscalations(chatterTargets);
        }

        // Send batched Slack notifications
        if (!slackNotifications.isEmpty()) {
            DeliveryEscalationNotifService.sendEscalationSlack(slackNotifications);
        }

        // Log escalation activity
        if (!logEntries.isEmpty()) {
            Database.insert(logEntries, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Builds a summary of all items currently in breach of escalation rules,
     *              without executing any actions. Used by getEscalationSummary().
     * @param rules Active escalation rules
     * @return List of EscalationSummary wrappers
     */
    public static List<DeliveryEscalationService.EscalationSummary> buildSummary(
        List<WorkflowEscalationRule__mdt> rules
    ) {
        List<DeliveryEscalationService.EscalationSummary> results =
            new List<DeliveryEscalationService.EscalationSummary>();

        if (rules == null || rules.isEmpty()) {
            return results;
        }

        Set<String> triggerStages = new Set<String>();
        for (WorkflowEscalationRule__mdt rule : rules) {
            if (String.isNotBlank(rule.TriggerStageTxt__c)) {
                triggerStages.add(rule.TriggerStageTxt__c);
            }
        }

        if (triggerStages.isEmpty()) {
            return results;
        }

        List<WorkItem__c> allCandidates = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   PriorityPk__c, WorkflowTypeTxt__c,
                   StageEnteredDateTime__c, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :triggerStages
            AND ActivatedDateTime__c != null
            WITH SYSTEM_MODE
        ];

        if (allCandidates.isEmpty()) {
            return results;
        }

        Map<String, List<WorkItem__c>> stageToItems = new Map<String, List<WorkItem__c>>();
        for (WorkItem__c wi : allCandidates) {
            String stage = wi.StageNamePk__c;
            if (!stageToItems.containsKey(stage)) {
                stageToItems.put(stage, new List<WorkItem__c>());
            }
            stageToItems.get(stage).add(wi);
        }

        Date today = Date.today();
        // Track items already added to avoid duplicates across rules
        Set<Id> seenItems = new Set<Id>();

        for (WorkflowEscalationRule__mdt rule : rules) {
            List<WorkItem__c> candidates = stageToItems.get(rule.TriggerStageTxt__c);
            if (candidates == null || candidates.isEmpty()) {
                continue;
            }

            Integer threshold = rule.DaysThresholdNumber__c != null
                ? rule.DaysThresholdNumber__c.intValue() : 0;
            String severity = String.isNotBlank(rule.SeverityLevelPk__c)
                ? rule.SeverityLevelPk__c : 'Warning';

            for (WorkItem__c wi : candidates) {
                if (seenItems.contains(wi.Id)) {
                    continue;
                }

                if (String.isNotBlank(rule.WorkflowTypeTxt__c)
                    && rule.WorkflowTypeTxt__c != wi.WorkflowTypeTxt__c) {
                    continue;
                }

                if (String.isNotBlank(rule.PriorityFilterTxt__c)
                    && rule.PriorityFilterTxt__c != wi.PriorityPk__c) {
                    continue;
                }

                Integer daysInStage = calculateDaysInStage(wi, today);
                if (daysInStage < threshold) {
                    continue;
                }

                seenItems.add(wi.Id);
                results.add(new DeliveryEscalationService.EscalationSummary(
                    wi.Id,
                    wi.Name,
                    rule.MasterLabel,
                    daysInStage,
                    severity,
                    wi.StageNamePk__c,
                    wi.PriorityPk__c
                ));
            }
        }

        return results;
    }

    /**
     * @description Calculates how many days a work item has been in its current stage.
     *              Prefers StageEnteredDateTime__c; falls back to LastModifiedDate.
     * @param wi The work item to check
     * @param today Reference date for calculation
     * @return Number of days in current stage
     */
    public static Integer calculateDaysInStage(WorkItem__c wi, Date today) {
        if (wi.StageEnteredDateTime__c != null) {
            return wi.StageEnteredDateTime__c.date().daysBetween(today);
        }
        // Fallback for items that predate StageEnteredDateTime__c
        return wi.LastModifiedDate.date().daysBetween(today);
    }
}
