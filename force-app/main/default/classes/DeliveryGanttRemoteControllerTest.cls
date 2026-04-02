/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryGanttRemoteController REST endpoint.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGanttRemoteControllerTest {

    @IsTest
    static void testPublishEvent_Success() {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'scroll',
            'value' => '{"x":10,"y":5}',
            'sessionId' => 'test-session-123'
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gantt-remote/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        String result = DeliveryGanttRemoteController.publishEvent();
        Test.stopTest();

        System.assertEquals('ok', result, 'Event should publish successfully');
    }

    @IsTest
    static void testPublishEvent_ZoomAction() {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'zoom',
            'value' => 'month',
            'sessionId' => 'session-456'
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gantt-remote/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        String result = DeliveryGanttRemoteController.publishEvent();
        Test.stopTest();

        System.assertEquals('ok', result, 'Zoom event should publish successfully');
    }

    @IsTest
    static void testPublishEvent_TapAction() {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'tap',
            'value' => '',
            'sessionId' => 'session-789'
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gantt-remote/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        String result = DeliveryGanttRemoteController.publishEvent();
        Test.stopTest();

        System.assertEquals('ok', result, 'Tap event should publish successfully');
    }

    @IsTest
    static void testPublishEvent_SwipeAction() {
        Map<String, Object> payload = new Map<String, Object>{
            'action' => 'swipe-left',
            'value' => '',
            'sessionId' => 'session-swipe'
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gantt-remote/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        String result = DeliveryGanttRemoteController.publishEvent();
        Test.stopTest();

        System.assertEquals('ok', result, 'Swipe event should publish successfully');
    }
}
