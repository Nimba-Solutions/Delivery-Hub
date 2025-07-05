public class DHTicket_JiraSync {

    @future(callout=true)
    public static void createJiraIssues(Set<Id> ticketIds) {
        List<DH_Ticket__c> tickets = [SELECT Id, BriefDescriptionTxt__c, DetailsTxt__c FROM DH_Ticket__c WHERE Id IN :ticketIds];
        List<DH_Ticket__c> updates = new List<DH_Ticket__c>();

        for (DH_Ticket__c t : tickets) {
            DH_Ticket__c updateRec = new DH_Ticket__c(Id = t.Id);
            String summary = String.isBlank(t.BriefDescriptionTxt__c) ? 'No summary provided' : t.BriefDescriptionTxt__c;

            String description = String.isBlank(t.DetailsTxt__c) ? 'No description provided' : t.DetailsTxt__c;

            Map<String, Object> descriptionADF = new Map<String, Object>{
                'type' => 'doc',
                'version' => 1,
                'content' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'paragraph',
                        'content' => new List<Object>{
                            new Map<String, Object>{
                                'type' => 'text',
                                'text' => description
                            }
                        }
                    }
                }
            };
            
            String body = JSON.serialize(new Map<String, Object>{
                'fields' => new Map<String, Object>{
                    'project' => new Map<String, String>{ 'key' => 'GP' },
                    'summary' => summary,
                    'description' => descriptionADF,
                    'issuetype' => new Map<String, String>{ 'name' => 'Task' }
                }
            });


            try {
                HttpResponse res = JiraCallout.httpHelper('issue', 'POST', body);
                if (res.getStatusCode() == 201) {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    //updateRec.JiraTicketKey__c = (String) parsed.get('key');
                	//updateRec.JiraSyncStatus__c = 'Created';
                } else {
                    //updateRec.JiraSyncStatus__c = 'Failed: ' + res.getStatus();
                    //updateRec.JiraLastResponse__c = res.getBody();
                }
            } catch (Exception e) {
                //updateRec.JiraSyncStatus__c = 'Exception';
                //updateRec.JiraLastResponse__c = e.getMessage();
            }

            updates.add(updateRec);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}