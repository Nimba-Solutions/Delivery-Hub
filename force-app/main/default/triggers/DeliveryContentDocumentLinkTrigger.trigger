/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryContentDocLinkTriggerHandler.handleAfterInsert(Trigger.new);
    }
}