/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Single source of truth for team capacity (DECISION-G3, Wave 5).
 *               `DeveloperCapacity__mdt` is THE capacity store: one row per developer
 *               (DeveloperUserIdTxt__c set) or per team pool (no user id), with
 *               MonthlyCapacityHoursNumber__c as the canonical number (the packaged
 *               seed row "Delivery Team" carries 1000 h/mo, derived from the TeamPool
 *               convention "Delivery Team|Development|1000"). Every capacity-reading
 *               surface resolves through this class so the numbers cannot drift:
 *               the buyer capacity slider (deliveryCapacityForecast), the velocity
 *               projection's capacity floor (DeliveryVelocityService), and the
 *               velocity dashboard's utilization panel (row resolution helpers).
 *
 *               FALLBACK CONTRACT (explicit, never a silent near-zero): when a
 *               subscriber org has NO DeveloperCapacity__mdt rows for the requested
 *               scope, getTeamCapacity returns the historical slider model —
 *               3 developer-equivalents × 160 h/dev-month = 480 h/mo — flagged with
 *               isConfigured=false so consumers can label the number as a default.
 *               Unconfigured orgs therefore keep the exact pre-G3 slider behavior.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.AvoidGlobalModifier')
global with sharing class DeliveryCapacityService {

    /** @description Average weeks per month (52 / 12) for monthly ↔ weekly conversion. */
    private static final Decimal WEEKS_PER_MONTH = 52.0 / 12.0;

    /** @description Percent divisor for AllocationPercentNumber__c scaling. */
    private static final Decimal PERCENT_DIVISOR = 100.0;

    /** @description Legacy default when a row has neither monthly nor weekly hours. */
    private static final Decimal DEFAULT_WEEKLY_HOURS = 40;

    /** @description Modeling unit for developer-equivalents — one dev-month ≈ 160h
     *               (the buyer slider's historical hardcoded unit, kept as the unit
     *               so team-pool rows translate into a sensible slider scale). */
    @TestVisible
    private static final Decimal HOURS_PER_DEV_MONTH = 160;

    /** @description Dev-equivalents in the explicit no-CMT fallback (3 × 160 = 480 h/mo
     *               — the slider's historical default, NOT a near-zero). */
    @TestVisible
    private static final Integer FALLBACK_DEVELOPER_EQUIVALENTS = 3;

    /** @description Test injection point — DeveloperCapacity__mdt rows cannot be
     *               inserted with DML in unit tests, and packaged seed rows ARE
     *               visible to tests, so deterministic tests inject here (empty
     *               list = simulate an unconfigured subscriber org). */
    @TestVisible
    private static List<DeveloperCapacity__mdt> capacityRowsOverride;

    /** @description Aggregated team capacity returned to LWC + Apex consumers. */
    global class TeamCapacity {
        /** @description Total effective team capacity, hours per month (allocation-scaled). */
        @AuraEnabled global Decimal monthlyCapacityHours;
        /** @description Total effective team capacity, hours per week (monthly × 12 / 52). */
        @AuraEnabled global Decimal weeklyCapacityHours;
        /** @description Developer-equivalents: per-dev rows count 1 each; team-pool rows
         *               count round(rowMonthly / 160), min 1. Drives the slider scale. */
        @AuraEnabled global Integer developerEquivalents;
        /** @description monthlyCapacityHours ÷ developerEquivalents — the slider's per-step size. */
        @AuraEnabled global Decimal perDeveloperMonthlyHours;
        /** @description true = numbers come from DeveloperCapacity__mdt rows;
         *               false = the documented explicit fallback (3 × 160 h/mo). */
        @AuraEnabled global Boolean isConfigured;
        /** @description Human-readable provenance for UI labels. */
        @AuraEnabled global String sourceLabel;
    }

    /**
     * @description Resolves the org's team capacity from DeveloperCapacity__mdt.
     * @param workflowType Optional WorkflowType__mdt DeveloperName filter (e.g.
     *                     'Software_Delivery'). Blank = all rows (whole-org capacity,
     *                     the buyer slider's scope).
     * @return TeamCapacity — CMT-derived when rows exist, else the explicit
     *         documented fallback (isConfigured=false). Never null, never near-zero.
     */
    @AuraEnabled(cacheable=true)
    global static TeamCapacity getTeamCapacity(String workflowType) {
        try {
            List<DeveloperCapacity__mdt> rows = queryRows(workflowType);
            if (rows.isEmpty()) {
                return fallbackCapacity();
            }

            Decimal monthlyTotal = 0;
            Integer devEquivalents = 0;
            for (DeveloperCapacity__mdt row : rows) {
                Decimal rowMonthly = monthlyHoursForRow(row);
                monthlyTotal += rowMonthly;
                if (String.isNotBlank(row.DeveloperUserIdTxt__c)) {
                    // A per-developer row is one developer, whatever its hours.
                    devEquivalents += 1;
                } else {
                    // A team-pool row translates to dev-equivalents at the 160 h/dev-month unit.
                    Long eq = (rowMonthly / HOURS_PER_DEV_MONTH).round(System.RoundingMode.HALF_UP);
                    devEquivalents += (eq < 1) ? 1 : eq.intValue();
                }
            }
            if (devEquivalents < 1) {
                devEquivalents = 1;
            }

            TeamCapacity result = new TeamCapacity();
            result.monthlyCapacityHours = monthlyTotal.setScale(2, System.RoundingMode.HALF_UP);
            result.weeklyCapacityHours = (monthlyTotal / WEEKS_PER_MONTH).setScale(2, System.RoundingMode.HALF_UP);
            result.developerEquivalents = devEquivalents;
            result.perDeveloperMonthlyHours = (monthlyTotal / devEquivalents).setScale(2, System.RoundingMode.HALF_UP);
            result.isConfigured = true;
            result.sourceLabel = 'DeveloperCapacity__mdt (' + rows.size()
                + (rows.size() == 1 ? ' record)' : ' records)');
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description The explicit no-CMT fallback: 3 developer-equivalents × 160 h/mo
     *              = 480 h/mo — the buyer slider's historical hardcoded model, so an
     *              unconfigured subscriber org sees NO behavior change, just an
     *              honest "default" label. Deliberately NOT near-zero (the pre-G3
     *              velocity-utilization panel read empty CMT as zeros — that silent
     *              near-zero is exactly what DECISION-G3 retires).
     */
    private static TeamCapacity fallbackCapacity() {
        TeamCapacity result = new TeamCapacity();
        result.developerEquivalents = FALLBACK_DEVELOPER_EQUIVALENTS;
        result.perDeveloperMonthlyHours = HOURS_PER_DEV_MONTH;
        result.monthlyCapacityHours = HOURS_PER_DEV_MONTH * FALLBACK_DEVELOPER_EQUIVALENTS;
        result.weeklyCapacityHours = (result.monthlyCapacityHours / WEEKS_PER_MONTH)
            .setScale(2, System.RoundingMode.HALF_UP);
        result.isConfigured = false;
        result.sourceLabel = 'Default (no DeveloperCapacity records configured)';
        return result;
    }

    /**
     * @description Raw DeveloperCapacity__mdt rows for a workflow scope. The shared
     *              query every capacity consumer goes through (velocity utilization
     *              included) so filters and test injection stay in one place.
     * @param workflowType Optional WorkflowTypeNameTxt__c filter; blank = all rows.
     * @return Matching rows; empty list when the org has none (fallback territory).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<DeveloperCapacity__mdt> queryRows(String workflowType) {
        if (capacityRowsOverride != null) {
            List<DeveloperCapacity__mdt> filtered = new List<DeveloperCapacity__mdt>();
            for (DeveloperCapacity__mdt row : capacityRowsOverride) {
                if (String.isBlank(workflowType) || row.WorkflowTypeNameTxt__c == workflowType) {
                    filtered.add(row);
                }
            }
            return filtered;
        }
        if (String.isBlank(workflowType)) {
            return [
                SELECT Label, DeveloperUserIdTxt__c, WeeklyCapacityHoursNumber__c,
                       MonthlyCapacityHoursNumber__c, AllocationPercentNumber__c,
                       WorkflowTypeNameTxt__c
                FROM DeveloperCapacity__mdt
                WITH SYSTEM_MODE
            ];
        }
        return [
            SELECT Label, DeveloperUserIdTxt__c, WeeklyCapacityHoursNumber__c,
                   MonthlyCapacityHoursNumber__c, AllocationPercentNumber__c,
                   WorkflowTypeNameTxt__c
            FROM DeveloperCapacity__mdt
            WHERE WorkflowTypeNameTxt__c = :workflowType
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description One row's UNSCALED weekly hours (allocation NOT applied — the
     *              utilization panel applies allocation itself). Monthly is the
     *              canonical number and wins; weekly is accepted for legacy rows;
     *              neither → the legacy 40 h/wk default.
     * @param row A DeveloperCapacity__mdt row.
     * @return Weekly capacity hours for the row.
     */
    public static Decimal weeklyHoursForRow(DeveloperCapacity__mdt row) {
        if (row.MonthlyCapacityHoursNumber__c != null && row.MonthlyCapacityHoursNumber__c > 0) {
            return (row.MonthlyCapacityHoursNumber__c / WEEKS_PER_MONTH)
                .setScale(2, System.RoundingMode.HALF_UP);
        }
        if (row.WeeklyCapacityHoursNumber__c != null && row.WeeklyCapacityHoursNumber__c > 0) {
            return row.WeeklyCapacityHoursNumber__c;
        }
        return DEFAULT_WEEKLY_HOURS;
    }

    /**
     * @description One row's EFFECTIVE monthly hours — monthly-first resolution
     *              (monthly wins; else weekly × 52/12; else 40 h/wk default), then
     *              scaled by AllocationPercentNumber__c (null → 100%).
     * @param row A DeveloperCapacity__mdt row.
     * @return Allocation-scaled monthly capacity hours for the row.
     */
    public static Decimal monthlyHoursForRow(DeveloperCapacity__mdt row) {
        Decimal monthly;
        if (row.MonthlyCapacityHoursNumber__c != null && row.MonthlyCapacityHoursNumber__c > 0) {
            monthly = row.MonthlyCapacityHoursNumber__c;
        } else if (row.WeeklyCapacityHoursNumber__c != null && row.WeeklyCapacityHoursNumber__c > 0) {
            monthly = row.WeeklyCapacityHoursNumber__c * WEEKS_PER_MONTH;
        } else {
            monthly = DEFAULT_WEEKLY_HOURS * WEEKS_PER_MONTH;
        }
        Decimal allocPct = row.AllocationPercentNumber__c != null
            ? row.AllocationPercentNumber__c : PERCENT_DIVISOR;
        return monthly * (allocPct / PERCENT_DIVISOR);
    }
}
