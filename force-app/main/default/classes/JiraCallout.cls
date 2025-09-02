public with sharing class JiraCallout {
    
    private static boolean hasAlreadyRun = false;
    //  public static HttpResponse httpHelper(String endpoint, String method, String body) {
    
    //     //  
    
    //     // Skip sync flag operations in test context to avoid DML before callout
    //     if (!Test.isRunningTest()) {
    //         try {
    //             Sync_In_Propgress__c setting = Sync_In_Propgress__c.getOrgDefaults();
    //             if (setting == null) {
    //                 setting = new Sync_In_Propgress__c(SalesforceToJiraBool__c = true); // Or appropriate default name
    //             }
    //             if (setting.SalesforceToJiraBool__c != true) {
    //                 setting.SalesforceToJiraBool__c = true;
    //                 upsert setting; // Use upsert for safety
    //                 System.debug('Salesforce-to-Jira sync flag set to TRUE.');
    //             }
    //         } catch (Exception e) {
    //             System.debug(LoggingLevel.ERROR, 'Failed to set sync flag to true: ' + e.getMessage());
    //             // Depending on requirements, you may want to stop here.
    //             throw new CalloutException('Could not set the sync flag before making a callout. ' + e.getMessage());
    //         }
    //     }
    
    //     hasAlreadyRun = true;
    
    //     try {
    //         Http h = new Http();
    //         HttpRequest req = new HttpRequest();
    //         if (body != null) {
    //             req.setBody(body);
    //             req.setHeader('Content-Type', 'application/json');
    //         }
    //         req.setMethod(method);
    //         req.setEndpoint('callout:Jira/' + endpoint);
    
    //         // 2. Make the actual callout.
    //         HttpResponse res = h.send(req);
    //         System.debug('Jira response received: ' + res.getStatusCode());
    //         return res;
    
    //     } finally {
    //         // 3. Enqueue a job to set the flag back to FALSE.
    //         // This runs in a separate transaction, avoiding CPU limits.
    //         // We use a check to prevent chaining queueable jobs if not needed.
    //         // Skip in test context to avoid complications
    //         if (!Test.isRunningTest() && !System.isQueueable() && !System.isBatch()) {
    //             System.enqueueJob(new UnsetSyncFlagQueueable());
    //             System.debug('Enqueued job to unset sync flag.');
    //         }
    //     }
    // }
    
    public static HttpResponse httpHelper(String endpoint, String method, String body) {
        
        // --- CHANGE: Fetch configuration from Custom Settings ---
        // Retrieve Jira URL and credentials from a centralized custom setting.
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        
        // Validate that the custom settings are properly configured.
        if (settings == null || String.isBlank(settings.JIRAInstanceUrl__c) || 
            String.isBlank(settings.JIRA_Username__c) || String.isBlank(settings.JIRA_API_Token__c)) {
                
                System.debug(LoggingLevel.ERROR, 'Jira configuration is missing in Delivery_Hub_Settings__c.');
                throw new CalloutException('Jira instance URL, username, or API token not configured in Custom Settings.');
            }
        
        // Skip sync flag operations in test context to avoid DML before callout.
        if (!Test.isRunningTest()) {
            try {
                Sync_In_Propgress__c setting = Sync_In_Propgress__c.getOrgDefaults();
                if (setting == null) {
                    setting = new Sync_In_Propgress__c(SalesforceToJiraBool__c = true);
                }
                if (setting.SalesforceToJiraBool__c != true) {
                    setting.SalesforceToJiraBool__c = true;
                    upsert setting;
                    System.debug(LoggingLevel.DEBUG, 'Salesforce-to-Jira sync flag set to TRUE.');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to set sync flag to true: ' + e.getMessage());
                throw new CalloutException('Could not set the sync flag before making a callout. ' + e.getMessage());
            }
        }
        
        hasAlreadyRun = true;
        
        try {
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            
            // --- CHANGE: Dynamically construct the full endpoint URL ---
            // This replaces the hardcoded 'callout:Jira/' from Named Credentials.
            String fullEndpoint = settings.JIRAInstanceUrl__c.removeEnd('/') + '/' + endpoint.removeStart('/');
            req.setEndpoint(fullEndpoint);
            System.debug(LoggingLevel.DEBUG, 'Making callout to endpoint: ' + fullEndpoint);
            
            // --- CHANGE: Set Authorization Header from Custom Settings ---
            // Manually create the Basic Authentication header.
            String jiraUsername = settings.JIRA_Username__c;
            String apiToken = settings.JIRA_API_Token__c;
            String basicAuth = jiraUsername + ':' + apiToken;
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(basicAuth)));
            
            if (body != null) {
                req.setBody(body);
                req.setHeader('Content-Type', 'application/json');
            }
            req.setMethod(method);
            req.setTimeout(120000); // Set a generous timeout for API calls.
            
            // Make the actual callout.
            HttpResponse res = h.send(req);
            System.debug(LoggingLevel.DEBUG, 'Jira response received: ' + res.getStatusCode());
            return res;
            
        } finally {
            // Enqueue a job to set the sync flag back to FALSE in a separate transaction.
            if (!Test.isRunningTest() && !System.isQueueable() && !System.isBatch()) {
                System.enqueueJob(new UnsetSyncFlagQueueable());
                System.debug(LoggingLevel.DEBUG, 'Enqueued job to unset sync flag.');
            }
        }
    }
    
    // --- All methods below are updated to include the full API path ---
    
    public static HttpResponse getProject(String key) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            
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
    
    /**
     * @description Updates an existing comment in Jira with new content
     * @param jiraKey The Jira issue key (e.g., 'DHS-123')
     * @param jiraCommentId The unique identifier of the comment to update
     * @param adfJsonBody The comment content in Atlassian Document Format (ADF) JSON
     * @return HttpResponse The response from the Jira API
     */
    public static HttpResponse updateComment(String jiraKey, String jiraCommentId, String adfJsonBody) {
        if (UserInfo.getName() == 'Delivery Hub Site Guest User') {
            System.debug(LoggingLevel.WARN, 'JiraCallout blocked for the "Delivery Hub Site Guest User".');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setStatus('Forbidden');
            res.setBody('{"error": "Jira callouts are not permitted for this user."}');
            return res;
        }
        
        // The body format for updating is the same as for creating
        String fullRequestBody = '{"body": ' + adfJsonBody + '}';
        
        // The endpoint requires BOTH the issue key and the comment ID
        String relativeEndpoint = 'rest/api/3/issue/' + jiraKey + '/comment/' + jiraCommentId;
        
        // Use the PUT method for updates
        return httpHelper(relativeEndpoint, 'PUT', fullRequestBody);
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
    
    /**
     * @description Retrieves available transitions for a Jira issue
     * @param issueKey The Jira issue key (e.g., 'DHS-123')
     * @return HttpResponse The response containing available transitions from the Jira API
     */
    public static HttpResponse getTransitions(String issueKey) {
        String relativeEndpoint = 'rest/api/3/issue/' + issueKey + '/transitions';
        return httpHelper(relativeEndpoint, 'GET', null);
    }
    
    public static HttpResponse transitionIssue(String issueKey, String transitionId) {
        String body = JSON.serialize(new Map<String, Object>{
            'transition' => new Map<String, String>{
                'id' => transitionId
                    }
        });
        
        String relativeEndpoint = 'rest/api/3/issue/' + issueKey + '/transitions';
        return httpHelper(relativeEndpoint, 'POST', body);
    }
}