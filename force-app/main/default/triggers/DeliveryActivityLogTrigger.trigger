/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryActivityLogTrigger on ActivityLog__c (before insert, before update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only

    if (Trigger.isBefore && Trigger.isInsert) {
        // Picklist GVS allowlist enforcement deprecated 4/26 — see DH PR for context.
        // GVS data wasn't reliably seeded across orgs and beta_create test gates
        // failed when describes returned empty allowlists. Trust the field
        // describe at runtime; rely on platform-level restricted=true (where
        // available) instead of trigger-layer enforcement.
        DeliveryAuditChainService.setHashOnInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryAuditChainService.blockLegalHoldDeletion(Trigger.old);
    }
}
