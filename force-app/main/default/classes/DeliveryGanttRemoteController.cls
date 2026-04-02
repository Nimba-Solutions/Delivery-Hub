/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  REST endpoint for the Gantt phone-as-remote-control feature.
 *               Receives orientation/gesture data from the mobile companion
 *               VF page and publishes a GanttRemoteEvent__e platform event
 *               so the LWC Gantt chart can react via empApi subscription.
 * @author Cloud Nimbus LLC
 */
@RestResource(urlMapping='/gantt-remote/*')
global with sharing class DeliveryGanttRemoteController {

    /**
     * @description Publishes a GanttRemoteEvent platform event from phone remote data.
     * @return 'ok' on success or 'error' on failure.
     */
    @HttpPost
    global static String publishEvent() {
        RestRequest req = RestContext.request;
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
            req.requestBody.toString()
        );

        GanttRemoteEvent__e evt = new GanttRemoteEvent__e();
        evt.ActionTxt__c = (String) body.get('action');
        evt.ValueTxt__c = (String) body.get('value');
        evt.SessionIdTxt__c = (String) body.get('sessionId');

        Database.SaveResult sr = EventBus.publish(evt);
        return sr.isSuccess() ? 'ok' : 'error';
    }
}
