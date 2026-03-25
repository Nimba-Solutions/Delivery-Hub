/**
 * @author Cloud Nimbus LLC
 */
trigger DeliverySyncEventTrigger on DeliverySync__e (after insert) { //NOPMD - AvoidLogicInTrigger: single-line delegation only
    DeliveryWebhookNotifier.enqueueSyncEvents(Trigger.new);
}
