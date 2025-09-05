@RestResource(urlMapping='/jira/webhook')
global with sharing class JiraWebhookApi {
    global class JiraUser { public String name; public String key; }
    global class JiraIssueFields { public String summary; public String description; }
    global class JiraIssue { public String id; public String key; public JiraIssueFields fields; }
    global class JiraChangeItem { public String field; public String fromString; public String toString; }
    global class JiraChangeLog { public List<JiraChangeItem> items; }
    global class JiraWebhookPayload {
        public Long timestamp;
        public String webhookEvent;
        public JiraUser user;
        public JiraIssue issue;
        public JiraChangeLog changelog;
    }

    @HttpPost
    global static void handle() {
        RestRequest req = RestContext.request;

        // Read raw JSON body correctly
        String raw = (req.requestBody != null) ? req.requestBody.toString() : null;

        // Optional shared-secret header check
        String secretHeader = req.headers.get('X-Jira-Secret');
        if (secretHeader != null && secretHeader != 'YOUR_SHARED_SECRET') {
            RestContext.response.statusCode = 401;
            return;
        }

        // Parse JSON safely
        JiraWebhookPayload payload = (raw != null && raw.trim().length() > 0)
            ? (JiraWebhookPayload) JSON.deserialize(raw, JiraWebhookPayload.class)
            : null;

        if (payload == null || payload.issue == null) {
            RestContext.response.statusCode = 400;
            return;
        }

        // Example action: upsert Ticket__c by Jira key
        List<Ticket__c> existing = [
            SELECT Id, JiraTicketKeyTxt__c
            FROM Ticket__c
            WHERE JiraTicketKeyTxt__c = :payload.issue.key
            LIMIT 1
        ];

        Ticket__c rec = existing.isEmpty() ? new Ticket__c() : existing[0];
        rec.JiraTicketKeyTxt__c = payload.issue.key;
        if (payload.issue.fields != null) {
            rec.BriefDescriptionTxt__c = payload.issue.fields.summary;
            rec.DetailsTxt__c          = payload.issue.fields.description;
        }
        upsert rec;

        // Respond 200 so Jira treats webhook delivery as successful
        RestContext.response.statusCode = 200;
    }
}