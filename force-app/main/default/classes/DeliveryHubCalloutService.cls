/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Centralized service for handling Delivery Hub HTTP callouts.
 * FIXED: Removed Named Credential dependency. Now relies strictly on the provided URL.
 * @author Cloud Nimbus LLC
 */
public inherited sharing class DeliveryHubCalloutService {

    /**
     * @description Generic GET method.
     * @param endpointUrl The fully qualified URL to send the GET request to.
     * @return HttpResponse The result of the callout.
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
     * @param endpointUrl The fully qualified URL to send the POST request to.
     * @param payload The data object to serialize into the JSON body.
     * @return HttpResponse The result of the callout.
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
     * @param specificUrl The raw URL string from the Network Entity.
     * @return String The normalized URL ending with a forward slash.
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
     * @param specificUrl The raw URL string from the Network Entity.
     * @param unusedDefault Legacy parameter, no longer used.
     * @return String The normalized URL ending with a forward slash.
     */
    public static String getBaseUrl(String specificUrl, String unusedDefault) {
        return getBaseUrl(specificUrl);
    }
}