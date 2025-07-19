public with sharing class JiraCallout {

    /**
     * Makes an HTTP callout to Jira using the provided endpoint/method/body.
     */
    public static HttpResponse httpHelper(String endpoint, String method, String body) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        if (body != null) {
            req.setBody(body);
            System.debug(body);
            req.setHeader('Content-Type', 'application/json');
        }
        req.setMethod(method);
        req.setEndpoint('callout:Jira/' + endpoint);

        HttpResponse res = h.send(req);
        System.debug(res.getBody());
        return res;
    }

    public static HttpResponse getProject(String key) {
        return httpHelper('project/' + key, 'GET', null);
    }

    public static HttpResponse createProject(String body) {
        return httpHelper('project', 'POST', body);
    }

    public static HttpResponse updateProject(String projectId, String body) {
        return httpHelper('project/' + projectId, 'PUT', body);
    }

    public static HttpResponse getUser(String email) {
        return httpHelper('user/search?query=' + email, 'GET', null);
    }

    public static HttpResponse createVersion(String version) {
        return httpHelper('version', 'POST', version);
    }

    public static HttpResponse getIssues(Map<String, String> params) {
        String endpoint = 'search?';
        for (String key : params.keySet()) {
            endpoint += key + '=' + params.get(key) + '&';
        }
        return httpHelper(endpoint, 'GET', null);
    }

    /**
     * Returns a List<Map> of "issues" as if from Jira, for testing.
     */
    public static List<Map<String, Object>> queryIssues(String jql) {
        // Build endpoint for JQL search (returns up to 50 issues by default)
        // You can increase maxResults if you want, e.g., &maxResults=100
        String endpoint = 'search?jql=' + EncodingUtil.urlEncode(jql, 'UTF-8') + '&maxResults=50';
    
        HttpResponse res = httpHelper(endpoint, 'GET', null);
    
        if (res == null || res.getStatusCode() != 200) {
            throw new AuraHandledException('Jira query failed: ' + (res == null ? 'No response' : res.getBody()));
        }
    
        // Parse the returned JSON into a Map
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    
        List<Object> issuesRaw = (List<Object>) body.get('issues');
        List<Map<String, Object>> issues = new List<Map<String, Object>>();
    
        for (Object obj : issuesRaw) {
            issues.add((Map<String, Object>) obj);
        }
        return issues;
    }

    public static HttpResponse addComment(String jiraKey, String commentBody) {
        // Build endpoint for adding a comment to an issue
        String endpoint = 'issue/' + jiraKey + '/comment';

        // Create JSON body as plain text
		String bodyJson = buildADFCommentBody(commentBody);

        return httpHelper(endpoint, 'POST', bodyJson);
    }

    
    public static String buildADFCommentBody(String commentText) {
        Map<String, Object> textNode = new Map<String, Object>{
            'type' => 'text',
            'text' => commentText
        };
        Map<String, Object> paragraphNode = new Map<String, Object>{
            'type' => 'paragraph',
            'content' => new List<Object>{ textNode }
        };
        Map<String, Object> bodyNode = new Map<String, Object>{
            'type' => 'doc',
            'version' => 1,
            'content' => new List<Object>{ paragraphNode }
        };
        Map<String, Object> root = new Map<String, Object>{
            'body' => bodyNode
        };
        return JSON.serialize(root);
    }

    /**
     * @description Uploads a file to a Jira issue.
     * @param jiraKey The key of the Jira issue (e.g., 'DHS-123').
     * @param filename The name of the file being uploaded.
     * @param fileBody The Blob content of the file.
     * @return HttpResponse from the callout.
     */
    public static HttpResponse addAttachment(String jiraKey, String filename, Blob fileBody) {
        String endpoint = 'callout:Jira/issue/' + jiraKey + '/attachments';
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endpoint);

        // This header is required by Jira for attachments
        req.setHeader('X-Atlassian-Token', 'no-check');

        // Build the multipart form body
        String boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);

        String bodyStart = '--' + boundary + '\r\n' +
                         'Content-Disposition: form-data; name="file"; filename="' + filename + '"\r\n' +
                         'Content-Type: application/octet-stream\r\n\r\n';

        String bodyEnd = '\r\n--' + boundary + '--';

        // Combine the parts into a single blob for the request body
        Blob requestBody = Blob.valueOf(bodyStart);
        requestBody = Blob.valueOf(bodyStart).append(fileBody);
        requestBody = requestBody.append(Blob.valueOf(bodyEnd));

        req.setBodyAsBlob(requestBody);
        req.setTimeout(120000); // Set 2-minute timeout for large files

        return http.send(req);
    }

}