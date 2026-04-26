/**
 * @name         Delivery Hub
 * @license      BSL 1.1 - See LICENSE.md
 * @description  Trigger handler for SyncItem__c. The 4/26 GVS picklist-allowlist
 *               enforcement was removed because the GVS data wasn't reliably seeded
 *               across orgs and beta_create failed on empty-describe paths.
 *               Handler is a no-op for now; kept as the trigger callback target
 *               so the trigger declaration stays stable.
 * @author       Cloud Nimbus LLC
 */
public with sharing class DeliverySyncItemTriggerHandler {

    /**
     * @description Before insert/update hook. No-op after GVS deprecation.
     * @param records The new/updated SyncItem__c records from Trigger.new.
     */
    public static void onBeforeInsertOrUpdate(List<SyncItem__c> records) {
        // intentionally empty - picklist-allowlist enforcement deprecated 4/26
        if (records == null) {
            return;
        }
    }
}
