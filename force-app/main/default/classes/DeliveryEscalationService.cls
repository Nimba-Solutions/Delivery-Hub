/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  CMT-driven escalation engine that detects stalled work items and
 *               takes automated action. Queries WorkflowEscalationRule__mdt records,
 *               matches them against work items that have exceeded the configured
 *               days threshold in a given stage, and executes the appropriate action
 *               (email, Chatter, Slack, bump priority, move stage, or reassign).
 *               Supports severity levels (Warning at threshold, Critical at 2x threshold)
 *               and duplicate prevention via LastEscalatedDateTime__c.
 *               Called nightly by DeliveryEscalationJob or DeliveryHubScheduler.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount, PMD.ExcessiveParameterList')
public with sharing class DeliveryEscalationService {

    /** @description Priority escalation ladder: Low -> Medium -> High -> Critical */
    private static final Map<String, String> PRIORITY_BUMP_MAP = new Map<String, String>{
        'Low' => 'Medium',
        'Medium' => 'High',
        'High' => 'Critical'
    };

    /** @description Hours before re-escalating the same work item (24h default) */
    @TestVisible
    private static final Integer ESCALATION_COOLDOWN_HOURS = 24;

    // -------------------------------------------------------------------------
    // AuraEnabled — callable from LWC dashboard
    // -------------------------------------------------------------------------

    /**
     * @description Returns a list of work items currently in breach of escalation rules.
     *              Each entry includes workItemId, workItemName, ruleName, daysInStage,
     *              and severityLevel. Callable from LWC components.
     * @return List of EscalationSummary wrappers for items currently breaching SLA.
     */
    @AuraEnabled(cacheable=true)
    public static List<EscalationSummary> getEscalationSummary() {
        List<WorkflowEscalationRule__mdt> rules = queryActiveRules();
        return buildSummary(rules);
    }

    // -------------------------------------------------------------------------
    // Public entry points — called by schedulers and other Apex
    // -------------------------------------------------------------------------

    /**
     * @description Main entry point — queries active escalation rules from CMT and processes them.
     *              Designed to be called from DeliveryEscalationJob or DeliveryHubScheduler.
     */
    public static void evaluateRules() {
        List<WorkflowEscalationRule__mdt> rules = queryActiveRules();
        processRules(rules);
    }

    /**
     * @description Backward-compatible alias — delegates to evaluateRules().
     *              Retained so DeliveryHubScheduler continues to work without changes.
     */
    public static void processEscalations() {
        evaluateRules();
    }

    /**
     * @description Testable overload that accepts rules as a parameter.
     *              Evaluates each rule against matching work items and executes actions.
     * @param rules List of escalation rules to process
     */
    @TestVisible
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    static void processEscalations(List<WorkflowEscalationRule__mdt> rules) {
        processRules(rules);
    }

    // -------------------------------------------------------------------------
    // Core engine
    // -------------------------------------------------------------------------

    /**
     * @description Queries all active escalation rules from CMT, ordered by SortOrder.
     * @return List of active WorkflowEscalationRule__mdt records
     */
    private static List<WorkflowEscalationRule__mdt> queryActiveRules() {
        return [
            SELECT MasterLabel, WorkflowTypeTxt__c, TriggerStageTxt__c,
                   DaysThresholdNum__c, ActionTypePk__c, TargetValueTxt__c,
                   PriorityFilterTxt__c, NotifyFieldTxt__c, SeverityLevelPk__c,
                   IsActiveBool__c, SortOrderNum__c
            FROM WorkflowEscalationRule__mdt
            WHERE IsActiveBool__c = true
            WITH SYSTEM_MODE
            ORDER BY SortOrderNum__c ASC
        ];
    }

    /**
     * @description Core processing loop. Evaluates rules against candidate work items,
     *              respects severity thresholds and cooldown periods, then executes actions.
     * @param rules List of escalation rules to evaluate
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    private static void processRules(List<WorkflowEscalationRule__mdt> rules) {
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

        // Query all active work items in any of the trigger stages
        List<WorkItem__c> allCandidates = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   PriorityPk__c, OwnerId, Developer__c,
                   WorkflowTypeTxt__c, StageEnteredDateTime__c,
                   LastModifiedDate, LastEscalatedDateTime__c
            FROM WorkItem__c
            WHERE StageNamePk__c IN :triggerStages
            AND IsActiveBool__c = true
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

        // Track which work items need DML updates (Bump_Priority, Move_Stage, Reassign, LastEscalated)
        Map<Id, WorkItem__c> itemsToUpdate = new Map<Id, WorkItem__c>();
        // Track email notifications: workItemId -> EscalationDetail
        Map<Id, EscalationDetail> emailTargets = new Map<Id, EscalationDetail>();
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

            Integer threshold = rule.DaysThresholdNum__c != null
                ? rule.DaysThresholdNum__c.intValue() : 0;

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
                    if (hoursSinceLastEscalation < ESCALATION_COOLDOWN_HOURS) {
                        continue;
                    }
                }

                // Mark as escalated
                WorkItem__c toUpdate = itemsToUpdate.containsKey(wi.Id)
                    ? itemsToUpdate.get(wi.Id) : new WorkItem__c(Id = wi.Id);
                toUpdate.LastEscalatedDateTime__c = now;
                itemsToUpdate.put(wi.Id, toUpdate);

                // Execute the action
                executeAction(rule, wi, daysInStage, severity, itemsToUpdate,
                    emailTargets, chatterTargets, slackNotifications, logEntries);
            }
        }

        // Perform batched DML for field updates (includes LastEscalatedDateTime__c)
        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate.values(), AccessLevel.SYSTEM_MODE);
        }

        // Send batched email notifications
        if (!emailTargets.isEmpty()) {
            sendEscalationEmails(emailTargets);
        }

        // Post Chatter messages
        if (!chatterTargets.isEmpty()) {
            postChatterEscalations(chatterTargets);
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
     * @description Builds a summary of all items currently in breach of escalation rules,
     *              without executing any actions. Used by getEscalationSummary().
     * @param rules Active escalation rules
     * @return List of EscalationSummary wrappers
     */
    @TestVisible
    static List<EscalationSummary> buildSummary(List<WorkflowEscalationRule__mdt> rules) {
        List<EscalationSummary> results = new List<EscalationSummary>();

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
            AND IsActiveBool__c = true
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

            Integer threshold = rule.DaysThresholdNum__c != null
                ? rule.DaysThresholdNum__c.intValue() : 0;
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
                results.add(new EscalationSummary(
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

    // -------------------------------------------------------------------------
    // Action routing
    // -------------------------------------------------------------------------

    /**
     * @description Routes a single escalation action to the appropriate handler.
     * @param rule The escalation rule being applied
     * @param wi The work item being escalated
     * @param daysInStage Number of days the item has been in the current stage
     * @param severity The resolved severity level for this escalation
     * @param itemsToUpdate Accumulator for DML updates
     * @param emailTargets Accumulator for email notifications
     * @param chatterTargets Accumulator for Chatter posts
     * @param slackNotifications Accumulator for Slack notifications
     * @param logEntries Accumulator for activity log entries
     */
    @SuppressWarnings('PMD.ExcessiveParameterList, PMD.CyclomaticComplexity, PMD.NcssMethodCount')
    private static void executeAction(
        WorkflowEscalationRule__mdt rule,
        WorkItem__c wi,
        Integer daysInStage,
        String severity,
        Map<Id, WorkItem__c> itemsToUpdate,
        Map<Id, EscalationDetail> emailTargets,
        Map<Id, String> chatterTargets,
        Map<String, String> slackNotifications,
        List<ActivityLog__c> logEntries
    ) {
        String action = rule.ActionTypePk__c;
        String logContext = '{"rule":"' + String.valueOf(rule.MasterLabel).escapeJava()
            + '","action":"' + action
            + '","severity":"' + severity
            + '","daysInStage":' + daysInStage
            + ',"workItemId":"' + wi.Id
            + '","stage":"' + String.valueOf(wi.StageNamePk__c).escapeJava() + '"}';

        String chatterMsg = severity + ' ESCALATION: ' + wi.Name + ' has been in '
            + wi.StageNamePk__c + ' for ' + daysInStage + ' day(s). Rule: ' + rule.MasterLabel;

        // Handle the new simplified action types
        if (action == 'Email' || action == 'Email_Owner' || action == 'Email_Manager') {
            emailTargets.put(wi.Id, new EscalationDetail(
                wi.StageNamePk__c, severity, daysInStage, rule.MasterLabel));
        } else if (action == 'Chatter') {
            chatterTargets.put(wi.Id, chatterMsg);
        } else if (action == 'Both') {
            emailTargets.put(wi.Id, new EscalationDetail(
                wi.StageNamePk__c, severity, daysInStage, rule.MasterLabel));
            chatterTargets.put(wi.Id, chatterMsg);
        } else if (action == 'Slack_Alert') {
            slackNotifications.put(
                wi.Name,
                severity + ' ESCALATION: stalled in ' + wi.StageNamePk__c
                + ' for ' + daysInStage + ' day(s)'
            );
        } else if (action == 'Bump_Priority') {
            handleBumpPriority(wi, itemsToUpdate);
        } else if (action == 'Move_Stage') {
            handleMoveStage(wi, rule.TargetValueTxt__c, itemsToUpdate);
        } else if (action == 'Reassign') {
            handleReassign(wi, rule.TargetValueTxt__c, itemsToUpdate);
        }

        // Send bell notification to the work item owner (if opted in)
        String briefDesc = String.isNotBlank(wi.BriefDescriptionTxt__c)
            ? wi.BriefDescriptionTxt__c : wi.Name;
        sendBellNotification(
            wi.Id,
            wi.OwnerId,
            'Delivery Hub: Item Needs Attention',
            briefDesc + ' — ' + rule.MasterLabel
        );

        logEntries.add(new ActivityLog__c(
            ActionTypePk__c = 'Feature_Use',
            ComponentNameTxt__c = 'DeliveryEscalationService',
            ContextDataTxt__c = logContext
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
                '[DeliveryEscalationService] Invalid Reassign targetOwnerId: ' + targetOwnerId);
        }
    }

    // -------------------------------------------------------------------------
    // Notification handlers
    // -------------------------------------------------------------------------

    /**
     * @description Sends escalation email notifications for stalled work items.
     *              Includes severity level and days-in-stage details in the email.
     * @param escalationDetails Map of WorkItem Id -> EscalationDetail
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    private static void sendEscalationEmails(Map<Id, EscalationDetail> escalationDetails) {
        // Query work items for email context
        List<WorkItem__c> workItems = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   Developer__c, OwnerId
            FROM WorkItem__c
            WHERE Id IN :escalationDetails.keySet()
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

            EscalationDetail detail = escalationDetails.get(wi.Id);
            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Work Item';
            String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view';
            String severityPrefix = detail.severity == 'Critical' ? 'CRITICAL ' : '';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject(severityPrefix + 'Delivery Hub Escalation: '
                + wi.Name + ' stalled in ' + detail.stalledStage
                + ' (' + detail.daysInStage + ' days)');
            email.setHtmlBody(buildEscalationHtml(
                wi.Name, title, detail.stalledStage, recordUrl,
                detail.severity, detail.daysInStage, detail.ruleName));
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
     * @description Posts Chatter feed items on escalated work items.
     * @param workItemIdToMessage Map of work item Id -> Chatter message body
     */
    private static void postChatterEscalations(Map<Id, String> workItemIdToMessage) {
        List<FeedItem> posts = new List<FeedItem>();
        for (Id wiId : workItemIdToMessage.keySet()) {
            FeedItem post = new FeedItem();
            post.ParentId = wiId;
            post.Body = workItemIdToMessage.get(wiId);
            posts.add(post);
        }
        if (!posts.isEmpty()) {
            try {
                Database.insert(posts, AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryEscalationService] Chatter post failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Posts escalation alerts to Slack for stalled work items.
     * @param workItemNameToMessage Map of work item Name -> escalation message
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
     * @description Sends a Salesforce bell notification to the work item owner if they have
     *              EnableBellNotificationsDateTime__c != null in their user-level DeliveryHubSettings.
     *              Uses the Delivery_Hub_Alert custom notification type.
     * @param workItemId The WorkItem__c Id to link the notification to.
     * @param ownerId The User Id to notify.
     * @param title Short notification title.
     * @param body Notification body text.
     */
    private static void sendBellNotification(Id workItemId, Id ownerId, String title, String body) {
        try {
            // Check user-level setting (hierarchy: user > profile > org)
            DeliveryHubSettings__c userSettings = DeliveryHubSettings__c.getInstance(ownerId);
            if (userSettings == null || userSettings.EnableBellNotificationsDateTime__c == null) {
                return; // User hasn't opted in
            }

            // Look up the custom notification type
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Delivery_Hub_Alert'
                LIMIT 1
            ];
            if (types.isEmpty()) {
                return; // Notification type not deployed
            }

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(types[0].Id);
            notification.setTargetId(workItemId);
            notification.send(new Set<String>{ ownerId });
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Bell notification failed: ' + e.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // Utility methods
    // -------------------------------------------------------------------------

    /**
     * @description Calculates how many days a work item has been in its current stage.
     *              Prefers StageEnteredDateTime__c; falls back to LastModifiedDate.
     * @param wi The work item to check
     * @param today Reference date for calculation
     * @return Number of days in current stage
     */
    @TestVisible
    private static Integer calculateDaysInStage(WorkItem__c wi, Date today) {
        if (wi.StageEnteredDateTime__c != null) {
            return wi.StageEnteredDateTime__c.date().daysBetween(today);
        }
        // Fallback for items that predate StageEnteredDateTime__c
        return wi.LastModifiedDate.date().daysBetween(today);
    }

    /**
     * @description Builds an HTML email body for an escalation notification with severity.
     * @param workItemName The work item auto-number name (e.g. WI-0042)
     * @param title The work item brief description
     * @param stalledStage The stage the item has been stuck in
     * @param recordUrl Deep link to the record in Salesforce
     * @param severity Warning or Critical
     * @param daysInStage Number of days stalled
     * @param ruleName Name of the escalation rule that triggered
     * @return HTML string
     */
    @TestVisible
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl, String severity,
        Integer daysInStage, String ruleName) {
        String headerColor = severity == 'Critical' ? '#ba1b1b' : '#e67e22';
        String severityLabel = severity == 'Critical' ? 'CRITICAL Escalation Alert' : 'Escalation Alert';

        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: ' + headerColor + ';">Delivery Hub ' + String.valueOf(severityLabel).escapeHtml4() + '</h2>'
            + '<p><strong>' + String.valueOf(workItemName).escapeHtml4() + '</strong>: '
            + String.valueOf(title).escapeHtml4() + '</p>'
            + '<p>This work item has been stalled in <strong>'
            + String.valueOf(stalledStage).escapeHtml4()
            + '</strong> for <strong>' + daysInStage + ' day(s)</strong> and requires attention.</p>'
            + '<p style="font-size: 0.9em; color: #555;">Escalation rule: '
            + String.valueOf(ruleName).escapeHtml4()
            + ' | Severity: ' + String.valueOf(severity).escapeHtml4() + '</p>'
            + '<p><a href="' + recordUrl + '" style="color: #0176d3;">View in Salesforce</a></p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">This is an automated escalation '
            + 'from Delivery Hub. To adjust escalation rules, update the '
            + 'Workflow Escalation Rule custom metadata in Setup.</p>'
            + '</div>';
    }

    /**
     * @description Overload for backward compatibility — calls the severity-aware version.
     * @param workItemName The work item name
     * @param title The work item description
     * @param stalledStage The stalled stage
     * @param recordUrl Record URL
     * @return HTML string
     */
    @TestVisible
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl) {
        return buildEscalationHtml(workItemName, title, stalledStage, recordUrl,
            'Warning', 0, 'Unknown');
    }

    // -------------------------------------------------------------------------
    // Inner classes
    // -------------------------------------------------------------------------

    /**
     * @description Wrapper returned by getEscalationSummary() for LWC consumption.
     */
    public class EscalationSummary {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String workItemName;
        @AuraEnabled public String ruleName;
        @AuraEnabled public Integer daysInStage;
        @AuraEnabled public String severityLevel;
        @AuraEnabled public String stageName;
        @AuraEnabled public String priority;

        /**
         * @description Constructor for EscalationSummary.
         * @param workItemId Work item record Id
         * @param workItemName Work item auto-number name
         * @param ruleName Label of the matched escalation rule
         * @param daysInStage Number of days in the current stage
         * @param severityLevel Warning or Critical
         * @param stageName Current stage API value
         * @param priority Current priority
         */
        @SuppressWarnings('PMD.ExcessiveParameterList')
        public EscalationSummary(Id workItemId, String workItemName, String ruleName,
            Integer daysInStage, String severityLevel, String stageName, String priority) {
            this.workItemId = workItemId;
            this.workItemName = workItemName;
            this.ruleName = ruleName;
            this.daysInStage = daysInStage;
            this.severityLevel = severityLevel;
            this.stageName = stageName;
            this.priority = priority;
        }
    }

    /**
     * @description Internal detail object for batching email notifications with context.
     */
    private class EscalationDetail {
        String stalledStage;
        String severity;
        Integer daysInStage;
        String ruleName;

        EscalationDetail(String stalledStage, String severity,
            Integer daysInStage, String ruleName) {
            this.stalledStage = stalledStage;
            this.severity = severity;
            this.daysInStage = daysInStage;
            this.ruleName = ruleName;
        }
    }
}
