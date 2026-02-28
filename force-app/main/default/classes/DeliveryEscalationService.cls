/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  CMT-driven escalation engine that detects stalled work items and
 *               takes automated action. Queries WorkflowEscalationRule__mdt records,
 *               matches them against work items that have exceeded the configured
 *               days threshold in a given stage, and executes the appropriate action
 *               (email, Slack, bump priority, move stage, or reassign).
 *               Called nightly by DeliveryHubScheduler.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryEscalationService {

    /** @description Priority escalation ladder: Low → Medium → High → Critical */
    private static final Map<String, String> PRIORITY_BUMP_MAP = new Map<String, String>{
        'Low' => 'Medium',
        'Medium' => 'High',
        'High' => 'Critical'
    };

    /**
     * @description Main entry point — queries active escalation rules from CMT and processes them.
     *              Designed to be called from a Schedulable context (DeliveryHubScheduler).
     */
    public static void processEscalations() {
        List<WorkflowEscalationRule__mdt> rules = [
            SELECT MasterLabel, WorkflowTypeTxt__c, TriggerStageTxt__c,
                   DaysThresholdNum__c, ActionTypePk__c, TargetValueTxt__c,
                   PriorityFilterTxt__c, IsActiveBool__c, SortOrderNum__c
            FROM WorkflowEscalationRule__mdt
            WHERE IsActiveBool__c = true
            WITH SYSTEM_MODE
            ORDER BY SortOrderNum__c ASC
        ];
        processEscalations(rules);
    }

    /**
     * @description Testable overload that accepts rules as a parameter.
     *              Evaluates each rule against matching work items and executes actions.
     * @param rules List of escalation rules to process
     */
    @TestVisible
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    static void processEscalations(List<WorkflowEscalationRule__mdt> rules) {
        if (rules == null || rules.isEmpty()) {
            return;
        }

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

        // Query all work items in any of the trigger stages
        List<WorkItem__c> allCandidates = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   PriorityPk__c, OwnerId, Developer__c,
                   WorkflowTypeTxt__c, LastModifiedDate
            FROM WorkItem__c
            WHERE StageNamePk__c IN :triggerStages
            WITH SYSTEM_MODE
        ];

        if (allCandidates.isEmpty()) {
            return;
        }

        // Build a lookup: stage → list of work items
        Map<String, List<WorkItem__c>> stageToItems = new Map<String, List<WorkItem__c>>();
        for (WorkItem__c wi : allCandidates) {
            String stage = wi.StageNamePk__c;
            if (!stageToItems.containsKey(stage)) {
                stageToItems.put(stage, new List<WorkItem__c>());
            }
            stageToItems.get(stage).add(wi);
        }

        // Track which work items need DML updates (Bump_Priority, Move_Stage, Reassign)
        Map<Id, WorkItem__c> itemsToUpdate = new Map<Id, WorkItem__c>();
        // Track email notifications to batch
        Map<Id, String> emailOwnerTargets = new Map<Id, String>();
        // Track Slack notifications to batch
        Map<String, String> slackNotifications = new Map<String, String>();
        // Track activity log entries
        List<ActivityLog__c> logEntries = new List<ActivityLog__c>();

        Date today = Date.today();

        for (WorkflowEscalationRule__mdt rule : rules) {
            List<WorkItem__c> candidates = stageToItems.get(rule.TriggerStageTxt__c);
            if (candidates == null || candidates.isEmpty()) {
                continue;
            }

            Integer threshold = rule.DaysThresholdNum__c != null
                ? rule.DaysThresholdNum__c.intValue() : 0;

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

                // Check staleness threshold
                Integer daysStalled = wi.LastModifiedDate.date().daysBetween(today);
                if (daysStalled < threshold) {
                    continue;
                }

                // Execute the action
                executeAction(rule, wi, itemsToUpdate, emailOwnerTargets,
                    slackNotifications, logEntries);
            }
        }

        // Perform batched DML for field updates
        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate.values(), AccessLevel.SYSTEM_MODE);
        }

        // Send batched email notifications
        if (!emailOwnerTargets.isEmpty()) {
            sendEscalationEmails(emailOwnerTargets);
        }

        // Send batched Slack notifications
        if (!slackNotifications.isEmpty()) {
            sendEscalationSlack(slackNotifications);
        }

        // Log escalation activity
        if (!logEntries.isEmpty()) {
            Database.insert(logEntries, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Routes a single escalation action to the appropriate handler.
     * @param rule The escalation rule being applied
     * @param wi The work item being escalated
     * @param itemsToUpdate Accumulator for DML updates
     * @param emailOwnerTargets Accumulator for email notifications
     * @param slackNotifications Accumulator for Slack notifications
     * @param logEntries Accumulator for activity log entries
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void executeAction(
        WorkflowEscalationRule__mdt rule,
        WorkItem__c wi,
        Map<Id, WorkItem__c> itemsToUpdate,
        Map<Id, String> emailOwnerTargets,
        Map<String, String> slackNotifications,
        List<ActivityLog__c> logEntries
    ) {
        String action = rule.ActionTypePk__c;
        String logContext = '{"rule":"' + String.valueOf(rule.MasterLabel).escapeJava()
            + '","action":"' + action
            + '","workItemId":"' + wi.Id
            + '","stage":"' + String.valueOf(wi.StageNamePk__c).escapeJava() + '"}';

        if (action == 'Email_Owner') {
            emailOwnerTargets.put(wi.Id, wi.StageNamePk__c);
        } else if (action == 'Email_Manager') {
            // For Email_Manager, we also send to the owner — in a real implementation
            // this would look up the owner's manager. For now, send to owner.
            emailOwnerTargets.put(wi.Id, wi.StageNamePk__c);
        } else if (action == 'Slack_Alert') {
            slackNotifications.put(
                wi.Name,
                'ESCALATION: stalled in ' + wi.StageNamePk__c
            );
        } else if (action == 'Bump_Priority') {
            handleBumpPriority(wi, itemsToUpdate);
        } else if (action == 'Move_Stage') {
            handleMoveStage(wi, rule.TargetValueTxt__c, itemsToUpdate);
        } else if (action == 'Reassign') {
            handleReassign(wi, rule.TargetValueTxt__c, itemsToUpdate);
        }

        logEntries.add(new ActivityLog__c(
            ActionTypePk__c = 'Feature_Use',
            ComponentNameTxt__c = 'DeliveryEscalationService',
            ContextDataTxt__c = logContext
        ));
    }

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
                '[DeliveryEscalationService] Invalid Reassign targetOwnerId: ' + targetOwnerId);
        }
    }

    /**
     * @description Sends escalation email notifications for stalled work items.
     *              Leverages the same email infrastructure as stage-change notifications.
     * @param workItemIdToStage Map of WorkItem Id → current stalled stage
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    private static void sendEscalationEmails(Map<Id, String> workItemIdToStage) {
        // Build escalation-specific stage labels to indicate this is an escalation
        Map<Id, String> escalationStageMap = new Map<Id, String>();
        for (Id wiId : workItemIdToStage.keySet()) {
            escalationStageMap.put(wiId,
                workItemIdToStage.get(wiId) + ' (Escalation: stalled)');
        }

        // Query work items for email context
        List<WorkItem__c> workItems = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   Developer__c, OwnerId
            FROM WorkItem__c
            WHERE Id IN :workItemIdToStage.keySet()
            WITH SYSTEM_MODE
        ];

        if (workItems.isEmpty()) {
            return;
        }

        // Collect recipient user Ids
        Set<Id> recipientIds = new Set<Id>();
        for (WorkItem__c wi : workItems) {
            if (wi.Developer__c != null) {
                recipientIds.add(wi.Developer__c);
            }
            if (wi.OwnerId != null && String.valueOf(wi.OwnerId).startsWith('005')) {
                recipientIds.add(wi.OwnerId);
            }
        }

        if (recipientIds.isEmpty()) {
            return;
        }

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Email FROM User
            WHERE Id IN :recipientIds AND IsActive = true
            WITH SYSTEM_MODE
        ]);

        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (WorkItem__c wi : workItems) {
            List<String> toAddresses = new List<String>();
            if (wi.Developer__c != null && userMap.containsKey(wi.Developer__c)) {
                toAddresses.add(userMap.get(wi.Developer__c).Email);
            }
            if (wi.OwnerId != null && userMap.containsKey(wi.OwnerId)) {
                String ownerEmail = userMap.get(wi.OwnerId).Email;
                if (!toAddresses.contains(ownerEmail)) {
                    toAddresses.add(ownerEmail);
                }
            }
            if (toAddresses.isEmpty()) {
                continue;
            }

            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Work Item';
            String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view';
            String stalledStage = workItemIdToStage.get(wi.Id);

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject('Delivery Hub Escalation: ' + wi.Name + ' stalled in ' + stalledStage);
            email.setHtmlBody(buildEscalationHtml(wi.Name, title, stalledStage, recordUrl));
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryEscalationService] email send failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Posts escalation alerts to Slack for stalled work items.
     * @param workItemNameToMessage Map of work item Name → escalation message
     */
    private static void sendEscalationSlack(Map<String, String> workItemNameToMessage) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrl__c)) {
            return;
        }

        List<String> lines = new List<String>();
        for (String name : workItemNameToMessage.keySet()) {
            lines.add('\u2022 *' + name + '* \u2014 ' + workItemNameToMessage.get(name));
        }
        String text = ':rotating_light: *Delivery Hub Escalation*\n' + String.join(lines, '\n');

        String payload = JSON.serialize(new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => text
                    }
                }
            }
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.SlackWebhookUrl__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        req.setTimeout(10000);
        try {
            new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryEscalationService] Slack callout failed: ' + e.getMessage());
        }
    }

    /**
     * @description Builds an HTML email body for an escalation notification.
     * @param workItemName The work item auto-number name (e.g. WI-0042)
     * @param title The work item brief description
     * @param stalledStage The stage the item has been stuck in
     * @param recordUrl Deep link to the record in Salesforce
     * @return HTML string
     */
    @TestVisible
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl) {
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #ba1b1b;">Delivery Hub — Escalation Alert</h2>'
            + '<p><strong>' + String.valueOf(workItemName).escapeHtml4() + '</strong>: '
            + String.valueOf(title).escapeHtml4() + '</p>'
            + '<p>This work item has been stalled in <strong>'
            + String.valueOf(stalledStage).escapeHtml4()
            + '</strong> and requires attention.</p>'
            + '<p><a href="' + recordUrl + '" style="color: #0176d3;">View in Salesforce</a></p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">This is an automated escalation '
            + 'from Delivery Hub. To adjust escalation rules, update the '
            + 'Workflow Escalation Rule custom metadata in Setup.</p>'
            + '</div>';
    }
}
