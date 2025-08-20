public with sharing class DH_JiraSyncWorker
        implements Queueable, Database.AllowsCallouts {

    public enum Mode { CREATE, UPDATE_JIRA }

    private Mode    mode;
    private Set<Id> ticketIds;

    public DH_JiraSyncWorker(Mode m, Set<Id> ids) {
        this.mode      = m;
        this.ticketIds = (ids != null) ? new Set<Id>(ids) : new Set<Id>();
    }

    public void execute(QueueableContext qc) {
        if (mode == DH_JiraSyncWorker.Mode.CREATE) {
            createJiraIssues(ticketIds);
        } else {
            updateJiraIssues(ticketIds);
        }
    }

    private static void createJiraIssues(Set<Id> ids) {
        System.debug('entering createJiraIssues');
        if (ids.isEmpty()) return;

        List<DH_Ticket__c> tickets = [
            SELECT Id, BriefDescriptionTxt__c, DetailsTxt__c
            FROM   DH_Ticket__c WHERE Id IN :ids
        ];

        List<DH_Ticket__c> updates = new List<DH_Ticket__c>();

        for (DH_Ticket__c t : tickets) {
            String summary     = String.isBlank(t.BriefDescriptionTxt__c)
                               ? 'No summary provided' : t.BriefDescriptionTxt__c;
            String description = String.isBlank(t.DetailsTxt__c)
                               ? 'No description provided' : t.DetailsTxt__c;

            Map<String,Object> adf = HtmlToAdfConverter.convert(description);

            String body = JSON.serialize(new Map<String,Object>{
                'fields' => new Map<String,Object>{
                    'project'     => new Map<String,String>{ 'key' => 'DHS' },
                    'summary'     => summary,
                    'description' => adf,
                    'issuetype'   => new Map<String,String>{ 'name' => 'Task' }
                }
            });

            System.debug('body');
            DH_Ticket__c upd = new DH_Ticket__c(Id = t.Id);

            try {
                HttpResponse res = JiraCallout.httpHelper('issue', 'POST', body);
                if (res.getStatusCode() == 201) {
                    Map<String,Object> parsed =
                        (Map<String,Object>)JSON.deserializeUntyped(res.getBody());
                    upd.JiraTicketKeyTxt__c = String.valueOf(parsed.get('key'));
                    upd.JiraSyncStatusTxt__c = 'Created';
                    System.debug('created');
                } else {
                    String statusMsg = 'Create failed: ' + res.getStatus() + ' | ' + res.getBody();
                    upd.JiraSyncStatusTxt__c = left255(statusMsg);
                    upd.JiraLastResponseTxt__c = res.getBody();
                    System.debug('kuch to gadbad h');
                }
            } catch (Exception e) {
                String errMsg = 'Create EX: ' + e.getMessage();
                upd.JiraSyncStatusTxt__c = left255(errMsg);
                upd.JiraLastResponseTxt__c = e.getMessage();
                System.debug('entered catfch');
            }
            updates.add(upd);
        }
        if (!updates.isEmpty()) update updates;
    }

    private static void updateJiraIssues(Set<Id> ids) {
        if (ids.isEmpty()) return;

        List<DH_Ticket__c> tickets = [
            SELECT Id, JiraTicketKeyTxt__c, StageNamePk__c,
                   BriefDescriptionTxt__c, DetailsTxt__c
            FROM   DH_Ticket__c
            WHERE  Id IN :ids AND JiraTicketKeyTxt__c != null
        ];

        List<DH_Ticket__c> updates = new List<DH_Ticket__c>();

        for (DH_Ticket__c t : tickets) {
            Boolean updated = false;
            DH_Ticket__c upd = new DH_Ticket__c(Id = t.Id);

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
                JiraCallout.httpHelper('issue/' + t.JiraTicketKeyTxt__c, 'PUT', updBody);
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
                    'issue/' + t.JiraTicketKeyTxt__c + '/transitions',
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
                        'issue/' + t.JiraTicketKeyTxt__c + '/transitions',
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
}