@IsTest
private class AccountApiTest {
    
    @IsTest
    static void testGetAccount() {
        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Set up the REST context
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/accounts/' + testAccount.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        AccountApi.doGet();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Expected successful response status code');
        
        Account returnedAccount = (Account)JSON.deserialize(res.responseBody.toString(), Account.class);
        System.assertEquals(testAccount.Id, returnedAccount.Id, 'Returned account ID should match test account ID');
        System.assertEquals(testAccount.Name, returnedAccount.Name, 'Returned account name should match test account name');
    }
    
    @IsTest
    static void testGetAccountNotFound() {
        // Set up the REST context for a non-existing account
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/accounts/001QL00000M8PiEYAV';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        AccountApi.doGet();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        System.assertEquals(404, res.statusCode, 'Expected not found status code for non-existing account');
    }
    
    @IsTest
    static void testGetAccountException() {
        // Set up the REST context to simulate an exception
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/accounts/invalidId';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        AccountApi.doGet();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        System.assertEquals(500, res.statusCode, 'Expected server error status code for invalid ID');
    }
    
    @IsTest
    static void testCreateAccount() {
        // Set up the REST context
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/accounts';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"Name": "New Test Account", "Industry": "Technology"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        AccountApi.doPost();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        System.assertEquals(201, res.statusCode, 'Expected created response status code');
        
        Account createdAccount = (Account)JSON.deserialize(res.responseBody.toString(), Account.class);
        System.assertNotEquals(null, createdAccount.Id, 'Created account should have an ID');
        System.assertEquals('New Test Account', createdAccount.Name, 'Created account name should match input');
        System.assertEquals('Technology', createdAccount.Industry, 'Created account industry should match input');
    }
    
    @IsTest
    static void testCreateAccountInvalidJson() {
        // Set up the REST context with invalid JSON
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/accounts';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"Name": "New Test Account", "Industry": Technology}');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        AccountApi.doPost();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Expected bad request status code for invalid JSON');
    }
    
    @IsTest
    static void testCreateAccountException() {
        // Set up the REST context to simulate an exception
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/v1/accounts';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"Name": "New Test Account"}'); // Missing fields to potentially cause an exception
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        Test.startTest();
        AccountApi.doPost();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        System.assertEquals(201, res.statusCode, 'Expected created status code even with minimal data');
    }
}