/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  CMT-driven escalation engine that detects stalled work items and
 *               takes automated action. This class is a thin orchestrator that delegates
 *               rule evaluation to DeliveryEscalationRuleEvaluator, action execution to
 *               DeliveryEscalationActionExecutor, and notifications to DeliveryEscalationNotifService.
 *               Called nightly by DeliveryEscalationJob or DeliveryHubScheduler.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class DeliveryEscalationService {

    /** @description Hours before re-escalating the same work item (24h default) */
    @TestVisible
    private static Integer escalationCooldownHours = 24;

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
    global static List<EscalationSummary> getEscalationSummary() {
        List<WorkflowEscalationRule__mdt> rules = DeliveryEscalationRuleEvaluator.queryActiveRules();
        return DeliveryEscalationRuleEvaluator.buildSummary(rules);
    }

    // -------------------------------------------------------------------------
    // Public entry points — called by schedulers and other Apex
    // -------------------------------------------------------------------------

    /**
     * @description Main entry point — queries active escalation rules from CMT and processes them.
     *              Designed to be called from DeliveryEscalationJob or DeliveryHubScheduler.
     */
    public static void evaluateRules() {
        List<WorkflowEscalationRule__mdt> rules = DeliveryEscalationRuleEvaluator.queryActiveRules();
        DeliveryEscalationRuleEvaluator.processRules(rules);
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
    static void processEscalations(List<WorkflowEscalationRule__mdt> rules) {
        DeliveryEscalationRuleEvaluator.processRules(rules);
    }

    // -------------------------------------------------------------------------
    // Delegate methods — preserve test-class call sites
    // -------------------------------------------------------------------------

    /**
     * @description Delegates to DeliveryEscalationRuleEvaluator.buildSummary().
     *              Retained so existing tests and callers continue to work.
     * @param rules Active escalation rules
     * @return List of EscalationSummary wrappers
     */
    @TestVisible
    static List<EscalationSummary> buildSummary(List<WorkflowEscalationRule__mdt> rules) {
        return DeliveryEscalationRuleEvaluator.buildSummary(rules);
    }

    /**
     * @description Delegates to DeliveryEscalationNotifService.buildEscalationHtml().
     *              Retained so existing tests continue to work.
     * @param workItemName The work item name
     * @param title The work item description
     * @param stalledStage The stalled stage
     * @param recordUrl Record URL
     * @return HTML string
     */
    @TestVisible
    static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl) {
        return DeliveryEscalationNotifService.buildEscalationHtml(
            workItemName, title, stalledStage, recordUrl);
    }

    /**
     * @description Delegates to DeliveryEscalationNotifService.buildEscalationHtml().
     *              Retained so existing tests continue to work.
     * @param workItemName The work item auto-number name
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
    static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl, String severity,
        Integer daysInStage, String ruleName) {
        return DeliveryEscalationNotifService.buildEscalationHtml(
            workItemName, title, stalledStage, recordUrl, severity,
            daysInStage, ruleName);
    }

    // -------------------------------------------------------------------------
    // Inner classes — global types must remain on this class
    // -------------------------------------------------------------------------

    /**
     * @description Wrapper returned by getEscalationSummary() for LWC consumption.
     */
    global class EscalationSummary {
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
     * @description Detail object for batching email notifications with context.
     *              Public so that DeliveryEscalationActionExecutor and DeliveryEscalationNotifService
     *              can construct and consume instances.
     */
    public class EscalationDetail {
        public String stalledStage;
        public String severity;
        public Integer daysInStage;
        public String ruleName;

        /**
         * @description Constructs an EscalationDetail.
         * @param stalledStage The stage the item is stalled in
         * @param severity Severity level (Warning or Critical)
         * @param daysInStage Number of days stalled
         * @param ruleName Name of the escalation rule
         */
        public EscalationDetail(String stalledStage, String severity,
            Integer daysInStage, String ruleName) {
            this.stalledStage = stalledStage;
            this.severity = severity;
            this.daysInStage = daysInStage;
            this.ruleName = ruleName;
        }
    }
}
