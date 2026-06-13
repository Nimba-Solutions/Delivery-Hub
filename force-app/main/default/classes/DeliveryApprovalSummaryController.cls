/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only aggregate feed for the deliveryApprovalSummaryCard
 *               LWC (PR3 of the work-approval queue): three agenda numbers —
 *               hours approved this month, requests pending approval, and
 *               approved work in flight — plus the report ids for tile
 *               click-through, plus the approved-vs-total pitch pair
 *               (totalActiveEstimatedHours / totalApprovedHours) so the card
 *               can surface how little of the active estimated portfolio is
 *               client-approved — the approval-queue pitch stat. Kept separate
 *               from DeliveryWorkApprovalService (the decision engine) so the
 *               card can evolve without touching the service under review.
 *
 *               SOQL is WITH SYSTEM_MODE per CLAUDE.md (WITH USER_MODE breaks
 *               in namespaced package test context). Report ids are resolved
 *               by DeveloperName the same way
 *               DeliveryHubDashboardController.getReportIds does — Report
 *               DeveloperNames are not namespace-prefixed on subscriber
 *               installs, so the bare names are safe.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryApprovalSummaryController {

    /** WorkRequest__c lifecycle values consumed by the aggregates. */
    private static final String REQUEST_ACCEPTED = 'Accepted';
    private static final String REQUEST_OFFER_SENT = 'Offer Sent';

    /** Report DeveloperNames for tile click-through (shipped in this PR). */
    @TestVisible
    private static final List<String> REPORT_DEVELOPER_NAMES = new List<String>{
        'Hours_Approved_This_Period',
        'Pending_Approval',
        'Approved_In_Progress',
        'Deployed_To_Prod_Awaiting_Verification'
    };

    /** WorkItem__c stages counted as approved-and-in-flight (dev → deploying). */
    @TestVisible
    private static final Set<String> IN_FLIGHT_STAGES = new Set<String>{
        'Ready for Development', 'In Development', 'Dev Clarification Requested',
        'Providing Dev Clarification', 'Back For Development', 'Dev Blocked',
        'Ready for Scratch Test', 'Scratch Testing', 'Ready for QA',
        'QA In Progress', 'Ready for Internal UAT', 'Internal UAT',
        'Ready for Client UAT', 'In Client UAT', 'Ready for UAT Sign-off',
        'Processing Sign-off', 'Ready for Merge', 'Merging',
        'Ready for Deployment', 'Deploying'
    };

    /**
     * WorkItem__c stages excluded from the active portfolio scope. CMT-driven
     * cross-type terminal union so the pitch denominator matches the active
     * definition every other dashboard/forecast count uses.
     */
    @TestVisible
    private static Set<String> terminalStages {
        get {
            if (terminalStages == null) {
                terminalStages = DeliveryWorkflowConfigService.getAllTerminalStageValues();
            }
            return terminalStages;
        }
        set;
    }

    /**
     * @description The three agenda tiles, the approved-vs-total pitch pair,
     *              plus report click-through ids.
     */
    public class ApprovalSummaryDTO {
        @AuraEnabled public Decimal hoursApprovedThisMonth;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public Decimal pendingQuotedHours;
        @AuraEnabled public Integer inProgressCount;
        @AuraEnabled public Decimal inProgressApprovedHours;
        /** Sum of EstimatedHoursNumber__c across the active portfolio scope. */
        @AuraEnabled public Decimal totalActiveEstimatedHours;
        /** Sum of ClientPreApprovedHoursNumber__c across the same scope. */
        @AuraEnabled public Decimal totalApprovedHours;
        @AuraEnabled public Map<String, String> reportIdsByDeveloperName;
    }

    /**
     * @description Builds the approval agenda summary: (1) sum of granted
     *              hours on requests Accepted this calendar month, (2) count +
     *              quoted-hours sum of Offer-Sent requests awaiting a
     *              decision, (3) count + approved-cap sum of in-flight
     *              WorkItems carrying a client-approved budget, (4) the
     *              approved-vs-total pitch pair over the active portfolio —
     *              plus the report ids backing each tile's click-through.
     * @return One ApprovalSummaryDTO; numbers default to 0 when empty.
     */
    @AuraEnabled(cacheable=true)
    public static ApprovalSummaryDTO getApprovalSummary() {
        ApprovalSummaryDTO dto = new ApprovalSummaryDTO();
        try {
            dto.hoursApprovedThisMonth = sumApprovedThisMonth();
            fillPendingAggregates(dto);
            fillInProgressAggregates(dto);
            fillApprovedShareAggregates(dto);
            dto.reportIdsByDeveloperName = resolveReportIds();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryApprovalSummaryController.getApprovalSummary] failed: '
                + e.getMessage());
            throw new AuraHandledException('Unable to load the approval summary.');
        }
        return dto;
    }

    /**
     * @description Sums PreApprovedHoursNumber__c on requests decided Accepted
     *              this calendar month.
     * @return Granted hours this month, 0 when none.
     */
    private static Decimal sumApprovedThisMonth() {
        AggregateResult row = [
            SELECT SUM(PreApprovedHoursNumber__c) granted
            FROM WorkRequest__c
            WHERE StatusPk__c = :REQUEST_ACCEPTED
              AND DecisionDateTime__c = THIS_MONTH
            WITH SYSTEM_MODE
        ];
        Decimal granted = (Decimal) row.get('granted');
        return granted == null ? 0 : granted;
    }

    /**
     * @description Counts Offer-Sent requests and sums their quoted hours.
     * @param dto DTO to fill (pendingCount / pendingQuotedHours).
     */
    private static void fillPendingAggregates(ApprovalSummaryDTO dto) {
        AggregateResult row = [
            SELECT COUNT(Id) cnt, SUM(QuotedHoursNumber__c) quoted
            FROM WorkRequest__c
            WHERE StatusPk__c = :REQUEST_OFFER_SENT
            WITH SYSTEM_MODE
        ];
        Integer cnt = (Integer) row.get('cnt');
        Decimal quoted = (Decimal) row.get('quoted');
        dto.pendingCount = cnt == null ? 0 : cnt;
        dto.pendingQuotedHours = quoted == null ? 0 : quoted;
    }

    /**
     * @description Counts approved in-flight WorkItems (client cap &gt; 0 and
     *              stage in the dev → deploying band) and sums their caps.
     * @param dto DTO to fill (inProgressCount / inProgressApprovedHours).
     */
    private static void fillInProgressAggregates(ApprovalSummaryDTO dto) {
        AggregateResult row = [
            SELECT COUNT(Id) cnt, SUM(ClientPreApprovedHoursNumber__c) approved
            FROM WorkItem__c
            WHERE ClientPreApprovedHoursNumber__c > 0
              AND StageNamePk__c IN :IN_FLIGHT_STAGES
            WITH SYSTEM_MODE
        ];
        Integer cnt = (Integer) row.get('cnt');
        Decimal approved = (Decimal) row.get('approved');
        dto.inProgressCount = cnt == null ? 0 : cnt;
        dto.inProgressApprovedHours = approved == null ? 0 : approved;
    }

    /**
     * @description The approval-queue pitch pair in ONE aggregate: total
     *              estimated hours across the active portfolio vs how much of
     *              it carries a client-approved cap. "Active" borrows the
     *              board's canonical scope (DeliveryHoursAnalyticsController's
     *              portfolio filter): activated, not archived, not a template,
     *              and not in a terminal stage. SUM ignores null caps, so the
     *              approved figure is exactly the sum of positive
     *              ClientPreApprovedHoursNumber__c values in that scope.
     * @param dto DTO to fill (totalActiveEstimatedHours / totalApprovedHours).
     */
    private static void fillApprovedShareAggregates(ApprovalSummaryDTO dto) {
        AggregateResult row = [
            SELECT SUM(EstimatedHoursNumber__c) est,
                   SUM(ClientPreApprovedHoursNumber__c) approved
            FROM WorkItem__c
            WHERE ActivatedDateTime__c != NULL
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
              AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
        ];
        Decimal est = (Decimal) row.get('est');
        Decimal approved = (Decimal) row.get('approved');
        dto.totalActiveEstimatedHours = est == null ? 0 : est;
        dto.totalApprovedHours = approved == null ? 0 : approved;
    }

    /**
     * @description Resolves the agenda reports' record ids by DeveloperName so
     *              tiles can navigate without hardcoding org-specific ids.
     *              Reports missing in the org are simply absent from the map
     *              (the LWC disables that tile's click-through).
     * @return Map of report DeveloperName to record id.
     */
    private static Map<String, String> resolveReportIds() {
        Map<String, String> out = new Map<String, String>();
        for (Report r : [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :REPORT_DEVELOPER_NAMES
            WITH SYSTEM_MODE
        ]) {
            out.put(r.DeveloperName, r.Id);
        }
        return out;
    }
}
