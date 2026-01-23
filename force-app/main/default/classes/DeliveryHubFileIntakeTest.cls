@IsTest
private class DeliveryHubFileIntakeTest {

    @TestSetup
    static void makeData() {
        // Create a Ticket to attach files to
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket', 
            BriefDescriptionTxt__c = 'File Upload Test'
        );
        insert t;
    }

    @IsTest
    static void testUploadFileSuccess() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        // 1. Prepare Mock Request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/files/' + t.Id;
        req.httpMethod = 'POST';
        
        // Mock JSON Payload
        Map<String, Object> body = new Map<String, Object>{
            'filename' => 'spec.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Fake PDF Content'))
        };
        req.requestBody = Blob.valueOf(JSON.serialize(body));
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // 2. Execute
        Test.startTest();
        DeliveryHubFileIntake.uploadFile();
        Test.stopTest();

        // 3. Assert Response
        System.assertEquals(201, res.statusCode, 'Should return 201 Created');
        
        // 4. Assert File Creation
        ContentVersion cv = [SELECT Id, Title, FirstPublishLocationId FROM ContentVersion WHERE Title = 'spec.pdf' LIMIT 1];
        System.assertNotEquals(null, cv, 'File should exist');
        System.assertEquals(t.Id, cv.FirstPublishLocationId, 'File should be linked to the ticket');
    }

    @IsTest
    static void testUploadFileMissingData() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/files/' + t.Id;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "filename": "" }'); // Missing data
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubFileIntake.uploadFile();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 Bad Request');
    }
}