@IsTest
private class DeliveryHubIntakeServiceTest {

    @TestSetup
    static void makeData() {
        // 1. Create a User to run the test as (Bypasses FLS issues)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'dhubint',
            Email = 'deliveryhub.intake@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'IntakeTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'deliveryhub.intaketester@example.com' + System.currentTimeMillis()
        );
        insert testUser;

        // 2. Assign the Admin Permission Set
        // This grants access to the new fields (PreApprovedHours, etc.)
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = ps.Id);
    }

    @IsTest
    static void testCreateTicketWithBrokerageData() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'dhubint' LIMIT 1];

        System.runAs(testUser) {
            // 1. Prepare Request with Brokerage Fields
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

            // 3. Assert Response (Should be 201 Created)
            System.assertEquals(201, res.statusCode, 'Should return 201 Created. If 500, check Perm Set assignments.');
            
            // 4. Assert Data Created correctly
            Ticket__c t = [SELECT Id, ExternalSourceOrgTxt__c, SourceEventReplayIdTxt__c, RequestTypePk__c FROM Ticket__c LIMIT 1];
            System.assertEquals('Mothership Corp', t.ExternalSourceOrgTxt__c);
            System.assertEquals('REQ-001', t.SourceEventReplayIdTxt__c);
        }
    }

    @IsTest
    static void testCheckStatus() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'dhubint' LIMIT 1];

        System.runAs(testUser) {
            // 1. Create a ticket to check (Run as user so they own it/can see it)
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
            System.assertEquals(200, res.statusCode, 'Should return 200. If 404, query likely failed due to permissions.');
            
            if (res.responseBody != null) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
                System.assertEquals('In Progress', body.get('status'));
            }
        }
    }
}