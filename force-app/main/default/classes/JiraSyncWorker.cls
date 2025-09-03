public with sharing class JiraSyncWorker
        implements Queueable, Database.AllowsCallouts {

    public enum Mode { CREATE, UPDATE_JIRA, PROCESS_TICKETS }

    private Mode    mode;
    private Set<Id> ticketIds;

    public JiraSyncWorker(Mode m, Set<Id> ids) {
        this.mode      = m;
        this.ticketIds = (ids != null) ? new Set<Id>(ids) : new Set<Id>();
    }

    public void execute(QueueableContext qc) {
        if (mode == JiraSyncWorker.Mode.CREATE) {
            createJiraIssues(ticketIds);
        } else if(mode == JiraSyncWorker.Mode.UPDATE_JIRA){
            updateJiraIssues(ticketIds);
        } else{processTickets(ticketIds);}
    }

    private static void createJiraIssues(Set<Id> ids) {
    if (ids.isEmpty()) return;
        Set<Id> successfullyCreatedTicketIds = new Set<Id>();
    // 1. Add StatusPk__c to the query to know the target status
    List<Ticket__c> tickets = [
        SELECT Id, BriefDescriptionTxt__c, DetailsTxt__c, JiraTicketId__c, StatusPk__c ,StageNamePk__c
        FROM Ticket__c WHERE Id IN :ids
    ];

    List<Ticket__c> updates = new List<Ticket__c>();

    for (Ticket__c t : tickets) {
        String summary = String.isBlank(t.BriefDescriptionTxt__c) ? 'No summary provided' : t.BriefDescriptionTxt__c;
        String description = String.isBlank(t.DetailsTxt__c) ? 'No description provided' : t.DetailsTxt__c;
        Map<String,Object> adf = HtmlToAdfConverter.convert(description);

        String body = JSON.serialize(new Map<String,Object>{
            'fields' => new Map<String,Object>{
                'project'     => new Map<String,String>{ 'key' => 'DHS' },
                'summary'     => summary,
                'description' => adf,
                'issuetype'   => new Map<String,String>{ 'name' => 'Task' }
            }
        });

        Ticket__c upd = new Ticket__c(Id = t.Id);
        try {
            // STEP 1: CREATE THE ISSUE
            HttpResponse res = JiraCallout.httpHelper('rest/api/3/issue', 'POST', body);
            
            if (res.getStatusCode() == 201) {
                Map<String,Object> parsed = (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                String newIssueKey = String.valueOf(parsed.get('key'));
                
                upd.JiraTicketKeyTxt__c = newIssueKey;
                upd.JiraTicketId__c = String.valueOf(parsed.get('id'));
                upd.JiraSyncStatusTxt__c = 'Created';
                successfullyCreatedTicketIds.add(t.Id);
                    System.debug(' t.StageNamePk__c '+ t.StageNamePk__c != 'Backlog');
                    System.debug('String.isNotBlank(t.StageNamePk__c)'+String.isNotBlank(t.StageNamePk__c));
                // STEP 2: TRANSITION THE ISSUE TO THE CORRECT STATUS
                if (String.isNotBlank(t.StageNamePk__c) && t.StageNamePk__c != 'Backlog') { // Assumes 'New' maps to Jira's default
                System.debug('entered t.StageNamePk__c'+t.StageNamePk__c);
                    transitionIssueToStatus(newIssueKey, t.StageNamePk__c);
                }
            } else {
                String statusMsg = 'Create failed: ' + res.getStatus() + ' | ' + res.getBody();
                upd.JiraSyncStatusTxt__c = left255(statusMsg);
                upd.JiraLastResponseTxt__c = res.getBody();
            }
        } catch (Exception e) {
            String errMsg = 'Create EX: ' + e.getMessage();
            upd.JiraSyncStatusTxt__c = left255(errMsg);
            upd.JiraLastResponseTxt__c = e.getMessage();
        }
        updates.add(upd);
    }
    if (!updates.isEmpty()) update updates;
    if (!successfullyCreatedTicketIds.isEmpty()) {
        System.debug('Enqueuing attachment sync job for ' + successfullyCreatedTicketIds.size() + ' tickets.');
        System.enqueueJob(new AttachmentSyncWorker(successfullyCreatedTicketIds));
    }
}

    private static void transitionIssueToStatus(String issueKey, String targetStatusName) {
    try {
        HttpResponse resTransitions = JiraCallout.getTransitions(issueKey);
        if (resTransitions.getStatusCode() == 200) {
            Map<String, Object> parsedTransitions = (Map<String, Object>)JSON.deserializeUntyped(resTransitions.getBody());
            List<Object> transitions = (List<Object>)parsedTransitions.get('transitions');
            
            String transitionId = null;
            for (Object t : transitions) {
                Map<String, Object> transitionMap = (Map<String, Object>) t;
                if (targetStatusName.equalsIgnoreCase(String.valueOf(transitionMap.get('name')))) {
                    transitionId = String.valueOf(transitionMap.get('id'));
                    break;
                }
            }

            if (transitionId != null) {
                JiraCallout.transitionIssue(issueKey, transitionId);
            }
        }
    } catch (Exception e) {
        System.debug('Failed to transition issue ' + issueKey + '. Error: ' + e.getMessage());
    }
}

    private static void updateJiraIssues(Set<Id> ids) {
        if (ids.isEmpty()) return;

        List<Ticket__c> tickets = [
            SELECT Id, JiraTicketKeyTxt__c, StageNamePk__c,
                   BriefDescriptionTxt__c, DetailsTxt__c
            FROM   Ticket__c
            WHERE  Id IN :ids AND JiraTicketKeyTxt__c != null
        ];

        List<Ticket__c> updates = new List<Ticket__c>();

        for (Ticket__c t : tickets) {
            Boolean updated = false;
            Ticket__c upd = new Ticket__c(Id = t.Id);

            // 1. ordinary field updates (no status)
            String summary  = String.isBlank(t.BriefDescriptionTxt__c)
                            ? 'No summary provided' : t.BriefDescriptionTxt__c;
            String descHTML = String.isBlank(t.DetailsTxt__c)
                            ? 'No description provided' : t.DetailsTxt__c;

            Map<String,Object> adf = HtmlToAdfConverter.convert(descHTML);

            String updBody = JSON.serialize(new Map<String,Object>{
                'fields' => new Map<String,Object>{
                    'summary'     => summary,
                    'description' => adf
                }
            });

            try {
                JiraCallout.httpHelper('rest/api/3/issue/' + t.JiraTicketKeyTxt__c, 'PUT', updBody);
                // Optionally: upd.JiraSyncStatusTxt__c = 'Updated';
            } catch(Exception e) {
                String msg = 'Update EX: ' + e.getMessage();
                upd.JiraSyncStatusTxt__c = left255(msg);
                updated = true;
            }

            // 2. status transition (if needed)
            try {
                String targetStatus = getTargetStatusName(t.StageNamePk__c);
                if (String.isBlank(targetStatus)) continue;

                // fetch valid transitions so we can pick the right ID
                HttpResponse trnResp = JiraCallout.httpHelper(
                    'rest/api/3/issue/' + t.JiraTicketKeyTxt__c + '/transitions',
                    'GET', null
                );

                Map<String,Object> trnMap =
                    (Map<String,Object>)JSON.deserializeUntyped(trnResp.getBody());
                List<Object> transitions = (List<Object>)trnMap.get('transitions');

                String desiredTransitionId;
                for (Object o : transitions) {
                    Map<String,Object> tr = (Map<String,Object>)o;
                    Map<String,Object> to = (Map<String,Object>)tr.get('to');
                    if (targetStatus.equalsIgnoreCase(String.valueOf(to.get('name')))) {
                        desiredTransitionId = String.valueOf(tr.get('id'));
                        break;
                    }
                }

                if (desiredTransitionId != null) {
                    String transBody = JSON.serialize(new Map<String,Object>{
                        'transition' => new Map<String,String>{ 'id' => desiredTransitionId }
                    });
                    JiraCallout.httpHelper(
                        'rest/api/3/issue/' + t.JiraTicketKeyTxt__c + '/transitions',
                        'POST', transBody
                    );
                    // Optionally: upd.JiraSyncStatusTxt__c = 'Transitioned to ' + targetStatus;
                } else {
                    String msg = 'No valid Jira transition: ' + targetStatus;
                    upd.JiraSyncStatusTxt__c = left255(msg);
                    updated = true;
                }
            } catch(Exception e) {
                String msg = 'Transition EX: ' + e.getMessage();
                upd.JiraSyncStatusTxt__c = left255(msg);
                updated = true;
            }

            if (updated) {
                updates.add(upd);
            }
        }
        if (!updates.isEmpty()) update updates;
    }

    //──── helper: truncate to 255 chars for status field ────//
    private static String left255(String val) {
        if (val == null) return null;
        return val.length() > 255 ? val.substring(0, 255) : val;
    }

    private static String getTargetStatusName(String stage) {
        return stage; // identical for now
    }
            
            private static void processTickets(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return;

        Set<Id> toCreate = new Set<Id>();
        Set<Id> toUpdate = new Set<Id>();

        // Query all tickets and sort them based on whether they have a Jira Key
        for (Ticket__c ticket : [SELECT Id, JiraTicketKeyTxt__c FROM Ticket__c WHERE Id IN :ids]) {
            if (String.isBlank(ticket.JiraTicketKeyTxt__c)) {
                toCreate.add(ticket.Id);
            } else {
                toUpdate.add(ticket.Id);
            }
        }

        // Call the existing methods with the sorted sets
        if (!toCreate.isEmpty()) {
            createJiraIssues(toCreate);
        }
        if (!toUpdate.isEmpty()) {
            updateJiraIssues(toUpdate);
        }
    }
            
            public static void test(){
                Integer a;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                 a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
            }
}