/**
 * @description Centralized service for handling Delivery Hub HTTP callouts.
 * FIXED: Removed Named Credential dependency. Now relies strictly on the provided URL.
 */
public inherited sharing class DeliveryHubCalloutService {

    /**
     * @description Generic GET method.
     */
    public static HttpResponse get(String endpointUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointUrl);
        req.setMethod('GET');
        req.setTimeout(60000); 
        return new Http().send(req);
    }

    /**
     * @description Generic POST method.
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
     * @description Helper to normalize URLs. 
     * Throws an exception if the URL is blank (since we aren't using Named Creds).
     */
    public static String getBaseUrl(String specificUrl) {
        if (String.isBlank(specificUrl)) {
            // Fail loudly so you know to fix the Network Entity record
            throw new CalloutException('Missing Endpoint URL. Check the Network Entity record.');
        }
        
        // Ensure URL ends with '/'
        return specificUrl.endsWith('/') ? specificUrl : specificUrl + '/';
    }

    /**
     * @description Overloaded method for backward compatibility, but ignores defaultUrl.
     */
    public static String getBaseUrl(String specificUrl, String unusedDefault) {
        return getBaseUrl(specificUrl);
    }
}