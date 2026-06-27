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

    // Inbound-request paths (e.g. the Report Issue ghost recorder) set this true
    // around their insert when the org runs intake-first (auto-activate off) so
    // the before-insert handler does NOT stamp ActivatedDateTime__c. That leaves
    // the new request un-activated → it lands in the Intake queue for triage
    // instead of appearing straight on the Board. Scoped per-insert: only the
    // path that sets it is affected; the board, cart, and every other creation
    // path keep their existing auto-activate behavior.
    public static Boolean suppressAutoActivate = false;

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