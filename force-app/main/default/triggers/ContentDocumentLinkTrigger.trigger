trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        ContentDocumentLinkTriggerHandler.handleAfterInsert(Trigger.new);
    }
}