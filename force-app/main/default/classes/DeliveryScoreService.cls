/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Calculates a 0-100 Delivery Score — a health rating for the delivery pipeline.
 *               Evaluates 6 factors: Flow Health, WIP Balance, Completion Rate,
 *               Backlog Health, Priority Balance, and Activity.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ExcessivePublicCount, PMD.ApexDoc')
global with sharing class DeliveryScoreService {

    // -------------------------------------------------------------------------
    // Wrapper classes
    // -------------------------------------------------------------------------

    global class ScoreFactor {
        @AuraEnabled public String name;
        @AuraEnabled public Integer score;       // 0-100
        @AuraEnabled public Decimal weight;      // 0.0-1.0
        @AuraEnabled public String detail;       // human-readable explanation
        @AuraEnabled public String status;       // good | warning | critical
    }

    global class DeliveryScoreResult {
        @AuraEnabled public Integer score;       // 0-100
        @AuraEnabled public String grade;        // A+, A, B+, B, C+, C, D, F
        @AuraEnabled public String scoreColor;   // hex color
        @AuraEnabled public String gradeLabel;   // Exceptional, Excellent, etc.
        @AuraEnabled public List<ScoreFactor> factors;
    }

    // -------------------------------------------------------------------------
    // AuraEnabled entry point
    // -------------------------------------------------------------------------

    /**
     * @description Queries all non-template WorkItem__c records and calculates the delivery score.
     *              Optionally scopes to a specific NetworkEntity via entityId.
     * @param entityId Optional NetworkEntity__c Id to scope the score to a single client.
     * @return DeliveryScoreResult with score, grade, color, and factor breakdown.
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static DeliveryScoreResult getDeliveryScore(Id entityId) {
        // Use static SOQL so CCI namespace-injects the child relationship name
        List<WorkItem__c> items;
        if (entityId != null) {
            items = [
                SELECT Id, StageNamePk__c, PriorityPk__c, WorkflowTypeTxt__c,
                       ClientNetworkEntityLookup__c, LastModifiedDate,
                       (SELECT Id FROM WorkItemComments__r)
                FROM WorkItem__c
                WHERE TemplateMarkedDateTime__c = null
                AND ClientNetworkEntityLookup__c = :entityId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
            ];
        } else {
            items = [
                SELECT Id, StageNamePk__c, PriorityPk__c, WorkflowTypeTxt__c,
                       ClientNetworkEntityLookup__c, LastModifiedDate,
                       (SELECT Id FROM WorkItemComments__r)
                FROM WorkItem__c
                WHERE TemplateMarkedDateTime__c = null
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
            ];
        }

        // Determine workflow type from items, default to Software_Delivery
        String workflowType = 'Software_Delivery';
        if (!items.isEmpty() && String.isNotBlank(items[0].WorkflowTypeTxt__c)) {
            workflowType = items[0].WorkflowTypeTxt__c;
        }

        // Load stage metadata for phase mapping
        Map<String, String> stagePhaseMap = DeliveryWorkflowConfigService.getStagePhaseMap(workflowType);
        Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowType);

        return calculateScore(items, stagePhaseMap, terminalStages);
    }

    // -------------------------------------------------------------------------
    // Core scoring engine
    // -------------------------------------------------------------------------

    @TestVisible
    private static DeliveryScoreResult calculateScore(
        List<WorkItem__c> items,
        Map<String, String> stagePhaseMap,
        Set<String> terminalStages
    ) {
        // Classify items by phase
        Map<String, List<WorkItem__c>> itemsByPhase = new Map<String, List<WorkItem__c>>();
        List<WorkItem__c> terminalItems = new List<WorkItem__c>();
        List<WorkItem__c> nonTerminalItems = new List<WorkItem__c>();

        for (WorkItem__c item : items) {
            String stage = item.StageNamePk__c;
            if (stage == null) { stage = 'Backlog'; }

            if (terminalStages.contains(stage)) {
                terminalItems.add(item);
                if (!itemsByPhase.containsKey('done')) {
                    itemsByPhase.put('done', new List<WorkItem__c>());
                }
                itemsByPhase.get('done').add(item);
            } else {
                nonTerminalItems.add(item);
                String phase = stagePhaseMap.containsKey(stage) ? stagePhaseMap.get(stage) : 'backlog';
                phase = phase.toLowerCase();
                if (!itemsByPhase.containsKey(phase)) {
                    itemsByPhase.put(phase, new List<WorkItem__c>());
                }
                itemsByPhase.get(phase).add(item);
            }
        }

        Integer totalItems = items.size();
        Integer doneCount = terminalItems.size();
        Integer activeCount = nonTerminalItems.size();

        // Calculate factors
        List<ScoreFactor> factors = new List<ScoreFactor>();
        factors.add(calcFlowHealth(itemsByPhase, totalItems, activeCount));
        factors.add(calcWipBalance(itemsByPhase, stagePhaseMap, nonTerminalItems));
        factors.add(calcCompletionRate(totalItems, doneCount));
        factors.add(calcBacklogHealth(itemsByPhase, totalItems));
        factors.add(calcPriorityBalance(nonTerminalItems, stagePhaseMap));
        factors.add(calcActivity(items));

        // Weighted score
        Decimal weightedScore = 0;
        for (ScoreFactor f : factors) {
            weightedScore += f.score * f.weight;
        }
        Integer finalScore = (Integer)Math.round(weightedScore);

        DeliveryScoreResult result = new DeliveryScoreResult();
        result.score = finalScore;
        result.grade = getGrade(finalScore);
        result.scoreColor = getColor(finalScore);
        result.gradeLabel = getGradeLabel(finalScore);
        result.factors = factors;
        return result;
    }

    // -------------------------------------------------------------------------
    // Factor 1: Flow Health (25%)
    // -------------------------------------------------------------------------

    private static ScoreFactor calcFlowHealth(
        Map<String, List<WorkItem__c>> itemsByPhase, Integer totalItems, Integer activeCount
    ) {
        ScoreFactor f = new ScoreFactor();
        f.name = 'Flow Health';
        f.weight = 0.25;

        if (totalItems == 0) {
            f.score = 50;
            f.detail = 'No items on the board yet. Add items to start tracking flow.';
            f.status = 'warning';
            return f;
        }

        // Active phases where work should be happening
        Set<String> activePhases = new Set<String>{'development', 'qa', 'production'};
        Integer activePhaseItems = 0;
        for (String phase : activePhases) {
            if (itemsByPhase.containsKey(phase)) {
                activePhaseItems += itemsByPhase.get(phase).size();
            }
        }

        Decimal activeRatio = (Decimal)activePhaseItems / totalItems;

        // Distribution evenness via coefficient of variation (skip done phase)
        List<Integer> phaseCounts = new List<Integer>();
        for (String phase : itemsByPhase.keySet()) {
            if (phase != 'done') {
                phaseCounts.add(itemsByPhase.get(phase).size());
            }
        }

        Decimal distributionScore = 100;
        if (!phaseCounts.isEmpty()) {
            Decimal sum = 0;
            for (Integer c : phaseCounts) { sum += c; }
            Decimal mean = sum / phaseCounts.size();

            if (mean > 0) {
                Decimal variance = 0;
                for (Integer c : phaseCounts) {
                    Decimal diff = c - mean;
                    variance += diff * diff;
                }
                variance /= phaseCounts.size();
                Decimal cv = (Decimal)Math.sqrt(variance.doubleValue()) / mean;
                distributionScore = Math.max(0, 100 - cv * 40);
            }
        }

        // 60% active ratio bonus + 40% distribution evenness
        f.score = (Integer)Math.round(Math.min(100, activeRatio * 100 * 0.6 + distributionScore * 0.4));

        if (f.score >= 70) {
            f.detail = activePhaseItems + ' of ' + totalItems + ' items are in active stages. Work is flowing well.';
        } else if (f.score >= 40) {
            f.detail = activePhaseItems + ' of ' + totalItems + ' items are in active stages. Some bottlenecks detected.';
        } else {
            f.detail = 'Only ' + activePhaseItems + ' of ' + totalItems + ' items are in active stages. Items are piling up.';
        }
        f.status = getStatus(f.score);
        return f;
    }

    // -------------------------------------------------------------------------
    // Factor 2: WIP Balance (20%)
    // -------------------------------------------------------------------------

    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    private static ScoreFactor calcWipBalance(
        Map<String, List<WorkItem__c>> itemsByPhase,
        Map<String, String> stagePhaseMap,
        List<WorkItem__c> nonTerminalItems
    ) {
        ScoreFactor f = new ScoreFactor();
        f.name = 'WIP Balance';
        f.weight = 0.20;

        // Group non-terminal items by individual stage for WIP assessment
        Map<String, Integer> stageCounts = new Map<String, Integer>();
        for (WorkItem__c item : nonTerminalItems) {
            String stage = item.StageNamePk__c != null ? item.StageNamePk__c : 'Backlog';
            String phase = stagePhaseMap.containsKey(stage) ? stagePhaseMap.get(stage) : 'backlog';
            phase = phase.toLowerCase();
            // Only evaluate active columns (not backlog, not done)
            if (phase != 'backlog' && phase != 'done') {
                if (!stageCounts.containsKey(stage)) {
                    stageCounts.put(stage, 0);
                }
                stageCounts.put(stage, stageCounts.get(stage) + 1);
            }
        }

        if (stageCounts.isEmpty()) {
            f.score = 50;
            f.detail = 'No active columns to evaluate.';
            f.status = 'warning';
            return f;
        }

        Integer totalScore = 0;
        Integer overloaded = 0;

        for (String stage : stageCounts.keySet()) {
            Integer count = stageCounts.get(stage);
            if (count == 0) {
                totalScore += 60;
            } else if (count <= 3) {
                totalScore += 100;
            } else if (count <= 5) {
                totalScore += 70;
            } else {
                totalScore += (Integer)Math.max(0, 40 - (count - 5) * 10);
                overloaded++;
            }
        }

        f.score = (Integer)Math.round((Decimal)totalScore / stageCounts.size());

        if (overloaded == 0) {
            f.detail = 'All columns have healthy WIP counts. Team is managing capacity well.';
        } else {
            f.detail = overloaded + ' column' + (overloaded > 1 ? 's are' : ' is') + ' overloaded (>5 items). Consider limiting work-in-progress.';
        }
        f.status = getStatus(f.score);
        return f;
    }

    // -------------------------------------------------------------------------
    // Factor 3: Completion Rate (20%)
    // -------------------------------------------------------------------------

    private static ScoreFactor calcCompletionRate(Integer totalItems, Integer doneItems) {
        ScoreFactor f = new ScoreFactor();
        f.name = 'Completion Rate';
        f.weight = 0.20;

        if (totalItems == 0) {
            f.score = 0;
            f.detail = 'No items on the board.';
            f.status = 'critical';
            return f;
        }

        Decimal ratio = (Decimal)doneItems / totalItems;
        f.score = (Integer)Math.round(Math.min(100, ratio * 160));

        Integer pct = (Integer)Math.round(ratio * 100);
        if (pct >= 50) {
            f.detail = doneItems + ' of ' + totalItems + ' items completed (' + pct + '%). Strong execution.';
        } else if (pct >= 25) {
            f.detail = doneItems + ' of ' + totalItems + ' items completed (' + pct + '%). Delivery is progressing.';
        } else {
            f.detail = 'Only ' + doneItems + ' of ' + totalItems + ' items completed (' + pct + '%). More throughput needed.';
        }
        f.status = getStatus(f.score);
        return f;
    }

    // -------------------------------------------------------------------------
    // Factor 4: Backlog Health (15%)
    // -------------------------------------------------------------------------

    private static ScoreFactor calcBacklogHealth(Map<String, List<WorkItem__c>> itemsByPhase, Integer totalItems) {
        ScoreFactor f = new ScoreFactor();
        f.name = 'Backlog Health';
        f.weight = 0.15;

        if (totalItems == 0) {
            f.score = 70;
            f.detail = 'No items to evaluate.';
            f.status = 'good';
            return f;
        }

        Integer backlogItems = 0;
        if (itemsByPhase.containsKey('backlog')) {
            backlogItems = itemsByPhase.get('backlog').size();
        }
        // Also include 'requirements' phase as early-stage
        if (itemsByPhase.containsKey('requirements')) {
            backlogItems += itemsByPhase.get('requirements').size();
        }

        Decimal backlogRatio = (Decimal)backlogItems / totalItems;

        if (backlogRatio <= 0.15) {
            f.score = 100;
        } else if (backlogRatio <= 0.25) {
            f.score = 85;
        } else if (backlogRatio <= 0.40) {
            f.score = 60;
        } else {
            f.score = (Integer)Math.max(0, Math.round(40 - (backlogRatio - 0.40) * 100));
        }

        Integer pct = (Integer)Math.round(backlogRatio * 100);
        if (f.score >= 70) {
            f.detail = 'Backlog is ' + pct + '% of all items. Lean and focused.';
        } else if (f.score >= 40) {
            f.detail = 'Backlog is ' + pct + '% of all items. Consider grooming or splitting work.';
        } else {
            f.detail = 'Backlog is ' + pct + '% of all items. Significant planning debt detected.';
        }
        f.status = getStatus(f.score);
        return f;
    }

    // -------------------------------------------------------------------------
    // Factor 5: Priority Balance (10%)
    // -------------------------------------------------------------------------

    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    private static ScoreFactor calcPriorityBalance(
        List<WorkItem__c> nonTerminalItems, Map<String, String> stagePhaseMap
    ) {
        ScoreFactor f = new ScoreFactor();
        f.name = 'Priority Balance';
        f.weight = 0.10;

        // Find high-priority items
        List<WorkItem__c> highPriItems = new List<WorkItem__c>();
        for (WorkItem__c item : nonTerminalItems) {
            if (item.PriorityPk__c == 'High') {
                highPriItems.add(item);
            }
        }

        if (highPriItems.isEmpty()) {
            f.score = 75;
            f.detail = 'No high-priority items. Consider prioritizing key work.';
            f.status = 'good';
            return f;
        }

        // Phase progression scoring
        Map<String, Integer> phaseScoreMap = new Map<String, Integer>{
            'backlog' => 10, 'requirements' => 30, 'development' => 60,
            'qa' => 80, 'production' => 90, 'done' => 100
        };

        Integer totalScore = 0;
        Integer earlyItems = 0;

        for (WorkItem__c item : highPriItems) {
            String stage = item.StageNamePk__c != null ? item.StageNamePk__c : 'Backlog';
            String phase = stagePhaseMap.containsKey(stage) ? stagePhaseMap.get(stage) : 'backlog';
            phase = phase.toLowerCase();
            Integer ps = phaseScoreMap.containsKey(phase) ? phaseScoreMap.get(phase) : 50;
            totalScore += ps;

            if (phase == 'backlog' || phase == 'requirements') {
                earlyItems++;
            }
        }

        f.score = (Integer)Math.round((Decimal)totalScore / highPriItems.size());

        if (earlyItems == 0) {
            f.detail = 'All ' + highPriItems.size() + ' high-priority items are progressing through the pipeline.';
        } else {
            f.detail = earlyItems + ' of ' + highPriItems.size() + ' high-priority items are still in early stages.';
        }
        f.status = getStatus(f.score);
        return f;
    }

    // -------------------------------------------------------------------------
    // Factor 6: Activity (10%)
    // -------------------------------------------------------------------------

    private static ScoreFactor calcActivity(List<WorkItem__c> items) {
        ScoreFactor f = new ScoreFactor();
        f.name = 'Activity';
        f.weight = 0.10;

        Integer totalItems = items.size();
        if (totalItems == 0) {
            f.score = 0;
            f.detail = 'No items to evaluate.';
            f.status = 'critical';
            return f;
        }

        Integer itemsWithComments = 0;
        Integer totalComments = 0;

        for (WorkItem__c item : items) {
            Integer commentCount = item.WorkItemComments__r != null ? item.WorkItemComments__r.size() : 0;
            if (commentCount > 0) {
                itemsWithComments++;
            }
            totalComments += commentCount;
        }

        Decimal commentRatio = (Decimal)itemsWithComments / totalItems;

        // Score based on coverage (60%) and volume (40%)
        Decimal coverageScore = commentRatio * 100;
        Decimal volumeScore = Math.min(100, ((Decimal)totalComments / totalItems) * 50);

        f.score = (Integer)Math.round(coverageScore * 0.6 + volumeScore * 0.4);

        if (f.score >= 70) {
            f.detail = totalComments + ' comments across ' + itemsWithComments + ' items. Active collaboration.';
        } else if (f.score >= 40) {
            f.detail = totalComments + ' comments across ' + itemsWithComments + ' items. Some items lack discussion.';
        } else {
            f.detail = 'Only ' + totalComments + ' comments total. More team engagement needed.';
        }
        f.status = getStatus(f.score);
        return f;
    }

    // -------------------------------------------------------------------------
    // Utility helpers
    // -------------------------------------------------------------------------

    @TestVisible
    private static String getGrade(Integer score) {
        if (score >= 90) { return 'A+'; }
        if (score >= 80) { return 'A'; }
        if (score >= 70) { return 'B+'; }
        if (score >= 60) { return 'B'; }
        if (score >= 50) { return 'C+'; }
        if (score >= 40) { return 'C'; }
        if (score >= 30) { return 'D'; }
        return 'F';
    }

    @TestVisible
    private static String getColor(Integer score) {
        if (score >= 80) { return '#22c55e'; } // green
        if (score >= 60) { return '#0ea5e9'; } // sky
        if (score >= 40) { return '#f59e0b'; } // amber
        return '#ef4444';                       // red
    }

    private static String getGradeLabel(Integer score) {
        if (score >= 90) { return 'Exceptional'; }
        if (score >= 80) { return 'Excellent'; }
        if (score >= 70) { return 'Good'; }
        if (score >= 60) { return 'Solid'; }
        if (score >= 50) { return 'Needs Work'; }
        if (score >= 40) { return 'At Risk'; }
        if (score >= 30) { return 'Critical'; }
        return 'Emergency';
    }

    private static String getStatus(Integer score) {
        if (score >= 70) { return 'good'; }
        if (score >= 40) { return 'warning'; }
        return 'critical';
    }
}
