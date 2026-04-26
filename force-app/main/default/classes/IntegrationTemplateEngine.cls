/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Minimal mustache-style template renderer. The framework uses it
 *              to render IntegrationProvider__mdt.RequestBodyTemplateTxt__c
 *              and EndpointPathTxt__c against the dispatch payload Map.
 *
 *              Supported syntax:
 *                {{key}}                    — substitute payload['key'] as string
 *                {{nested.path}}            — walk Map<String,Object> by dot path
 *                {{key|default:fallback}}   — use fallback when key missing/null
 *
 *              Deliberately NOT supported (keeps the engine readable):
 *                - Conditionals ({{#if}}/{{else}})
 *                - Iteration ({{#each}})
 *                - Custom helpers
 *                - HTML escaping (we render JSON / URLs, not HTML)
 *
 *              When subscribers hit something this minimal engine can't do,
 *              the escape hatch is the IIntegrationTemplateExtension —
 *              compute the value imperatively, set it as a header, done.
 *
 *              JSON-safety: values are inserted verbatim. Subscribers must
 *              encode strings in their templates appropriately. For the
 *              common JSON-body case use {{key}} inside a quoted string
 *              and accept that the substituted value should not contain
 *              unescaped quotes (i.e. preprocess in the caller, or use the
 *              extension hook to JSON-encode the whole payload).
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class IntegrationTemplateEngine {

    /**
     * @description Render a template string against a payload Map. Missing
     *              keys without a default render as the empty string.
     * @param template Template source. Null returns empty string.
     * @param payload Payload Map. Null treated as empty.
     * @return Rendered string with all {{...}} substitutions resolved.
     */
    public static String render(String template, Map<String, Object> payload) {
        if (String.isBlank(template)) {
            return '';
        }
        Map<String, Object> safePayload = payload == null ? new Map<String, Object>() : payload;
        Pattern p = Pattern.compile('\\{\\{([^{}]+)\\}\\}');
        Matcher m = p.matcher(template);
        List<String> parts = new List<String>();
        Integer cursor = 0;
        while (m.find()) {
            parts.add(template.substring(cursor, m.start()));
            parts.add(resolveExpression(m.group(1).trim(), safePayload));
            cursor = m.end();
        }
        parts.add(template.substring(cursor));
        return String.join(parts, '');
    }

    /**
     * @description Resolve a single expression like "key" or "nested.path" or
     *              "key|default:fallback". Returns the resolved value as a
     *              string, or the fallback (or empty) when missing.
     * @param expr Expression body (without the {{ }} wrappers).
     * @param payload Payload Map to resolve against.
     * @return Resolved string value.
     */
    @TestVisible
    private static String resolveExpression(String expr, Map<String, Object> payload) {
        String pathPart = expr;
        String fallback = '';
        Boolean hasFallback = false;
        Integer pipe = expr.indexOf('|');
        if (pipe >= 0) {
            pathPart = expr.substring(0, pipe).trim();
            String rest = expr.substring(pipe + 1).trim();
            if (rest.startsWith('default:')) {
                fallback = rest.substring('default:'.length());
                hasFallback = true;
            }
        }
        Object value = walkPath(pathPart, payload);
        if (value == null) {
            return hasFallback ? fallback : '';
        }
        return String.valueOf(value);
    }

    /**
     * @description Walk a dotted path through nested Maps. Stops at first
     *              non-Map / null intermediate. Returns null when the path
     *              doesn't resolve.
     * @param path Dotted path like "user.id" or "data.records.0".
     * @param root Root Map to walk from.
     * @return Resolved value or null.
     */
    @TestVisible
    private static Object walkPath(String path, Map<String, Object> root) {
        if (String.isBlank(path)) {
            return null;
        }
        List<String> parts = path.split('\\.');
        Object current = root;
        for (String part : parts) {
            Map<String, Object> mapVal;
            try {
                mapVal = (Map<String, Object>) current;
            } catch (Exception e) {
                return null;
            }
            if (mapVal == null) {
                return null;
            }
            current = mapVal.get(part);
            if (current == null) {
                return null;
            }
        }
        return current;
    }
}
