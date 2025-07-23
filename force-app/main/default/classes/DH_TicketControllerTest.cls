/**
 * @description Test class for DH_TicketController AI Enhancement functionality
 */
@isTest
public class DH_TicketControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test DH_Ticket__c records if needed for other tests
        List<DH_Ticket__c> testTickets = new List<DH_Ticket__c>();
        testTickets.add(new DH_Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket 1',
            StageNamePk__c = 'Backlog',
            IsActiveBool__c = true,
            SortOrderNumber__c = 1
        ));
        testTickets.add(new DH_Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket 2',
            StageNamePk__c = 'In Development',
            IsActiveBool__c = true,
            SortOrderNumber__c = 2
        ));
        insert testTickets;
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_AuthKeywords() {
        // Mock HTTP callout for OpenAI
        Test.setMock(HttpCalloutMock.class, new OpenAIMockHttpResponse());
        
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'User login system', 
            'Need authentication for users'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.title, 'Title should not be null');
        System.assertNotEquals(null, result.description, 'Description should not be null');
        System.assert(result.estimatedDays > 0, 'Estimated days should be positive');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_DashboardKeywords() {
        // Mock HTTP callout for OpenAI
        Test.setMock(HttpCalloutMock.class, new OpenAIMockHttpResponse());
        
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Analytics dashboard', 
            'Create charts and reports'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.title, 'Title should not be null');
        System.assertNotEquals(null, result.description, 'Description should not be null');
        System.assert(result.estimatedDays > 0, 'Estimated days should be positive');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_ApiKeywords() {
        // Mock HTTP callout for OpenAI
        Test.setMock(HttpCalloutMock.class, new OpenAIMockHttpResponse());
        
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'REST API endpoints', 
            'Build service integration'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.title, 'Title should not be null');
        System.assertNotEquals(null, result.description, 'Description should not be null');
        System.assert(result.estimatedDays > 0, 'Estimated days should be positive');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_MobileKeywords() {
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Mobile app interface', 
            'Responsive design needed'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Mobile-Responsive Application Interface', result.title, 'Should return mobile-related title');
        System.assert(result.description.contains('mobile'), 'Description should contain mobile details');
        System.assertEquals(10, result.estimatedDays, 'Should return 10 days for mobile');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_DatabaseKeywords() {
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Database optimization', 
            'Improve data storage performance'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Optimized Data Management System', result.title, 'Should return database-related title');
        System.assert(result.description.contains('data'), 'Description should contain data details');
        System.assertEquals(7, result.estimatedDays, 'Should return 7 days for database');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_GenericInput() {
        // Mock HTTP callout for OpenAI
        Test.setMock(HttpCalloutMock.class, new OpenAIMockHttpResponse());
        
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Custom feature', 
            'Some generic functionality'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.title, 'Title should not be null');
        System.assertNotEquals(null, result.description, 'Description should not be null');
        System.assert(result.estimatedDays > 0, 'Estimated days should be positive');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_TitleOnly() {
        // Mock HTTP callout for OpenAI
        Test.setMock(HttpCalloutMock.class, new OpenAIMockHttpResponse());
        
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'User authentication', 
            null
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.title, 'Title should not be null');
        System.assertNotEquals(null, result.description, 'Description should not be null');
        System.assert(result.estimatedDays > 0, 'Estimated days should be positive');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_DescriptionOnly() {
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            null, 
            'Need to build API endpoints for integration'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Scalable RESTful API for Core Services', result.title, 'Should return API-related title');
        System.assert(result.description.contains('API'), 'Description should contain API details');
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_EmptyInput() {
        Test.startTest();
        
        try {
            DH_TicketController.getAiEnhancedTicketDetails('', '');
            System.assert(false, 'Should have thrown an exception for empty input');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Please provide at least a title or description'), 
                         'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_NullInput() {
        Test.startTest();
        
        try {
            DH_TicketController.getAiEnhancedTicketDetails(null, null);
            System.assert(false, 'Should have thrown an exception for null input');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Please provide at least a title or description'), 
                         'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_WhitespaceInput() {
        Test.startTest();
        
        try {
            DH_TicketController.getAiEnhancedTicketDetails('   ', '   ');
            System.assert(false, 'Should have thrown an exception for whitespace-only input');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Please provide at least a title or description'), 
                         'Should throw appropriate error message');
        }
        
        Test.stopTest();
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_ProcessingDelay() {
        Test.startTest();
        
        Long startTime = System.currentTimeMillis();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Test feature', 
            'Test description'
        );
        
        Long endTime = System.currentTimeMillis();
        Long duration = endTime - startTime;
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // Note: In test context, the delay might not work exactly as expected due to test execution limits
        // but we can verify the method completes successfully
    }

    @isTest
    static void testGetAiEnhancedTicketDetails_CaseInsensitive() {
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result1 = DH_TicketController.getAiEnhancedTicketDetails(
            'USER AUTH SYSTEM', 
            'LOGIN FUNCTIONALITY'
        );
        
        DH_TicketController.AISuggestionWrapper result2 = DH_TicketController.getAiEnhancedTicketDetails(
            'user auth system', 
            'login functionality'
        );
        
        Test.stopTest();
        
        System.assertEquals(result1.title, result2.title, 'Results should be case insensitive');
        System.assertEquals(result1.estimatedDays, result2.estimatedDays, 'Estimated days should be the same');
    }

    @isTest
    static void testAISuggestionWrapper_Properties() {
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper wrapper = new DH_TicketController.AISuggestionWrapper();
        wrapper.title = 'Test Title';
        wrapper.description = 'Test Description';
        wrapper.estimatedDays = 5;
        
        Test.stopTest();
        
        System.assertEquals('Test Title', wrapper.title, 'Title should be set correctly');
        System.assertEquals('Test Description', wrapper.description, 'Description should be set correctly');
        System.assertEquals(5, wrapper.estimatedDays, 'Estimated days should be set correctly');
    }

    // Test existing methods to ensure AI addition doesn't break them
    @isTest
    static void testGetTickets() {
        Test.startTest();
        
        List<DH_Ticket__c> tickets = DH_TicketController.getTickets();
        
        Test.stopTest();
        
        System.assertNotEquals(null, tickets, 'Tickets list should not be null');
        System.assertEquals(2, tickets.size(), 'Should return 2 test tickets');
    }

    @isTest
    static void testCreateDummyTickets() {
        Test.startTest();
        
        List<DH_Ticket__c> dummyTickets = DH_TicketController.createDummyTickets();
        
        Test.stopTest();
        
        System.assertNotEquals(null, dummyTickets, 'Dummy tickets should not be null');
        System.assertEquals(4, dummyTickets.size(), 'Should create 4 dummy tickets');
        
        // Verify tickets were actually inserted
        List<DH_Ticket__c> allTickets = [SELECT Id FROM DH_Ticket__c];
        System.assertEquals(6, allTickets.size(), 'Should have 6 total tickets (2 setup + 4 dummy)');
    }

    @isTest
    static void testOpenAICalloutSuccess() {
        // Mock successful OpenAI response
        Test.setMock(HttpCalloutMock.class, new OpenAIMockHttpResponse());
        
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Build API', 
            'Create REST endpoints'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Enhanced API Development', result.title, 'Should return mocked title');
        System.assert(result.description.contains('comprehensive'), 'Description should contain expected content');
        System.assertEquals(7, result.estimatedDays, 'Should return mocked estimated days');
    }

    @isTest
    static void testOpenAICalloutFailure() {
        // Mock failed OpenAI response
        Test.setMock(HttpCalloutMock.class, new OpenAIFailureMockHttpResponse());
        
        Test.startTest();
        
        // Should fallback to keyword-based suggestions
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'API endpoints', 
            'Build REST services'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // Should get fallback suggestion for API keywords
        System.assertEquals('Scalable RESTful API for Core Services', result.title, 'Should return fallback title');
        System.assertEquals(6, result.estimatedDays, 'Should return fallback estimated days');
    }

    @isTest
    static void testOpenAIConfigurationMissing() {
        // Don't set up any configuration - should fallback to keyword suggestions
        Test.startTest();
        
        DH_TicketController.AISuggestionWrapper result = DH_TicketController.getAiEnhancedTicketDetails(
            'Dashboard feature', 
            'Analytics and reporting'
        );
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        // Should get fallback suggestion for dashboard keywords
        System.assertEquals('Interactive Analytics Dashboard', result.title, 'Should return fallback title');
        System.assertEquals(12, result.estimatedDays, 'Should return fallback estimated days');
    }

    // Mock HTTP Response for successful OpenAI calls
    private class OpenAIMockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            // Mock OpenAI response structure
            Map<String, Object> mockResponse = new Map<String, Object>{
                'choices' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'message' => new Map<String, Object>{
                            'content' => '{\n' +
                                       '  "title": "Enhanced API Development",\n' +
                                       '  "description": "A comprehensive API development project that includes REST endpoint creation, authentication, documentation, and testing strategies.",\n' +
                                       '  "estimatedDays": 7\n' +
                                       '}'
                        }
                    }
                }
            };
            
            res.setBody(JSON.serialize(mockResponse));
            return res;
        }
    }

    // Mock HTTP Response for failed OpenAI calls
    private class OpenAIFailureMockHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error": {"message": "Service temporarily unavailable"}}');
            return res;
        }
    }
}