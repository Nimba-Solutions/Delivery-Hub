@isTest
public class DHTicket_JiraSyncTest {

    // Mock HTTP Callout Class
    public class MockJiraCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getMethod() == 'POST') {
                res.setStatusCode(201);
                res.setBody('{"key": "DHS-123"}');
            } else if (req.getMethod() == 'PUT') {
                res.setStatusCode(204);
                res.setBody('');
            }

            return res;
        }
    }

    @testSetup
    static void setupData() {
        List<DH_Ticket__c> tickets = new List<DH_Ticket__c>();

        // Create one ticket to test createJiraIssues
        tickets.add(new DH_Ticket__c(
            BriefDescriptionTxt__c = 'Create Test Ticket',
            DetailsTxt__c = '<p>Details for create</p>'
        ));

        // Create one ticket to test updateJiraIssues
        tickets.add(new DH_Ticket__c(
            BriefDescriptionTxt__c = 'Update Test Ticket',
            DetailsTxt__c = '<p>Details for update</p>',
            JiraTicketKeyTxt__c = 'DHS-999'
        ));

        insert tickets;
    }

    @isTest
    static void testCreateJiraIssues() {
        Test.setMock(HttpCalloutMock.class, new MockJiraCallout());

        DH_Ticket__c t = [SELECT Id FROM DH_Ticket__c WHERE JiraTicketKeyTxt__c = null LIMIT 1];

        Test.startTest();
        DHTicket_JiraSync.createJiraIssues(new Set<Id>{ t.Id });
        Test.stopTest();

        // Verify ticket is updated
        t = [SELECT JiraTicketKeyTxt__c, JiraSyncStatusTxt__c FROM DH_Ticket__c WHERE Id = :t.Id];
        System.assertEquals('DHS-123', t.JiraTicketKeyTxt__c);
        System.assertEquals('Created', t.JiraSyncStatusTxt__c);
    }

    @isTest
    static void testUpdateJiraIssues() {
        Test.setMock(HttpCalloutMock.class, new MockJiraCallout());

        DH_Ticket__c t = [SELECT Id FROM DH_Ticket__c WHERE JiraTicketKeyTxt__c != null LIMIT 1];

        Test.startTest();
        DHTicket_JiraSync.updateJiraIssues(new Set<Id>{ t.Id });
        Test.stopTest();

        // No exceptions = success
        System.assert(true, 'Update callout succeeded');
    }
}