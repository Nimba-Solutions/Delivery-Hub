public class Ticket_JiraSync {

    // Public wrapper method for testing
    public static void createJiraIssuesSync(Set<Id> ticketIds) {
        if (Test.isRunningTest()) {
            createJiraIssuesImpl(ticketIds);
        } else {
            createJiraIssues(ticketIds);
        }
    }

    // Public wrapper method for testing
    public static void updateJiraIssuesSync(Set<Id> ticketIds) {
        if (Test.isRunningTest()) {
            updateJiraIssuesImpl(ticketIds);
        } else {
            updateJiraIssues(ticketIds);
        }
    }

    @future(callout=true)
    public static void createJiraIssues(Set<Id> ticketIds) {
        createJiraIssuesImpl(ticketIds);
    }

    private static void createJiraIssuesImpl(Set<Id> ticketIds) {
        System.debug('createJiraIssuesImpl called with ticketIds: ' + ticketIds);
        List<Ticket__c> tickets = [
            SELECT Id, BriefDescriptionTxt__c, DetailsTxt__c 
            FROM Ticket__c 
            WHERE Id IN :ticketIds
        ];
        System.debug('Found ' + tickets.size() + ' tickets to process');
        List<Ticket__c> updates = new List<Ticket__c>();

        for (Ticket__c t : tickets) {
            Ticket__c updateRec = new Ticket__c(Id = t.Id);

            String summary = String.isBlank(t.BriefDescriptionTxt__c) ? 'No summary provided' : t.BriefDescriptionTxt__c;
            String description = String.isBlank(t.DetailsTxt__c) ? 'No description provided' : t.DetailsTxt__c;

            // NEW: Convert HTML description to Jira ADF
            Map<String, Object> descriptionADF;
            try {
                descriptionADF = HtmlToAdfConverter.convert(description);
            } catch (Exception e) {
                // Fallback to simple text if conversion fails
                descriptionADF = new Map<String, Object>{
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
                System.debug('HtmlToAdfConverter failed: ' + e.getMessage());
            }

            String body = JSON.serialize(new Map<String, Object>{
                'fields' => new Map<String, Object>{
                    'project' => new Map<String, String>{ 'key' => 'DHS' },
                    'summary' => summary,
                    'description' => descriptionADF,
                    'issuetype' => new Map<String, String>{ 'name' => 'Task' }
                }
            });

            try {
                System.debug('Making HTTP callout for ticket: ' + t.Id);
                HttpResponse res = JiraCallout.httpHelper('rest/api/3/issue', 'POST', body);
                System.debug('HTTP Response Status: ' + res.getStatusCode());
                System.debug('HTTP Response Body: ' + res.getBody());
                if (res.getStatusCode() == 201) {
                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    updateRec.JiraTicketKeyTxt__c = (String) parsed.get('key');
                    updateRec.JiraSyncStatusTxt__c = 'Created';
                    System.debug('Successfully set Jira key: ' + updateRec.JiraTicketKeyTxt__c);
                } else {
                    updateRec.JiraSyncStatusTxt__c = 'Failed: ' + res.getStatus();
                    updateRec.JiraLastResponseTxt__c = res.getBody();
                    System.debug('HTTP callout failed with status: ' + res.getStatus());
                }
            } catch (Exception e) {
                updateRec.JiraSyncStatusTxt__c = 'Exception';
                updateRec.JiraLastResponseTxt__c = e.getMessage();
                System.debug('Exception in HTTP callout: ' + e.getMessage());
            }

            updates.add(updateRec);
        }

        if (!updates.isEmpty()) {
            TicketTriggerHandler.triggerDisabled = true;
            update updates;
            TicketTriggerHandler.triggerDisabled = false;
        }
    }

    @future(callout=true)
    public static void updateJiraIssues(Set<Id> ticketIds) {
        updateJiraIssuesImpl(ticketIds);
    }

    private static void updateJiraIssuesImpl(Set<Id> ticketIds) {
        List<Ticket__c> tickets = [
            SELECT Id, JiraTicketKeyTxt__c, BriefDescriptionTxt__c, DetailsTxt__c 
            FROM Ticket__c 
            WHERE Id IN :ticketIds AND JiraTicketKeyTxt__c != null
        ];

        for (Ticket__c t : tickets) {
            String summary = String.isBlank(t.BriefDescriptionTxt__c) ? 'No summary provided' : t.BriefDescriptionTxt__c;
            String description = String.isBlank(t.DetailsTxt__c) ? 'No description provided' : t.DetailsTxt__c;

            // NEW: Convert HTML description to Jira ADF
            Map<String, Object> descriptionADF;
            try {
                descriptionADF = HtmlToAdfConverter.convert(description);
            } catch (Exception e) {
                // Fallback to simple text if conversion fails
                descriptionADF = new Map<String, Object>{
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
                System.debug('HtmlToAdfConverter failed in update: ' + e.getMessage());
            }

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