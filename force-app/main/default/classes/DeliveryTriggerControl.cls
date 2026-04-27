/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Provides static flags to enable or disable trigger-based
 *              after-logic (e.g., sync engine enqueue) at runtime.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryTriggerControl {

    // This is the switch. When true, the async logic runs. When false, it's skipped.
    public static Boolean runAfterLogic = true;

    // Inbound-sync ingestor sets this true around its insert/update DML so
    // before-insert handlers can skip receiver-side auto-population that would
    // overwrite source values (e.g. ActivatedDateTime__c on WorkItem__c).
    // Without this, every record sync'd into a subscriber org gets auto-activated
    // regardless of source state, which corrupts the Delivery Timeline view.
    public static Boolean inboundSyncContext = false;

    /**
     * @description Disables the after-trigger logic that enqueues jobs.
     */
    public static void disableAfterLogic() {
        runAfterLogic = false;
    }

    /**
     * @description Enables the after-trigger logic.
     */
    public static void enableAfterLogic() {
        runAfterLogic = true;
    }
}