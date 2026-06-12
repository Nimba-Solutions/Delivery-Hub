/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Canonical resolver for the org-default approver ids configured
 *               on DeliveryHubSettings__c (ApproverUserIdTxt__c primary,
 *               ApproverBackupUserIdTxt__c backup). Custom settings cannot
 *               hold lookups, so both are Text(18) fields parsed with the
 *               shared trim + Id.valueOf + WARN-and-null-on-bad idiom.
 *               Extracted from the private copies that had drifted into
 *               DeliveryWorkCapEnforcementService and
 *               DeliveryNotificationService (generalizability audit 2026-06).
 *               DeliveryWorkApprovalService keeps its own settings-param
 *               variants — that class is owned by a parallel change and is
 *               deliberately untouched here.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryApproverService {

    /**
     * @description Resolves the org-default PRIMARY approver from
     *              DeliveryHubSettings__c.ApproverUserIdTxt__c org defaults.
     *              Blank or malformed values resolve to null with a WARN so
     *              callers can skip silently — approver configuration is
     *              settings-optional everywhere it is consumed.
     * @return The configured approver's user id, or null when unset/invalid.
     */
    public static Id resolveDefaultApproverId() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return parseUserId(
            settings == null ? null : settings.ApproverUserIdTxt__c,
            'resolveDefaultApproverId');
    }

    /**
     * @description Resolves the optional BACKUP approver from
     *              DeliveryHubSettings__c.ApproverBackupUserIdTxt__c org
     *              defaults — same parse-and-tolerate idiom as the primary.
     *              The backup may decide pending requests but is never
     *              auto-assigned and gets no submit pings.
     * @return The configured backup approver's user id, or null when
     *         unset/invalid.
     */
    public static Id resolveBackupApproverId() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return parseUserId(
            settings == null ? null : settings.ApproverBackupUserIdTxt__c,
            'resolveBackupApproverId');
    }

    /**
     * @description Shared Text(18) → Id parse: trim, Id.valueOf, WARN + null
     *              on anything malformed. Never throws.
     * @param raw The raw settings text value (may be null/blank).
     * @param context Caller label for the WARN log line.
     * @return The parsed user id, or null.
     */
    private static Id parseUserId(String raw, String context) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Id.valueOf(raw.trim());
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryApproverService.' + context + '] bad id in settings: '
                + e.getMessage());
            return null;
        }
    }
}
