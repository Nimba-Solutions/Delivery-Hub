@isTest
private class KanbanSettingsControllerTest {

    // =================================================================================
    // SECTION 1: getSettings() and saveSettings() Tests
    // =================================================================================

   

    // =================================================================================
    // SECTION 3: HTTP Mock Implementation
    // =================================================================================

    /**
     * @description Mock class to simulate HTTP responses from the OpenAI API.
     */
    private class OpenAIMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String body;
        private Boolean throwException;

        // Constructor for standard responses
        public OpenAIMock(Integer statusCode, String status, String body) {
            this.statusCode = statusCode;
            this.status = status;
            this.body = body;
            this.throwException = false;
        }

        // Constructor to simulate a system-level exception
        public OpenAIMock(Boolean throwEx) {
            this.throwException = throwEx;
        }

        public HttpResponse respond(HttpRequest req) {
            if (this.throwException) {
                // Simulate a system-level failure, like no network connection.
                throw new CalloutException('Callout failed');
            }

            // Create a mock response.
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.body);
            res.setStatusCode(this.statusCode);
            res.setStatus(this.status);
            return res;
        }
    }
}