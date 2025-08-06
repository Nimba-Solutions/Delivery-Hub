@isTest
private class DH_JiraSyncWorkerTest {

    // Mock implementation of the JiraCallout.httpHelper method
    private class MockJiraHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getMethod() == 'POST' && req.getEndpoint().contains('/issue')) {
                res.setStatusCode(201);
                res.setBody('{"key": "DHS-123"}');
            } else if (req.getMethod() == 'PUT') {
                res.setStatusCode(204);
            } else if (req.getMethod() == 'GET' && req.getEndpoint().contains('/transitions')) {
                res.setStatusCode(200);
                res.setBody('{"transitions": [{"id":"11","to":{"name":"In Progress"}}, {"id":"21","to":{"name":"Done"}}]}');
            } else if (req.getMethod() == 'POST' && req.getEndpoint().contains('/transitions')) {
                res.setStatusCode(204);
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Invalid request"}');
            }

            return res;
        }
    }

    @testSetup
    static void setup() {
        List<DH_Ticket__c> tickets = new List<DH_Ticket__c>();
        for (Integer i = 0; i < 2; i++) {
            tickets.add(new DH_Ticket__c(
                BriefDescriptionTxt__c = 'Test Summary ' + i,
                DetailsTxt__c = '<p>Test Description ' + i + '</p>',
                StageNamePk__c = 'In Progress'
            ));
        }
        insert tickets;
    }

    @isTest
    static void testCreateJiraIssues() {
        Test.setMock(HttpCalloutMock.class, new MockJiraHttpResponseGenerator());

        List<DH_Ticket__c> tickets = [SELECT Id FROM DH_Ticket__c];
        Set<Id> ticketIds = new Set<Id>();
        for (DH_Ticket__c t : tickets) {
            ticketIds.add(t.Id);
        }

        Test.startTest();
        DH_JiraSyncWorker worker = new DH_JiraSyncWorker(DH_JiraSyncWorker.Mode.CREATE, ticketIds);
        System.enqueueJob(worker);
        Test.stopTest();

        List<DH_Ticket__c> updated = [SELECT JiraTicketKeyTxt__c, JiraSyncStatusTxt__c FROM DH_Ticket__c];
        System.assertEquals('Created', updated[0].JiraSyncStatusTxt__c);
        System.assertEquals(true, updated[0].JiraTicketKeyTxt__c != null);
    }

    @isTest
    static void testUpdateJiraIssues() {
        Test.setMock(HttpCalloutMock.class, new MockJiraHttpResponseGenerator());

        List<DH_Ticket__c> tickets = [SELECT Id FROM DH_Ticket__c];
        List<DH_Ticket__c> toUpdate = new List<DH_Ticket__c>();
        for (DH_Ticket__c t : tickets) {
            t.JiraTicketKeyTxt__c = 'DHS-123';
            toUpdate.add(t);
        }
        update toUpdate;

        Set<Id> ticketIds = new Set<Id>();
        for (DH_Ticket__c t : toUpdate) {
            ticketIds.add(t.Id);
        }

        Test.startTest();
        DH_JiraSyncWorker worker = new DH_JiraSyncWorker(DH_JiraSyncWorker.Mode.UPDATE_JIRA, ticketIds);
        System.enqueueJob(worker);
        Test.stopTest();

        List<DH_Ticket__c> updated = [SELECT JiraSyncStatusTxt__c FROM DH_Ticket__c];
        System.assertEquals(true, updated[0].JiraSyncStatusTxt__c == null || updated[0].JiraSyncStatusTxt__c.contains('Transitioned'));
    }

    @isTest
    static void testEmptyIds() {
        Test.startTest();
        DH_JiraSyncWorker worker = new DH_JiraSyncWorker(DH_JiraSyncWorker.Mode.CREATE, new Set<Id>());
        System.enqueueJob(worker);
        Test.stopTest();
        // No assertions needed; just ensures no exceptions are thrown
    }
}