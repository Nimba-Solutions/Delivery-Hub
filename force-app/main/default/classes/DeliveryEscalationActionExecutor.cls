/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Action execution logic extracted from DeliveryEscalationService.
 *               Routes each escalation action to the appropriate handler based on
 *               ActionTypePk__c (Email, Chatter, Both, Slack_Alert, Bump_Priority,
 *               Move_Stage, Reassign). Uses a strategy-like dispatch pattern.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryEscalationActionExecutor {

    /** @description Priority escalation ladder: Low -> Medium -> High -> Critical */
    private static final Map<String, String> PRIORITY_BUMP_MAP = new Map<String, String>{
        'Low' => 'Medium',
        'Medium' => 'High',
        'High' => 'Critical'
    };

    /**
     * @description Routes a single escalation action to the appropriate handler.
     *              Populates the context's accumulator collections and publishes a
     *              platform event for external subscribers.
     * @param ctx The escalation context containing rule, work item, and accumulators
     */
    @SuppressWarnings('PMD.CyclomaticComplexity')
    public static void executeAction(DeliveryEscalationContext ctx) {
        WorkflowEscalationRule__mdt rule = ctx.rule;
        WorkItem__c wi = ctx.workItem;
        String action = rule.ActionTypePk__c;

        String logContext = '{"rule":"' + String.valueOf(rule.MasterLabel).escapeJava()
            + '","action":"' + action
            + '","severity":"' + ctx.severity
            + '","daysInStage":' + ctx.daysInStage
            + ',"workItemId":"' + wi.Id
            + '","stage":"' + String.valueOf(wi.StageNamePk__c).escapeJava() + '"}';

        String chatterMsg = ctx.severity + ' ESCALATION: ' + wi.Name + ' has been in '
            + wi.StageNamePk__c + ' for ' + ctx.daysInStage + ' day(s). Rule: ' + rule.MasterLabel;

        // Handle the new simplified action types
        if (action == 'Email' || action == 'Email_Owner' || action == 'Email_Manager') {
            ctx.emailTargets.put(wi.Id, new DeliveryEscalationService.EscalationDetail(
                wi.StageNamePk__c, ctx.severity, ctx.daysInStage, rule.MasterLabel));
        } else if (action == 'Chatter') {
            ctx.chatterTargets.put(wi.Id, chatterMsg);
        } else if (action == 'Both') {
            ctx.emailTargets.put(wi.Id, new DeliveryEscalationService.EscalationDetail(
                wi.StageNamePk__c, ctx.severity, ctx.daysInStage, rule.MasterLabel));
            ctx.chatterTargets.put(wi.Id, chatterMsg);
        } else if (action == 'Slack_Alert') {
            ctx.slackNotifications.put(
                wi.Name,
                ctx.severity + ' ESCALATION: stalled in ' + wi.StageNamePk__c
                + ' for ' + ctx.daysInStage + ' day(s)'
            );
        } else if (action == 'Bump_Priority') {
            handleBumpPriority(wi, ctx.itemsToUpdate);
        } else if (action == 'Move_Stage') {
            handleMoveStage(wi, rule.TargetValueTxt__c, ctx.itemsToUpdate);
        } else if (action == 'Reassign') {
            handleReassign(wi, rule.TargetValueTxt__c, ctx.itemsToUpdate);
        }

        // Send bell notification to the work item owner (if opted in)
        String briefDesc = String.isNotBlank(wi.BriefDescriptionTxt__c)
            ? wi.BriefDescriptionTxt__c : wi.Name;
        DeliveryEscalationNotifService.sendBellNotification(
            wi.Id,
            wi.OwnerId,
            'Delivery Hub: Item Needs Attention',
            briefDesc + ' — ' + rule.MasterLabel
        );

        ctx.logEntries.add(new ActivityLog__c(
            ActionTypePk__c = 'Feature_Use',
            ComponentNameTxt__c = 'DeliveryEscalationService',
            ContextDataTxt__c = logContext
        ));

        // Publish platform event for external subscribers
        EventBus.publish(new DeliveryEscalation__e(
            WorkItemIdTxt__c = wi.Id,
            RuleNameTxt__c = rule.MasterLabel,
            ActionTypePk__c = action,
            SeverityPk__c = ctx.severity,
            DaysInStageNumber__c = ctx.daysInStage
        ));
    }

    // -------------------------------------------------------------------------
    // Field-update action handlers
    // -------------------------------------------------------------------------

    /**
     * @description Bumps the work item's priority one level up the escalation ladder.
     *              Critical items are not bumped further.
     * @param wi The work item to bump
     * @param itemsToUpdate Accumulator for DML updates
     */
    private static void handleBumpPriority(WorkItem__c wi, Map<Id, WorkItem__c> itemsToUpdate) {
        String currentPriority = wi.PriorityPk__c;
        String newPriority = PRIORITY_BUMP_MAP.get(currentPriority);
        if (newPriority == null) {
            // Already Critical or unknown — nothing to bump
            return;
        }
        WorkItem__c toUpdate = itemsToUpdate.containsKey(wi.Id)
            ? itemsToUpdate.get(wi.Id) : new WorkItem__c(Id = wi.Id);
        toUpdate.PriorityPk__c = newPriority;
        itemsToUpdate.put(wi.Id, toUpdate);
    }

    /**
     * @description Moves the work item to a new stage specified by the rule's TargetValueTxt__c.
     * @param wi The work item to move
     * @param targetStage The stage to move to
     * @param itemsToUpdate Accumulator for DML updates
     */
    private static void handleMoveStage(WorkItem__c wi, String targetStage,
        Map<Id, WorkItem__c> itemsToUpdate) {
        if (String.isBlank(targetStage)) {
            return;
        }
        WorkItem__c toUpdate = itemsToUpdate.containsKey(wi.Id)
            ? itemsToUpdate.get(wi.Id) : new WorkItem__c(Id = wi.Id);
        toUpdate.StageNamePk__c = targetStage;
        itemsToUpdate.put(wi.Id, toUpdate);
    }

    /**
     * @description Reassigns the work item's owner to the user/queue specified by TargetValueTxt__c.
     *              Expects a valid 15 or 18-character Salesforce Id.
     * @param wi The work item to reassign
     * @param targetOwnerId The new owner Id
     * @param itemsToUpdate Accumulator for DML updates
     */
    private static void handleReassign(WorkItem__c wi, String targetOwnerId,
        Map<Id, WorkItem__c> itemsToUpdate) {
        if (String.isBlank(targetOwnerId)) {
            return;
        }
        try {
            Id newOwnerId = Id.valueOf(targetOwnerId.trim());
            WorkItem__c toUpdate = itemsToUpdate.containsKey(wi.Id)
                ? itemsToUpdate.get(wi.Id) : new WorkItem__c(Id = wi.Id);
            toUpdate.OwnerId = newOwnerId;
            itemsToUpdate.put(wi.Id, toUpdate);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryEscalationActionExecutor] Invalid Reassign targetOwnerId: ' + targetOwnerId);
        }
    }
}
