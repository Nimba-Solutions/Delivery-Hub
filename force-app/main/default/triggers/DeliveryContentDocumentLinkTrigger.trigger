trigger DeliveryContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryContentDocumentLinkTriggerHandler.handleAfterInsert(Trigger.new);
    }
}