/**
 * @description Test class for DeliveryAiController.
 *              Covers all branches of draftStatusUpdate: success, AI disabled,
 *              missing API key, no settings record, ticket not found, API error,
 *              and empty choices response.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryAiControllerTest {

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static Delivery_Hub_Settings__c createSettings(Boolean aiEnabled, String apiKey) {
        Delivery_Hub_Settings__c s = new Delivery_Hub_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            AISuggestionsEnabledBool__c = aiEnabled,
            OpenAIApiKeyTxt__c = apiKey,
            OpenAIModelTxt__c = 'gpt-3.5-turbo'
        );
        insert s;
        return s;
    }

    private static Ticket__c createTicket() {
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Add dark mode to the dashboard',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'High',
            EstimatedHoursNumber__c = 8,
            TotalLoggedHoursNumber__c = 3
        );
        insert t;
        return t;
    }

    private static String successBody() {
        return '{\"choices\":[{\"message\":{\"content\":\"Work on this ticket is progressing well. '
             + 'The team is currently in active development and on track for UAT next week.\"}}]}';
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    /**
     * @description Happy path: AI enabled, key present, ticket exists,
     *              OpenAI returns a valid choice. Should return the draft text.
     */
    @IsTest
    static void testDraftStatusUpdateSuccess() {
        createSettings(true, 'sk-test-key-123');
        Ticket__c ticket = createTicket();
        Test.setMock(HttpCalloutMock.class, new OpenAIMock(200, 'OK', successBody()));

        Test.startTest();
        String result = DeliveryAiController.draftStatusUpdate(ticket.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null on success.');
        System.assert(result.length() > 10, 'Result should contain meaningful text.');
    }

    /**
     * @description AI suggestions toggle is disabled — should throw before making any callout.
     */
    @IsTest
    static void testDraftStatusUpdateAiDisabled() {
        createSettings(false, 'sk-test-key-123');
        Ticket__c ticket = createTicket();

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryAiController.draftStatusUpdate(ticket.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException when AI is disabled.');
    }

    /**
     * @description AI is enabled but the API key is blank — should throw before callout.
     */
    @IsTest
    static void testDraftStatusUpdateNoApiKey() {
        createSettings(true, '');
        Ticket__c ticket = createTicket();

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryAiController.draftStatusUpdate(ticket.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException when API key is blank.');
    }

    /**
     * @description No Delivery_Hub_Settings__c record exists — getOrgDefaults returns
     *              a record with null fields, so AI is treated as disabled.
     */
    @IsTest
    static void testDraftStatusUpdateNoSettingsRecord() {
        Ticket__c ticket = createTicket();

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryAiController.draftStatusUpdate(ticket.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException when no settings record exists.');
    }

    /**
     * @description Ticket is inserted then deleted so the Id is valid in format but
     *              the record no longer exists. Controller should throw 'Ticket not found.'
     */
    @IsTest
    static void testDraftStatusUpdateTicketNotFound() {
        createSettings(true, 'sk-test-key-123');
        Ticket__c ticket = createTicket();
        Id ticketId = ticket.Id;
        delete ticket;

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryAiController.draftStatusUpdate(ticketId);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException when ticket does not exist.');
    }

    /**
     * @description OpenAI returns a 401 Unauthorized — should throw AuraHandledException
     *              with an error message referencing the status code.
     */
    @IsTest
    static void testDraftStatusUpdateApiError() {
        createSettings(true, 'sk-test-key-123');
        Ticket__c ticket = createTicket();
        Test.setMock(HttpCalloutMock.class,
            new OpenAIMock(401, 'Unauthorized', '{\"error\":{\"message\":\"Invalid API key.\"}}'));

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryAiController.draftStatusUpdate(ticket.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException on non-200 OpenAI response.');
    }

    /**
     * @description OpenAI returns 200 but with an empty choices array — should throw.
     */
    @IsTest
    static void testDraftStatusUpdateEmptyChoices() {
        createSettings(true, 'sk-test-key-123');
        Ticket__c ticket = createTicket();
        Test.setMock(HttpCalloutMock.class, new OpenAIMock(200, 'OK', '{\"choices\":[]}'));

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryAiController.draftStatusUpdate(ticket.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw AuraHandledException when choices array is empty.');
    }

    // ── Mock ─────────────────────────────────────────────────────────────────

    private class OpenAIMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String body;

        /**
         * @description Constructs a mock HTTP response for OpenAI callout tests.
         * @param statusCode The HTTP status code to return.
         * @param status     The HTTP status string (e.g. 'OK', 'Unauthorized').
         * @param body       The response body JSON string.
         */
        public OpenAIMock(Integer statusCode, String status, String body) {
            this.statusCode = statusCode;
            this.status     = status;
            this.body       = body;
        }

        /**
         * @description Returns a pre-configured HttpResponse for any inbound request,
         *              asserting that the request targets the OpenAI API via POST.
         * @param req The outbound HttpRequest being intercepted.
         * @return HttpResponse The configured mock response.
         */
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod(), 'AI callout should be a POST.');
            System.assert(req.getEndpoint().contains('openai.com'), 'Should target the OpenAI API.');

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.body);
            res.setStatusCode(this.statusCode);
            res.setStatus(this.status);
            return res;
        }
    }
}
