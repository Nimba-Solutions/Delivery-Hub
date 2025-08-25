public class DHTicket_JiraSync {

    @future(callout=true)
    public static void createJiraIssues(Set<Id> ticketIds) {
        List<DH_Ticket__c> tickets = [
            SELECT Id, BriefDescriptionTxt__c, DetailsTxt__c 
            FROM DH_Ticket__c 
            WHERE Id IN :ticketIds
        ];
        List<DH_Ticket__c> updates = new List<DH_Ticket__c>();

        for (DH_Ticket__c t : tickets) {
            DH_Ticket__c updateRec = new DH_Ticket__c(Id = t.Id);

            String summary = String.isBlank(t.BriefDescriptionTxt__c) ? 'No summary provided' : t.BriefDescriptionTxt__c;
            String description = String.isBlank(t.DetailsTxt__c) ? 'No description provided' : t.DetailsTxt__c;

            // NEW: Convert HTML description to Jira ADF
            Map<String, Object> descriptionADF = HtmlToAdfConverter.convert(description);

            String body = JSON.serialize(new Map<String, Object>{
                'fields' => new Map<String, Object>{
                    'project' => new Map<String, String>{ 'key' => 'DHS' },
                    'summary' => summary,
                    'description' => descriptionADF,
                    'issuetype' => new Map<String, String>{ 'name' => 'Task' }
                }
            });

            try {
                HttpResponse res = JiraCallout.httpHelper('rest/api/3/issue', 'POST', body);
                if (res.getStatusCode() == 201) {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    updateRec.JiraTicketKeyTxt__c = (String) parsed.get('key');
                    updateRec.JiraSyncStatusTxt__c = 'Created';
                } else {
                    updateRec.JiraSyncStatusTxt__c = 'Failed: ' + res.getStatus();
                    updateRec.JiraLastResponseTxt__c = res.getBody();
                }
            } catch (Exception e) {
                updateRec.JiraSyncStatusTxt__c = 'Exception';
                updateRec.JiraLastResponseTxt__c = e.getMessage();
            }

            updates.add(updateRec);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    @future(callout=true)
    public static void updateJiraIssues(Set<Id> ticketIds) {
        List<DH_Ticket__c> tickets = [
            SELECT Id, JiraTicketKeyTxt__c, BriefDescriptionTxt__c, DetailsTxt__c 
            FROM DH_Ticket__c 
            WHERE Id IN :ticketIds AND JiraTicketKeyTxt__c != null
        ];

        for (DH_Ticket__c t : tickets) {
            String summary = String.isBlank(t.BriefDescriptionTxt__c) ? 'No summary provided' : t.BriefDescriptionTxt__c;
            String description = String.isBlank(t.DetailsTxt__c) ? 'No description provided' : t.DetailsTxt__c;

            // NEW: Convert HTML description to Jira ADF
            Map<String, Object> descriptionADF = HtmlToAdfConverter.convert(description);

            String body = JSON.serialize(new Map<String, Object>{
                'fields' => new Map<String, Object>{
                    'summary' => summary,
                    'description' => descriptionADF
                }
            });

            try {
                HttpResponse res = JiraCallout.httpHelper('rest/api/3/issue/' + t.JiraTicketKeyTxt__c, 'PUT', body);
                System.debug('Jira update response: ' + res.getBody());
            } catch (Exception e) {
                System.debug('Jira update exception: ' + e.getMessage());
            }
        }
    }
}