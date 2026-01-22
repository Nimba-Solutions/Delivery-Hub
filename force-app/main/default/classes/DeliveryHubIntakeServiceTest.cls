@IsTest
private class DeliveryHubIntakeServiceTest {

    @IsTest
    static void testCreateTicketWithBrokerageData() {
        // 1. Prepare Request with Brokerage Fields (PreApproved Hours, etc.)
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/intake/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'title' => 'Broker Ticket',
            'briefSummary' => 'Inbound Test',
            'detailedContent' => 'Details',
            'priority' => 'High',
            'type' => 'Bug',
            'companyName' => 'Mothership Corp',
            'brokerRequestId' => 'REQ-001',
            'preApprovedHours' => 5.0,
            'hourlyRate' => 100.00
        }));
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // 2. Execute
        Test.startTest();
        DeliveryHubIntakeService.createTicket();
        Test.stopTest();

        // 3. Assert Response
        System.assertEquals(201, res.statusCode);
        
        // 4. Assert Data Created correctly
        Ticket__c t = [SELECT Id, ExternalSourceOrgTxt__c, SourceEventReplayIdTxt__c, RequestTypePk__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Mothership Corp', t.ExternalSourceOrgTxt__c, 'Should map Company Name');
        System.assertEquals('REQ-001', t.SourceEventReplayIdTxt__c, 'Should map Broker Request ID');
        System.assertEquals('Partner Request', t.RequestTypePk__c);
    }

    @IsTest
    static void testCheckStatus() {
        // 1. Create a ticket to check
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Status Check Ticket', 
            StatusPk__c = 'In Progress'
        );
        insert t;

        // 2. Prepare GET Request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/intake/' + t.Id;
        req.httpMethod = 'GET';
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // 3. Execute
        Test.startTest();
        DeliveryHubIntakeService.checkStatus();
        Test.stopTest();

        // 4. Verify
        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('In Progress', body.get('status'));
    }
}