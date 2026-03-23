/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryContentDocumentLinkTrigger on ContentDocumentLink (after insert) { //NOPMD - AvoidLogicInTrigger: trivial guard + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryContentDocLinkTriggerHandler.handleAfterInsert(Trigger.new);
    }
}