public with sharing class JiraCallout {

     private static boolean hasAlreadyRun = false;
     public static HttpResponse httpHelper(String endpoint, String method, String body) {
         
        //  
         
        try {
            Sync_In_Propgress__c setting = Sync_In_Propgress__c.getOrgDefaults();
            if (setting == null) {
                setting = new Sync_In_Propgress__c(Salesforce_to_jira__c = true); // Or appropriate default name
            }
            if (setting.Salesforce_to_jira__c != true) {
                setting.Salesforce_to_jira__c = true;
                upsert setting; // Use upsert for safety
                System.debug('Salesforce-to-Jira sync flag set to TRUE.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to set sync flag to true: ' + e.getMessage());
            // Depending on requirements, you may want to stop here.
            throw new CalloutException('Could not set the sync flag before making a callout. ' + e.getMessage());
        }

        hasAlreadyRun = true;
        
        try {
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            if (body != null) {
                req.setBody(body);
                req.setHeader('Content-Type', 'application/json');
            }
            req.setMethod(method);
            req.setEndpoint('callout:Jira/' + endpoint);

            // 2. Make the actual callout.
            HttpResponse res = h.send(req);
            System.debug('Jira response received: ' + res.getStatusCode());
            return res;

        } finally {
            // 3. Enqueue a job to set the flag back to FALSE.
            // This runs in a separate transaction, avoiding CPU limits.
            // We use a check to prevent chaining queueable jobs if not needed.
            if (!System.isQueueable() && !System.isBatch()) {
                System.enqueueJob(new UnsetSyncFlagQueueable());
                System.debug('Enqueued job to unset sync flag.');
            }
        }
    }

    // --- All methods below are updated to include the full API path ---

    public static HttpResponse getProject(String key) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        return httpHelper('rest/api/3/project/' + key, 'GET', null);
    }

    public static HttpResponse createProject(String body) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        return httpHelper('rest/api/3/project', 'POST', body);
    }

    public static HttpResponse updateProject(String projectId, String body) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        return httpHelper('rest/api/3/project/' + projectId, 'PUT', body);
    }

    public static HttpResponse getUser(String email) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        return httpHelper('rest/api/3/user/search?query=' + email, 'GET', null);
    }

    public static HttpResponse createVersion(String version) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        return httpHelper('rest/api/3/version', 'POST', version);
    }

    public static HttpResponse getIssues(Map<String, String> params) {
        
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        
        // FIXED: Added the API path prefix
        String endpoint = 'rest/api/3/search?';
        for (String key : params.keySet()) {
            endpoint += key + '=' + params.get(key) + '&';
        }
        return httpHelper(endpoint, 'GET', null);
    }

    public static List<Map<String, Object>> queryIssues(String jql) {
        // FIXED: Added the API path prefix
        String endpoint = 'rest/api/3/search?jql=' + EncodingUtil.urlEncode(jql, 'UTF-8') + '&maxResults=50';
        HttpResponse res = httpHelper(endpoint, 'GET', null);
    
        if (res == null || res.getStatusCode() != 200) {
            throw new AuraHandledException('Jira query failed: ' + (res == null ? 'No response' : res.getBody()));
        }
    
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> issuesRaw = (List<Object>) body.get('issues');
        List<Map<String, Object>> issues = new List<Map<String, Object>>();
    
        for (Object obj : issuesRaw) {
            issues.add((Map<String, Object>) obj);
        }
        return issues;
    }
    
    public static HttpResponse addComment(String jiraKey, String adfJsonBody) {
        
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        
        String fullRequestBody = '{"body": ' + adfJsonBody + '}';
        // FIXED: Added the API path prefix
        String relativeEndpoint = 'rest/api/3/issue/' + jiraKey + '/comment';
        return httpHelper(relativeEndpoint, 'POST', fullRequestBody);
    }
    
    // This method does not use the httpHelper, so its endpoint must also be corrected.
    public static HttpResponse addAttachment(String jiraKey, String filename, Blob fileBody) {
        
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug('JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
            // Return a dummy "Forbidden" response to prevent a NullPointerException in the calling code.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        
        // FIXED: Endpoint now correctly builds the full path.
        String endpoint = 'callout:Jira/rest/api/3/issue/' + jiraKey + '/attachments';
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endpoint);

        req.setHeader('X-Atlassian-Token', 'no-check');
        String boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW';
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        String bodyStart = '--' + boundary + '\r\n' +
                         'Content-Disposition: form-data; name="file"; filename="' + filename + '"\r\n' +
                         'Content-Type: application/octet-stream\r\n\r\n';
        String bodyEnd = '\r\n--' + boundary + '--';
        Blob requestBody = Blob.valueOf(bodyStart + EncodingUtil.base64Encode(fileBody) + bodyEnd);
        req.setBodyAsBlob(requestBody);
        req.setTimeout(120000);

        return http.send(req);
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

   
}