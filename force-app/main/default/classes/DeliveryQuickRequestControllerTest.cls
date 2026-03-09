/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryQuickRequestController. Validates work item
 *               creation, AI enhancement flow, input validation, and error handling.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class DeliveryQuickRequestControllerTest {

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static DeliveryHubSettings__c enableAi() {
        DeliveryHubSettings__c s = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            AISuggestionsEnabledBool__c = true,
            OpenAIApiKeyTxt__c = 'sk-test-key-123',
            OpenAIModelTxt__c = 'gpt-3.5-turbo'
        );
        insert s;
        return s;
    }

    // ── Tests: Basic Creation ────────────────────────────────────────────────

    @IsTest
    static void testCreateWorkRequestBasic() {
        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'Fix login bug', 'High', 'Users cannot log in after password reset', false
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.recordId, 'Record Id should be returned');
        System.assertNotEquals(null, result.recordName, 'Record Name should be returned');

        WorkItem__c wi = [
            SELECT BriefDescriptionTxt__c, PriorityPk__c, StageNamePk__c,
                   IsActiveBool__c, StatusPk__c, DetailsTxt__c
            FROM WorkItem__c
            WHERE Id = :result.recordId
            LIMIT 1
        ];

        System.assertEquals('Fix login bug', wi.BriefDescriptionTxt__c, 'Title should match');
        System.assertEquals('High', wi.PriorityPk__c, 'Priority should match');
        System.assertEquals('Backlog', wi.StageNamePk__c, 'Stage should be Backlog');
        System.assertEquals(true, wi.IsActiveBool__c, 'Should be active');
        System.assertEquals('New', wi.StatusPk__c, 'Status should be New');
        System.assert(wi.DetailsTxt__c.contains('password reset'), 'Description should be stored');
    }

    @IsTest
    static void testCreateWorkRequestDefaultPriority() {
        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'Add dark mode', null, null, false
            );
        Test.stopTest();

        WorkItem__c wi = [
            SELECT PriorityPk__c, DetailsTxt__c
            FROM WorkItem__c
            WHERE Id = :result.recordId
            LIMIT 1
        ];

        System.assertEquals('Medium', wi.PriorityPk__c, 'Default priority should be Medium');
        System.assertEquals(null, wi.DetailsTxt__c, 'Description should be null when not provided');
    }

    @IsTest
    static void testCreateWorkRequestBlankTitleThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryQuickRequestController.createWorkRequest('', 'Medium', null, false);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when title is blank');
    }

    @IsTest
    static void testCreateWorkRequestNullTitleThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryQuickRequestController.createWorkRequest(null, 'Medium', null, false);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when title is null');
    }

    // ── Tests: AI Enhancement ────────────────────────────────────────────────

    @IsTest
    static void testCreateWithAiEnhanceSuccess() {
        enableAi();

        String aiBody = '{"choices":[{"message":{"content":"'
            + '{\\"description\\":\\"A detailed fix for login issues after password reset.\\",'
            + '\\"acceptanceCriteria\\":\\"- Users can log in after reset\\\\n- Error message is shown on failure\\",'
            + '\\"estimatedHours\\":4}'
            + '"}}]}';
        Test.setMock(HttpCalloutMock.class, new AiMock(200, 'OK', aiBody));

        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'Fix login bug', 'High', 'Users cannot log in', true
            );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId, 'Record should be created');

        WorkItem__c wi = [
            SELECT DetailsTxt__c, AcceptanceCriteriaTxt__c, EstimatedHoursNumber__c
            FROM WorkItem__c
            WHERE Id = :result.recordId
            LIMIT 1
        ];

        System.assert(wi.DetailsTxt__c.contains('detailed fix'), 'AI description should be applied');
        System.assert(wi.AcceptanceCriteriaTxt__c.contains('Users can log in'), 'AI criteria should be applied');
        System.assertEquals(4, wi.EstimatedHoursNumber__c, 'AI hours estimate should be applied');
    }

    @IsTest
    static void testCreateWithAiEnhanceNoSettingsSkips() {
        // No AI settings — enhancement should silently skip

        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'New feature', 'Low', null, true
            );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId, 'Record should still be created');

        WorkItem__c wi = [
            SELECT DetailsTxt__c, AcceptanceCriteriaTxt__c
            FROM WorkItem__c
            WHERE Id = :result.recordId
            LIMIT 1
        ];

        System.assertEquals(null, wi.AcceptanceCriteriaTxt__c, 'No AI criteria when AI is disabled');
    }

    @IsTest
    static void testCreateWithAiEnhanceApiError() {
        enableAi();
        Test.setMock(HttpCalloutMock.class, new AiMock(500, 'Server Error', '{"error":"fail"}'));

        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'Broken feature', 'Medium', 'Something broke', true
            );
        Test.stopTest();

        // Record should still be created even though AI failed
        System.assertNotEquals(null, result.recordId, 'Record should be created despite AI failure');

        WorkItem__c wi = [
            SELECT BriefDescriptionTxt__c, AcceptanceCriteriaTxt__c
            FROM WorkItem__c
            WHERE Id = :result.recordId
            LIMIT 1
        ];

        System.assertEquals('Broken feature', wi.BriefDescriptionTxt__c, 'Title should still be set');
        System.assertEquals(null, wi.AcceptanceCriteriaTxt__c, 'No AI criteria when API errors');
    }

    @IsTest
    static void testCreateWithAiEnhanceMalformedJson() {
        enableAi();

        String aiBody = '{"choices":[{"message":{"content":"This is not valid JSON at all"}}]}';
        Test.setMock(HttpCalloutMock.class, new AiMock(200, 'OK', aiBody));

        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'Dashboard widget', 'Medium', null, true
            );
        Test.stopTest();

        // Record should still be created even with malformed AI response
        System.assertNotEquals(null, result.recordId, 'Record should be created despite bad AI JSON');
    }

    @IsTest
    static void testCreateWithAiEnhanceCodeFences() {
        enableAi();

        String aiBody = '{"choices":[{"message":{"content":"```json\\n'
            + '{\\"description\\":\\"Enhanced description with code fences.\\",'
            + '\\"acceptanceCriteria\\":\\"- Works correctly\\",'
            + '\\"estimatedHours\\":2}'
            + '\\n```"}}]}';
        Test.setMock(HttpCalloutMock.class, new AiMock(200, 'OK', aiBody));

        Test.startTest();
        DeliveryQuickRequestController.QuickRequestResult result =
            DeliveryQuickRequestController.createWorkRequest(
                'Code fence test', 'Low', null, true
            );
        Test.stopTest();

        System.assertNotEquals(null, result.recordId, 'Record should be created');
    }

    // ── Mock ─────────────────────────────────────────────────────────────────

    private class AiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String body;

        public AiMock(Integer statusCode, String status, String body) {
            this.statusCode = statusCode;
            this.status     = status;
            this.body       = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.body);
            res.setStatusCode(this.statusCode);
            res.setStatus(this.status);
            return res;
        }
    }
}
