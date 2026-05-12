/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Velocity-based forecast service for a WorkItem__c tree. Reads the
 *              tree's WorkLog__c history, computes rolling N-week velocity, and
 *              projects the date at which cumulative actual hours will cross the
 *              tree's total EstimatedHoursNumber budget. Confidence bands are
 *              derived from ±1 std-dev of weekly velocity over the rolling window.
 *
 *              Used by deliveryProjectBurnUpChart LWC (record-page panel).
 *              Phase 3 of the hours/forecast/auto-schedule plan.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.AvoidGlobalModifier,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.OperationWithLimitsInLoop')
global with sharing class DeliveryForecastService {

    /** @description Rolling window size in weeks for velocity calculation. */
    private static final Integer VELOCITY_WINDOW_WEEKS = 4;

    /** @description Hard cap on tree-walk depth (defensive against cycles). */
    private static final Integer MAX_TREE_DEPTH = 10;

    /** @description Hard cap on the number of weekly buckets returned for charting. */
    private static final Integer MAX_HISTORY_WEEKS = 104;

    /** @description Number of days in a week. */
    private static final Integer DAYS_PER_WEEK = 7;

    /** @description Forecast headline numbers returned to the LWC. */
    global class ProjectForecast {
        @AuraEnabled global Id rootWorkItemId;
        @AuraEnabled global Decimal totalEstimatedHours;
        @AuraEnabled global Decimal totalLoggedHours;
        @AuraEnabled global Decimal currentVelocityHoursPerWeek;
        @AuraEnabled global Decimal velocityStdDev;
        @AuraEnabled global Decimal projectedFinalHours;
        @AuraEnabled global Date projectedCompletionDate;
        @AuraEnabled global Date confidenceLowDate;
        @AuraEnabled global Date confidenceHighDate;
        @AuraEnabled global Decimal weeksRemaining;
        @AuraEnabled global Boolean isOverBudgetTrajectory;
        @AuraEnabled global Boolean hasEstimate;
        @AuraEnabled global Boolean hasVelocity;
        @AuraEnabled global Date earliestStart;
        @AuraEnabled global Date latestEnd;
        @AuraEnabled global List<WeeklyPoint> history;
        @AuraEnabled global List<WeeklyPoint> projection;
    }

    /** @description Single weekly bucket on the burn-up chart. */
    global class WeeklyPoint {
        @AuraEnabled global String weekStart;
        @AuraEnabled global Decimal hoursThisWeek;
        @AuraEnabled global Decimal cumulativeHours;
        @AuraEnabled global Decimal scopeHours;
    }

    /**
     * @description Computes the velocity-based forecast for the WI tree rooted at
     *              workItemId. Walks descendants via ParentWorkItemLookup__c (depth
     *              capped at MAX_TREE_DEPTH).
     * @param workItemId Root WorkItem Id. Required.
     * @return ProjectForecast populated with history + projection + headline numbers.
     */
    @AuraEnabled(cacheable=true)
    global static ProjectForecast calculateProjectForecast(Id workItemId) {
        try {
            if (workItemId == null) {
                throw new AuraHandledException('workItemId is required.');
            }

            Set<Id> treeIds = walkDescendants(workItemId);
            List<WorkItem__c> tree = [
                SELECT Id, EstimatedHoursNumber__c, TotalLoggedHoursSum__c,
                       EstimatedStartDevDate__c, EstimatedEndDevDate__c
                FROM WorkItem__c
                WHERE Id IN :treeIds
                WITH SYSTEM_MODE
                LIMIT 5000
            ];

            ProjectForecast f = new ProjectForecast();
            f.rootWorkItemId = workItemId;
            f.totalEstimatedHours = 0;
            f.totalLoggedHours = 0;
            f.earliestStart = null;
            f.latestEnd = null;

            for (WorkItem__c wi : tree) {
                if (wi.EstimatedHoursNumber__c != null) {
                    f.totalEstimatedHours += wi.EstimatedHoursNumber__c;
                }
                if (wi.TotalLoggedHoursSum__c != null) {
                    f.totalLoggedHours += wi.TotalLoggedHoursSum__c;
                }
                if (wi.EstimatedStartDevDate__c != null
                    && (f.earliestStart == null || wi.EstimatedStartDevDate__c < f.earliestStart)) {
                    f.earliestStart = wi.EstimatedStartDevDate__c;
                }
                if (wi.EstimatedEndDevDate__c != null
                    && (f.latestEnd == null || wi.EstimatedEndDevDate__c > f.latestEnd)) {
                    f.latestEnd = wi.EstimatedEndDevDate__c;
                }
            }
            f.hasEstimate = f.totalEstimatedHours > 0;

            f.history = buildWeeklyHistory(treeIds, f);

            populateVelocityStats(f);

            populateProjection(f);

            return f;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description BFS walk over ParentWorkItemLookup__c. Capped at MAX_TREE_DEPTH.
     */
    /**
     * @description Rounds a Decimal up to the nearest whole number, clamping to ≥ 1.
     *              Wraps the round-then-cast dance and keeps the projection math readable.
     */
    private static Integer clampPositive(Decimal value) {
        if (value == null || value <= 1) {
            return 1;
        }
        Long rounded = value.round(System.RoundingMode.HALF_UP);
        if (rounded < 1) {
            return 1;
        }
        if (rounded > 10000) {
            return 10000;
        }
        return rounded.intValue();
    }

    private static Set<Id> walkDescendants(Id rootId) {
        Set<Id> collected = new Set<Id>{ rootId };
        Set<Id> frontier = new Set<Id>{ rootId };
        for (Integer depth = 0; depth < MAX_TREE_DEPTH && !frontier.isEmpty(); depth++) {
            Set<Id> next = new Set<Id>();
            for (WorkItem__c child : [
                SELECT Id
                FROM WorkItem__c
                WHERE ParentWorkItemLookup__c IN :frontier
                WITH SYSTEM_MODE
                LIMIT 5000
            ]) {
                if (!collected.contains(child.Id)) {
                    collected.add(child.Id);
                    next.add(child.Id);
                }
            }
            frontier = next;
        }
        return collected;
    }

    /**
     * @description Aggregates WorkLog rows into weekly buckets (Mondays). Window
     *              extends from the earliest log to today. Returns empty list when
     *              the tree has no logs.
     */
    private static List<WeeklyPoint> buildWeeklyHistory(Set<Id> treeIds, ProjectForecast f) {
        if (treeIds.isEmpty()) {
            return new List<WeeklyPoint>();
        }
        List<AggregateResult> rows = [
            SELECT CALENDAR_YEAR(WorkDateDate__c) y,
                   WEEK_IN_YEAR(WorkDateDate__c) w,
                   MIN(WorkDateDate__c) minDate,
                   SUM(HoursLoggedNumber__c) total
            FROM WorkLog__c
            WHERE WorkItemLookup__c IN :treeIds
            WITH SYSTEM_MODE
            GROUP BY CALENDAR_YEAR(WorkDateDate__c), WEEK_IN_YEAR(WorkDateDate__c)
            ORDER BY CALENDAR_YEAR(WorkDateDate__c), WEEK_IN_YEAR(WorkDateDate__c)
            LIMIT 5000
        ];

        if (rows.isEmpty()) {
            return new List<WeeklyPoint>();
        }

        Map<Date, Decimal> hoursByWeek = new Map<Date, Decimal>();
        Date earliestWeek = null;
        for (AggregateResult ar : rows) {
            Date minDate = (Date) ar.get('minDate');
            if (minDate == null) {
                continue;
            }
            Date weekStart = minDate.toStartOfWeek();
            Decimal total = (Decimal) ar.get('total');
            if (total == null) {
                total = 0;
            }
            Decimal existing = hoursByWeek.containsKey(weekStart) ? hoursByWeek.get(weekStart) : 0;
            hoursByWeek.put(weekStart, existing + total);
            if (earliestWeek == null || weekStart < earliestWeek) {
                earliestWeek = weekStart;
            }
        }

        Date todayWeek = Date.today().toStartOfWeek();
        List<WeeklyPoint> out = new List<WeeklyPoint>();
        Decimal cumulative = 0;
        Date cursor = earliestWeek;
        Integer guard = 0;
        while (cursor <= todayWeek && guard < MAX_HISTORY_WEEKS) {
            Decimal weeklyHours = hoursByWeek.containsKey(cursor) ? hoursByWeek.get(cursor) : 0;
            cumulative += weeklyHours;
            WeeklyPoint p = new WeeklyPoint();
            p.weekStart = String.valueOf(cursor);
            p.hoursThisWeek = weeklyHours;
            p.cumulativeHours = cumulative;
            p.scopeHours = f.totalEstimatedHours;
            out.add(p);
            cursor = cursor.addDays(DAYS_PER_WEEK);
            guard++;
        }
        return out;
    }

    /**
     * @description Computes rolling-window mean + std-dev velocity. Stores into f.
     *              When history < 2 weeks, velocity is 0 and hasVelocity is false.
     */
    private static void populateVelocityStats(ProjectForecast f) {
        f.currentVelocityHoursPerWeek = 0;
        f.velocityStdDev = 0;
        f.hasVelocity = false;
        if (f.history == null || f.history.isEmpty()) {
            return;
        }

        Integer windowSize = Math.min(VELOCITY_WINDOW_WEEKS, f.history.size());
        if (windowSize < 2) {
            // Single week of data — use it as a point estimate but don't claim confidence.
            f.currentVelocityHoursPerWeek = f.history[f.history.size() - 1].hoursThisWeek;
            return;
        }

        Decimal sum = 0;
        Integer startIdx = f.history.size() - windowSize;
        for (Integer i = startIdx; i < f.history.size(); i++) {
            sum += f.history[i].hoursThisWeek;
        }
        Decimal mean = (sum / windowSize).setScale(3, System.RoundingMode.HALF_UP);

        Decimal sumSquaredDeviations = 0;
        for (Integer i = startIdx; i < f.history.size(); i++) {
            Decimal delta = f.history[i].hoursThisWeek - mean;
            sumSquaredDeviations += delta * delta;
        }
        Decimal variance = sumSquaredDeviations / windowSize;
        Decimal stdDev = Decimal.valueOf(Math.sqrt(variance.doubleValue())).setScale(3, System.RoundingMode.HALF_UP);

        f.currentVelocityHoursPerWeek = mean;
        f.velocityStdDev = stdDev;
        f.hasVelocity = mean > 0;
    }

    /**
     * @description Extrapolates the cumulative actual line at velocity slope to the
     *              scope intersection. Populates projectedFinalHours, weeksRemaining,
     *              projectedCompletionDate, confidence band dates, and the projection
     *              list (week-by-week future buckets).
     */
    private static void populateProjection(ProjectForecast f) {
        f.projection = new List<WeeklyPoint>();
        f.projectedFinalHours = f.totalLoggedHours;
        f.weeksRemaining = 0;
        f.projectedCompletionDate = null;
        f.confidenceLowDate = null;
        f.confidenceHighDate = null;
        f.isOverBudgetTrajectory = false;

        if (!f.hasEstimate || !f.hasVelocity || f.history.isEmpty()) {
            return;
        }

        Decimal remainingScope = f.totalEstimatedHours - f.totalLoggedHours;
        if (remainingScope <= 0) {
            // Already at or past scope — completed (or overshot).
            f.weeksRemaining = 0;
            f.projectedCompletionDate = Date.today();
            f.projectedFinalHours = f.totalLoggedHours;
            f.isOverBudgetTrajectory = f.totalLoggedHours > f.totalEstimatedHours;
            return;
        }

        Decimal weeksToFinishMean = remainingScope / f.currentVelocityHoursPerWeek;
        f.weeksRemaining = weeksToFinishMean.setScale(2, System.RoundingMode.HALF_UP);

        Integer weeksMean = clampPositive(weeksToFinishMean);
        f.projectedCompletionDate = Date.today().toStartOfWeek().addDays(weeksMean * DAYS_PER_WEEK);

        Decimal velocityFloor = 0.01;
        Decimal lowVelocity = f.currentVelocityHoursPerWeek - f.velocityStdDev;
        if (lowVelocity < velocityFloor) {
            lowVelocity = velocityFloor;
        }
        Decimal highVelocity = f.currentVelocityHoursPerWeek + f.velocityStdDev;
        if (highVelocity < velocityFloor) {
            highVelocity = velocityFloor;
        }
        // Lower velocity → longer to finish → later confidenceHighDate.
        Integer weeksHigh = clampPositive(remainingScope / lowVelocity);
        Integer weeksLow = clampPositive(remainingScope / highVelocity);
        f.confidenceLowDate = Date.today().toStartOfWeek().addDays(weeksLow * DAYS_PER_WEEK);
        f.confidenceHighDate = Date.today().toStartOfWeek().addDays(weeksHigh * DAYS_PER_WEEK);

        f.projectedFinalHours = f.totalLoggedHours + remainingScope;

        // Over-budget if the project's planned end date is BEFORE the velocity-extrapolated
        // completion date — i.e., we'll run past the deadline at current pace.
        if (f.latestEnd != null && f.projectedCompletionDate > f.latestEnd) {
            f.isOverBudgetTrajectory = true;
        }

        // Build week-by-week projection points so the LWC can render the dashed line.
        Decimal cumulative = f.totalLoggedHours;
        Date cursor = Date.today().toStartOfWeek().addDays(DAYS_PER_WEEK);
        Integer guard = 0;
        while (cumulative < f.totalEstimatedHours && guard < MAX_HISTORY_WEEKS) {
            cumulative += f.currentVelocityHoursPerWeek;
            if (cumulative > f.totalEstimatedHours) {
                cumulative = f.totalEstimatedHours;
            }
            WeeklyPoint p = new WeeklyPoint();
            p.weekStart = String.valueOf(cursor);
            p.hoursThisWeek = f.currentVelocityHoursPerWeek;
            p.cumulativeHours = cumulative;
            p.scopeHours = f.totalEstimatedHours;
            f.projection.add(p);
            cursor = cursor.addDays(DAYS_PER_WEEK);
            guard++;
        }
    }
}
