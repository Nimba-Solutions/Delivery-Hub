public with sharing class DH_AttachmentSyncService {

    @future(callout=true)
    public static void syncFilesToJira(Id ticketId, List<Id> contentDocumentIds) {
        // 1. Get the Jira Key from the ticket
        List<DH_Ticket__c> tickets = [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c WHERE Id = :ticketId LIMIT 1];
        if (tickets.isEmpty() || String.isBlank(tickets[0].JiraTicketKeyTxt__c)) {
            // Cannot sync without a Jira Key. Log this appropriately.
            return;
        }
        DH_Ticket__c ticket = tickets[0];

        // 2. Get the file content from ContentVersion
        List<ContentVersion> versions = [
            SELECT Id, Title, VersionData, ContentDocumentId
            FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true
        ];

        List<DH_Attachment_Sync_Log__c> logsToInsert = new List<DH_Attachment_Sync_Log__c>();

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
            logsToInsert.add(new DH_Attachment_Sync_Log__c(
                Ticket__c = ticketId,
                Jira_Attachment_ID__c = jiraAttachmentId, // Will be null on failure
                Salesforce_ContentDocumentId__c = cv.ContentDocumentId,
                Filename__c = cv.Title,
                Sync_Direction__c = 'Salesforce to Jira',
                Sync_Status__c = status,
                Error_Details__c = errorDetails
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