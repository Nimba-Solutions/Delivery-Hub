@isTest
global class JiraCalloutMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"issues": [ { "key": "JIRA-1", "fields": { "status": { "name": "In Development" }, "updatedBy": { "displayName": "Test User" } } } ]}');
        res.setStatusCode(200);
        return res;
    }
}