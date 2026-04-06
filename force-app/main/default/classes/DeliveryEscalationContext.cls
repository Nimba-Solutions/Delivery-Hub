/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Wrapper class that replaces the 9-parameter executeAction signature
 *               on DeliveryEscalationService. Bundles the rule, work item, and all
 *               accumulator collections into a single object that flows through the
 *               escalation pipeline.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryEscalationContext {

    /** @description The escalation rule currently being evaluated */
    public WorkflowEscalationRule__mdt rule;

    /** @description The work item being escalated */
    public WorkItem__c workItem;

    /** @description Number of days the item has been in its current stage */
    public Integer daysInStage;

    /** @description Resolved severity level (Warning or Critical) */
    public String severity;

    /** @description Accumulator for work items requiring DML updates */
    public Map<Id, WorkItem__c> itemsToUpdate;

    /** @description Accumulator for email notification targets: workItemId -> EscalationDetail */
    public Map<Id, DeliveryEscalationService.EscalationDetail> emailTargets;

    /** @description Accumulator for Chatter post targets: workItemId -> message */
    public Map<Id, String> chatterTargets;

    /** @description Accumulator for Slack notifications: workItemName -> message */
    public Map<String, String> slackNotifications;

    /** @description Accumulator for activity log entries */
    public List<ActivityLog__c> logEntries;

    /**
     * @description Constructs a context with all required fields and accumulators.
     * @param rule The escalation rule being applied
     * @param workItem The work item being escalated
     * @param daysInStage Days in current stage
     * @param severity Resolved severity level
     * @param itemsToUpdate DML update accumulator
     * @param emailTargets Email notification accumulator
     * @param chatterTargets Chatter post accumulator
     * @param slackNotifications Slack notification accumulator
     * @param logEntries Activity log accumulator
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public DeliveryEscalationContext(
        WorkflowEscalationRule__mdt rule,
        WorkItem__c workItem,
        Integer daysInStage,
        String severity,
        Map<Id, WorkItem__c> itemsToUpdate,
        Map<Id, DeliveryEscalationService.EscalationDetail> emailTargets,
        Map<Id, String> chatterTargets,
        Map<String, String> slackNotifications,
        List<ActivityLog__c> logEntries
    ) {
        this.rule = rule;
        this.workItem = workItem;
        this.daysInStage = daysInStage;
        this.severity = severity;
        this.itemsToUpdate = itemsToUpdate;
        this.emailTargets = emailTargets;
        this.chatterTargets = chatterTargets;
        this.slackNotifications = slackNotifications;
        this.logEntries = logEntries;
    }
}
