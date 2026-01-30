/**
 * @description Centralized service for handling Delivery Hub HTTP callouts.
 * Replaces disparate Http logic in Sender and CommentController.
 */
public inherited sharing class DeliveryHubCalloutService {

    /**
     * @description Generic POST method for JSON payloads.
     * @param endpointUrl The full URL or Named Credential (e.g. 'callout:Mothership/...')
     * @param payload The object to serialize as JSON.
     * @return HttpResponse
     */
    public static HttpResponse post(String endpointUrl, Object payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(120000); // 2 minute timeout
        
        return new Http().send(req);
    }
    
    /**
     * @description Helper to normalize base URLs (ensures trailing slash).
     */
    public static String getBaseUrl(String specificUrl, String defaultUrl) {
        String url = String.isNotBlank(specificUrl) ? specificUrl : defaultUrl;
        if (!url.endsWith('/')) {
            url += '/';
        }
        return url;
    }
}