public with sharing class DH_JiraAttachmentSyncBatch implements Database.Batchable<SObject>, Schedulable, Database.AllowsCallouts {

    // --- Schedulable Interface ---
    public void execute(SchedulableContext sc) {
        System.debug('DH_JiraAttachmentSyncBatch: Starting scheduled execution');
        Database.executeBatch(new DH_JiraAttachmentSyncBatch());
    }

    // --- Batchable Interface: Start ---
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('DH_JiraAttachmentSyncBatch: Starting batch job');
        String query = 'SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c WHERE JiraTicketKeyTxt__c != NULL';
        System.debug('DH_JiraAttachmentSyncBatch: Query: ' + query);
        return Database.getQueryLocator(query);
    }

    // --- Batchable Interface: Execute ---
    public void execute(Database.BatchableContext bc, List<DH_Ticket__c> scope) {
        System.debug('DH_JiraAttachmentSyncBatch: Processing batch with ' + scope.size() + ' tickets');
        Set<Id> ticketIds = new Map<Id, SObject>(scope).keySet();
        System.debug('DH_JiraAttachmentSyncBatch: Ticket IDs: ' + ticketIds);

        // 1. Get all attachments already synced for these tickets to prevent duplicates
        Set<String> existingJiraAttachmentIds = new Set<String>();
        List<DH_Attachment_Sync_Log__c> existingLogs = [
            SELECT Jira_Attachment_ID__c FROM DH_Attachment_Sync_Log__c
            WHERE Ticket__c IN :ticketIds AND Jira_Attachment_ID__c != NULL
        ];
        System.debug('DH_JiraAttachmentSyncBatch: Found ' + existingLogs.size() + ' existing sync logs');
        for (DH_Attachment_Sync_Log__c log : existingLogs) {
            existingJiraAttachmentIds.add(log.Jira_Attachment_ID__c);
        }
        System.debug('DH_JiraAttachmentSyncBatch: Existing Jira attachment IDs: ' + existingJiraAttachmentIds);

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<DH_Attachment_Sync_Log__c> logsToInsert = new List<DH_Attachment_Sync_Log__c>();
        Map<Integer, Id> indexToTicketIdMap = new Map<Integer, Id>();

        // 2. For each ticket, get its attachment list from Jira
        for (DH_Ticket__c ticket : scope) {
            System.debug('DH_JiraAttachmentSyncBatch: Processing ticket: ' + ticket.Id + ' with Jira key: ' + ticket.JiraTicketKeyTxt__c);
            try {
                String endpoint = 'issue/' + ticket.JiraTicketKeyTxt__c + '?fields=attachment';
                System.debug('DH_JiraAttachmentSyncBatch: Making request to endpoint: ' + endpoint);
                HttpResponse res = JiraCallout.httpHelper(endpoint, 'GET', null);
                System.debug('DH_JiraAttachmentSyncBatch: Response status code: ' + res.getStatusCode());
                System.debug('DH_JiraAttachmentSyncBatch: Response status: ' + res.getStatus());
                System.debug('DH_JiraAttachmentSyncBatch: Response body: ' + res.getBody());
                
                if (res.getStatusCode() != 200) {
                    System.debug('DH_JiraAttachmentSyncBatch: Non-200 response for ticket ' + ticket.JiraTicketKeyTxt__c + ': ' + res.getStatusCode() + ' - ' + res.getStatus());
                    continue;
                }

                Map<String, Object> issueDetails = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                System.debug('DH_JiraAttachmentSyncBatch: Issue details keys: ' + issueDetails.keySet());
                Map<String, Object> fields = (Map<String, Object>) issueDetails.get('fields');
                System.debug('DH_JiraAttachmentSyncBatch: Fields keys: ' + (fields != null ? String.valueOf(fields.keySet()) : 'null'));
                List<Object> attachments = (List<Object>) fields.get('attachment');
                System.debug('DH_JiraAttachmentSyncBatch: Found ' + (attachments != null ? attachments.size() : 0) + ' attachments for ticket ' + ticket.JiraTicketKeyTxt__c);
                
                if (attachments == null) {
                    System.debug('DH_JiraAttachmentSyncBatch: No attachments found for ticket ' + ticket.JiraTicketKeyTxt__c);
                    continue;
                }
                
                // 3. For each attachment, check if it's new
                for (Object attObj : attachments) {
                    Map<String, Object> att = (Map<String, Object>) attObj;
                    String jiraAttId = (String) att.get('id');
                    String filename = (String) att.get('filename');
                    String contentUrl = (String) att.get('content');
                    System.debug('DH_JiraAttachmentSyncBatch: Processing attachment - ID: ' + jiraAttId + ', Filename: ' + filename + ', URL: ' + contentUrl);

                    if (existingJiraAttachmentIds.contains(jiraAttId)) {
                        System.debug('DH_JiraAttachmentSyncBatch: Attachment ' + jiraAttId + ' already synced, skipping');
                        continue; // Already synced, skip.
                    }

                    // 4. Download the new attachment content
                    System.debug('DH_JiraAttachmentSyncBatch: Downloading attachment from URL: ' + contentUrl);
                    HttpRequest fileReq = new HttpRequest();
                    fileReq.setEndpoint(contentUrl);
                    fileReq.setMethod('GET');
                    fileReq.setTimeout(120000); // 2 minutes timeout
                    // Note: Authentication is handled by Named Credential
                    System.debug('DH_JiraAttachmentSyncBatch: File request endpoint: ' + fileReq.getEndpoint());
                    System.debug('DH_JiraAttachmentSyncBatch: File request method: ' + fileReq.getMethod());
                    
                    HttpResponse fileRes = new Http().send(fileReq);
                    System.debug('DH_JiraAttachmentSyncBatch: File download response code: ' + fileRes.getStatusCode());
                    System.debug('DH_JiraAttachmentSyncBatch: File download response status: ' + fileRes.getStatus());
                    
                    if (fileRes.getStatusCode() == 200) {
                        System.debug('DH_JiraAttachmentSyncBatch: Successfully downloaded attachment: ' + filename);
                        // 5. Create the ContentVersion in Salesforce
                        ContentVersion cv = new ContentVersion();
                        cv.Title = filename;
                        cv.PathOnClient = filename;
                        cv.VersionData = fileRes.getBodyAsBlob();
                        System.debug('DH_JiraAttachmentSyncBatch: Created ContentVersion for: ' + filename + ', Size: ' + fileRes.getBodyAsBlob().size() + ' bytes');
                        versionsToInsert.add(cv);
                        
                        // Store the mapping for later use
                        indexToTicketIdMap.put(versionsToInsert.size() - 1, ticket.Id);
                        
                        // Prepare log record
                        logsToInsert.add(new DH_Attachment_Sync_Log__c(
                            Ticket__c = ticket.Id,
                            Jira_Attachment_ID__c = jiraAttId,
                            Filename__c = cv.Title,
                            Sync_Direction__c = 'Jira to SF',
                            Sync_Status__c = 'Success'
                        ));
                        System.debug('DH_JiraAttachmentSyncBatch: Prepared sync log for attachment: ' + jiraAttId);
                    } else {
                        System.debug('DH_JiraAttachmentSyncBatch: Failed to download attachment ' + jiraAttId + ': ' + fileRes.getStatusCode() + ' - ' + fileRes.getStatus());
                        System.debug('DH_JiraAttachmentSyncBatch: File download error body: ' + fileRes.getBody());
                    }
                }
            } catch (Exception e) {
                // Log the exception for the entire ticket sync attempt
                System.debug('DH_JiraAttachmentSyncBatch: Error syncing attachments for ticket ' + ticket.Id + ': ' + e.getMessage());
                System.debug('DH_JiraAttachmentSyncBatch: Exception stack trace: ' + e.getStackTraceString());
                System.debug('DH_JiraAttachmentSyncBatch: Exception type: ' + e.getTypeName());
            }
        }
        
        // 6. Insert all new files and logs
        System.debug('DH_JiraAttachmentSyncBatch: Preparing to insert ' + versionsToInsert.size() + ' ContentVersions');
        if (!versionsToInsert.isEmpty()) {
            try {
                // Use Security.stripInaccessible for FLS compliance
                SObjectAccessDecision cvDecision = Security.stripInaccessible(
                    AccessType.CREATABLE, versionsToInsert);
                System.debug('DH_JiraAttachmentSyncBatch: Inserting ' + cvDecision.getRecords().size() + ' ContentVersions after FLS check');
                insert cvDecision.getRecords();
                System.debug('DH_JiraAttachmentSyncBatch: Successfully inserted ContentVersions');

                // Get the ContentDocumentIds of the newly inserted files
                List<Id> newVersionIds = new List<Id>();
                for(ContentVersion cv : (List<ContentVersion>)cvDecision.getRecords()) { 
                    newVersionIds.add(cv.Id); 
                }
                System.debug('DH_JiraAttachmentSyncBatch: New version IDs: ' + newVersionIds);
                
                Map<Id, Id> versionIdToDocId = new Map<Id, Id>();
                for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :newVersionIds]) {
                    versionIdToDocId.put(cv.Id, cv.ContentDocumentId);
                }
                System.debug('DH_JiraAttachmentSyncBatch: Version to Document ID mapping: ' + versionIdToDocId);
            
                // Now create the ContentDocumentLink records
                List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
                for(Integer i = 0; i < cvDecision.getRecords().size(); i++){
                    ContentVersion cv = (ContentVersion)cvDecision.getRecords()[i];
                    DH_Attachment_Sync_Log__c log = logsToInsert[i];

                    Id docId = versionIdToDocId.get(cv.Id);
                    log.Salesforce_ContentDocumentId__c = docId; // Update log with SF ID
                    System.debug('DH_JiraAttachmentSyncBatch: Creating link for document ' + docId + ' to ticket ' + log.Ticket__c);

                    linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId = log.Ticket__c, // Get ticket ID from the log
                        ShareType = 'V'
                    ));
                }
                System.debug('DH_JiraAttachmentSyncBatch: Prepared ' + linksToInsert.size() + ' ContentDocumentLinks');
            
                // Insert links with FLS compliance
                SObjectAccessDecision linkDecision = Security.stripInaccessible(
                    AccessType.CREATABLE, linksToInsert);
                insert linkDecision.getRecords();
                System.debug('DH_JiraAttachmentSyncBatch: Successfully inserted ContentDocumentLinks');
                
                // Update logs with ContentDocumentId and insert with FLS compliance
                SObjectAccessDecision logDecision = Security.stripInaccessible(
                    AccessType.CREATABLE, logsToInsert);
                insert logDecision.getRecords();
                System.debug('DH_JiraAttachmentSyncBatch: Successfully inserted sync logs');
            } catch (Exception e) {
                System.debug('DH_JiraAttachmentSyncBatch: Error during file insertion: ' + e.getMessage());
                System.debug('DH_JiraAttachmentSyncBatch: File insertion error stack trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('DH_JiraAttachmentSyncBatch: No new attachments to insert');
        }
    }

    // --- Batchable Interface: Finish ---
    public void finish(Database.BatchableContext bc) {
        // Optional: Send an email summary of the batch job
        System.debug('DH_JiraAttachmentSyncBatch: Batch job completed successfully');
        System.debug('DH_JiraAttachmentSyncBatch: Job ID: ' + bc.getJobId());
    }
}