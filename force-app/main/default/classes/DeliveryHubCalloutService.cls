/**
 * @description Centralized service for handling Delivery Hub HTTP callouts.
 */
public inherited sharing class DeliveryHubCalloutService {

    // Centralize the default named credential path here
    private static final String DEFAULT_NAMED_CRED = 'callout:Mothership/services/apexrest/delivery/deliveryhub/v1';

    /**
     * @description Generic POST method for JSON payloads.
     * @param endpointUrl The full URL.
     * @param payload The object to serialize.
     * @return HttpResponse
     */
    public static HttpResponse post(String endpointUrl, Object payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(120000); 
        return new Http().send(req);
    }
    
    /**
     * @description Simpler method: Only pass the specific URL. 
     * If blank, it automatically uses the stored Default Named Credential.
     * @param specificUrl The override URL (optional).
     * @return String The normalized URL.
     */
    public static String getBaseUrl(String specificUrl) {
        return getBaseUrl(specificUrl, DEFAULT_NAMED_CRED);
    }

    /**
     * @description Original method (kept for flexibility).
     * @param specificUrl The override URL.
     * @param defaultUrl The fallback URL.
     * @return String The normalized URL.
     */
    public static String getBaseUrl(String specificUrl, String defaultUrl) {
        String url = String.isNotBlank(specificUrl) ? specificUrl : defaultUrl;
        if (!url.endsWith('/')) {
            url += '/';
        }
        return url;
    }
}