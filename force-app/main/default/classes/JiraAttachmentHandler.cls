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
    
    // Salesforce file size limits (in bytes)
    private static final Integer MAX_FILE_SIZE = 25 * 1024 * 1024; // 25MB for ContentVersion
    private static final Integer MAX_HEAP_SIZE = 6 * 1024 * 1024;  // 6MB heap limit consideration
    
    /**
     * @description Handles attachment added events from Jira webhooks
     * @param payload The webhook payload containing attachment and issue information
     * @return Boolean indicating if the operation was successful
     */
    public static Boolean handleAttachmentAdded(Map<String, Object> payload) {
        System.debug('JiraAttachmentHandler.handleAttachmentAdded called');
        
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
            Integer fileSize = (Integer)attachment.get('size');
            String contentUrl = (String)attachment.get('content');
            
            System.debug('Processing attachment: ' + filename + ' (ID: ' + attachmentId + ') for issue: ' + issueKey);
            
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
            
            // Validate file size before attempting download
            if (!validateFileSize(fileSize, filename, ticket.Id, attachmentId)) {
                return false; // Validation creates its own sync log
            }
            
            // Download attachment content from Jira
            Blob attachmentContent = downloadAttachmentFromJira(contentUrl, attachmentId, filename, ticket.Id);
            if (attachmentContent == null) {
                return false; // Download method creates its own sync log on failure
            }
            
            // Create ContentVersion record
            String contentDocumentId = createContentVersion(attachmentContent, filename, ticket.Id, attachmentId);
            if (contentDocumentId == null) {
                return false; // Creation method creates its own sync log on failure
            }
            
            // Create ContentDocumentLink to associate with ticket
            Boolean linkCreated = createContentDocumentLink(contentDocumentId, ticket.Id, attachmentId, filename);
            if (!linkCreated) {
                return false; // Link creation method creates its own sync log on failure
            }
            
            // Create success sync log
            createSyncLog(ticket.Id, attachmentId, filename, 'Jira to SF', 'Success', 
                         null, contentDocumentId);
            
            System.debug('Attachment successfully synced from Jira to SF: ' + filename);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in handleAttachmentAdded: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            
            // Create error sync log with available information
            try {
                Map<String, Object> attachment = (Map<String, Object>)payload.get('attachment');
                String attachmentId = attachment != null ? (String)attachment.get('id') : 'unknown';
                String filename = attachment != null ? (String)attachment.get('filename') : 'unknown';
                
                createSyncLog(null, attachmentId, filename, 'Jira to SF', 'Failed', 
                             'Unexpected error: ' + e.getMessage(), null);
            } catch (Exception logError) {
                System.debug(LoggingLevel.ERROR, 'Failed to create error sync log: ' + logError.getMessage());
            }
            
            return false;
        }
    }
    
    /**
     * @description Handles attachment removed events from Jira webhooks
     * @param payload The webhook payload containing attachment and issue information
     * @return Boolean indicating if the operation was successful
     */
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
                SELECT Id, Salesforce_ContentDocumentId__c, Sync_Status__c
                FROM Attachment_Sync_Log__c
                WHERE Ticket__c = :ticket.Id 
                AND Jira_Attachment_ID__c = :attachmentId
                AND Sync_Status__c = 'Success'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if (existingLogs.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No successful sync log found for attachment: ' + attachmentId);
                createSyncLog(ticket.Id, attachmentId, filename, 'Jira to SF', 'Failed', 
                             'No existing ContentDocument found for attachment removal', null);
                return false;
            }
            
            String contentDocumentId = existingLogs[0].Salesforce_ContentDocumentId__c;
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
            HttpResponse response = JiraCallout.httpHelper(relativePath, 'GET', null);
            
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
     * @param attachmentContent The attachment content as a Blob
     * @param filename The name of the file
     * @param ticketId The ID of the associated ticket
     * @param attachmentId The Jira attachment ID
     * @return String The ContentDocument ID if successful, null if failed
     */
    private static String createContentVersion(Blob attachmentContent, String filename, Id ticketId, String attachmentId) {
        System.debug('Creating ContentVersion for: ' + filename);
        
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = filename;
            cv.PathOnClient = filename;
            cv.VersionData = attachmentContent;
            cv.IsMajorVersion = true;
            cv.Description = 'Synced from Jira attachment ID: ' + attachmentId;
            
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
            syncLog.Jira_Attachment_ID__c = jiraAttachmentId;
            syncLog.Filename__c = filename;
            syncLog.Sync_Direction__c = syncDirection;
            syncLog.Sync_Status__c = syncStatus;
            syncLog.Error_Details__c = errorDetails;
            syncLog.Salesforce_ContentDocumentId__c = contentDocumentId;
            
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