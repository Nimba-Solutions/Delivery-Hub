/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for IntegrationResponseMapper · status-code rule matching,
 *              dotted-path body extraction, default rules behavior.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class IntegrationResponseMapperTest {

    private static IntegrationProvider__mdt cfgWith(String rules, String parseExpr) {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'Test_Provider';
        cfg.ResponseRulesJsonTxt__c = rules;
        cfg.SuccessParseExprTxt__c = parseExpr;
        return cfg;
    }

    @IsTest
    static void exactCodeRuleWins() {
        IntegrationProvider__mdt cfg = cfgWith(
            '{"200":"Sent","2xx":"RetryableFailure"}', null);
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(200, '{}', cfg);
        System.assertEquals('Sent', r.statusCode);
    }

    @IsTest
    static void rangeMatchesWhenNoExact() {
        IntegrationProvider__mdt cfg = cfgWith(
            '{"4xx":"TerminalFailure"}', null);
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(404, '', cfg);
        System.assertEquals('TerminalFailure', r.statusCode);
    }

    @IsTest
    static void defaultRuleMatchesWhenNothingElse() {
        IntegrationProvider__mdt cfg = cfgWith(
            '{"200":"Sent","default":"RetryableFailure"}', null);
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(503, '', cfg);
        System.assertEquals('RetryableFailure', r.statusCode);
    }

    @IsTest
    static void blankRulesUsesBuiltinDefaults() {
        IntegrationProvider__mdt cfg = cfgWith(null, null);
        System.assertEquals('Sent',
            IntegrationResponseMapper.mapResponse(200, '', cfg).statusCode);
        System.assertEquals('TerminalFailure',
            IntegrationResponseMapper.mapResponse(400, '', cfg).statusCode);
        System.assertEquals('RetryableFailure',
            IntegrationResponseMapper.mapResponse(500, '', cfg).statusCode);
    }

    @IsTest
    static void malformedRulesFallsBackToDefaults() {
        IntegrationProvider__mdt cfg = cfgWith('not-json', null);
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(200, '', cfg);
        System.assertEquals('Sent', r.statusCode);
    }

    @IsTest
    static void parseExprExtractsTopLevel() {
        IntegrationProvider__mdt cfg = cfgWith(null, '$.id');
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(
            200, '{"id":"abc-123"}', cfg);
        System.assertEquals('Sent', r.statusCode);
        System.assertEquals('abc-123', r.responseValue);
    }

    @IsTest
    static void parseExprExtractsNested() {
        IntegrationProvider__mdt cfg = cfgWith(null, '$.user.email');
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(
            200, '{"user":{"email":"a@b.com"}}', cfg);
        System.assertEquals('a@b.com', r.responseValue);
    }

    @IsTest
    static void parseExprExtractsArrayIndex() {
        IntegrationProvider__mdt cfg = cfgWith(null, '$.choices[0].message.content');
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(200,
            '{"choices":[{"message":{"role":"assistant","content":"hi"}}]}', cfg);
        System.assertEquals('hi', r.responseValue);
    }

    @IsTest
    static void parseExprMissingPathReturnsNull() {
        IntegrationProvider__mdt cfg = cfgWith(null, '$.absent.path');
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(
            200, '{"id":"x"}', cfg);
        System.assertEquals('Sent', r.statusCode);
        System.assertEquals(null, r.responseValue);
    }

    @IsTest
    static void parseExprOnFailureIsSkipped() {
        IntegrationProvider__mdt cfg = cfgWith(null, '$.id');
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(
            500, '{"id":"x"}', cfg);
        System.assertEquals('RetryableFailure', r.statusCode);
        System.assertEquals(null, r.responseValue);
    }

    @IsTest
    static void retryableMessageReferencesHttpCode() {
        IntegrationProvider__mdt cfg = cfgWith(null, null);
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(503, '', cfg);
        System.assertEquals(503, r.httpStatusCode);
        System.assert(r.statusMessage.contains('503'));
    }

    @IsTest
    static void terminalMessageReferencesHttpCode() {
        IntegrationProvider__mdt cfg = cfgWith(null, null);
        IntegrationDispatcherResult r = IntegrationResponseMapper.mapResponse(401, '', cfg);
        System.assertEquals(401, r.httpStatusCode);
        System.assert(r.statusMessage.contains('401'));
    }
}
