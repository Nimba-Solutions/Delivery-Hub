/**
 * @name         Delivery Hub Integration Framework
 * @license      BSL 1.1 - See LICENSE.md
 * @description Maps an HttpResponse to an IntegrationDispatcherResult using
 *              status-code rules declared on IntegrationProvider__mdt.
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
     * @param providerConfig The provider config record.
     * @return Configured IntegrationDispatcherResult.
     */
    public static IntegrationDispatcherResult mapResponse(Integer httpStatus, String body, IntegrationProvider__mdt providerConfig) {
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
            r = IntegrationDispatcherResult.terminal('HTTP ' + httpStatus + ' (terminal)', httpStatus, body);
        } else {
            r = IntegrationDispatcherResult.retryable('HTTP ' + httpStatus + ' (retryable)', httpStatus, body);
        }
        return r;
    }

    /**
     * @description Parse status-code rules JSON into a lower-cased map.
     * @param rulesJson Provider's ResponseRulesJsonTxt__c value (may be blank).
     * @return Lower-cased rule map; falls back to defaults on blank/malformed input.
     */
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
     * @param status HTTP status code.
     * @param rules Lower-cased rule map.
     * @return Matched outcome string.
     */
    @TestVisible
    private static String matchRule(Integer status, Map<String, String> rules) {
        if (status == null) {
            return rules.containsKey('default') ? rules.get('default') : 'RetryableFailure';
        }
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
     * @param body Response body string.
     * @param expr Path expression starting with $.
     * @return Extracted value as string, or null when not found.
     */
    @TestVisible
    private static String extractValue(String body, String expr) {
        try {
            Object root = JSON.deserializeUntyped(body);
            String path = expr.startsWith('$.') ? expr.substring(2) : expr;
            Object current = root;
            for (String segment : path.split('\\.')) {
                if (current == null) {
                    return null;
                }
                if (segment.contains('[') && segment.endsWith(']')) {
                    Integer bracket = segment.indexOf('[');
                    String key = segment.substring(0, bracket);
                    Integer idx = Integer.valueOf(segment.substring(bracket + 1, segment.length() - 1));
                    Map<String, Object> mapVal = asMap(current);
                    if (mapVal != null) {
                        current = mapVal.get(key);
                    }
                    List<Object> listVal = asList(current);
                    if (listVal != null) {
                        current = (idx < listVal.size()) ? listVal[idx] : null;
                    }
                } else {
                    Map<String, Object> mapVal = asMap(current);
                    if (mapVal == null) {
                        return null;
                    }
                    current = mapVal.get(segment);
                }
            }
            return current == null ? null : String.valueOf(current);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Try-cast Object to Map.
     * @param o Object to cast.
     * @return Cast Map or null if not a Map.
     */
    private static Map<String, Object> asMap(Object o) {
        try {
            return (Map<String, Object>) o;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Try-cast Object to List.
     * @param o Object to cast.
     * @return Cast List or null if not a List.
     */
    private static List<Object> asList(Object o) {
        try {
            return (List<Object>) o;
        } catch (Exception e) {
            return null;
        }
    }
}
