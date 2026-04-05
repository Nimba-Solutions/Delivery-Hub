/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryActivityLogTrigger on ActivityLog__c (before insert, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only

    if (Trigger.isBefore && Trigger.isInsert) {
        DeliveryAuditChainService.setHashOnInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryAuditChainService.blockLegalHoldDeletion(Trigger.old);
    }
}
