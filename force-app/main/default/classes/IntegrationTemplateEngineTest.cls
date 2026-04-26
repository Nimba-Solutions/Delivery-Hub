/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for IntegrationTemplateEngine. Covers basic substitution,
 *              nested-path walking, default-value fallback, edge cases.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class IntegrationTemplateEngineTest {

    @IsTest
    static void rendersBasicSubstitution() {
        String out = IntegrationTemplateEngine.render(
            '{"text":"{{message}}"}',
            new Map<String, Object>{ 'message' => 'hello world' });
        System.assertEquals('{"text":"hello world"}', out);
    }

    @IsTest
    static void rendersMultipleSubstitutions() {
        String out = IntegrationTemplateEngine.render(
            '{"a":"{{x}}","b":"{{y}}"}',
            new Map<String, Object>{ 'x' => '1', 'y' => '2' });
        System.assertEquals('{"a":"1","b":"2"}', out);
    }

    @IsTest
    static void rendersNestedPath() {
        String out = IntegrationTemplateEngine.render(
            'user={{user.name}}',
            new Map<String, Object>{
                'user' => new Map<String, Object>{ 'name' => 'glen' }
            });
        System.assertEquals('user=glen', out);
    }

    @IsTest
    static void rendersDefaultWhenMissing() {
        String out = IntegrationTemplateEngine.render(
            'val={{missing|default:fallback}}',
            new Map<String, Object>{});
        System.assertEquals('val=fallback', out);
    }

    @IsTest
    static void rendersDefaultWhenNull() {
        String out = IntegrationTemplateEngine.render(
            'val={{key|default:fb}}',
            new Map<String, Object>{ 'key' => null });
        System.assertEquals('val=fb', out);
    }

    @IsTest
    static void rendersEmptyWhenMissingNoDefault() {
        String out = IntegrationTemplateEngine.render(
            'val={{absent}}',
            new Map<String, Object>{});
        System.assertEquals('val=', out);
    }

    @IsTest
    static void rendersBlankTemplateAsEmpty() {
        System.assertEquals('', IntegrationTemplateEngine.render('', null));
        System.assertEquals('', IntegrationTemplateEngine.render(null, null));
    }

    @IsTest
    static void rendersTemplateWithoutTokens() {
        String t = '{"static":true}';
        System.assertEquals(t, IntegrationTemplateEngine.render(t, new Map<String, Object>()));
    }

    @IsTest
    static void rendersIntegerValueAsString() {
        String out = IntegrationTemplateEngine.render(
            'count={{n}}',
            new Map<String, Object>{ 'n' => 42 });
        System.assertEquals('count=42', out);
    }

    @IsTest
    static void rendersBooleanAsLowercase() {
        String out = IntegrationTemplateEngine.render(
            'flag={{b}}',
            new Map<String, Object>{ 'b' => true });
        System.assertEquals('flag=true', out);
    }

    @IsTest
    static void deepNestedPathReturnsValue() {
        Object r = IntegrationTemplateEngine.walkPath(
            'a.b.c',
            new Map<String, Object>{
                'a' => new Map<String, Object>{
                    'b' => new Map<String, Object>{ 'c' => 'leaf' }
                }
            });
        System.assertEquals('leaf', String.valueOf(r));
    }

    @IsTest
    static void nestedPathStopsAtNonMap() {
        Object r = IntegrationTemplateEngine.walkPath(
            'a.b.c',
            new Map<String, Object>{ 'a' => 'string-not-map' });
        System.assertEquals(null, r);
    }

    @IsTest
    static void resolveExpressionStripsWhitespace() {
        String out = IntegrationTemplateEngine.render(
            'v={{ key }}',
            new Map<String, Object>{ 'key' => 'ok' });
        System.assertEquals('v=ok', out);
    }
}
