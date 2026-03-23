/**
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidLogicInTrigger') // trivial guard + handler delegation only
trigger DeliveryContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryContentDocLinkTriggerHandler.handleAfterInsert(Trigger.new);
    }
}