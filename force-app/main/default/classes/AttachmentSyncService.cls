/**
 * @description Service class for synchronizing attachments between Salesforce and Jira
 * @author Delivery Hub Team
 * @date 2025
 */
public with sharing class AttachmentSyncService {

    /**
     * @description Synchronizes files from Salesforce to Jira asynchronously
     * @param ticketId The ID of the ticket to sync attachments for
     * @param contentDocumentIds List of ContentDocument IDs to sync to Jira
     */
    @future(callout=true)
    public static void syncFilesToJira(Id ticketId, List<Id> contentDocumentIds) {
        // 1. Get the Jira Key from the ticket
        List<Ticket__c> tickets = [SELECT Id, JiraTicketKeyTxt__c FROM Ticket__c WHERE Id = :ticketId WITH SECURITY_ENFORCED LIMIT 1];
        if (tickets.isEmpty() || String.isBlank(tickets[0].JiraTicketKeyTxt__c)) {
            // Cannot sync without a Jira Key. Log this appropriately.
            return;
        }
        Ticket__c ticket = tickets[0];

        // 2. Get the file content from ContentVersion
        List<ContentVersion> versions = [
            SELECT Id, Title, VersionData, ContentDocumentId
            FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true
            WITH SECURITY_ENFORCED
        ];

        List<Attachment_Sync_Log__c> logsToInsert = new List<Attachment_Sync_Log__c>();

        for (ContentVersion cv : versions) {
            String status = 'Success';
            String errorDetails = '';
            String jiraAttachmentId = null;

            try {
                // 3. Make the callout to Jira
                HttpResponse res = JiraCallout.addAttachment(ticket.JiraTicketKeyTxt__c, cv.Title, cv.VersionData);

                if (res.getStatusCode() == 200) {
                    List<Object> responseList = (List<Object>) JSON.deserializeUntyped(res.getBody());
                    if (!responseList.isEmpty()) {
                        Map<String, Object> attachmentDetails = (Map<String, Object>) responseList[0];
                        jiraAttachmentId = (String) attachmentDetails.get('id');
                    }
                } else {
                    status = 'Failed';
                    errorDetails = res.getStatusCode() + ': ' + res.getBody();
                }
            } catch (Exception e) {
                status = 'Failed';
                errorDetails = e.getMessage();
            }

            // 4. Create a log entry for the attempt
            logsToInsert.add(new Attachment_Sync_Log__c(
                Ticket__c = ticketId,
                JiraAttachmentIdTxt__c = jiraAttachmentId, // Will be null on failure
                SalesforceContentDocumentIdTxt__c = cv.ContentDocumentId,
                FilenameTxt__c = cv.Title,
                SyncDirectionPk__c = 'Salesforce to Jira',
                 SyncStatusPk__c = status,
                ErrorDetailsTxt__c = errorDetails
            ));
        }

        if (!logsToInsert.isEmpty()) {
            // Use Security.stripInaccessible for FLS compliance
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, logsToInsert);
            insert decision.getRecords();
        }
    }
}