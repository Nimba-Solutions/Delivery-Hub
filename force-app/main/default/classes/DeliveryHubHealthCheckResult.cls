/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  One row in the Delivery Hub health dashboard. Returned by
 *               DeliveryHubHealthService.runAllChecks and rendered as a
 *               card in deliveryHubHealthDashboard LWC.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ExcessiveParameterList')
public class DeliveryHubHealthCheckResult {
    @AuraEnabled public String checkKey;
    @AuraEnabled public String label;
    @AuraEnabled public String statusPk;
    @AuraEnabled public String detail;
    @AuraEnabled public String repairKey;
    @AuraEnabled public Datetime checkedAtDateTime;

    /**
     * @description Pass result with a short detail string.
     * @param checkKey Stable identifier (used by repair dispatch).
     * @param label Human-readable card title.
     * @param detail Short body text.
     * @return Populated HealthCheckResult with statusPk='pass'.
     */
    public static DeliveryHubHealthCheckResult pass(String checkKey, String label, String detail) {
        return build(checkKey, label, 'pass', detail, null);
    }

    /**
     * @description Warn result — configured but suboptimal.
     * @param checkKey Stable identifier.
     * @param label Human-readable card title.
     * @param detail Short body text.
     * @param repairKey Optional dispatch key for a repair button; null = no repair.
     * @return Populated HealthCheckResult with statusPk='warn'.
     */
    public static DeliveryHubHealthCheckResult warn(String checkKey, String label, String detail, String repairKey) {
        return build(checkKey, label, 'warn', detail, repairKey);
    }

    /**
     * @description Fail result — blocking issue requiring admin attention.
     * @param checkKey Stable identifier.
     * @param label Human-readable card title.
     * @param detail Short body text.
     * @param repairKey Optional dispatch key for a repair button; null = no repair.
     * @return Populated HealthCheckResult with statusPk='fail'.
     */
    public static DeliveryHubHealthCheckResult fail(String checkKey, String label, String detail, String repairKey) {
        return build(checkKey, label, 'fail', detail, repairKey);
    }

    private static DeliveryHubHealthCheckResult build(String checkKey, String label, String status, String detail, String repairKey) {
        DeliveryHubHealthCheckResult r = new DeliveryHubHealthCheckResult();
        r.checkKey = checkKey;
        r.label = label;
        r.statusPk = status;
        r.detail = detail;
        r.repairKey = repairKey;
        r.checkedAtDateTime = Datetime.now();
        return r;
    }

    /**
     * @description Attach (or change) a repair button on this result. Useful
     *              for pass results that nonetheless offer a maintenance
     *              action — e.g. "rules are configured; click to backfill
     *              existing users."
     * @param newRepairKey Repair dispatch key.
     * @return Same result (chainable).
     */
    public DeliveryHubHealthCheckResult withRepair(String newRepairKey) {
        this.repairKey = newRepairKey;
        return this;
    }
}
