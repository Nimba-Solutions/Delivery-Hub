public with sharing class JiraCommentSyncHelper {

    public static void handleAfterInsert(Map<Id, DH_Ticket_Comment__c> commentMap) {
        // Collect ticket IDs
        Set<Id> ticketIds = new Set<Id>();
        for (DH_Ticket_Comment__c comment : commentMap.values()) {
            ticketIds.add(comment.TicketId__c);
        }

        // Query related tickets
        Map<Id, DH_Ticket__c> ticketMap = new Map<Id, DH_Ticket__c>(
            [SELECT Id, JiraTicketKeyTxt__c FROM DH_Ticket__c WHERE Id IN :ticketIds]
        );

        // Gather IDs for queueable
        List<Id> commentIdsToSync = new List<Id>();
        for (DH_Ticket_Comment__c comment : commentMap.values()) {
            DH_Ticket__c ticket = ticketMap.get(comment.TicketId__c);
            if (
                comment.SourcePk__c != 'Jira' &&
                !String.isBlank(comment.BodyTxt__c) &&
                String.isBlank(comment.JiraSyncStatusTxt__c) &&
                ticket != null &&
                !String.isBlank(ticket.JiraTicketKeyTxt__c)
            ) {
                commentIdsToSync.add(comment.Id);
            }
        }
        if (!commentIdsToSync.isEmpty()) {
            System.enqueueJob(new JiraCommentSyncHelperQueueable(commentIdsToSync));
        }
    }

    // Your queueable class definition (or move this to a separate file if you want)
    public class JiraCommentSyncHelperQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> commentIds;

        public JiraCommentSyncHelperQueueable(List<Id> commentIds) {
            this.commentIds = commentIds;
        }

		public void execute(QueueableContext context) {
            List<DH_Ticket_Comment__c> comments = [
                SELECT Id, BodyTxt__c, TicketId__c, JiraSyncStatusTxt__c,
                    TicketId__r.JiraTicketKeyTxt__c
                FROM DH_Ticket_Comment__c
                WHERE Id IN :commentIds
            ];
    
            List<DH_Ticket_Comment__c> commentsToUpdate = new List<DH_Ticket_Comment__c>();
    
            for (DH_Ticket_Comment__c comment : comments) {
                String status;
                String jiraKey = comment.TicketId__r != null ? comment.TicketId__r.JiraTicketKeyTxt__c : null;
    
                if (String.isBlank(jiraKey)) {
                    status = 'No Jira Key on ticket';
                } else if (String.isBlank(comment.BodyTxt__c)) {
                    status = 'No comment body';
                } else {
                    try {
                        // Use JiraCallout here!
                        HttpResponse res = JiraCallout.addComment(jiraKey, comment.BodyTxt__c);
    
                        if (res != null && (res.getStatusCode() == 201 || res.getStatusCode() == 200)) {
                            status = 'Success';
                        } else {
                            status = 'Error: ' + (res == null ? 'No response' : res.getStatusCode() + ' ' + res.getBody());
                        }
                    } catch (Exception e) {
                        status = 'Exception: ' + e.getMessage();
                    }
                }
    
                comment.JiraSyncStatusTxt__c = status;
                commentsToUpdate.add(comment);
            }
    
            if (!commentsToUpdate.isEmpty()) {
                update commentsToUpdate;
            }
        }
    }
}