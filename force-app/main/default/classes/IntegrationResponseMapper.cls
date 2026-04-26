/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Maps an HttpResponse to an IntegrationDispatcherResult using
 *              status-code rules declared on IntegrationProvider__mdt.
 *
 *              ResponseRulesJsonTxt__c shape:
 *                {
 *                  "200": "Sent",
 *                  "2xx": "Sent",
 *                  "429": "RetryableFailure",
 *                  "4xx": "TerminalFailure",
 *                  "5xx": "RetryableFailure",
 *                  "default": "RetryableFailure"
 *                }
 *
 *              Match precedence: exact code > range pattern (Nxx) > "default".
 *              Falls back to {2xx:Sent, 4xx:TerminalFailure, 5xx:RetryableFailure}
 *              when ResponseRulesJsonTxt__c is blank.
 *
 *              When SuccessParseExprTxt__c is set on the provider AND the
 *              outcome is "Sent", the mapper attempts to extract a value from
 *              the response body using a dotted-path expression. Supported
 *              syntax:
 *                $.id                        — top-level "id" field
 *                $.user.email                — nested map walk
 *                $.choices[0].message.content — array index walk
 *
 *              Extracted value lands in result.responseValue.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class IntegrationResponseMapper {

    private static final Map<String, String> DEFAULT_RULES = new Map<String, String>{
        '2xx' => 'Sent',
        '4xx' => 'TerminalFailure',
        '5xx' => 'RetryableFailure',
        'default' => 'RetryableFailure'
    };

    /**
     * @description Map a response to a dispatcher result.
     * @param httpStatus HTTP status code from the callout.
     * @param body Response body (may be null/empty).
     * @param providerConfig The provider config; rules come from
     *                      ResponseRulesJsonTxt__c, extraction from
     *                      SuccessParseExprTxt__c.
     * @return Configured IntegrationDispatcherResult.
     */
    public static IntegrationDispatcherResult map(Integer httpStatus, String body, IntegrationProvider__mdt providerConfig) {
        Map<String, String> rules = parseRules(providerConfig.ResponseRulesJsonTxt__c);
        String outcome = matchRule(httpStatus, rules);
        IntegrationDispatcherResult r;
        if (outcome == 'Sent') {
            r = IntegrationDispatcherResult.sent(httpStatus, body);
            String parseExpr = providerConfig.SuccessParseExprTxt__c;
            if (String.isNotBlank(parseExpr) && String.isNotBlank(body)) {
                r.responseValue = extractValue(body, parseExpr);
            }
        } else if (outcome == 'TerminalFailure') {
            r = IntegrationDispatcherResult.terminal(
                'HTTP ' + httpStatus + ' (terminal per provider rules)',
                httpStatus, body);
        } else {
            r = IntegrationDispatcherResult.retryable(
                'HTTP ' + httpStatus + ' (retryable per provider rules)',
                httpStatus, body);
        }
        return r;
    }

    @TestVisible
    private static Map<String, String> parseRules(String rulesJson) {
        if (String.isBlank(rulesJson)) {
            return DEFAULT_RULES;
        }
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(rulesJson);
            Map<String, String> out = new Map<String, String>();
            for (String k : parsed.keySet()) {
                out.put(k.toLowerCase(), String.valueOf(parsed.get(k)));
            }
            return out;
        } catch (Exception e) {
            return DEFAULT_RULES;
        }
    }

    /**
     * @description Match a status code to a rule. Order: exact, range, default.
     *              Range syntax: "2xx" matches 200-299, "4xx" matches 400-499.
     * @param status HTTP status code.
     * @param rules Lower-cased rule map.
     * @return Matched outcome string.
     */
    @TestVisible
    private static String matchRule(Integer status, Map<String, String> rules) {
        String exact = String.valueOf(status);
        if (rules.containsKey(exact)) {
            return rules.get(exact);
        }
        String range = (status / 100) + 'xx';
        if (rules.containsKey(range)) {
            return rules.get(range);
        }
        if (rules.containsKey('default')) {
            return rules.get('default');
        }
        return 'RetryableFailure';
    }

    /**
     * @description Extract a value from a JSON body using a dotted-path expression.
     *              Returns null when the path doesn't resolve or body isn't JSON.
     * @param body Response body string.
     * @param expr Path expression starting with "$." (e.g. "$.choices[0].message.content").
     * @return Extracted value as string, or null when not found.
     */
    @TestVisible
    private static String extractValue(String body, String expr) {
        try {
            Object root = JSON.deserializeUntyped(body);
            String path = expr.startsWith('$.') ? expr.substring(2) : expr;
            Object current = root;
            for (String segment : splitPath(path)) {
                if (current == null) { return null; }
                if (segment.contains('[') && segment.endsWith(']')) {
                    Integer bracket = segment.indexOf('[');
                    String key = segment.substring(0, bracket);
                    Integer idx = Integer.valueOf(
                        segment.substring(bracket + 1, segment.length() - 1)
                    );
                    if (current instanceof Map<String, Object>) {
                        current = ((Map<String, Object>) current).get(key);
                    }
                    if (current instanceof List<Object>) {
                        List<Object> arr = (List<Object>) current;
                        current = (idx < arr.size()) ? arr[idx] : null;
                    }
                } else if (current instanceof Map<String, Object>) {
                    current = ((Map<String, Object>) current).get(segment);
                } else {
                    return null;
                }
            }
            return current == null ? null : String.valueOf(current);
        } catch (Exception e) {
            return null;
        }
    }

    private static List<String> splitPath(String path) {
        return path.split('\\.');
    }
}
