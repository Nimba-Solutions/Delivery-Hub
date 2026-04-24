/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryActivityLogTrigger on ActivityLog__c (before insert, before update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only

    if (Trigger.isBefore && Trigger.isInsert) {
        // Picklist allowlist integrity — GVS-backed but non-restricted due to SF retrofit block.
        for (ActivityLog__c rec : Trigger.new) {
            DeliveryPicklistIntegrityService.validate(rec, 'ActionTypePk__c', 'DeliveryActivityActionType');
        }
        DeliveryAuditChainService.setHashOnInsert(Trigger.new);
    }

    if (Trigger.isBefore && Trigger.isUpdate) {
        for (ActivityLog__c rec : Trigger.new) {
            DeliveryPicklistIntegrityService.validate(rec, 'ActionTypePk__c', 'DeliveryActivityActionType');
        }
    }

    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryAuditChainService.blockLegalHoldDeletion(Trigger.old);
    }
}
