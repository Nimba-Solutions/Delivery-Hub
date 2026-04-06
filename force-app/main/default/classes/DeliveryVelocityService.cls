/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Velocity tracking and capacity planning service. Calculates team and
 *               developer velocity (items completed per week), projected completion dates,
 *               and capacity utilization using DeveloperCapacity__mdt configuration.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.ExcessivePublicCount')
global with sharing class DeliveryVelocityService {

    private static final Integer DEFAULT_WEEKS = 8;
    private static final Integer DAYS_PER_WEEK = 7;
    private static final Decimal PERCENT_DIVISOR = 100.0;

    // ── Result wrappers ──────────────────────────────────────────────────

    global class WeeklyVelocity {
        @AuraEnabled public String weekLabel;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Date weekStart;
    }

    global class DeveloperUtilization {
        @AuraEnabled public String developerName;
        @AuraEnabled public String developerId;
        @AuraEnabled public Decimal weeklyCapacityHours;
        @AuraEnabled public Decimal allocationPercent;
        @AuraEnabled public Decimal allocatedHours;
        @AuraEnabled public Integer activeItemCount;
    }

    global class ProjectionResult {
        @AuraEnabled public Integer remainingItems;
        @AuraEnabled public Decimal averageVelocity;
        @AuraEnabled public Integer estimatedWeeks;
        @AuraEnabled public Date projectedCompletionDate;
    }

    global class CapacityResult {
        @AuraEnabled public Decimal totalCapacityHours;
        @AuraEnabled public Decimal allocatedHours;
        @AuraEnabled public Decimal utilizationPercent;
        @AuraEnabled public Integer developerCount;
        @AuraEnabled public List<DeveloperUtilization> developers;
    }

    global class VelocityDashboard {
        @AuraEnabled public List<WeeklyVelocity> weeklyVelocity;
        @AuraEnabled public ProjectionResult projection;
        @AuraEnabled public CapacityResult capacity;
    }

    // ── AuraEnabled entry points ─────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static List<WeeklyVelocity> getTeamVelocity(String workflowType, Integer weeks) {
        if (weeks == null || weeks <= 0) { weeks = DEFAULT_WEEKS; }
        if (String.isBlank(workflowType)) { workflowType = 'Software_Delivery'; }

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);

        Date startDate = Date.today().addDays(-(weeks * DAYS_PER_WEEK));

        List<WorkItem__c> completed = [
            SELECT Id, LastModifiedDate
            FROM WorkItem__c
            WHERE TemplateMarkedDateTime__c = null
            AND StageNamePk__c IN :terminalStages
            AND WorkflowTypeTxt__c = :workflowType
            AND LastModifiedDate >= :startDate
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate ASC
        ];

        return buildWeeklyBuckets(completed, weeks);
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static List<WeeklyVelocity> getDeveloperVelocity(String developerId, Integer weeks) {
        if (weeks == null || weeks <= 0) { weeks = DEFAULT_WEEKS; }
        if (String.isBlank(developerId)) {
            return new List<WeeklyVelocity>();
        }

        Date startDate = Date.today().addDays(-(weeks * DAYS_PER_WEEK));

        // Gather terminal stages across all workflow types
        Set<String> allTerminalStages = new Set<String>();
        for (Map<String,Object> wt : DeliveryWorkflowConfigService.getWorkflowTypes()) {
            allTerminalStages.addAll(
                DeliveryWorkflowConfigService.getTerminalStageValues((String) wt.get('developerName'))
            );
        }

        List<WorkItem__c> completed = [
            SELECT Id, LastModifiedDate
            FROM WorkItem__c
            WHERE TemplateMarkedDateTime__c = null
            AND StageNamePk__c IN :allTerminalStages
            AND DeveloperLookupId__c = :developerId
            AND LastModifiedDate >= :startDate
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate ASC
        ];

        return buildWeeklyBuckets(completed, weeks);
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static ProjectionResult getProjectedCompletion(String workflowType) {
        if (String.isBlank(workflowType)) { workflowType = 'Software_Delivery'; }

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);

        // Count remaining (non-terminal, non-template) items
        Integer remaining = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE TemplateMarkedDateTime__c = null
            AND StageNamePk__c NOT IN :terminalStages
            AND WorkflowTypeTxt__c = :workflowType
            WITH SYSTEM_MODE
        ];

        // Get recent velocity
        List<WeeklyVelocity> velocity = getTeamVelocity(workflowType, DEFAULT_WEEKS);
        Decimal avgVelocity = calculateAverageVelocity(velocity);

        ProjectionResult result = new ProjectionResult();
        result.remainingItems = remaining;
        result.averageVelocity = avgVelocity;

        if (avgVelocity > 0) {
            result.estimatedWeeks = (Integer) Math.ceil(remaining / avgVelocity);
            result.projectedCompletionDate = Date.today().addDays(result.estimatedWeeks * DAYS_PER_WEEK);
        } else {
            result.estimatedWeeks = 0;
            result.projectedCompletionDate = null;
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static CapacityResult getCapacityUtilization(String workflowType) {
        if (String.isBlank(workflowType)) { workflowType = 'Software_Delivery'; }

        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);

        // Load capacity configuration from CMT
        List<DeveloperCapacity__mdt> capacities = [
            SELECT DeveloperUserIdTxt__c, WeeklyCapacityHoursNumber__c,
                   AllocationPercentNumber__c, WorkflowTypeNameTxt__c, Label
            FROM DeveloperCapacity__mdt
            WHERE WorkflowTypeNameTxt__c = :workflowType
            WITH SYSTEM_MODE
        ];

        // Count active items per developer
        Map<String, Integer> activeCountByDev = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT DeveloperLookupId__c devId, COUNT(Id) cnt
            FROM WorkItem__c
            WHERE TemplateMarkedDateTime__c = null
            AND StageNamePk__c NOT IN :terminalStages
            AND WorkflowTypeTxt__c = :workflowType
            AND DeveloperLookupId__c != null
            WITH SYSTEM_MODE
            GROUP BY DeveloperLookupId__c
        ]) {
            String devId = String.valueOf(ar.get('devId'));
            Integer cnt = (Integer) ar.get('cnt');
            activeCountByDev.put(devId, cnt);
        }

        Decimal totalCapacity = 0;
        Decimal totalAllocated = 0;
        List<DeveloperUtilization> devList = new List<DeveloperUtilization>();

        for (DeveloperCapacity__mdt cap : capacities) {
            Decimal weeklyHours = cap.WeeklyCapacityHoursNumber__c != null ? cap.WeeklyCapacityHoursNumber__c : 40;
            Decimal allocPct = cap.AllocationPercentNumber__c != null ? cap.AllocationPercentNumber__c : 100;
            Decimal allocated = weeklyHours * (allocPct / PERCENT_DIVISOR);

            DeveloperUtilization du = new DeveloperUtilization();
            du.developerName = cap.Label;
            du.developerId = cap.DeveloperUserIdTxt__c;
            du.weeklyCapacityHours = weeklyHours;
            du.allocationPercent = allocPct;
            du.allocatedHours = allocated;
            du.activeItemCount = activeCountByDev.containsKey(cap.DeveloperUserIdTxt__c)
                ? activeCountByDev.get(cap.DeveloperUserIdTxt__c) : 0;

            devList.add(du);
            totalCapacity += weeklyHours;
            totalAllocated += allocated;
        }

        CapacityResult result = new CapacityResult();
        result.totalCapacityHours = totalCapacity;
        result.allocatedHours = totalAllocated;
        result.utilizationPercent = totalCapacity > 0 ? (totalAllocated / totalCapacity) * PERCENT_DIVISOR : 0;
        result.developerCount = capacities.size();
        result.developers = devList;

        return result;
    }

    @AuraEnabled(cacheable=true)
    global static VelocityDashboard getVelocityDashboard(String workflowType) {
        if (String.isBlank(workflowType)) { workflowType = 'Software_Delivery'; }

        VelocityDashboard dashboard = new VelocityDashboard();
        dashboard.weeklyVelocity = getTeamVelocity(workflowType, DEFAULT_WEEKS);
        dashboard.projection = getProjectedCompletion(workflowType);
        dashboard.capacity = getCapacityUtilization(workflowType);

        return dashboard;
    }

    // ── Private helpers ──────────────────────────────────────────────────

    @TestVisible
    private static List<WeeklyVelocity> buildWeeklyBuckets(List<WorkItem__c> items, Integer weeks) {
        Map<Date, Integer> weekBuckets = new Map<Date, Integer>();
        Date today = Date.today();

        // Initialize all week buckets
        for (Integer i = weeks - 1; i >= 0; i--) {
            Date weekStart = today.addDays(-(i * DAYS_PER_WEEK));
            // Align to Monday
            weekStart = weekStart.toStartOfWeek();
            if (!weekBuckets.containsKey(weekStart)) {
                weekBuckets.put(weekStart, 0);
            }
        }

        // Distribute items into weekly buckets
        for (WorkItem__c item : items) {
            Date itemDate = item.LastModifiedDate.date();
            Date weekStart = itemDate.toStartOfWeek();
            if (weekBuckets.containsKey(weekStart)) {
                weekBuckets.put(weekStart, weekBuckets.get(weekStart) + 1);
            }
        }

        // Convert to sorted list
        List<Date> sortedWeeks = new List<Date>(weekBuckets.keySet());
        sortedWeeks.sort();

        List<WeeklyVelocity> result = new List<WeeklyVelocity>();
        for (Date ws : sortedWeeks) {
            WeeklyVelocity wv = new WeeklyVelocity();
            wv.weekStart = ws;
            wv.completedCount = weekBuckets.get(ws);
            wv.weekLabel = ws.month() + '/' + ws.day();
            result.add(wv);
        }

        return result;
    }

    @TestVisible
    private static Decimal calculateAverageVelocity(List<WeeklyVelocity> velocity) {
        if (velocity == null || velocity.isEmpty()) {
            return 0;
        }
        Decimal total = 0;
        for (WeeklyVelocity wv : velocity) {
            total += wv.completedCount;
        }
        return total / velocity.size();
    }
}
