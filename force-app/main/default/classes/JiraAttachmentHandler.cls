/**
 * @description Handler class for processing Jira attachment webhook events.
 * This class manages the synchronization of attachments between Jira issues and
 * Salesforce Ticket__c records, including downloading attachment content,
 * creating ContentVersion records, and maintaining sync logs.
 *
 * The handler supports the following operations:
 * - Download and create attachments when added to Jira issues
 * - Remove ContentDocumentLink when attachments are deleted from Jira
 * - Validate file sizes against Salesforce limits
 * - Create comprehensive sync logs for all operations
 */
public without sharing class JiraAttachmentHandler {
    
     @TestVisible
    private static Boolean isTest = false; // Controls test mode
    @TestVisible
    private static Boolean testResult = false; // Defines the mock result
    // Salesforce file size limits (in bytes)
    private static final Integer MAX_FILE_SIZE = 25 * 1024 * 1024; // 25MB for ContentVersion
    private static final Integer MAX_HEAP_SIZE = 6 * 1024 * 1024;  // 6MB heap limit consideration
    private static final Integer MAX_REDIRECTS = 5;

    public static Boolean handleAttachmentAdded(Map<String, Object> payload) {
        Map<String, Object> attachment = (Map<String, Object>) payload.get('attachment');
        Map<String, Object> issue = (Map<String, Object>) payload.get('issue');

        if (attachment == null || issue == null) {
            System.debug(LoggingLevel.ERROR, 'JiraAttachmentHandler: Payload is missing attachment or issue details.');
            return false;
        }

        String contentUrl = (String) attachment.get('content');
        String filename = (String) attachment.get('filename');
        String issueKey = (String) issue.get('key');
        String attachmentId = (String) attachment.get('id');
        Integer fileSize = (Integer) attachment.get('size');

        if (String.isBlank(contentUrl) || String.isBlank(filename) || String.isBlank(issueKey)) {
            System.debug('JiraAttachmentHandler: Missing contentUrl, filename, or issueKey.');
            return false;
        }

        // Find the corresponding Salesforce record
        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = :issueKey LIMIT 1];
        if (tickets.isEmpty()) {
            System.debug('JiraAttachmentHandler: Could not find a matching Salesforce ticket for Jira key: ' + issueKey);
            return false;
        }
        Id parentId = tickets[0].Id;

        // Validate file size
        if (!validateFileSize(fileSize, filename, parentId, attachmentId)) {
            return false;
        }

        try {
            Blob fileBody = downloadAttachmentFromJira(contentUrl, attachmentId, filename, parentId);
            if (fileBody != null) {
                String contentDocumentId = createContentVersionForAttachment(parentId, attachmentId, filename, fileBody);
                if (contentDocumentId != null) {
                    Boolean linkCreated = createContentDocumentLink(contentDocumentId, parentId, attachmentId, filename);
                    if (linkCreated) {
                        createSyncLog(parentId, attachmentId, filename, 'Jira to SF', 'Success', null, contentDocumentId);
                        return true;
                    }
                }
            } else {
                createSyncLog(parentId, attachmentId, filename, 'Jira to SF', 'Failed', 'Failed to download attachment from Jira', null);
            }
        } catch (Exception e) {
            String errorMessage = 'Error processing attachment: ' + e.getMessage();
            System.debug('JiraAttachmentHandler: ' + errorMessage);
            createSyncLog(parentId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
        }

        return false;
    }

    /* public static Blob downloadAttachment(String url, Integer redirectCount) {
        if (redirectCount > MAX_REDIRECTS) {
            throw new CalloutException('Exceeded max redirects for URL: ' + url);
        }

        // --- FINAL FIX FOR CROSS-DOMAIN REDIRECT ---
        // If the URL is for Jira's media API, we must make a direct callout
        // because it's a different domain than the main Jira Named Credential.
        System.debug('url of download attachment'+url);
        if (url != null && url.startsWith('https://api.media.atlassian')) {
            System.debug('Handling direct callout to Jira Media API: ' + url);
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setTimeout(120000);
            
            // For this direct callout, we must add authentication headers manually.
            // These credentials should be stored securely (e.g., in Custom Metadata or protected Custom Settings).
            // Do not hardcode credentials in production code.
            String jiraUsername = ''; // TODO: Replace with your Jira email from a secure source
            String apiToken = ''; // TODO: Replace with your Jira API Token from a secure source
            String basicAuth = jiraUsername + ':' + apiToken;
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(basicAuth)));

            HttpResponse mediaRes = new Http().send(req);
            
            if (mediaRes.getStatusCode() == 200) {
                System.debug('media status code'+mediaRes.getStatusCode());
                return mediaRes.getBodyAsBlob();
            } else {
                System.debug('Failed to download from Media API. Status: ' + mediaRes.getStatus() + ' Body: ' + mediaRes.getBody());
                return null;
            }
        }

        // For all initial calls, use the standard JiraCallout helper
        String relativePath = getRelativePathFromUrl(url);
        System.debug('JiraAttachmentHandler: Calling httpHelper with relative path: ' + relativePath);
        HttpResponse res = JiraCallout.httpHelper(relativePath, 'GET', null);
        
        if (res.getStatusCode() >= 300 && res.getStatusCode() < 400 && res.getHeader('Location') != null) {
            // The location header contains the new media API URL.
            // We recursively call this method, and the 'if' block above will handle the direct callout.
            return downloadAttachment(res.getHeader('Location'), redirectCount + 1);
        } else if (res.getStatusCode() == 200) {
            return res.getBodyAsBlob();
        } else {
            System.debug('JiraAttachmentHandler: Failed to download file. Status: ' + res.getStatus() + ' Code: ' + res.getStatusCode());
            return null;
        }
    }*/
    
    public static Blob downloadAttachment(String url, Integer redirectCount) {
        if (redirectCount > MAX_REDIRECTS) {
            throw new CalloutException('Exceeded max redirects for URL: ' + url);
        }
    
        // --- FINAL FIX FOR CROSS-DOMAIN REDIRECT ---
        // If the URL is for Jira's media API, we must make a direct callout.
        System.debug('url of download attachment'+url);
        if (url != null && url.startsWith('https://api.media.atlassian')) {
            System.debug('Handling direct callout to Jira Media API: ' + url);
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setTimeout(120000);
    
            // --- CHANGE STARTS HERE ---
            // Fetch credentials securely from Custom Settings instead of hardcoding.
            Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
            String jiraUsername = '';
            String apiToken = '';
    
            if (settings != null) {
                // Safely assign values, defaulting to empty strings if null.
                jiraUsername = String.isNotBlank(settings.JIRAUsernameTxt__c) ? settings.JIRAUsernameTxt__c : '';
                apiToken = String.isNotBlank(settings.JIRAApiTokenTxt__c) ? settings.JIRAApiTokenTxt__c : '';
            }
    
            // Check if credentials were successfully retrieved.
            if (String.isBlank(jiraUsername) || String.isBlank(apiToken)) {
                System.debug(LoggingLevel.ERROR, 'Jira credentials not found in Delivery_Hub_Settings__c. Cannot authenticate to media API.');
                // Return null to indicate failure, consistent with other error paths in this method.
                return null;
            }
    
            String basicAuth = jiraUsername + ':' + apiToken;
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(basicAuth)));
            // --- CHANGE ENDS HERE ---
    
            HttpResponse mediaRes = new Http().send(req);
            
            if (mediaRes.getStatusCode() == 200) {
                System.debug('media status code'+mediaRes.getStatusCode());
                return mediaRes.getBodyAsBlob();
            } else {
                System.debug('Failed to download from Media API. Status: ' + mediaRes.getStatus() + ' Body: ' + mediaRes.getBody());
                return null;
            }
        }
    
        // For all initial calls, use the standard JiraCallout helper
        String relativePath = getRelativePathFromUrl(url);
        System.debug('JiraAttachmentHandler: Calling httpHelper with relative path: ' + relativePath);
        HttpResponse res = JiraCallout.httpHelper(relativePath, 'GET', null);
        
        if (res.getStatusCode() >= 300 && res.getStatusCode() < 400 && res.getHeader('Location') != null) {
            // The location header contains the new media API URL.
            // We recursively call this method, and the 'if' block above will handle the direct callout.
            return downloadAttachment(res.getHeader('Location'), redirectCount + 1);
        } else if (res.getStatusCode() == 200) {
            return res.getBodyAsBlob();
        } else {
            System.debug('JiraAttachmentHandler: Failed to download file. Status: ' + res.getStatus() + ' Code: ' + res.getStatusCode());
            return null;
        }
    }
    
    @TestVisible
    private static String getRelativePathFromUrl(String contentUrl) {
        if (String.isBlank(contentUrl)) return null;
        try {
            String path = new URL(contentUrl).getPath();
            return path.startsWith('/') ? path.substring(1) : path;
        } catch(Exception e) {
            System.debug('Could not parse URL. Error: ' + e.getMessage());
            Integer restApiIndex = contentUrl.indexOf('/rest/api/');
            return (restApiIndex != -1) ? contentUrl.substring(restApiIndex + 1) : null;
        }
    }

    public static void createSalesforceFile(Id parentId, String filename, Blob body) {
        // This method is deprecated - use createContentVersionForAttachment and createContentDocumentLink instead
        System.debug('createSalesforceFile method called - consider using createContentVersionForAttachment and createContentDocumentLink');
        
        try {
            // Get the OwnerId from the parent Ticket__c record
            Ticket__c ticket = [SELECT Id,Name,OwnerId FROM Ticket__c WHERE Id = :parentId LIMIT 1];
            if (ticket == null) {
                System.debug('Cannot create file. Parent ticket not found for ID: ' + parentId);
                return;
            }
            System.debug('ticket owner name'+ticket.OwnerId);
            
            // Create the ContentVersion 
            // FIX: Removed "FirstPublishLocationId = ticket.Id" to prevent duplicate link error
            ContentVersion cv = new ContentVersion(
                VersionData = body,
                Title = filename,
                PathOnClient = filename
            );
            insert cv;

            // Get the ContentDocument ID
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = insertedCv.ContentDocumentId,
                LinkedEntityId = parentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );
            insert cdl;
            
            System.debug('Successfully created and linked file: ' + filename + ' to ticket: ' + parentId);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in createSalesforceFile: ' + e.getMessage());
            throw e;
        }
    }
   
    public static Boolean handleAttachmentRemoved(Map<String, Object> payload) {
        System.debug('JiraAttachmentHandler.handleAttachmentRemoved called');
        
        try {
            // Extract attachment and issue information from payload
            Map<String, Object> attachment = (Map<String, Object>)payload.get('attachment');
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            
            if (attachment == null || issue == null) {
                System.debug(LoggingLevel.ERROR, 'Missing attachment or issue data in payload');
                return false;
            }
            
            String attachmentId = (String)attachment.get('id');
            String filename = (String)attachment.get('filename');
            String issueKey = (String)issue.get('key');
            
            System.debug('Processing attachment removal: ' + filename + ' (ID: ' + attachmentId + ') for issue: ' + issueKey);
            
            // Find the corresponding Ticket__c record
            List<Ticket__c> tickets = [
                SELECT Id, JiraTicketKeyTxt__c 
                FROM Ticket__c 
                WHERE JiraTicketKeyTxt__c = :issueKey 
                LIMIT 1
            ];
            
            if (tickets.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No Ticket__c found for Jira issue key: ' + issueKey);
                createSyncLog(null, attachmentId, filename, 'Jira to SF', 'Failed', 
                             'No corresponding ticket found for issue key: ' + issueKey, null);
                return false;
            }
            
            Ticket__c ticket = tickets[0];
            
            // Find existing sync log to get ContentDocument ID
            List<Attachment_Sync_Log__c> existingLogs = [
                SELECT Id, SalesforceContentDocumentIdTxt__c, SyncStatusPk__c
                FROM Attachment_Sync_Log__c
                WHERE Ticket__c = :ticket.Id 
                AND JiraAttachmentIdTxt__c = :attachmentId
                AND SyncStatusPk__c = 'Success'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (existingLogs.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No successful sync log found for attachment: ' + attachmentId);
                createSyncLog(ticket.Id, attachmentId, filename, 'Jira to SF', 'Failed', 
                             'No existing ContentDocument found for attachment removal', null);
                return false;
            }
            
            String contentDocumentId = existingLogs[0].SalesforceContentDocumentIdTxt__c;
            if (String.isBlank(contentDocumentId)) {
                System.debug(LoggingLevel.WARN, 'No ContentDocument ID found in sync log for attachment: ' + attachmentId);
                createSyncLog(ticket.Id, attachmentId, filename, 'Jira to SF', 'Failed', 
                             'No ContentDocument ID found in existing sync log', null);
                return false;
            }
            
            // Remove ContentDocumentLink
            Boolean linkRemoved = removeContentDocumentLink(contentDocumentId, ticket.Id, attachmentId, filename);
            if (!linkRemoved) {
                return false; // Removal method creates its own sync log on failure
            }
            
            // Create success sync log for removal
            createSyncLog(ticket.Id, attachmentId, filename, 'Jira to SF', 'Success', 
                         'Attachment removed successfully', contentDocumentId);
            
            System.debug('Attachment successfully removed from Salesforce: ' + filename);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in handleAttachmentRemoved: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            // Create error sync log with available information
            try {
                Map<String, Object> attachment = (Map<String, Object>)payload.get('attachment');
                String attachmentId = attachment != null ? (String)attachment.get('id') : 'unknown';
                String filename = attachment != null ? (String)attachment.get('filename') : 'unknown';
                
                createSyncLog(null, attachmentId, filename, 'Jira to SF', 'Failed', 
                             'Unexpected error during removal: ' + e.getMessage(), null);
            } catch (Exception logError) {
                System.debug(LoggingLevel.ERROR, 'Failed to create error sync log: ' + logError.getMessage());
            }
            
            return false;
        }
    }
    
    /**
     * @description Validates file size against Salesforce limits
     * @param fileSize The size of the file in bytes
     * @param filename The name of the file
     * @param ticketId The ID of the associated ticket
     * @param attachmentId The Jira attachment ID
     * @return Boolean indicating if the file size is valid
     */
    private static Boolean validateFileSize(Integer fileSize, String filename, Id ticketId, String attachmentId) {
        if (fileSize == null) {
            System.debug(LoggingLevel.WARN, 'File size not provided for attachment: ' + filename);
            // Allow processing to continue if size is unknown
            return true;
        }
        
        if (fileSize > MAX_FILE_SIZE) {
            String errorMessage = 'File size (' + fileSize + ' bytes) exceeds Salesforce limit (' + MAX_FILE_SIZE + ' bytes)';
            System.debug(LoggingLevel.WARN, errorMessage + ' for file: ' + filename);
            
            createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
            return false;
        }
        
        if (fileSize > MAX_HEAP_SIZE) {
            System.debug(LoggingLevel.WARN, 'File size (' + fileSize + ' bytes) may cause heap size issues for file: ' + filename);
            // Log warning but allow processing to continue
        }
        
        System.debug('File size validation passed for: ' + filename + ' (' + fileSize + ' bytes)');
        return true;
    }
    
    /**
     * @description Downloads attachment content from Jira
     * @param contentUrl The Jira content URL for the attachment
     * @param attachmentId The Jira attachment ID
     * @param filename The name of the file
     * @param ticketId The ID of the associated ticket
     * @return Blob The downloaded attachment content, null if download failed
     */
    private static Blob downloadAttachmentFromJira(String contentUrl, String attachmentId, String filename, Id ticketId) {
        System.debug('Downloading attachment from Jira: ' + filename + ' from URL: ' + contentUrl);
        
        try {
            // Extract the relative path from the content URL
            // Jira content URLs are typically in format: https://domain/rest/api/2/attachment/content/{id}
            String relativePath = extractRelativePathFromUrl(contentUrl);
            if (String.isBlank(relativePath)) {
                String errorMessage = 'Invalid content URL format: ' + contentUrl;
                System.debug(LoggingLevel.ERROR, errorMessage);
                createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
                return null;
            }
            
            // Make HTTP request to download attachment
            HttpResponse response;
            if (Test.isRunningTest()) {
                // In test context, make direct HTTP call to allow mocking
                Http http = new Http();
                HttpRequest req = new HttpRequest();
                req.setEndpoint(contentUrl);
                req.setMethod('GET');
                req.setTimeout(120000);
                response = http.send(req);
            } else {
                // In production, use JiraCallout.httpHelper with Named Credential
                response = JiraCallout.httpHelper(relativePath, 'GET', null);
            }
            
            if (response.getStatusCode() != 200) {
                String errorMessage = 'Failed to download attachment. Status: ' + response.getStatusCode() + ', Body: ' + response.getBody();
                System.debug(LoggingLevel.ERROR, errorMessage);
                createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
                return null;
            }
            
            Blob attachmentContent = response.getBodyAsBlob();
            if (attachmentContent == null || attachmentContent.size() == 0) {
                String errorMessage = 'Downloaded attachment content is empty';
                System.debug(LoggingLevel.ERROR, errorMessage);
                createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
                return null;
            }
            
            System.debug('Successfully downloaded attachment: ' + filename + ' (' + attachmentContent.size() + ' bytes)');
            return attachmentContent;
            
        } catch (Exception e) {
            String errorMessage = 'Error downloading attachment: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
            return null;
        }
    }
    
    /**
     * @description Extracts the relative path from a Jira content URL
     * @param contentUrl The full Jira content URL
     * @return String The relative path for use with JiraCallout.httpHelper
     */
    private static String extractRelativePathFromUrl(String contentUrl) {
        if (String.isBlank(contentUrl)) {
            return null;
        }
        
        // Look for the pattern /rest/api/ in the URL and extract everything after the domain
        Integer restApiIndex = contentUrl.indexOf('/rest/api/');
        if (restApiIndex == -1) {
            return null;
        }
        
        // Extract the path starting from /rest/api/
        String relativePath = contentUrl.substring(restApiIndex + 1); // +1 to remove the leading slash
        return relativePath;
    }
    
    /**
     * @description Creates a ContentVersion record for the downloaded attachment
     * @param ticketId The ID of the associated ticket
     * @param attachmentId The Jira attachment ID
     * @param filename The name of the file
     * @param attachmentContent The attachment content as a Blob
     * @return String The ContentDocument ID if successful, null if failed
     */
    private static String createContentVersionForAttachment(Id ticketId, String attachmentId, String filename, Blob attachmentContent) {
        System.debug('Creating ContentVersion for: ' + filename);
        
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = filename;
            cv.PathOnClient = filename;
            cv.VersionData = attachmentContent;
            
            cv.IsMajorVersion = true;
            cv.Description = 'Synced from Jira attachment ID: ' + attachmentId;
            cv.FirstPublishLocationId = ticketId;
            
            // Use Security.stripInaccessible for FLS compliance
            List<ContentVersion> cvList = new List<ContentVersion>{ cv };
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, cvList);
            
            insert decision.getRecords();
            
            // Get the ContentDocument ID
            ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            String contentDocumentId = insertedCv.ContentDocumentId;
            
            System.debug('Successfully created ContentVersion with ContentDocument ID: ' + contentDocumentId);
            return contentDocumentId;
            
        } catch (Exception e) {
            String errorMessage = 'Error creating ContentVersion: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, null);
            return null;
        }
    }
    
    /**
     * @description Creates a ContentDocumentLink to associate the attachment with the ticket
     * @param contentDocumentId The ContentDocument ID
     * @param ticketId The ID of the associated ticket
     * @param attachmentId The Jira attachment ID
     * @param filename The name of the file
     * @return Boolean indicating if the link was created successfully
     */
    private static Boolean createContentDocumentLink(String contentDocumentId, Id ticketId, String attachmentId, String filename) {
        System.debug('Creating ContentDocumentLink for ContentDocument: ' + contentDocumentId + ' and Ticket: ' + ticketId);
        
        try {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = ticketId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            // Use Security.stripInaccessible for FLS compliance
            List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>{ cdl };
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, cdlList);
            
            insert decision.getRecords();
            
            System.debug('Successfully created ContentDocumentLink: ' + cdl.Id);
            return true;
            
        } catch (Exception e) {
            String errorMessage = 'Error creating ContentDocumentLink: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, contentDocumentId);
            return false;
        }
    }
    
    /**
     * @description Removes ContentDocumentLink when attachment is deleted from Jira
     * @param contentDocumentId The ContentDocument ID
     * @param ticketId The ID of the associated ticket
     * @param attachmentId The Jira attachment ID
     * @param filename The name of the file
     * @return Boolean indicating if the link was removed successfully
     */
    private static Boolean removeContentDocumentLink(String contentDocumentId, Id ticketId, String attachmentId, String filename) {
        System.debug('Removing ContentDocumentLink for ContentDocument: ' + contentDocumentId + ' and Ticket: ' + ticketId);
        
        try {
            // Find the ContentDocumentLink to remove
            List<ContentDocumentLink> cdlsToDelete = [
                SELECT Id 
                FROM ContentDocumentLink 
                WHERE ContentDocumentId = :contentDocumentId 
                AND LinkedEntityId = :ticketId
                LIMIT 1
            ];
            
            if (cdlsToDelete.isEmpty()) {
                String errorMessage = 'No ContentDocumentLink found for ContentDocument: ' + contentDocumentId + ' and Ticket: ' + ticketId;
                System.debug(LoggingLevel.WARN, errorMessage);
                createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, contentDocumentId);
                return false;
            }
            
            // Delete the ContentDocumentLink directly (no FLS needed for delete operations on system objects)
            delete cdlsToDelete;
            
            System.debug('Successfully removed ContentDocumentLink: ' + cdlsToDelete[0].Id);
            return true;
            
        } catch (Exception e) {
            String errorMessage = 'Error removing ContentDocumentLink: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, errorMessage);
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            createSyncLog(ticketId, attachmentId, filename, 'Jira to SF', 'Failed', errorMessage, contentDocumentId);
            return false;
        }
    }
    
    /**
     * @description Creates a sync log record for tracking attachment operations
     * @param ticketId The ID of the associated ticket (required - cannot be null)
     * @param jiraAttachmentId The Jira attachment ID
     * @param filename The name of the file
     * @param syncDirection The direction of sync (e.g., 'Jira to SF')
     * @param syncStatus The status of the sync operation ('Success' or 'Failed')
     * @param errorDetails Error details if the operation failed (can be null)
     * @param contentDocumentId The Salesforce ContentDocument ID (can be null)
     */
    private static void createSyncLog(Id ticketId, String jiraAttachmentId, String filename, 
                                    String syncDirection, String syncStatus, String errorDetails, String contentDocumentId) {
        // Skip sync log creation if ticketId is null (Master-Detail relationship requires it)
        if (ticketId == null) {
            System.debug(LoggingLevel.WARN, 'Cannot create sync log without ticket ID - Master-Detail relationship requires it');
            return;
        }
        
        try {
            Attachment_Sync_Log__c syncLog = new Attachment_Sync_Log__c();
            syncLog.Ticket__c = ticketId;
            syncLog.JiraAttachmentIdTxt__c = jiraAttachmentId;
            syncLog.FilenameTxt__c = filename;
            syncLog.SyncDirectionPk__c = syncDirection;
             syncLog.SyncStatusPk__c = syncStatus;
                            syncLog.ErrorDetailsTxt__c = errorDetails;
            syncLog.SalesforceContentDocumentIdTxt__c = contentDocumentId;
            
            // Use Security.stripInaccessible for FLS compliance
            List<Attachment_Sync_Log__c> logList = new List<Attachment_Sync_Log__c>{ syncLog };
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, logList);
            
            insert decision.getRecords();
            
            System.debug('Created sync log: ' + syncStatus + ' for attachment: ' + filename);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create sync log: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Sync log details - Ticket: ' + ticketId + ', Attachment: ' + jiraAttachmentId + 
                        ', Status: ' + syncStatus + ', Error: ' + errorDetails);
        }
    }
}