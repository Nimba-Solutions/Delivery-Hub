/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryDocEventTrigger on DeliveryDocEvent__e (after insert) { //NOPMD - AvoidLogicInTrigger: single-line delegation only
    DeliveryWebhookNotifier.enqueueDocEvents(Trigger.new);
}
